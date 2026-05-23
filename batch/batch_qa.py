#!/usr/bin/env python3
"""
batch_qa.py — 批量导入题目到 Frances Allen 知识问答系统

读取同级目录的 batch.md，解析 `#` / `$$$$` / `%%%%` 标记格式，
通过 REST API 按条创建 QA 题目。

用法:
    python3 batch_qa.py                        # 读取 batch.md
    python3 batch_qa.py /path/to/other.md      # 读取指定文件

batch.md 格式:
    # 题库名称          → 题库名，后续题目都归入此题库（直到下一个 # 或 EOF）
    $$$$               → 题目开始，到 %%%% 之间的内容是 question
        image:URL      → 题目中嵌入的图片 URL（可选行，中英文冒号均支持）
    %%%%               → 答案开始，每行一个答案（直到下一个 $$$$ / # 或 EOF）
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
BANK_HEADER_RE = re.compile(r"^#\s+(.+)$")          # # 题库名
QA_START = "$$$$"                                     # 题目开始
ANSWER_START = "%%%%"                                 # 答案开始
IMAGE_LINE_RE = re.compile(r"^image[：:]\s*(.+)$")    # image：URL 或 image:URL


# ═══════════════════════════════════════════════════════
#  API 层
# ═══════════════════════════════════════════════════════

def _request(method, path, data=None):
    """发送 HTTP 请求，返回解析后的 JSON 或报错退出。"""
    url = f"{API_BASE}{path}"
    headers = {"Content-Type": "application/json"}

    if data is not None:
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
    else:
        body = None

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
    """按名称搜索题库，精确匹配返回 (id, name) 或 None。"""
    params = urllib.parse.urlencode({"keyword": name, "page_size": 10})
    resp = _request("GET", f"/api/banks?{params}")
    if resp is None or "items" not in resp:
        return None
    for item in resp["items"]:
        if item["name"] == name:
            return item["id"], item["name"]
    return None


def create_bank(name):
    """创建题库，返回 (id, name) 或 None。"""
    resp = _request("POST", "/api/banks", {"name": name})
    if resp and "id" in resp:
        return resp["id"], resp["name"]
    return None


def find_or_create_bank(name):
    """查找题库，不存在则创建。返回 (id, name) 或 None。"""
    result = find_bank(name)
    if result:
        return result
    print(f"  题库「{name}」不存在，自动创建...")
    result = create_bank(name)
    if result:
        print(f"  ✓ 题库「{name}」创建成功 (id={result[0]})")
    return result


def create_qa(bank_id, question, answers, image_url=None):
    """创建题目，返回 (success, id_or_error)。"""
    body = {
        "question": question,
        "answer": answers,
        "bank_id": bank_id,
    }
    if image_url:
        body["image_url"] = image_url

    resp = _request("POST", "/api/qas", body)
    if resp and "id" in resp:
        return True, resp["id"]
    return False, resp


# ═══════════════════════════════════════════════════════
#  解析器
# ═══════════════════════════════════════════════════════

def parse_batch_md(content):
    """
    解析 batch.md 文本，返回:
    [
        {
            "bank_name": "阿里云",
            "questions": [
                {"question": "...", "image_url": "...", "answers": ["..."]},
            ]
        },
    ]
    """
    lines = content.splitlines()
    sections = []          # 最终结果
    current_section = None # {"bank_name": str, "questions": [...]}
    state = "out"          # out | in_question | in_answer
    current_question = ""  # 当前题目文本行（多行拼接）
    current_image = None   # 当前题目的图片 URL
    current_answers = []   # 当前题目的答案列表

    for raw in lines:
        line = raw.rstrip("\r")

        # ── 题库头 # ──
        m = BANK_HEADER_RE.match(line)
        if m:
            _flush_qa(state, current_question, current_image, current_answers, current_section)
            if current_section and current_section["questions"]:
                sections.append(current_section)
            current_section = {"bank_name": m.group(1).strip(), "questions": []}
            current_question, current_image, current_answers = "", None, []
            state = "out"
            continue

        # ── $$$$ → 进入题目 ──
        if line.strip() == QA_START:
            _flush_qa(state, current_question, current_image, current_answers, current_section)
            current_question, current_image, current_answers = "", None, []
            state = "in_question"
            continue

        # ── %%%% → 进入答案 ──
        if line.strip() == ANSWER_START:
            # 将已收集的 question 文本整理
            current_question = _clean_question(current_question)
            state = "in_answer"
            continue

        # ── 内容行 ──
        if state == "in_question":
            # 检查是否是 image 行
            im = IMAGE_LINE_RE.match(line.strip())
            if im:
                current_image = im.group(1).strip()
            else:
                if current_question:
                    current_question += "\n" + line
                else:
                    current_question = line
        elif state == "in_answer":
            stripped = line.strip()
            if stripped:
                current_answers.append(stripped)
        # else: state == "out" — 忽略

    # 文件结束：flush 最后一个 QA 和 section
    _flush_qa(state, current_question, current_image, current_answers, current_section)
    if current_section and current_section["questions"]:
        sections.append(current_section)

    return sections


def _flush_qa(state, question, image, answers, section):
    """将积攒的 QA 数据写入 section。"""
    if state == "in_answer" and question.strip() and answers:
        if section is not None:
            section["questions"].append({
                "question": question.strip(),
                "image_url": image,
                "answers": answers,
            })


def _clean_question(text):
    """整理 question 文本：去掉首尾空行，每行 trim。"""
    lines = text.strip().splitlines()
    return "\n".join(l.strip() for l in lines if l.strip())


# ═══════════════════════════════════════════════════════
#  主流程
# ═══════════════════════════════════════════════════════

def main():
    # 1. 确定 batch.md 路径
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

    # 统计
    total_q = sum(len(s["questions"]) for s in sections)
    print(f"📊 解析完成: {len(sections)} 个题库, {total_q} 道题目\n")

    # 3. 逐题库、逐题创建
    ok_count = 0
    fail_count = 0

    for sec in sections:
        bank_name = sec["bank_name"]
        questions = sec["questions"]
        print(f"── 题库: {bank_name} ({len(questions)} 题) ──")

        result = find_or_create_bank(bank_name)
        if result is None:
            print(f"  ✗ 题库「{bank_name}」创建失败，跳过该题库所有题目。")
            fail_count += len(questions)
            continue
        bank_id, _ = result

        for i, q in enumerate(questions, 1):
            label = f"  [{i}/{len(questions)}]"
            q_text = q["question"].replace("\n", " / ")[:60]
            success, info = create_qa(bank_id, q["question"], q["answers"], q.get("image_url"))
            if success:
                print(f"{label} ✓ {q_text}... (id={info})")
                ok_count += 1
            else:
                print(f"{label} ✗ {q_text}... 失败")
                fail_count += 1
        print()

    # 4. 汇总
    print("═" * 50)
    print(f"✅ 成功: {ok_count}")
    print(f"❌ 失败: {fail_count}")
    print(f"📝 合计: {ok_count + fail_count}")


if __name__ == "__main__":
    main()
