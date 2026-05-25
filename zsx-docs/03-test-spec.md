# Frances Allen — 测试方案

> 版本：v2.0 | 更新日期：2026-05-25

---

## 1. 测试范围与策略

| 层级 | 类型 | 工具 | 目标 | 触发条件 |
|------|------|------|------|----------|
| 后端API | 全量集成测试 | Python requests脚本 | 验证所有API端点的字段、状态码、业务逻辑 | 每次部署前 |
| 后端API | 健康检查 | curl | 验证服务运行状态 | 部署后自动 |
| 移动端 | 静态分析 | flutter analyze | 确保代码无编译错误和警告 | 每次代码变更 |
| 移动端 | 构建验证 | flutter build apk --debug | 确保APK可成功构建 | 发布前 |
| 移动端 | Web构建验证 | flutter build web | 确保Web版本可构建 | 发布前 |
| 主题一致性 | 规范审查 | 人工对比 | 确保UI符合AppTheme规范 | 重构后 |

### 测试环境

- 后端API：`http://8.160.174.178:8000`（阿里云ECS）
- 数据库：阿里云RDS MySQL `frances-allen`
- 文件存储：阿里云OSS `zsx-r7000p`

---

## 2. 后端API全量测试用例

### 2.1 健康检查（1项）

| # | 测试名称 | 请求 | 验证点 |
|---|---------|------|--------|
| 1 | 健康检查 | `GET /` | `app=frances-allen`，`status=running` |

### 2.2 题库管理（9项）

| # | 测试名称 | 请求 | 验证点 |
|---|---------|------|--------|
| 1 | 创建根题库 | `POST /api/banks` `{"name":"Java","sort_order":0}` | 200, 验证 id/create_time/update_time/name/parent_id/sort_order |
| 2 | 创建带sort_order的题库 | `POST /api/banks` `{"name":"Spring","sort_order":10}` | 200, sort_order=10 |
| 3 | 创建子题库 | `POST /api/banks` `{"name":"Java基础","parent_id":"...","sort_order":0}` | 200, parent_id匹配 |
| 4 | 不存在的parent_id | `POST /api/banks` `{"name":"test","parent_id":"nonexistent"}` | 500或错误消息 |
| 5 | 更新题库 | `PUT /api/banks/:id` `{"name":"Java进阶","sort_order":5}` | 200, name/sort_order/update_time |
| 6 | 分页查询题库 | `GET /api/banks?current_page=1&page_size=10` | 200, items/total/current_page/page_size |
| 7 | 关键字搜索题库 | `GET /api/banks?keyword=Java` | 200, total>=1 |
| 8 | 题库树形结构 | `GET /api/banks/tree` | 200, 列表格式，有children层级 |
| 9 | 题库题目数量统计 | `GET /api/banks/question-counts` | 200, 返回 {bank_id: count} |

### 2.3 标签管理（7项）

| # | 测试名称 | 请求 | 验证点 |
|---|---------|------|--------|
| 1 | 创建标签 | `POST /api/tags` `{"name":"重点","sort_order":0}` | 200, id/create_time/update_time/name/sort_order |
| 2 | 创建带sort_order的标签 | `POST /api/tags` `{"name":"易错","sort_order":5}` | 200, sort_order=5 |
| 3 | 更新标签 | `PUT /api/tags/:id` `{"name":"核心重点","sort_order":3}` | 200, name/sort_order/update_time |
| 4 | 分页查询标签 | `GET /api/tags?current_page=1&page_size=10` | 200, items/total |
| 5 | 关键字搜索标签 | `GET /api/tags?keyword=核心` | 200, total>=1 |
| 6 | 标签题目统计 | `GET /api/qas/tag-counts` | 200, 返回dict |
| 7 | 批量获取标签 | `POST /api/tags/batch` `{"ids":["id1","id2"]}` | 200, 返回对应标签列表 |

### 2.4 题目管理（16项）

