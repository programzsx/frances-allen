#!/usr/bin/env python3
"""
batch_qa.py — 批量导入题目到 Frances Allen 知识问答系统

读取同级目录的 qa.md，解析简化标记格式，
通过 REST API 按条创建 QA 题目。

qa.md 格式:
    # 题库名称           ← 题库行（# + 空格 + 名称）
        后续题目归入此题库，直到下一个 # 行。

    题目文本第一行        ← 题目行（题库行到答案行之间的所有行）
    题目文本第二行
    - 答案文本           ← 答案行（- + 空格 + 答案）
    ----                 ← 分隔行（四个短横，分隔 Q&A 对）

完整示例:
    # 计算机基础
    HTTP的默认端口号是___。
    - 80
    ----
    JVM的全称是___。
    - Java Virtual Machine
    ----
    # 网络协议
    TCP三次握手中，客户端最后发送___包。
    - ACK

用法:
    python3 batch_qa.py                        # 读取同目录 qa.md
    python3 batch_qa.py /path/to/qa.md         # 读取指定文件
"""

import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

# ── 配置 ──────────────────────────────────────────────
API_BASE = "http://8.160.174.178:8000"
REQUEST_TIMEOUT = 30  # 秒

# ── 标记 ──────────────────────────────────────────────
BANK_HEADER_RE = re.compile(r"^#\s+(.+)$")        # # 题库名称
ANSWER_LINE_RE = re.compile(r"^-\s+(.+)$")         # - 答案文本
SEPARATOR_RE   = re.compile(r"^-{4,}$")            # ---- 分隔行


# ═══════════════════════════════════════════════════════
#  API 层
# ═══════════════════════════════════════════════════════

def _request(method, path, data=None):
    url = f"{API_BASE}{path}"
    headers = {"Content-Type": "application/json"}
    body = json.dumps(data, ensure_ascii=False).encode("utf-8") if data else None
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", errors="replace")
        print(f"  ✗ HTTP {e.code}: {detail[:300]}")
        return None
    except urllib.error.URLError as e:
        print(f"  ✗ 网络错误: {e.reason}")
        return None
    except json.JSONDecodeError:
        print(f"  ✗ 响应 JSON 解析失败")
        return None


def find_bank(name):
    """模糊搜索题库，精确匹配名称后返回 (id, name)"""
    params = urllib.parse.urlencode({"keyword": name, "page_size": 10})
    resp = _request("GET", f"/api/banks?{params}")
    if resp is None or "items" not in resp:
        return None
    for item in resp["items"]:
        if item["name"] == name:
            return item["id"], item["name"]
    return None


def create_bank(name):
    """创建题库，返回 (id, name)"""
    resp = _request("POST", "/api/banks", {"name": name})
    if resp and "id" in resp:
        return resp["id"], resp["name"]
    return None


def find_or_create_bank(name):
    """查找题库，不存在则自动创建"""
    result = find_bank(name)
    if result:
        return result
    print(f"  题库「{name}」不存在，自动创建...")
    result = create_bank(name)
    if result:
        print(f"  ✓ 题库「{name}」创建成功 (id={result[0]})")
    else:
        print(f"  ✗ 题库「{name}」创建失败")
    return result


def create_qa(bank_id, question, answers):
    """创建题目，返回 (success: bool, result)"""
    body = {
        "question": question,
        "answer": answers,
        "category_id": bank_id,
        "sort_order": 0,
        "score": 0,
    }
    resp = _request("POST", "/api/qas", body)
    if resp and "id" in resp:
        return True, resp["id"]
    return False, resp


# ═══════════════════════════════════════════════════════
#  解析器
# ═══════════════════════════════════════════════════════

class QAPair:
    """一个 Q&A 对"""
    __slots__ = ("question", "answer")
    def __init__(self, question="", answer=""):
        self.question = question
        self.answer = answer


class BankSection:
    """一个题库段落"""
    __slots__ = ("name", "qas")
    def __init__(self, name):
        self.name = name
        self.qas = []  # list[QAPair]


