# Frances Allen — 产品需求文档

> 项目：frances-allen（知识问答系统）
> GitHub：https://github.com/programzsx/frances-allen.git
> 版本：v1.0

---

## 1. 设计背景与动机

我想开发一个跨端app，安装到我的Android手机上，随时随地进行知识问答练习。

大模型让知识问答更普遍，但这些知识并不进入我的大脑。我要通过考试的方式把知识练进大脑。这就是frances-allen项目的出发点。

---

## 2. 技术栈选型

| 层级 | 技术 | 版本/说明 |
|------|------|-----------|
| 移动端 | Flutter | Material3（M3）官方组件 + flutter_screenutil适配 |
| 后端 | FastAPI | Python3 + SQLAlchemy + PyMySQL |
| 数据库 | MySQL | 阿里云RDS，外网地址`rm-bp148re5az8vk250qyo.mysql.rds.aliyuncs.com:3306` |
| 文件存储 | 阿里云OSS | Endpoint`oss-cn-beijing.aliyuncs.com`，Bucket`zsx-r7000p` |
| 部署 | Shell脚本 | 基于uvicorn |

数据库账号：`frances_allen`，库名：`frances-allen`。

---

## 3. 基础功能设计

先数据后用户，这是我的设计顺序。已设计三张表：`kb_qa`、`kb_bank`、`kb_tag`。

### 数据分层架构

借鉴Java Web的设计模式来理解数据流转：

- **DO（Data Object）**：面向持久化层，与数据库结构一一对应。也可叫PO、entity
- **BO（Business Object）**：面向Service层，一个BO可以是多个DO的操作
- **VO（View Object）**：面向展示层，把页面展示需要的数据封装

### 数据库原子操作

对每张表提供增删改查方法：

- 增：`add`
- 删：`delete`
- 改：`update`
- 查：多条件筛选、分页查询、随机查询
  - 分页参数：`pageSize`（步长）、`total`（总数据量）、`currentPage`（当前页）

---

## 4. 业务功能概览

核心功能模块：

- **题目管理**：题目列表、搜索、多条件筛选、富文本编辑
- **题库管理**：题库CRUD、层级管理（父子题库）
- **标签管理**：标签CRUD、与题目多对多关联
- **图片管理**：阿里云OSS文件浏览、上传、删除、签名URL
- **练习模式**：随机模式、顺序模式、错题模式

---

## 5. 页面导航设计

### 底部导航栏

底部导航栏采用精简设计，仅保留两个一级入口：

| 序号 | 标签 | 图标 | 说明 |
|------|------|------|------|
| 0 | 考试 | quiz | 考试功能总入口，内部通过顶部切换器细分 |
| 1 | 图片 | image | 图片管理（OSS） |

### 考试页面内部组织

进入"考试"tab后，页面内部顶部设有横向切换栏，包含四个子标签：

| 子标签 | 图标 | 对应页面 | 说明 |
|--------|------|----------|------|
| 题目 | edit_note | QaPage | 题目列表、搜索、筛选、编辑 |
| 练习 | school | PracticePage | 练习模式选择与答题 |
| 题库 | folder | BankPage | 题库管理 |
| 标签 | label | TagPage | 标签管理 |

顶部切换栏使用底部高亮线指示当前选中标签，带图标和文字，支持点击切换。子页面使用`AutomaticKeepAliveClientMixin`保活，切换不丢失状态。

### 设计动机

将题目、练习、题库、标签四个紧密关联的功能整合到"考试"一个tab下，避免底部导航项过多。后续新增功能可直接添加为底部tab，不需要重新组织架构。

---

## 6. 目录结构约定

- 图片统一上传到`/images/`目录下
- 题目图片存储路径示例：`/images/qa/xxx.jpg`
- 用户可在上传时指定子目录，或默认上传到`/images/`根目录
