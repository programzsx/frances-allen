# Frances Allen

知识问答练习App — 支持题库管理、标签分类、多模式练习的完整知识学习系统。

设计文档详见 [kb-design-spec.md](./kb-design-spec.md)。

## 技术栈

| 层级 | 技术 | 说明 |
|------|------|------|
| 移动端 | Flutter3.x（Dart） | Material3组件 + flutter_screenutil适配 |
| 桌面端 | Flutter Windows | 与移动端共享业务逻辑 |
| 后端 | FastAPI（Python3）+ SQLAlchemy + PyMySQL | 异步ORM，分层架构 |
| 数据库 | MySQL | 阿里云RDS |
| 文件存储 | 阿里云OSS | Bucket`zsx-r7000p` |

## 项目结构

```
frances-allen/
├── server/                    # FastAPI后端服务
│   ├── app/
│   │   ├── main.py            # 应用入口，CORS&路由注册
│   │   ├── config.py          # 环境配置（MySQL, OSS）
│   │   ├── database.py        # SQLAlchemy引擎&Base
│   │   ├── models/            # ORM模型（kb_qa, kb_bank, kb_tag）
│   │   ├── schemas/           # Pydantic请求/响应模型
│   │   ├── dao/               # 数据访问层
│   │   ├── services/          # 业务逻辑层
│   │   ├── routers/           # API路由
│   │   └── utils/             # 工具（雪花ID生成器）
│   ├── tests/                 # API测试
│   ├── run.py                 # 启动入口
│   └── requirements.txt
├── mobile/                    # Flutter移动端
│   ├── lib/
│   │   ├── main.dart          # App入口
│   │   ├── models/            # 数据模型
│   │   ├── pages/             # 页面组件
│   │   ├── services/          # API调用&全局状态
│   │   └── theme/             # 主题定义
│   └── pubspec.yaml
├── desktop/                   # Flutter Windows桌面端
│   ├── lib/                   # Dart源码（与mobile结构对称）
│   ├── windows/               # Windows原生配置
│   └── pubspec.yaml
├── batch/                     # 批量脚本
├── kb-design-spec.md          # 系统设计文档
├── deploy.sh                  # 服务器一键部署脚本
└── README.md
```

## 功能模块

### 题目管理

- 题目的增删改查，支持富文本题目展示
- 填空题用`___`占位符，答案以JSON数组存储，支持多空
- 快捷输入工具栏：填空、加粗、高亮、代码、分割线按钮
- 题目预览对话框，编辑页实时预览渲染效果
- 按题库/标签筛选，关键词搜索，滚动分页

### 练习模式

- **随机模式**：从题库中随机抽取题目
- **顺序模式**：按`random_int`字段顺序依次作答
- **错题模式**：针对错题次数≥N的题目重点练习
- 实时显示正确/错误统计，自动更新答题次数

### 题库管理

- 题库的CRUD操作
- 树形层级结构（支持父子题库），前端缩进展示
- 父题库下拉选择器，防止循环引用
- 从题库直接下钻查看关联题目

### 标签管理

- 标签的CRUD操作
- 与题目多对多关联（JSON数组存储）
- 标签题目数量统计

### 图片管理

- 阿里云OSS文件浏览（目录树+文件列表）
- 图片上传（支持移动端拍照/相册），自定义重命名
- 生成签名URL用于临时访问
- 全屏预览，左右滑动切换图片
- 视图切换（列表/图标）

### 富文本渲染

支持类Markdown标记语法：加粗`**`、高亮`==`、代码`` ` ``、分割线`----`、填空`___`、图片`![url]`。在题目列表、练习页面、预览对话框中统一渲染。

## 快速开始

### 后端

```bash
cd server

# 创建.env配置文件（参考deploy.sh中的模板）
# 需要配置: DB_HOST, DB_USER, DB_PASSWORD, DB_NAME, OSS_*

pip install -r requirements.txt
python run.py
```

服务默认运行在`http://0.0.0.0:8000`。

### 移动端

```bash
cd mobile

# 配置API地址: 编辑lib/services/api_config.dart

flutter pub get
flutter run
```

### 一键部署到服务器

```bash
# 打包server目录为server.tar.gz，上传到服务器/home/
# 在服务器上执行:
chmod +x deploy.sh && ./deploy.sh
```

`deploy.sh`自动完成：停止旧进程→备份.env→解压代码→恢复配置→安装依赖→启动服务→健康检查。

## API概览

| 路径 | 说明 |
|------|------|
| `GET /` | 健康检查 |
| `GET/POST /api/banks` | 题库列表/创建 |
| `PUT/DELETE /api/banks/:id` | 更新/删除题库 |
| `GET /api/banks/tree` | 题库树 |
| `GET/POST /api/tags` | 标签列表/创建 |
| `PUT/DELETE /api/tags/:id` | 更新/删除标签 |
| `POST /api/tags/batch` | 批量获取标签 |
| `GET/POST /api/qas` | 题目列表/创建 |
| `PUT/DELETE /api/qas/:id` | 更新/删除题目 |
| `GET /api/qas/random/list` | 随机题目 |
| `GET /api/qas/sequential/list` | 顺序题目 |
| `GET /api/qas/wrong/list` | 错题列表 |
| `GET /api/qas/tag-counts` | 标签题目统计 |
| `GET /api/images/list` | OSS文件列表 |
| `POST /api/images/upload` | 上传图片 |
| `DELETE /api/images/:key` | 删除图片 |
| `GET /api/images/:key/signed-url` | 获取签名URL |
| `GET /api/images/:key/public-url` | 获取公开URL |