| # | 测试名称 | 请求 | 验证点 |
|---|---------|------|--------|
| 1 | 创建题目（完整字段） | `POST /api/qas` 含question/answer/image_url/category_id/tag_id | 200, 全部字段验证(id/create_time/update_time/question/answer/image_url/total/right/wrong/random_int/category_id/tag_id) |
| 2 | 创建题目（无图无标签） | `POST /api/qas` 仅question+answer | 200, image_url=null, category_id=null, tag_id=null |
| 3 | 创建题目（tag_id为列表） | `POST /api/qas` tag_id=["id1","id2"] | 200, tag_id正确序列化存储 |
| 4 | 不存在的category_id | `POST /api/qas` category_id="nonexistent" | 500或错误消息 |
| 5 | 获取题目详情 | `GET /api/qas/:id` | 200, id/question/answer/所有字段 |
| 6 | 更新题目 | `PUT /api/qas/:id` `{"question":"新题","answer":["答"]}` | 200, question/answer更新 |
| 7 | 更新题目统计字段 | `PUT /api/qas/:id` `{"total":10,"right":7,"wrong":3}` | 200（后端会跳过这些非模型字段） |
| 8 | 分页查询 | `GET /api/qas?current_page=1&page_size=10` | 200, items/total |
| 9 | 按题库筛选 | `GET /api/qas?category_id=xxx` | 200, 所有item的category_id匹配 |
| 10 | 按标签筛选 | `GET /api/qas?tag_id=xxx` | 200, 返回关联该标签的题目 |
| 11 | 关键字搜索 | `GET /api/qas?keyword=杨幂` | 200, total>=1 |
| 12 | 随机获取 | `GET /api/qas/random/list?limit=5` | 200, 返回list，len<=5 |
| 13 | 按题库随机 | `GET /api/qas/random/list?limit=5&category_id=xxx` | 200, 所有item的category_id匹配 |
| 14 | 顺序获取 | `GET /api/qas/sequential/list?limit=5` | 200, 返回list，len<=5，按random_int升序 |
| 15 | 错题筛选 | `GET /api/qas/wrong/list?limit=10&min_score=0` | 200, 返回list |
| 16 | tag_id兼容性 | 验证从API获取的题目tag_id可被Flutter正确解析 | tag_id为null/字符串/JSON数组三种情况均可解析 |

### 2.5 图片管理OSS（5项）

| # | 测试名称 | 请求 | 验证点 |
|---|---------|------|--------|
| 1 | 列出kb/目录 | `GET /api/images/list?prefix=kb` | 200, 有dirs/files字段 |
| 2 | 列出根目录 | `GET /api/images/list?prefix=` | 200, 有dirs/files字段 |
| 3 | 获取签名URL | `GET /api/images/:key/signed-url` | 200, url以http开头 |
| 4 | 获取公开URL | `GET /api/images/:key/public-url` | 200, 返回url |
| 5 | 删除不存在的文件 | `DELETE /api/images/nonexistent-key` | 404或错误 |

### 2.6 删除与清理（3项）

| # | 测试名称 | 验证点 |
|---|---------|--------|
| 1 | 删除题目 | `DELETE /api/qas/:id` → success，二次查询返回null |
| 2 | 删除标签 | `DELETE /api/tags/:id` → success |
| 3 | 删除题库 | `DELETE /api/banks/:id` → success（先确保无子题库和关联题目） |

---

## 3. 前端页面功能测试方案

### 3.1 每日练习流程

| # | 操作 | 预期结果 |
|---|------|----------|
| 1 | 启动APP | 直接进入DailyQuizPage，显示5道随机题的第1题 |
| 2 | 提交答案 | 显示结果（正确绿色/错误红色），显示正确答案 |
| 3 | 下一题 | 进度条更新，显示下一题 |
| 4 | 完成5题 | 显示完成页，正确数+emoji |
| 5 | 点击进入APP | 跳转HomePage，不可返回练习页 |
| 6 | 练习中按返回 | 提示"请先完成今日练习" |

### 3.2 练习页面（层级下钻）

| # | 操作 | 预期结果 |
|---|------|----------|
| 1 | 进入练习Tab | 加载题库树，展示根题库卡片（Wrap可换行） |
| 2 | 点击有子题库的卡片 | 下钻到子题库列表，面包屑更新 |
| 3 | 面包屑回退 | 点击面包屑任意级回到对应层级 |
| 4 | 点击叶子题库 | 选中为练习目标，卡片变红，显示题库信息 |
| 5 | 选择当前层级 | 点击"选择「xxx」"选中非叶子题库 |
| 6 | 切换练习模式 | 随机/顺序/错题三栏可切换 |
| 7 | 错题模式滑块 | -1到1，默认0 |
| 8 | 开始练习 | 跳转PracticeQuizPage，加载该题库全部题目 |
| 9 | 答题提交 | 精确匹配，绿/红反馈，显示正确答案 |
| 10 | 缓存复用 | 离开练习Tab再回，状态保持，无loading |

