"""
Frances Allen — 后端API全量集成测试
版本: v2.0 | 日期: 2026-05-25
目标: http://8.160.174.178:8000
覆盖: 01-prd-spec.md 所有API功能点
"""
import json
import sys
import time
import requests

BASE = "http://8.160.174.178:8000"
TS = str(int(time.time()))[-6:]  # 时间戳后缀确保唯一

passed = 0
failed = 0
errors = []


def test(name, func):
    global passed, failed
    try:
        func()
        print(f"  \033[32m✓\033[0m {name}")
        passed += 1
    except AssertionError as e:
        msg = f"  \033[31m✗\033[0m {name}: {e}"
        print(msg)
        errors.append(msg)
        failed += 1
    except Exception as e:
        msg = f"  \033[31m✗\033[0m {name}: {type(e).__name__}: {e}"
        print(msg)
        errors.append(msg)
        failed += 1


def ok(resp):
    """检查响应是否成功"""
    if resp.status_code == 200:
        data = resp.json()
        if isinstance(data, dict) and data.get("success") is False:
            raise AssertionError(data.get("error", "unknown"))
        return data
    assert resp.status_code == 200, f"status={resp.status_code}, body={resp.text[:200]}"


# ======================== 健康检查 ========================
print("\n========== 健康检查 ==========")


def test_health():
    resp = requests.get(f"{BASE}/")
    assert resp.status_code == 200
    data = resp.json()
    assert data["app"] == "frances-allen"
    assert data["status"] == "running"


test("健康检查 GET /", test_health)

# ======================== 题库管理 ========================
print("\n========== 题库管理 ==========")

bank1 = None
bank2 = None
bn1 = f"Java{TS}"
bn2 = f"Spring{TS}"


def test_create_bank_root():
    global bank1
    data = ok(requests.post(f"{BASE}/api/banks", json={"name": bn1, "sort_order": 0}))
    assert "id" in data, "缺少 id"
    assert "create_time" in data, "缺少 create_time"
    assert "update_time" in data, "缺少 update_time"
    assert data["name"] == bn1, f"name={data['name']}"
    assert data.get("parent_id") is None, f"parent_id={data.get('parent_id')}"
    assert data.get("sort_order") == 0, f"sort_order={data.get('sort_order')}"
    bank1 = data


test("创建根题库 - 全部字段验证", test_create_bank_root)


def test_create_bank_with_sort():
    data = ok(requests.post(f"{BASE}/api/banks", json={"name": bn2, "sort_order": 10}))
    assert data["sort_order"] == 10, f"sort_order={data['sort_order']}"


test("创建题库 - sort_order=10", test_create_bank_with_sort)


def test_create_child_bank():
    global bank2
    data = ok(requests.post(f"{BASE}/api/banks", json={
        "name": f"{bn1}基础", "parent_id": bank1["id"], "sort_order": 0
    }))
    assert data["parent_id"] == bank1["id"]
    bank2 = data


test("创建子题库 - parent_id关联", test_create_child_bank)


def test_create_bank_invalid_parent():
    resp = requests.post(f"{BASE}/api/banks", json={
        "name": f"test{TS}", "parent_id": "nonexistent"
    })
    assert resp.status_code >= 400, f"应报错, got {resp.status_code}"


test("创建题库 - 不存在的parent_id应报错", test_create_bank_invalid_parent)


def test_update_bank():
    data = ok(requests.put(f"{BASE}/api/banks/{bank1['id']}", json={
        "name": f"{bn1}进阶", "sort_order": 5
    }))
    assert data["name"] == f"{bn1}进阶"
    assert data["sort_order"] == 5, f"sort_order={data['sort_order']}"
    assert "update_time" in data


test("更新题库 - name/sort_order/update_time", test_update_bank)


def test_page_banks():
    resp = requests.get(f"{BASE}/api/banks", params={"current_page": 1, "page_size": 10})
    assert resp.status_code == 200
    data = resp.json()
    assert "items" in data
    assert "total" in data
    assert data["total"] >= 2


test("分页查询题库", test_page_banks)


def test_search_banks():
    resp = requests.get(f"{BASE}/api/banks", params={"keyword": bn1})
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] >= 1


test("关键字搜索题库", test_search_banks)


def test_bank_tree():
    resp = requests.get(f"{BASE}/api/banks/tree")
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)


test("题库树形结构", test_bank_tree)


def test_bank_question_counts():
    resp = requests.get(f"{BASE}/api/banks/question-counts")
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, dict)


