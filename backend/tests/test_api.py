"""
Frances Allen 后端接口完整测试
覆盖每个接口、每个数据库字段
"""
import json
import sys
import requests

BASE = "http://127.0.0.1:8000"

passed = 0
failed = 0


def test(name, func):
    global passed, failed
    try:
        func()
        print(f"  ✓ {name}")
        passed += 1
    except AssertionError as e:
        print(f"  ✗ {name}: {e}")
        failed += 1
    except Exception as e:
        print(f"  ✗ {name}: 异常 {type(e).__name__}: {e}")
        failed += 1


# ======================== 题库管理 ========================
print("\n========== 题库管理 ==========")

# 创建根题库
bank1 = None


def test_create_bank():
    global bank1
    resp = requests.post(f"{BASE}/api/banks", json={"name": "Java"})
    assert resp.status_code == 200, f"状态码 {resp.status_code}"
    data = resp.json()
    # 验证全部字段：id, create_time, update_time, name, parent_id
    assert "id" in data, "缺少 id 字段"
    assert "create_time" in data, "缺少 create_time 字段"
    assert "update_time" in data, "缺少 update_time 字段"
    assert data["name"] == "Java", f"name 应为 Java，实际 {data['name']}"
    assert data["parent_id"] is None, f"parent_id 应为 None，实际 {data['parent_id']}"
    bank1 = data


test("创建根题库 - 验证 id/create_time/update_time/name/parent_id", test_create_bank)

# 创建子题库
bank2 = None


def test_create_child_bank():
    global bank2
    resp = requests.post(f"{BASE}/api/banks", json={"name": "Java基础", "parent_id": bank1["id"]})
    assert resp.status_code == 200
    data = resp.json()
    assert data["parent_id"] == bank1["id"], f"parent_id 应为 {bank1['id']}"
    bank2 = data


test("创建子题库 - 验证 parent_id 关联", test_create_child_bank)

# 创建不存在的 parent_id 应失败


def test_create_bank_invalid_parent():
    resp = requests.post(f"{BASE}/api/banks", json={"name": "test", "parent_id": "nonexistent_id"})
    assert resp.status_code == 500 or "不存在" in resp.text, "应报错父题库不存在"


test("创建题库 - 不存在的 parent_id 应报错", test_create_bank_invalid_parent)


# 更新题库名称


def test_update_bank():
    resp = requests.put(f"{BASE}/api/banks/{bank1['id']}", json={"name": "Java进阶"})
    assert resp.status_code == 200
    data = resp.json()
    assert data["name"] == "Java进阶", f"name 应为 Java进阶，实际 {data['name']}"
    assert "update_time" in data, "缺少 update_time 字段"


test("更新题库 - 验证 name/update_time", test_update_bank)


# 分页查询题库


def test_page_bank():
    resp = requests.get(f"{BASE}/api/banks", params={"current_page": 1, "page_size": 10})
    assert resp.status_code == 200
    data = resp.json()
    assert "items" in data, "缺少 items 字段"
    assert "total" in data, "缺少 total 字段"
    assert "current_page" in data, "缺少 current_page 字段"
    assert "page_size" in data, "缺少 page_size 字段"
    assert data["total"] >= 2, f"total 应 >= 2，实际 {data['total']}"
    assert data["current_page"] == 1, f"current_page 应为 1"
    assert data["page_size"] == 10, f"page_size 应为 10"
    assert len(data["items"]) >= 2, "items 数量不足"


test("分页查询题库 - 验证 items/total/current_page/page_size", test_page_bank)


# 关键字搜索题库


def test_search_bank():
    resp = requests.get(f"{BASE}/api/banks", params={"keyword": "Java"})
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] >= 1, "搜索Java应有结果"


test("关键字搜索题库", test_search_bank)


# 题库树形结构


def test_bank_tree():
    resp = requests.get(f"{BASE}/api/banks/tree")
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list), "树形结构应为列表"
    # 找到根节点应有 children
    found = False
    for node in data:
        if node["id"] == bank1["id"]:
            assert "children" in node, "树节点应有 children 字段"
            assert len(node["children"]) >= 1, "根题库应有子题库"
            found = True
    assert found, "树中未找到根题库"


test("题库树形结构 - 验证 children 层级", test_bank_tree)


# ======================== 标签管理 ========================
print("\n========== 标签管理 ==========")

tag1 = None
tag2 = None


def test_create_tag():
    global tag1, tag2
    resp1 = requests.post(f"{BASE}/api/tags", json={"name": "重点"})
    assert resp1.status_code == 200
    data1 = resp1.json()
    # 验证全部字段：id, create_time, update_time, name
    assert "id" in data1, "缺少 id"
    assert "create_time" in data1, "缺少 create_time"
    assert "update_time" in data1, "缺少 update_time"
    assert data1["name"] == "重点", f"name 应为 重点，实际 {data1['name']}"
    tag1 = data1

    resp2 = requests.post(f"{BASE}/api/tags", json={"name": "易错"})
    assert resp2.status_code == 200
    tag2 = resp2.json()


