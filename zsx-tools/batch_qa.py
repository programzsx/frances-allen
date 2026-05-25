#!/usr/bin/env python3
"""
batch_qa.py — 批量导入题目到 Frances Allen 知识问答系统

读取同级目录的 batch.md，解析 `#` / `$$$$` / `%%%%` 标记格式，
通过 REST API 按条创建 QA 题目（基于最新 QaCreateBO schema）。

用法:
    python3 batch_qa.py                        # 读取同目录 batch.md
    python3 batch_qa.py /path/to/file.md       # 读取指定文件

batch.md 格式:
    # 题库名称
        定义题库，后续题目归入此题库（直到下一个 # 或 EOF）。
        题库不存在则自动创建。

    $$$$
        题目开始标记。以下行到 %%%% 之间为题目文本。
        题目中 ___ 表示填空占位符。可多行。

    题目属性行（可选，位于 $$$$ 和 %%%% 之间）：
        @score 1      掌握程度 -1(不会)/0(模糊)/1(掌握)，默认 0
        @sort 10      排序值，默认 0
        @tag 标签1,标签2    逗号分隔的标签名称

    %%%%
        答案开始标记。每行一个答案，与题目中 ___ 一一对应。
        直到下一个 $$$$ / # 或 EOF。

完整示例:
    # Java
    $$$$
    Java中___关键字用于实现接口。
    @score 1
    @sort 5
    %%%%
    implements
    $$$$
    JVM的全称是___。
    %%%%
    Java Virtual Machine

    # 计算机网络
    $$$$
    HTTP的默认端口号是___。
    %%%%
    80
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

# ── 分隔标记 ──────────────────────────────────────────
BANK_HEADER_RE = re.compile(r"^#\s+(.+)$")
QA_START = "$$$$"
ANSWER_START = "%%%%"
ATTR_RE = re.compile(r"^@(\w+)\s+(.+)$")  # @key value


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
    params = urllib.parse.urlencode({"keyword": name, "page_size": 10})
    resp = _request("GET", f"/api/banks?{params}")
    if resp is None or "items" not in resp:
        return None
    for item in resp["items"]:
        if item["name"] == name:
            return item["id"], item["name"]
    return None


def create_bank(name):
    resp = _request("POST", "/api/banks", {"name": name})
    if resp and "id" in resp:
        return resp["id"], resp["name"]
    return None


def find_or_create_bank(name):
    result = find_bank(name)
    if result:
        return result
    print(f"  题库「{name}」不存在，自动创建...")
    result = create_bank(name)
    if result:
        print(f"  ✓ 题库「{name}」创建成功 (id={result[0]})")
    return result


def create_qa(bank_id, question, answers, *, sort_order=0, score=0, tag_id=None):
    """创建题目，所有字段对齐 QaCreateBO schema。"""
    body = {
        "question": question,
        "answer": answers,
        "category_id": bank_id,
        "sort_order": sort_order,
        "score": score,
    }
    if tag_id:
        body["tag_id"] = tag_id

    resp = _request("POST", "/api/qas", body)
    if resp and "id" in resp:
        return True, resp["id"]
    return False, resp


# ═══════════════════════════════════════════════════════
#  解析器
# ═══════════════════════════════════════════════════════

class QAItem:
    __slots__ = ("question", "answers", "score", "sort_order", "tag_id")
    def __init__(self):
        self.question = ""
        self.answers = []
        self.score = 0
        self.sort_order = 0
        self.tag_id = None  # list[str] | None


class BankSection:
    __slots__ = ("name", "qas")
    def __init__(self, name):
        self.name = name
        self.qas = []


def parse_batch_md(content):
    """解析 batch.md，返回 [BankSection, ...]"""
    lines = content.splitlines()
    sections = []
    current_section = None
    state = "out"          # out | in_question | in_answer
    current_qa = None

    for raw in lines:
        line = raw.rstrip("\r")

        # ── # 题库头 ──
        m = BANK_HEADER_RE.match(line)
        if m:
            _commit_qa(state, current_qa, current_section)
            if current_section and current_section.qas:
                sections.append(current_section)
            current_section = BankSection(m.group(1).strip())
            current_qa = None
            state = "out"
            continue

        # ── $$$$ → 新题目 ──
        if line.strip() == QA_START:
            _commit_qa(state, current_qa, current_section)
            current_qa = QAItem()
            state = "in_question"
            continue

        # ── %%%% → 进入答案 ──
        if line.strip() == ANSWER_START:
            current_qa.question = current_qa.question.strip() if current_qa else ""
            state = "in_answer"
            continue

        # ── 内容行 ──
        if state == "in_question":
            attr = ATTR_RE.match(line.strip())
            if attr:
                key, val = attr.group(1), attr.group(2).strip()
                if key == "score":
                    try:
                        current_qa.score = max(-1, min(1, int(val)))
                    except ValueError:
                        print(f"  ⚠ 无效 score 值: {val}，已忽略")
                elif key == "sort":
                    try:
                        current_qa.sort_order = int(val)
                    except ValueError:
                        print(f"  ⚠ 无效 sort 值: {val}，已忽略")
                elif key == "tag":
                    current_qa.tag_id = [t.strip() for t in val.split(",") if t.strip()]
            else:
                if current_qa.question:
                    current_qa.question += "\n" + line
                else:
                    current_qa.question = line

        elif state == "in_answer":
            stripped = line.strip()
            if stripped:
                current_qa.answers.append(stripped)

    # EOF flush
    _commit_qa(state, current_qa, current_section)
    if current_section and current_section.qas:
        sections.append(current_section)

    return sections


def _commit_qa(state, qa, section):
    if state == "in_answer" and qa and qa.question and qa.answers:
        if section:
            section.qas.append(qa)


# ═══════════════════════════════════════════════════════
#  主流程
# ═══════════════════════════════════════════════════════

def main():
    # 1. 确定文件路径
    if len(sys.argv) > 1:
        md_path = sys.argv[1]
    else:
        md_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "batch.md")

    if not os.path.isfile(md_path):
        print(f"✗ 文件不存在: {md_path}")
        sys.exit(1)

    print(f"📖 读取: {md_path}")
    with open(md_path, "r", encoding="utf-8") as f:
        content = f.read()

    # 2. 解析
    sections = parse_batch_md(content)
    if not sections:
        print("✗ 未解析到任何题目，请检查 batch.md 格式。")
        sys.exit(1)

    total_q = sum(len(s.qas) for s in sections)
    print(f"📊 解析完成: {len(sections)} 个题库, {total_q} 道题目\n")

    # 3. 逐题库创建
    ok = fail = 0

    for sec in sections:
        print(f"── 题库: {sec.name} ({len(sec.qas)} 题) ──")

        result = find_or_create_bank(sec.name)
        if result is None:
            print(f"  ✗ 题库创建失败，跳过 {len(sec.qas)} 题")
            fail += len(sec.qas)
            continue
        bank_id, _ = result

        for i, qa in enumerate(sec.qas, 1):
            label = f"  [{i}/{len(sec.qas)}]"
            preview = qa.question.replace("\n", " / ")[:55]
            extras = []
            if qa.score != 0:
                extras.append(f"score={qa.score}")
            if qa.sort_order != 0:
                extras.append(f"sort={qa.sort_order}")
            if qa.tag_id:
                extras.append(f"tags={','.join(qa.tag_id)}")
            extra_str = f" ({', '.join(extras)})" if extras else ""

            success, info = create_qa(
                bank_id, qa.question, qa.answers,
                sort_order=qa.sort_order,
                score=qa.score,
                tag_id=qa.tag_id,
            )
            if success:
                print(f"{label} ✓ {preview}...{extra_str} (id={info})")
                ok += 1
            else:
                print(f"{label} ✗ {preview}... 失败")
                fail += 1
        print()

    # 4. 汇总
    print("═" * 50)
    print(f"✅ 成功: {ok}")
    print(f"❌ 失败: {fail}")
    print(f"📝 合计: {ok + fail}")
    sys.exit(1 if fail > 0 else 0)


if __name__ == "__main__":
    main()