test("题库题目数量统计", test_bank_question_counts)

# ======================== 标签管理 ========================
print("\n========== 标签管理 ==========")

tag1 = None
tag2 = None
tn1 = f"重点{TS}"
tn2 = f"易错{TS}"


def test_create_tags():
    global tag1, tag2
    data1 = ok(requests.post(f"{BASE}/api/tags", json={"name": tn1, "sort_order": 0}))
    assert "id" in data1
    assert "create_time" in data1
    assert "update_time" in data1
    assert data1["name"] == tn1
    assert data1.get("sort_order") == 0
    tag1 = data1

    data2 = ok(requests.post(f"{BASE}/api/tags", json={"name": tn2, "sort_order": 5}))
    assert data2["sort_order"] == 5
    tag2 = data2


test("创建标签 - 全部字段+sort_order", test_create_tags)


def test_update_tag():
    data = ok(requests.put(f"{BASE}/api/tags/{tag1['id']}", json={
        "name": f"{tn1}核心", "sort_order": 3
    }))
    assert data["name"] == f"{tn1}核心"
    assert data["sort_order"] == 3
    assert "update_time" in data


test("更新标签 - name/sort_order", test_update_tag)


def test_page_tags():
    data = ok(requests.get(f"{BASE}/api/tags", params={"current_page": 1, "page_size": 10}))
    assert "items" in data
    assert "total" in data


test("分页查询标签", test_page_tags)


def test_search_tags():
    data = ok(requests.get(f"{BASE}/api/tags", params={"keyword": tn1}))
    assert data["total"] >= 1


test("关键字搜索标签", test_search_tags)


def test_tag_counts():
    resp = requests.get(f"{BASE}/api/qas/tag-counts")
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, dict) or data is None, f"type={type(data)}"


test("标签题目统计", test_tag_counts)


def test_batch_tags():
    data = ok(requests.post(f"{BASE}/api/tags/batch", json={"ids": [tag1["id"], tag2["id"]]}))
    assert isinstance(data, list)


test("批量获取标签", test_batch_tags)

# ======================== 题目管理 ========================
print("\n========== 题目管理 ==========")

qa1 = None
qa2 = None


def test_create_qa_full():
    global qa1
    data = ok(requests.post(f"{BASE}/api/qas", json={
        "question": f"测试题{TS}出生于___年，毕业于___。",
        "answer": ["1986", "北京电影学院"],
        "image_url": "https://zsx-r7000p.oss-cn-beijing.aliyuncs.com/test.jpg",
        "category_id": bank1["id"],
        "tag_id": [tag1["id"], tag2["id"]],
    }))
    assert "id" in data
    assert data["question"] == f"测试题{TS}出生于___年，毕业于___。"
    assert data["answer"] == ["1986", "北京电影学院"]
    assert data["category_id"] == bank1["id"]
    qa1 = data


test("创建题目 - 全部字段", test_create_qa_full)


def test_create_qa_minimal():
    global qa2
    data = ok(requests.post(f"{BASE}/api/qas", json={
        "question": f"1+1=___?{TS}",
        "answer": ["2"],
    }))
    assert data.get("image_url") is None
    assert data.get("category_id") is None
    assert data.get("tag_id") is None
    qa2 = data


test("创建题目 - 无图无标签", test_create_qa_minimal)


def test_create_qa_invalid_bank():
    resp = requests.post(f"{BASE}/api/qas", json={
        "question": "test", "answer": ["a"], "category_id": "nonexistent"
    })
    assert resp.status_code >= 400


test("创建题目 - 不存在的category_id", test_create_qa_invalid_bank)


def test_get_qa():
    data = ok(requests.get(f"{BASE}/api/qas/{qa1['id']}"))
    assert data["id"] == qa1["id"]


test("获取题目详情", test_get_qa)


def test_update_qa():
    data = ok(requests.put(f"{BASE}/api/qas/{qa1['id']}", json={
        "question": f"新题{TS}",
        "answer": ["答案1"],
    }))
    assert data["question"] == f"新题{TS}"
    assert data["answer"] == ["答案1"]


test("更新题目", test_update_qa)


def test_update_qa_stats():
    ok(requests.put(f"{BASE}/api/qas/{qa1['id']}", json={
        "total": 10, "right": 7, "wrong": 3,
    }))


test("更新题目统计字段", test_update_qa_stats)


