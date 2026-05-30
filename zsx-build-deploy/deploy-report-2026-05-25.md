# Frances Allen 部署测试报告

> 时间：2026-05-25  
> 服务器：8.160.174.178:8000  
> 部署目录：/opt/frances-allen/server

---

## 一、本次变更

### 数据库 Migration

| # | SQL | 说明 |
|---|-----|------|
| 1 | `01_rename_qa_category_id.sql` | `kb_qa.kb_category_id` → `category_id` |
| 2 | `02_rename_kb_category_qa_count.sql` | `kb_category.qa_count` → `count` |

### 后端模型对齐

| 表 | 模型变更 |
|----|---------|
| `kb_qa` | 删除 `image_url/total/right/wrong`，新增 `sort_order/score`，`bank_id`→`category_id`，`tag_id` Text→varchar(64) |
| `kb_category` | `__tablename__` 改为 `kb_category`，新增 `description/sort_order/random_int/count`，`qa_count`→`count` |

### 前端

| 端 | 文件数 | 变更 |
|----|--------|------|
| Desktop | 6 | `bankId`→`categoryId`，`bank_id`→`category_id` |
| Mobile | 8 | 同上 + `global_filter.dart` + `bank_page.dart` |

---

## 二、测试结果

**全部通过：21/21 ✓**

| # | 测试项 | 结果 |
|---|--------|------|
| 1 | Health Check `GET /` | ✓ |
| 2 | 分类列表 `GET /api/banks` — 29 条 | ✓ |
| 3 | 创建分类 `POST /api/banks` | ✓ |
| 4 | 创建题目 `POST /api/qas` — `category_id` 字段 | ✓ |
| 4.1 | `category_id` 值正确 | ✓ |
| 4.2 | `score=1` | ✓ |
| 4.3 | `sort_order=10` | ✓ |
| 5 | 题目详情 `GET /api/qas/{id}` — 所有字段 | ✓ |
| 5.1 | `id/question/category_id/score/random_int/sort_order` | ✓ |
| 5.2 | 无旧字段 `bank_id/image_url/total/right/wrong` | ✓ |
| 6 | 分类筛选 `GET /api/qas?category_id=` | ✓ |
| 7 | 随机取题 `GET /api/qas/random/list` | ✓ |
| 8 | 顺序取题 `GET /api/qas/sequential/list` | ✓ |
| 9 | 薄弱题目 `GET /api/qas/wrong/list` | ✓ |
| 10 | 更新题目 `PUT /api/qas/{id}` — score/sort_order | ✓ |
| 11 | 删除题目 `DELETE /api/qas/{id}` | ✓ |
| 12 | 删除分类 `DELETE /api/banks/{id}` | ✓ |

---

## 三、部署流程

1. 本地 `git commit && git push`
2. 打包：`tar -czf zsx-build-deploy/server.tar.gz server/`
3. 上传：`scp server.tar.gz deploy.sh root@8.160.174.178:/home/`
4. ECS 执行：`bash /home/deploy.sh`
5. 数据库 migration（如需要）：`mysql < migration.sql`
6. 测试：`python3 test_api.py`
