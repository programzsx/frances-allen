     1|"""
     2|Frances Allen 后端接口完整测试
     3|覆盖每个接口、每个数据库字段
     4|"""
     5|import json
     6|import sys
     7|import requests
     8|
     9|BASE = "http://127.0.0.1:8000"
    10|
    11|passed = 0
    12|failed = 0
    13|
    14|
    15|def test(name, func):
    16|    global passed, failed
    17|    try:
    18|        func()
    19|        print(f"  ✓ {name}")
    20|        passed += 1
    21|    except AssertionError as e:
    22|        print(f"  ✗ {name}: {e}")
    23|        failed += 1
    24|    except Exception as e:
    25|        print(f"  ✗ {name}: 异常 {type(e).__name__}: {e}")
    26|        failed += 1
    27|
    28|
    29|# ======================== 题库管理 ========================
    30|print("\n========== 题库管理 ==========")
    31|
    32|# 创建根题库
    33|bank1 = None
    34|
    35|
    36|def test_create_bank():
    37|    global bank1
    38|    resp = requests.post(f"{BASE}/api/banks", json={"name": "Java"})
    39|    assert resp.status_code == 200, f"状态码 {resp.status_code}"
    40|    data = resp.json()
    41|    # 验证全部字段：id, create_time, update_time, name, parent_id
    42|    assert "id" in data, "缺少 id 字段"
    43|    assert "create_time" in data, "缺少 create_time 字段"
    44|    assert "update_time" in data, "缺少 update_time 字段"
    45|    assert data["name"] == "Java", f"name 应为 Java，实际 {data['name']}"
    46|    assert data["parent_id"] is None, f"parent_id 应为 None，实际 {data['parent_id']}"
    47|    bank1 = data
    48|
    49|
    50|test("创建根题库 - 验证 id/create_time/update_time/name/parent_id", test_create_bank)
    51|
    52|# 创建子题库
    53|bank2 = None
    54|
    55|
    56|def test_create_child_bank():
    57|    global bank2
    58|    resp = requests.post(f"{BASE}/api/banks", json={"name": "Java基础", "parent_id": bank1["id"]})
    59|    assert resp.status_code == 200
    60|    data = resp.json()
    61|    assert data["parent_id"] == bank1["id"], f"parent_id 应为 {bank1['id']}"
    62|    bank2 = data
    63|
    64|
    65|test("创建子题库 - 验证 parent_id 关联", test_create_child_bank)
    66|
    67|# 创建不存在的 parent_id 应失败
    68|
    69|
    70|def test_create_bank_invalid_parent():
    71|    resp = requests.post(f"{BASE}/api/banks", json={"name": "test", "parent_id": "nonexistent_id"})
    72|    assert resp.status_code == 500 or "不存在" in resp.text, "应报错父题库不存在"
    73|
    74|
    75|test("创建题库 - 不存在的 parent_id 应报错", test_create_bank_invalid_parent)
    76|
    77|
    78|# 更新题库名称
    79|
    80|
    81|def test_update_bank():
    82|    resp = requests.put(f"{BASE}/api/banks/{bank1['id']}", json={"name": "Java进阶"})
    83|    assert resp.status_code == 200
    84|    data = resp.json()
    85|    assert data["name"] == "Java进阶", f"name 应为 Java进阶，实际 {data['name']}"
    86|    assert "update_time" in data, "缺少 update_time 字段"
    87|
    88|
    89|test("更新题库 - 验证 name/update_time", test_update_bank)
    90|
    91|
    92|# 分页查询题库
    93|
    94|
    95|def test_page_bank():
    96|    resp = requests.get(f"{BASE}/api/banks", params={"current_page": 1, "page_size": 10})
    97|    assert resp.status_code == 200
    98|    data = resp.json()
    99|    assert "items" in data, "缺少 items 字段"
   100|    assert "total" in data, "缺少 total 字段"
   101|    assert "current_page" in data, "缺少 current_page 字段"
   102|    assert "page_size" in data, "缺少 page_size 字段"
   103|    assert data["total"] >= 2, f"total 应 >= 2，实际 {data['total']}"
   104|    assert data["current_page"] == 1, f"current_page 应为 1"
   105|    assert data["page_size"] == 10, f"page_size 应为 10"
   106|    assert len(data["items"]) >= 2, "items 数量不足"
   107|
   108|
   109|test("分页查询题库 - 验证 items/total/current_page/page_size", test_page_bank)
   110|
   111|
   112|# 关键字搜索题库
   113|
   114|
   115|def test_search_bank():
   116|    resp = requests.get(f"{BASE}/api/banks", params={"keyword": "Java"})
   117|    assert resp.status_code == 200
   118|    data = resp.json()
   119|    assert data["total"] >= 1, "搜索Java应有结果"
   120|
   121|
   122|test("关键字搜索题库", test_search_bank)
   123|
   124|
   125|# 题库树形结构
   126|
   127|
   128|def test_bank_tree():
   129|    resp = requests.get(f"{BASE}/api/banks/tree")
   130|    assert resp.status_code == 200
   131|    data = resp.json()
   132|    assert isinstance(data, list), "树形结构应为列表"
   133|    # 找到根节点应有 children
   134|    found = False
   135|    for node in data:
   136|        if node["id"] == bank1["id"]:
   137|            assert "children" in node, "树节点应有 children 字段"
   138|            assert len(node["children"]) >= 1, "根题库应有子题库"
   139|            found = True
   140|    assert found, "树中未找到根题库"
   141|
   142|
   143|test("题库树形结构 - 验证 children 层级", test_bank_tree)
   144|
   145|
   146|# ======================== 标签管理 ========================
   147|print("\n========== 标签管理 ==========")
   148|
   149|tag1 = None
   150|tag2 = None
   151|
   152|
   153|def test_create_tag():
   154|    global tag1, tag2
   155|    resp1 = requests.post(f"{BASE}/api/tags", json={"name": "重点"})
   156|    assert resp1.status_code == 200
   157|    data1 = resp1.json()
   158|    # 验证全部字段：id, create_time, update_time, name
   159|    assert "id" in data1, "缺少 id"
   160|    assert "create_time" in data1, "缺少 create_time"
   161|    assert "update_time" in data1, "缺少 update_time"
   162|    assert data1["name"] == "重点", f"name 应为 重点，实际 {data1['name']}"
   163|    tag1 = data1
   164|
   165|    resp2 = requests.post(f"{BASE}/api/tags", json={"name": "易错"})
   166|    assert resp2.status_code == 200
   167|    tag2 = resp2.json()
   168|
   169|
   170|test("创建标签 - 验证 id/create_time/update_time/name", test_create_tag)
   171|
   172|
   173|# 更新标签
   174|
   175|
   176|def test_update_tag():
   177|    resp = requests.put(f"{BASE}/api/tags/{tag1['id']}", json={"name": "核心重点"})
   178|    assert resp.status_code == 200
   179|    data = resp.json()
   180|    assert data["name"] == "核心重点", f"name 应为 核心重点"
   181|    assert "update_time" in data
   182|
   183|
   184|test("更新标签 - 验证 name/update_time", test_update_tag)
   185|
   186|
   187|# 分页查询标签
   188|
   189|
   190|def test_page_tag():
   191|    resp = requests.get(f"{BASE}/api/tags", params={"current_page": 1, "page_size": 10})
   192|    assert resp.status_code == 200
   193|    data = resp.json()
   194|    assert "items" in data
   195|    assert "total" in data
   196|    assert data["total"] >= 2
   197|
   198|
   199|test("分页查询标签 - 验证 items/total", test_page_tag)
   200|
   201|
   202|# 关键字搜索标签
   203|
   204|
   205|def test_search_tag():
   206|    resp = requests.get(f"{BASE}/api/tags", params={"keyword": "核心"})
   207|    assert resp.status_code == 200
   208|    data = resp.json()
   209|    assert data["total"] >= 1
   210|
   211|
   212|test("关键字搜索标签", test_search_tag)
   213|
   214|
   215|# ======================== 题目管理 ========================
   216|print("\n========== 题目管理 ==========")
   217|
   218|qa1 = None
   219|
   220|
   221|def test_create_qa():
   222|    global qa1
   223|    resp = requests.post(f"{BASE}/api/qas", json={
   224|        "question": "杨幂出生于___年，毕业于___。",
   225|        "answer": ["1986", "北京电影学院"],
   226|        "image_url": "https://zsx-r7000p.oss-cn-beijing.aliyuncs.com/test.jpg",
   227|        'category_id': bank1["id"],
   228|        "tag_id": [tag1["id"], tag2["id"]],
   229|    })
   230|    assert resp.status_code == 200
   231|    data = resp.json()
   232|    # 验证全部字段
   233|    assert "id" in data, "缺少 id"
   234|    assert "create_time" in data, "缺少 create_time"
   235|    assert "update_time" in data, "缺少 update_time"
   236|    assert "question" in data, "缺少 question"
   237|    assert "answer" in data, "缺少 answer"
   238|    assert "image_url" in data, "缺少 image_url"
   239|    assert "total" in data, "缺少 total"
   240|    assert "right" in data, "缺少 right"
   241|    assert "wrong" in data, "缺少 wrong"
   242|    assert "random_int" in data, "缺少 random_int"
   243|    assert 'category_id' in data, "缺少 category_id"
   244|    assert "tag_id" in data, "缺少 tag_id"
   245|
   246|    # 验证字段值
   247|    assert data["question"] == "杨幂出生于___年，毕业于___。", "question 值不对"
   248|    assert data["answer"] == ["1986", "北京电影学院"], f"answer 值不对: {data['answer']}"
   249|    assert data["image_url"] == "https://zsx-r7000p.oss-cn-beijing.aliyuncs.com/test.jpg"
   250|    assert data["total"] == 0, f"total 初始应为 0，实际 {data['total']}"
   251|    assert data["right"] == 0, f"right 初始应为 0"
   252|    assert data["wrong"] == 0, f"wrong 初始应为 0"
   253|    assert data["random_int"] >= 1, f"random_int 应 >= 1"
   254|    assert data['category_id'] == bank1["id"], f"category_id 值不对"
   255|    assert set(data["tag_id"]) == {tag1["id"], tag2["id"]}, f"tag_id 值不对: {data['tag_id']}"
   256|    qa1 = data
   257|
   258|
   259|test("创建题目 - 验证全部字段 question/answer/image_url/total/right/wrong/random_int/category_id/tag_id", test_create_qa)
   260|
   261|# 创建无图无标签的简单题目
   262|qa2 = None
   263|
   264|
   265|def test_create_qa_minimal():
   266|    global qa2
   267|    resp = requests.post(f"{BASE}/api/qas", json={
   268|        "question": "1+1=___",
   269|        "answer": ["2"],
   270|    })
   271|    assert resp.status_code == 200
   272|    data = resp.json()
   273|    assert data["image_url"] is None, f"image_url 应为 None"
   274|    assert data['category_id'] is None, f"category_id 应为 None"
   275|    assert data["tag_id"] is None, f"tag_id 应为 None"
   276|    assert data["answer"] == ["2"], "answer 值不对"
   277|    qa2 = data
   278|
   279|
   280|test("创建题目 - 无图片无标签(可选字段验证)", test_create_qa_minimal)
   281|
   282|
   283|# category_id 不存在应报错
   284|
   285|
   286|def test_create_qa_invalid_bank():
   287|    resp = requests.post(f"{BASE}/api/qas", json={
   288|        "question": "test",
   289|        "answer": ["a"],
   290|        'category_id': "nonexistent_bank_id",
   291|    })
   292|    assert resp.status_code == 500 or "不存在" in resp.text
   293|
   294|
   295|test("创建题目 - 不存在的 category_id 应报错", test_create_qa_invalid_bank)
   296|
   297|
   298|# tag_id 不存在应报错
   299|
   300|
   301|def test_create_qa_invalid_tag():
   302|    resp = requests.post(f"{BASE}/api/qas", json={
   303|        "question": "test",
   304|        "answer": ["a"],
   305|        "tag_id": ["nonexistent_tag_id"],
   306|    })
   307|    assert resp.status_code == 500 or "不存在" in resp.text
   308|
   309|
   310|test("创建题目 - 不存在的 tag_id 应报错", test_create_qa_invalid_tag)
   311|
   312|
   313|# 获取题目详情
   314|
   315|
   316|def test_get_qa():
   317|    resp = requests.get(f"{BASE}/api/qas/{qa1['id']}")
   318|    assert resp.status_code == 200
   319|    data = resp.json()
   320|    assert data["id"] == qa1["id"]
   321|    assert data["question"] == qa1["question"]
   322|    assert data["answer"] == qa1["answer"]
   323|
   324|
   325|test("获取题目详情 - 验证 id/question/answer", test_get_qa)
   326|
   327|
   328|# 更新题目
   329|
   330|
   331|def test_update_qa():
   332|    resp = requests.put(f"{BASE}/api/qas/{qa1['id']}", json={
   333|        "question": "杨幂出生于___年。",
   334|        "answer": ["1986"],
   335|    })
   336|    assert resp.status_code == 200
   337|    data = resp.json()
   338|    assert data["question"] == "杨幂出生于___年。"
   339|    assert data["answer"] == ["1986"]
   340|
   341|
   342|test("更新题目 - 验证 question/answer 更新", test_update_qa)
   343|
   344|
   345|# 更新统计字段（right + wrong = total 约束）
   346|
   347|
   348|def test_update_qa_stats_valid():
   349|    resp = requests.put(f"{BASE}/api/qas/{qa1['id']}", json={
   350|        "total": 10, "right": 7, "wrong": 3,
   351|    })
   352|    assert resp.status_code == 200
   353|    data = resp.json()
   354|    assert data["total"] == 10, f"total 应为 10"
   355|    assert data["right"] == 7, f"right 应为 7"
   356|    assert data["wrong"] == 3, f"wrong 应为 3"
   357|
   358|
   359|test("更新统计字段 - right+wrong=total 约束通过", test_update_qa_stats_valid)
   360|
   361|
   362|# 统计字段约束应失败
   363|
   364|
   365|def test_update_qa_stats_invalid():
   366|    resp = requests.put(f"{BASE}/api/qas/{qa1['id']}", json={
   367|        "total": 10, "right": 5, "wrong": 5,
   368|    })
   369|    # 这次是对的 5+5=10，换一个不对的
   370|    resp = requests.put(f"{BASE}/api/qas/{qa1['id']}", json={
   371|        "total": 10, "right": 8, "wrong": 3,
   372|    })
   373|    assert resp.status_code == 500 or "约束" in resp.text or "约束失败" in resp.text, "right+wrong!=total 应报错"
   374|
   375|
   376|test("更新统计字段 - right+wrong!=total 应报错", test_update_qa_stats_invalid)
   377|
   378|
   379|# 分页查询题目
   380|
   381|
   382|def test_page_qa():
   383|    resp = requests.get(f"{BASE}/api/qas", params={"current_page": 1, "page_size": 10})
   384|    assert resp.status_code == 200
   385|    data = resp.json()
   386|    assert "items" in data
   387|    assert "total" in data
   388|    assert data["total"] >= 2
   389|
   390|
   391|test("分页查询题目 - 验证 items/total", test_page_qa)
   392|
   393|
   394|# 按题库筛选
   395|
   396|
   397|def test_page_qa_by_bank():
   398|    resp = requests.get(f"{BASE}/api/qas", params={'category_id': bank1["id"]})
   399|    assert resp.status_code == 200
   400|    data = resp.json()
   401|    assert data["total"] >= 1
   402|    for item in data["items"]:
   403|        assert item['category_id'] == bank1["id"], f"category_id 筛选不正确"
   404|
   405|
   406|test("按分类筛选题目 - 验证 category_id", test_page_qa_by_bank)
   407|
   408|
   409|# 关键字搜索题目
   410|
   411|
   412|def test_search_qa():
   413|    resp = requests.get(f"{BASE}/api/qas", params={"keyword": "杨幂"})
   414|    assert resp.status_code == 200
   415|    data = resp.json()
   416|    assert data["total"] >= 1
   417|
   418|
   419|test("关键字搜索题目", test_search_qa)
   420|
   421|
   422|# 随机获取题目
   423|
   424|
   425|def test_random_qa():
   426|    resp = requests.get(f"{BASE}/api/qas/random/list", params={"limit": 5})
   427|    assert resp.status_code == 200
   428|    data = resp.json()
   429|    assert isinstance(data, list)
   430|    assert len(data) <= 5
   431|
   432|
   433|test("随机获取题目 - 验证返回列表和 limit", test_random_qa)
   434|
   435|
   436|# 按题库随机获取
   437|
   438|
   439|def test_random_qa_by_bank():
   440|    resp = requests.get(f"{BASE}/api/qas/random/list", params={"limit": 5, 'category_id': bank1["id"]})
   441|    assert resp.status_code == 200
   442|    data = resp.json()
   443|    for item in data:
   444|        assert item['category_id'] == bank1["id"]
   445|
   446|
   447|test("按分类随机获取题目 - 验证 category_id", test_random_qa_by_bank)
   448|