def test_page_qas():
    data = ok(requests.get(f"{BASE}/api/qas", params={"current_page": 1, "page_size": 10}))
    assert "items" in data
    assert "total" in data


test("分页查询题目", test_page_qas)


def test_page_qas_by_bank():
    data = ok(requests.get(f"{BASE}/api/qas", params={"category_id": bank1["id"]}))
    assert data["total"] >= 1
    for item in data["items"]:
        assert item["category_id"] == bank1["id"]


test("按题库筛选题目", test_page_qas_by_bank)


def test_page_qas_by_tag():
    ok(requests.get(f"{BASE}/api/qas", params={"tag_id": tag1["id"]}))


test("按标签筛选题目", test_page_qas_by_tag)


def test_search_qas():
    data = ok(requests.get(f"{BASE}/api/qas", params={"keyword": f"新题{TS}"}))
    assert data["total"] >= 1


test("关键字搜索题目", test_search_qas)


def test_random_qas():
    resp = requests.get(f"{BASE}/api/qas/random/list", params={"limit": 5})
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert len(data) <= 5


test("全局随机题目", test_random_qas)


def test_random_qas_by_bank():
    resp = requests.get(f"{BASE}/api/qas/random/list", params={"limit": 5, "category_id": bank1["id"]})
    assert resp.status_code == 200


test("按题库随机题目", test_random_qas_by_bank)


def test_sequential_qas():
    resp = requests.get(f"{BASE}/api/qas/sequential/list", params={"limit": 5})
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert len(data) <= 5


test("顺序获取题目", test_sequential_qas)


def test_wrong_qas():
    resp = requests.get(f"{BASE}/api/qas/wrong/list", params={"limit": 10, "min_score": 0})
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)


test("错题筛选", test_wrong_qas)


def test_tag_id_compatibility():
    data = ok(requests.get(f"{BASE}/api/qas/{qa1['id']}"))
    tag_id = data.get("tag_id")
    assert tag_id is None or isinstance(tag_id, (str, list)), \
        f"tag_id类型异常: {type(tag_id)}"


test("tag_id兼容性 - null/str/list均可", test_tag_id_compatibility)

# ======================== 图片管理 ========================
print("\n========== 图片管理（OSS）==========")


def test_list_kb_dir():
    data = ok(requests.get(f"{BASE}/api/images/list", params={"prefix": "kb"}))
    assert "dirs" in data or "files" in data


test("列出OSS kb/目录", test_list_kb_dir)


def test_list_root():
    ok(requests.get(f"{BASE}/api/images/list", params={"prefix": ""}))


test("列出OSS根目录", test_list_root)


def test_get_signed_url():
    resp = requests.get(f"{BASE}/api/images/kb/test.jpg/signed-url")
    assert resp.status_code in [200, 404]


test("获取签名URL", test_get_signed_url)


def test_get_public_url():
    resp = requests.get(f"{BASE}/api/images/kb/test.jpg/public-url")
    assert resp.status_code in [200, 404]


test("获取公开URL", test_get_public_url)

# ======================== 删除与清理 ========================
print("\n========== 删除与清理 ==========")


def test_delete_qa():
    resp = requests.delete(f"{BASE}/api/qas/{qa1['id']}")
    assert resp.status_code == 200
    assert resp.json().get("success") is True
    resp2 = requests.get(f"{BASE}/api/qas/{qa1['id']}")
    assert resp2.json() is None


test("删除题目 + 二次验证", test_delete_qa)

requests.delete(f"{BASE}/api/qas/{qa2['id']}")


def test_delete_tags():
    requests.delete(f"{BASE}/api/tags/{tag1['id']}")
    resp = requests.delete(f"{BASE}/api/tags/{tag2['id']}")
    assert resp.status_code == 200


test("删除标签", test_delete_tags)


def test_delete_banks():
    requests.delete(f"{BASE}/api/banks/{bank2['id']}")
    resp = requests.delete(f"{BASE}/api/banks/{bank1['id']}")
    assert resp.status_code == 200


test("删除题库（先子后根）", test_delete_banks)

# ======================== 测试报告 ========================
print("\n" + "=" * 50)
total = passed + failed
rate = (passed / total * 100) if total > 0 else 0
print(f"  通过: {passed} / {total}")
print(f"  失败: {failed} / {total}")
print(f"  通过率: {rate:.1f}%")
print("=" * 50)

if errors:
    print("\n失败详情:")
    for e in errors:
        print(e)

sys.exit(0 if failed == 0 else 1)