def parse_qa_md(content):
    """
    解析 qa.md，返回 [BankSection, ...]

    格式规则:
        # 题库名称               → 题库行
        题目文本（可多行）         → 题目行
        - 答案文本                → 答案行
        ----                     → 分隔行（Q&A 对之间）

    解析逻辑:
        - 扫描每一行
        - # xxx → 切换题库，提交上一个题库
        - - xxx → 保存答案，提交当前 Q&A 对
        - ---- → 跳过（纯装饰分隔符）
        - 其他  → 累积为题目文本
    """
    lines = content.splitlines()
    sections = []
    current_section = None
    question_lines = []
    current_answer = ""

    def _flush_qa():
        """将当前题目+答案提交到当前题库"""
        nonlocal question_lines, current_answer
        q_text = "\n".join(question_lines).strip()
        if q_text and current_answer and current_section:
            current_section.qas.append(QAPair(question=q_text, answer=current_answer))
        question_lines = []
        current_answer = ""

    def _flush_section():
        """提交当前题库到 sections 列表"""
        nonlocal current_section
        if current_section and current_section.qas:
            sections.append(current_section)
        current_section = None

    for raw in lines:
        line = raw.rstrip("\r")

        # ── # 题库行 ──
        m = BANK_HEADER_RE.match(line)
        if m:
            _flush_qa()               # 先提交上一个 Q&A
            _flush_section()          # 再提交上一个题库
            current_section = BankSection(m.group(1).strip())
            continue

        # 还没遇到任何一个题库行 → 跳过
        if current_section is None:
            continue

        # ── - 答案行 ──
        m = ANSWER_LINE_RE.match(line)
        if m:
            current_answer = m.group(1).strip()
            _flush_qa()               # Q&A 完整 → 提交
            continue

        # ── ---- 分隔行 ──
        if SEPARATOR_RE.match(line):
            # 分隔行只是装饰，不影响解析
            # 如果分隔行前有未提交的题目文本（无答案），丢弃
            if question_lines and not current_answer:
                q_preview = "\n".join(question_lines).strip()[:40]
                print(f"  ⚠ 分隔行前有未配对题目文本，已丢弃: {q_preview}...")
                question_lines = []
            continue

        # ── 题目行（普通文本） ──
        # 跳过全空行（题目内部的空行保留，但首尾空行去掉）
        question_lines.append(line)

    # EOF 收尾
    _flush_qa()
    _flush_section()

    return sections


# ═══════════════════════════════════════════════════════
#  主流程
# ═══════════════════════════════════════════════════════

def main():
    # 1. 确定文件路径
    script_dir = os.path.dirname(os.path.abspath(__file__))
    if len(sys.argv) > 1:
        md_path = sys.argv[1]
    else:
        md_path = os.path.join(script_dir, "qa.md")

    if not os.path.isfile(md_path):
        print(f"✗ 文件不存在: {md_path}")
        sys.exit(1)

    print(f"📖 读取: {md_path}")
    print(f"🌐 API: {API_BASE}")
    print()

    with open(md_path, "r", encoding="utf-8") as f:
        content = f.read()

    if not content.strip():
        print("⚠ qa.md 为空，无需导入")
        sys.exit(0)

    # 2. 解析
    sections = parse_qa_md(content)
    if not sections:
        print("✗ 未解析到任何题目，请检查 qa.md 格式。")
        print("  期望格式：")
        print("    # 题库名称")
        print("    题目文本（可多行）")
        print("    - 答案文本")
        print("    ----")
        sys.exit(1)

    total_q = sum(len(s.qas) for s in sections)
    print(f"📊 解析完成: {len(sections)} 个题库, {total_q} 道题目")
    print()

    # 3. 逐题库插入
    ok = 0
    fail = 0
    failed_sections = []  # 记录失败的题库及题目数

    for si, sec in enumerate(sections, 1):
        print(f"── [{si}/{len(sections)}] 题库: {sec.name} ({len(sec.qas)} 题) ──")

        result = find_or_create_bank(sec.name)
        if result is None:
            print(f"  ✗ 题库创建失败，跳过 {len(sec.qas)} 题")
            fail += len(sec.qas)
            failed_sections.append(f"题库「{sec.name}」: 题库创建失败，{len(sec.qas)} 题未导入")
            continue
        bank_id, bank_name = result
        print(f"  题库 ID: {bank_id}")

        section_ok = 0
        section_fail = 0

        for i, qa in enumerate(sec.qas, 1):
            label = f"  [{i}/{len(sec.qas)}]"
            preview = qa.question.replace("\n", " / ")[:55]

            success, info = create_qa(bank_id, qa.question, [qa.answer])
            if success:
                print(f"{label} ✓ {preview}... (id={info})")
                ok += 1
                section_ok += 1
            else:
                print(f"{label} ✗ {preview}... 失败")
                fail += 1
                section_fail += 1
                failed_sections.append(f"「{sec.name}」第{i}题: {preview}")

        print(f"  结果: ✓ {section_ok}  ✗ {section_fail}")
        print()

    # 4. 汇总
    print("═" * 55)
    print(f"✅ 成功: {ok}")
    print(f"❌ 失败: {fail}")
    print(f"📝 合计: {ok + fail}")
    print()

    # 5. 全部成功 → 清空 qa.md；有失败 → 保留
    if fail == 0 and ok > 0:
        with open(md_path, "w", encoding="utf-8") as f:
            f.write("")
        print(f"🗑  全部成功，已清空: {md_path}")
    elif fail > 0:
        print(f"⚠  有 {fail} 条失败，qa.md 已保留不删除。")
        print(f"   失败明细:")
        for fs in failed_sections:
            print(f"     - {fs}")

    sys.exit(1 if fail > 0 else 0)


if __name__ == "__main__":
    main()