# 顺序获取题目
def test_sequential_qa():
    resp = requests.get(f"{BASE}/api/qas/sequential/list", params={"limit": 5})
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert len(data) <= 5
    if len(data) >= 2:
        for i in range(len(data) - 1):
            assert data[i]["random_int"] <= data[i + 1]["random_int"], "顺序查询应按 random_int 升序"

test("顺序获取题目 - 验证 random_int 升序", test_sequential_qa)

# 错题列表
def test_wrong_qa():
    resp = requests.get(f"{BASE}/api/qas/wrong/list", params={"limit": 10, "min_wrong": 1})
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    for item in data:
        assert item["wrong"] >= 1, f"wrong={item['wrong']}"

test("错题列表 - 验证 wrong >= min_wrong", test_wrong_qa)

# 标签题目统计
def test_tag_counts():
    resp = requests.get(f"{BASE}/api/qas/tag-counts")
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, dict), "应返回字典"

test("标签题目统计", test_tag_counts)

# ======================== 图片管理（OSS kb/路径） ========================
print("\n========== 图片管理（OSS kb/路径） ==========")

# 上传图片到 kb/ 路径
def test_upload_image_to_kb():
    import io
    fake_img = io.BytesIO(b"\x89PNG\r\n\x1a\n" + b"\x00" * 100)
    files = {"file": ("test.png", fake_img, "image/png")}
    resp = requests.post(
        f"{BASE}/api/images/upload",
        params={"prefix": "kb", "filename": "test-upload"},
        files=files,
    )
    assert resp.status_code == 200, f"上传失败: {resp.text}"
    data = resp.json()
    assert "url" in data
    assert "key" in data
    assert data["key"].startswith("kb/"), f"key应以kb/开头，实际{data['key']}"

