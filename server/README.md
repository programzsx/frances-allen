# Frances Allen Backend

知识问答练习 App 后端服务，基于 Python FastAPI。

## 快速启动

```bash
# 安装依赖
pip install -r requirements.txt

# 启动服务（开发模式，热重载）
python run.py

# 或直接使用 uvicorn
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## API 文档

启动后访问：
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## 项目结构

```
backend/
├── app/
│   ├── main.py           # 应用入口
│   ├── config.py         # 配置管理
│   ├── database.py       # 数据库连接
│   ├── models/           # DO层：ORM模型
│   ├── schemas/          # BO/VO层：Pydantic模型
│   ├── dao/              # DAO层：原子化数据库操作
│   ├── services/         # Service层：业务逻辑
│   ├── routers/          # Controller层：API路由
│   └── utils/            # 工具类
├── .env                  # 环境变量
├── requirements.txt      # Python依赖
└── run.py               # 启动脚本
```

## API 列表

### 题库管理
- `POST   /api/banks`          新增题库
- `DELETE /api/banks/{id}`     删除题库
- `PUT    /api/banks/{id}`     更新题库
- `GET    /api/banks`          分页查询题库
- `GET    /api/banks/tree`     题库树形结构

### 标签管理
- `POST   /api/tags`           新增标签
- `DELETE /api/tags/{id}`      删除标签
- `PUT    /api/tags/{id}`      更新标签
- `GET    /api/tags`           分页查询标签

### 题目管理
- `POST   /api/qas`            新增题目
- `DELETE /api/qas/{id}`       删除题目
- `PUT    /api/qas/{id}`       更新题目
- `GET    /api/qas/{id}`       获取题目详情
- `GET    /api/qas`            分页+条件筛选查询
- `GET    /api/qas/random/list` 随机获取题目（练习模式）

### 图片管理
- `POST   /api/images/upload`  上传图片到OSS
- `DELETE /api/images/{key}`   删除OSS图片
- `GET    /api/images/{key}/signed-url` 获取签名URL
