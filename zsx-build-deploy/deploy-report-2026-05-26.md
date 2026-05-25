# Frances Allen 部署测试报告

> 时间：2026-05-26 00:05 CST
> 服务器：8.160.174.178:8000
> 部署目录：/home/frances-allen/server

---

## 一、本次变更

### 部署路径迁移

| 配置项 | 旧值 | 新值 |
|--------|------|------|
| 部署目录 | `/opt/frances-allen` | `/home/frances-allen` |
| venv 路径 | `/opt/frances-allen/venv` | `/home/frances-allen/venv` |
| .env 路径 | `/opt/frances-allen/server/.env` | `/home/frances-allen/server/.env` |

修改文件：
- `zsx-build-deploy/auto-deploy.sh` — ECS_DEPLOY_DIR + migration source
- `zsx-build-deploy/deploy.sh` — DEPLOY_DIR
- `zsx-build-deploy/frances-allen.service` — WorkingDirectory / EnvironmentFile / ExecStart
- `zsx-docs/04-deploy-spec.md` — 文档对齐

### Git 最新提交

```
d0f1091 feat: batch_qa 全部成功时自动清空 batch.md
aecfd42 batch_qa.py 重写：对齐最新 QaCreateBO schema
```

---

## 二、测试结果

**全部通过：13/13 ✓**

| # | 测试项 | 结果 |
|---|--------|------|
| 1 | Health Check `GET /` | ✓ `{"app":"frances-allen","status":"running"}` |
| 2 | 分类列表 `GET /api/banks` — 10 条 | ✓ |
| 3 | 创建分类 `POST /api/banks` | ✓ |
| 4 | 创建题目 `POST /api/qas` — answer: list, score: int | ✓ |
| 5 | 题目详情 `GET /api/qas/{id}` — 字段完整 | ✓ |
| 6 | 分类筛选 `GET /api/qas?category_id=` | ✓ |
| 7 | 随机取题 `GET /api/qas/random/list` | ✓ |
| 8 | 顺序取题 `GET /api/qas/sequential/list` | ✓ |
| 9 | 薄弱题目 `GET /api/qas/wrong/list` | ✓ |
| 10 | 更新题目 `PUT /api/qas/{id}` — score/sort_order | ✓ |
| 11 | 标签列表 `GET /api/tags` | ✓ |
| 12 | 删除题目 `DELETE /api/qas/{id}` | ✓ |
| 13 | 删除分类 `DELETE /api/banks/{id}` | ✓ |

---

## 三、部署流程

1. 本地 git pull 最新代码
2. 修改四个文件路径 `/opt` → `/home`
3. `tar -czf zsx-build-deploy/server.tar.gz server/`
4. `scp server.tar.gz deploy.sh root@8.160.174.178:/home/`
5. `scp frances-allen.service root@8.160.174.178:/etc/systemd/system/`
6. ECS 执行 `bash /home/deploy.sh`
7. 健康检查 `curl http://8.160.174.178:8000/`
8. 运行 13 项 API 测试

---

## 四、注意事项

- **未有旧 .env**：首次部署到 `/home/frances-allen`，deploy.sh 创建了默认 .env，需确认数据库密码等配置是否正确
- systemd 需执行 `systemctl daemon-reload` 以加载新的 service 文件
- 打包大小：17KB