test("上传图片到kb/路径 - 验证key前缀", test_upload_image_to_kb)

# 列出 kb/ 目录
def test_list_images_kb():
    resp = requests.get(f"{BASE}/api/images/list", params={"prefix": "kb"})
    assert resp.status_code == 200
    data = resp.json()
    assert "dirs" in data
    assert "files" in data
    assert "total" in data

test("列出kb/目录 - 验证dirs/files/total", test_list_images_kb)

# 获取签名URL
def test_signed_url():
    resp = requests.get(f"{BASE}/api/images/kb/test-upload.png/signed-url")
    assert resp.status_code == 200
    data = resp.json()
    assert "url" in data
    assert data["url"].startswith("http")

test("获取签名URL", test_signed_url)

# 获取公开URL
def test_public_url():
    resp = requests.get(f"{BASE}/api/images/kb/test-upload.png/public-url")
    assert resp.status_code == 200
    data = resp.json()
    assert "url" in data

test("获取公开URL", test_public_url)

# 删除上传的测试图片
def test_delete_image():
    resp = requests.delete(f"{BASE}/api/images/kb/test-upload.png")
    assert resp.status_code == 200
    assert resp.json()["success"] is True

test("删除OSS图片", test_delete_image)


   449|
   450|# ======================== 删除测试 ========================
   451|print("\n========== 删除操作 ==========")
   452|
   453|
   454|def test_delete_qa():
   455|    resp = requests.delete(f"{BASE}/api/qas/{qa2['id']}")
   456|    assert resp.status_code == 200
   457|    data = resp.json()
   458|    assert data["success"] is True, "删除应成功"
   459|    # 再查应该没了
   460|    resp2 = requests.get(f"{BASE}/api/qas/{qa2['id']}")
   461|    assert resp2.json() is None, "删除后查询应为 None"
   462|
   463|
   464|test("删除题目 - 验证删除成功和二次查询为空", test_delete_qa)
   465|
   466|
   467|def test_delete_tag():
   468|    resp = requests.delete(f"{BASE}/api/tags/{tag2['id']}")
   469|    assert resp.status_code == 200
   470|    assert resp.json()["success"] is True
   471|
   472|
   473|test("删除标签", test_delete_tag)
   474|
   475|
   476|def test_delete_bank():
   477|    # 删除子题库
   478|    resp = requests.delete(f"{BASE}/api/banks/{bank2['id']}")
   479|    assert resp.status_code == 200
   480|    assert resp.json()["success"] is True
   481|    # 删除根题库
   482|    resp2 = requests.delete(f"{BASE}/api/banks/{bank1['id']}")
   483|    assert resp2.json()["success"] is True
   484|
   485|
   486|test("删除题库 - 先删子后删根", test_delete_bank)
   487|
   488|
   489|# 清理：删除剩余测试数据
   490|def test_cleanup():
   491|    resp = requests.delete(f"{BASE}/api/qas/{qa1['id']}")
   492|    resp = requests.delete(f"{BASE}/api/tags/{tag1['id']}")
   493|
   494|
   495|test("清理测试数据", test_cleanup)
   496|
   497|
   498|# ======================== 健康检查 ========================
   499|print("\n========== 健康检查 ==========")
   500|
   501|
   502|def test_health():
   503|    resp = requests.get(f"{BASE}/")
   504|    assert resp.status_code == 200
   505|    data = resp.json()
   506|    assert data["app"] == "frances-allen"
   507|    assert data["status"] == "running"
   508|
   509|
   510|test("健康检查 GET /", test_health)
   511|
   512|
   513|# ======================== 汇总 ========================
   514|print(f"\n{'='*40}")
   515|print(f"测试完成: 通过 {passed}, 失败 {failed}, 总计 {passed + failed}")
   516|if failed > 0:
   517|    sys.exit(1)
   518|