### 3.3 考试页面

| # | 操作 | 预期结果 |
|---|------|----------|
| 1 | 进入考试Tab | 显示题目列表，搜索框，题库芯片行 |
| 2 | 搜索题目 | 输入关键字回车，列表过滤 |
| 3 | 点击题库chip | 选中红色，标签行出现，列表刷新 |
| 4 | 再次点击同一chip | 取消选中 |
| 5 | 点击标签chip | 选中/取消，列表刷新 |
| 6 | AppBar题库 | 跳转BankPage |
| 7 | AppBar标签 | 跳转TagPage |
| 8 | AppBar图片 | 跳转ImageManagePage |
| 9 | 点击题目卡片 | 跳转QaDetailPage |
| 10 | FAB新增 | 跳转QaFormPage |
| 11 | 状态保持 | 切换Tab再回，筛选状态/滚动位置保持 |

### 3.4 题库管理

| # | 操作 | 预期结果 |
|---|------|----------|
| 1 | 进入题库管理 | 显示树形列表+题目数量 |
| 2 | 点击编辑图标 | 弹窗，预填名称/排序值/父题库 |
| 3 | 修改排序值 | 保存后列表更新 |
| 4 | 点击题库名称 | 跳转BankDetailPage，标题为题库名，展示关联题目 |
| 5 | 删除题库 | 确认弹窗，删除后列表刷新 |
| 6 | 新增子题库 | 父题库下拉选择，保存后显示缩进 |
| 7 | 缓存复用 | 离开再进，瞬间渲染，无loading |
| 8 | 搜索过滤 | 输入关键字，列表过滤 |

### 3.5 标签管理

| # | 操作 | 预期结果 |
|---|------|----------|
| 1 | 进入标签管理 | 显示标签列表+题目数量 |
| 2 | 点击编辑按钮 | 弹窗，预填名称/排序值 |
| 3 | 修改排序值 | 保存后列表更新 |
| 4 | 点击标签名称 | 跳转TagDetailPage，标题为标签名，展示关联题目 |
| 5 | 删除标签 | 确认弹窗，删除后列表刷新 |
| 6 | 新增标签 | 填写名称+排序值，保存后出现 |
| 7 | 缓存复用 | 离开再进，瞬间渲染，无loading |

### 3.6 图片管理

| # | 操作 | 预期结果 |
|---|------|----------|
| 1 | 进入图片管理 | 展示kb/目录内容 |
| 2 | 面包屑导航 | 可进入子目录，可回退到根 |
| 3 | 视图切换 | 列表/网格切换 |
| 4 | 缓存复用 | 同目录离开再进，瞬间渲染 |

### 3.7 导航与全局

| # | 操作 | 预期结果 |
|---|------|----------|
| 1 | 底部Tab切换 | 练习↔考试，IndexedStack保持状态 |
| 2 | 主页按返回 | 弹窗确认退出，取消留在APP |
| 3 | 子页面返回 | 正常返回上一页 |
| 4 | 主题颜色 | #E53935红色主色，#F5F5F5浅灰背景 |
| 5 | 返回确认 | PopScope拦截，取消/确认按钮 |

---

## 4. 前端构建验证

| # | 检查项 | 命令 | 预期 |
|---|--------|------|------|
| 1 | 静态分析 | `flutter analyze` | 0 errors |
| 2 | APK构建 | `flutter build apk --debug` | BUILD SUCCESSFUL |
| 3 | Web构建 | `flutter build web` | BUILD SUCCESSFUL |

---

## 5. 已知边界条件

| 场景 | 预期处理 |
|------|----------|
| 空题库 | 显示"暂无题库"提示 |
| 空题目列表 | 显示"暂无题目"图标+文字 |
| 无网络 | Loading后显示错误SnackBar |
| 长列表 | 无限滚动分页加载 |
| 每日练习无题 | 显示"暂无题目"+"进入APP"按钮 |
| tag_id为null/字符串/列表 | Flutter _parseTagId兼容处理 |
| 并发创建同名 | 后端返回唯一性错误 |
| 循环引用（题库） | 编辑时排除自身及子孙节点 |
| 统计字段更新 | 后端DAO忽略非模型字段(total/right/wrong) |