test("创建标签 - 验证 id/create_time/update_time/name", test_create_tag)


# 更新标签


def test_update_tag():
    resp = requests.put(f"{BASE}/api/tags/{tag1['id']}", json={"name": "核心重点"})
    assert resp.status_code == 200
    data = resp.json()
    assert data["name"] == "核心重点", f"name 应为 核心重点"
    assert "update_time" in data


test("更新标签 - 验证 name/update_time", test_update_tag)


# 分页查询标签


def test_page_tag():
    resp = requests.get(f"{BASE}/api/tags", params={"current_page": 1, "page_size": 10})
    assert resp.status_code == 200
    data = resp.json()
    assert "items" in data
    assert "total" in data
    assert data["total"] >= 2


test("分页查询标签 - 验证 items/total", test_page_tag)


# 关键字搜索标签


def test_search_tag():
    resp = requests.get(f"{BASE}/api/tags", params={"keyword": "核心"})
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] >= 1


test("关键字搜索标签", test_search_tag)


# ======================== 题目管理 ========================
print("\n========== 题目管理 ==========")

qa1 = None


def test_create_qa():
    global qa1
    resp = requests.post(f"{BASE}/api/qas", json={
        "question": "杨幂出生于___年，毕业于___。",
        "answer": ["1986", "北京电影学院"],
        "image_url": "https://zsx-r7000p.oss-cn-beijing.aliyuncs.com/test.jpg",
        "bank_id": bank1["id"],
        "tag_id": [tag1["id"], tag2["id"]],
    })
    assert resp.status_code == 200
    data = resp.json()
    # 验证全部字段
    assert "id" in data, "缺少 id"
    assert "create_time" in data, "缺少 create_time"
    assert "update_time" in data, "缺少 update_time"
    assert "question" in data, "缺少 question"
    assert "answer" in data, "缺少 answer"
    assert "image_url" in data, "缺少 image_url"
    assert "total" in data, "缺少 total"
    assert "right" in data, "缺少 right"
    assert "wrong" in data, "缺少 wrong"
    assert "random_int" in data, "缺少 random_int"
    assert "bank_id" in data, "缺少 bank_id"
    assert "tag_id" in data, "缺少 tag_id"

    # 验证字段值
    assert data["question"] == "杨幂出生于___年，毕业于___。", "question 值不对"
    assert data["answer"] == ["1986", "北京电影学院"], f"answer 值不对: {data['answer']}"
    assert data["image_url"] == "https://zsx-r7000p.oss-cn-beijing.aliyuncs.com/test.jpg"
    assert data["total"] == 0, f"total 初始应为 0，实际 {data['total']}"
    assert data["right"] == 0, f"right 初始应为 0"
    assert data["wrong"] == 0, f"wrong 初始应为 0"
    assert data["random_int"] >= 1, f"random_int 应 >= 1"
    assert data["bank_id"] == bank1["id"], f"bank_id 值不对"
    assert set(data["tag_id"]) == {tag1["id"], tag2["id"]}, f"tag_id 值不对: {data['tag_id']}"
    qa1 = data


test("创建题目 - 验证全部字段 question/answer/image_url/total/right/wrong/random_int/bank_id/tag_id", test_create_qa)

# 创建无图无标签的简单题目
qa2 = None


def test_create_qa_minimal():
    global qa2
    resp = requests.post(f"{BASE}/api/qas", json={
        "question": "1+1=___",
        "answer": ["2"],
    })
    assert resp.status_code == 200
    data = resp.json()
    assert data["image_url"] is None, f"image_url 应为 None"
    assert data["bank_id"] is None, f"bank_id 应为 None"
    assert data["tag_id"] is None, f"tag_id 应为 None"
    assert data["answer"] == ["2"], "answer 值不对"
    qa2 = data


test("创建题目 - 无图片无标签(可选字段验证)", test_create_qa_minimal)


# bank_id 不存在应报错


def test_create_qa_invalid_bank():
    resp = requests.post(f"{BASE}/api/qas", json={
        "question": "test",
        "answer": ["a"],
        "bank_id": "nonexistent_bank_id",
    })
    assert resp.status_code == 500 or "不存在" in resp.text


test("创建题目 - 不存在的 bank_id 应报错", test_create_qa_invalid_bank)


# tag_id 不存在应报错


def test_create_qa_invalid_tag():
    resp = requests.post(f"{BASE}/api/qas", json={
        "question": "test",
        "answer": ["a"],
        "tag_id": ["nonexistent_tag_id"],
    })
    assert resp.status_code == 500 or "不存在" in resp.text


test("创建题目 - 不存在的 tag_id 应报错", test_create_qa_invalid_tag)


# 获取题目详情


def test_get_qa():
    resp = requests.get(f"{BASE}/api/qas/{qa1['id']}")
    assert resp.status_code == 200
    data = resp.json()
    assert data["id"] == qa1["id"]
    assert data["question"] == qa1["question"]
    assert data["answer"] == qa1["answer"]


test("获取题目详情 - 验证 id/question/answer", test_get_qa)


# 更新题目


def test_update_qa():
    resp = requests.put(f"{BASE}/api/qas/{qa1['id']}", json={
        "question": "杨幂出生于___年。",
        "answer": ["1986"],
    })
    assert resp.status_code == 200
    data = resp.json()
    assert data["question"] == "杨幂出生于___年。"
    assert data["answer"] == ["1986"]


test("更新题目 - 验证 question/answer 更新", test_update_qa)


# 更新统计字段（right + wrong = total 约束）


def test_update_qa_stats_valid():
    resp = requests.put(f"{BASE}/api/qas/{qa1['id']}", json={
        "total": 10, "right": 7, "wrong": 3,
    })
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 10, f"total 应为 10"
    assert data["right"] == 7, f"right 应为 7"
    assert data["wrong"] == 3, f"wrong 应为 3"


test("更新统计字段 - right+wrong=total 约束通过", test_update_qa_stats_valid)


# 统计字段约束应失败


def test_update_qa_stats_invalid():
    resp = requests.put(f"{BASE}/api/qas/{qa1['id']}", json={
        "total": 10, "right": 5, "wrong": 5,
    })
    # 这次是对的 5+5=10，换一个不对的
    resp = requests.put(f"{BASE}/api/qas/{qa1['id']}", json={
        "total": 10, "right": 8, "wrong": 3,
    })
    assert resp.status_code == 500 or "约束" in resp.text or "约束失败" in resp.text, "right+wrong!=total 应报错"


test("更新统计字段 - right+wrong!=total 应报错", test_update_qa_stats_invalid)


# 分页查询题目


def test_page_qa():
    resp = requests.get(f"{BASE}/api/qas", params={"current_page": 1, "page_size": 10})
    assert resp.status_code == 200
    data = resp.json()
    assert "items" in data
    assert "total" in data
    assert data["total"] >= 2


test("分页查询题目 - 验证 items/total", test_page_qa)


# 按题库筛选


def test_page_qa_by_bank():
    resp = requests.get(f"{BASE}/api/qas", params={"bank_id": bank1["id"]})
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] >= 1
    for item in data["items"]:
        assert item["bank_id"] == bank1["id"], f"bank_id 筛选不正确"


test("按题库筛选题目 - 验证 bank_id", test_page_qa_by_bank)


# 关键字搜索题目


def test_search_qa():
    resp = requests.get(f"{BASE}/api/qas", params={"keyword": "杨幂"})
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] >= 1


test("关键字搜索题目", test_search_qa)


# 随机获取题目


def test_random_qa():
    resp = requests.get(f"{BASE}/api/qas/random/list", params={"limit": 5})
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert len(data) <= 5


test("随机获取题目 - 验证返回列表和 limit", test_random_qa)


# 按题库随机获取


def test_random_qa_by_bank():
    resp = requests.get(f"{BASE}/api/qas/random/list", params={"limit": 5, "bank_id": bank1["id"]})
    assert resp.status_code == 200
    data = resp.json()
    for item in data:
        assert item["bank_id"] == bank1["id"]


test("按题库随机获取题目 - 验证 bank_id", test_random_qa_by_bank)


# ======================== 删除测试 ========================
print("\n========== 删除操作 ==========")


def test_delete_qa():
    resp = requests.delete(f"{BASE}/api/qas/{qa2['id']}")
    assert resp.status_code == 200
    data = resp.json()
    assert data["success"] is True, "删除应成功"
    # 再查应该没了
    resp2 = requests.get(f"{BASE}/api/qas/{qa2['id']}")
    assert resp2.json() is None, "删除后查询应为 None"


test("删除题目 - 验证删除成功和二次查询为空", test_delete_qa)


def test_delete_tag():
    resp = requests.delete(f"{BASE}/api/tags/{tag2['id']}")
    assert resp.status_code == 200
    assert resp.json()["success"] is True


test("删除标签", test_delete_tag)


def test_delete_bank():
    # 删除子题库
    resp = requests.delete(f"{BASE}/api/banks/{bank2['id']}")
    assert resp.status_code == 200
    assert resp.json()["success"] is True
    # 删除根题库
    resp2 = requests.delete(f"{BASE}/api/banks/{bank1['id']}")
    assert resp2.json()["success"] is True


test("删除题库 - 先删子后删根", test_delete_bank)


# 清理：删除剩余测试数据
def test_cleanup():
    resp = requests.delete(f"{BASE}/api/qas/{qa1['id']}")
    resp = requests.delete(f"{BASE}/api/tags/{tag1['id']}")


test("清理测试数据", test_cleanup)


# ======================== 健康检查 ========================
print("\n========== 健康检查 ==========")


def test_health():
    resp = requests.get(f"{BASE}/")
    assert resp.status_code == 200
    data = resp.json()
    assert data["app"] == "frances-allen"
    assert data["status"] == "running"


test("健康检查 GET /", test_health)


# ======================== 汇总 ========================
print(f"\n{'='*40}")
print(f"测试完成: 通过 {passed}, 失败 {failed}, 总计 {passed + failed}")
if failed > 0:
    sys.exit(1)
