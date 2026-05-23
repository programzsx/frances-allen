# Frances Allen 测试方案

## 1、测试范围与策略

| 层级 | 类型 | 工具 | 触发条件 |
|------|------|------|----------|
| 后端API | 集成测试 | Python requests脚本 | 服务运行时手动执行 |
| 移动端 | 静态分析 | flutter analyze | 每次代码变更 |
| 移动端 | Widget测试 | flutter test | 构建前 |
| 移动端 | Web构建 | flutter build web | 发布前 |
| 桌面端 | 静态分析 | flutter analyze | 每次代码变更 |
| 主题一致性 | 人工审查 | 视觉对比alan-perlis | 重构后 |

## 2、后端API测试

### 测试文件

`server/tests/test_api.py` — 单文件脚本，使用`requests`库，无需pytest。

### 运行方式

```bash
cd server
pip install requests
python tests/test_api.py
```

### 测试用例清单

#### 题库管理（5项）

| # | 测试名称 | 验证点 |
|---|---------|--------|
| 1 | 创建根题库 | id/create_time/update_time/name/parent_id |
| 2 | 创建子题库 | parent_id关联 |
| 3 | 不存在的parent_id报错 | 500或错误消息 |
| 4 | 更新题库 | name/update_time |
| 5 | 分页查询题库 | items/total/current_page/page_size |
| 6 | 关键字搜索题库 | total>=1 |
| 7 | 题库树形结构 | children层级 |

#### 标签管理（4项）

| # | 测试名称 | 验证点 |
|---|---------|--------|
| 1 | 创建标签 | id/create_time/update_time/name |
| 2 | 更新标签 | name/update_time |
| 3 | 分页查询标签 | items/total |
| 4 | 关键字搜索标签 | total>=1 |
| 5 | 标签题目统计 | 返回dict |

#### 题目管理（12项）

| # | 测试名称 | 验证点 |
|---|---------|--------|
| 1 | 创建题目（完整字段） | 全部11字段验证 |
| 2 | 创建题目（无图无标签） | 可选字段为None |
| 3 | 不存在的bank_id | 报错 |
| 4 | 不存在的tag_id | 报错 |
| 5 | 获取题目详情 | id/question/answer |
| 6 | 更新题目 | question/answer |
| 7 | 统计字段约束通过 | right+wrong=total |
| 8 | 统计字段约束失败 | right+wrong!=total报错 |
| 9 | 分页查询 | items/total |
| 10 | 按题库筛选 | bank_id |  
| 11 | 关键字搜索 | total>=1 |
| 12 | 随机获取 | limit限制 |
| 13 | 按题库随机 | bank_id筛选 |
| 14 | 顺序获取 | random_int升序 |
| 15 | 错题列表 | wrong>=min_wrong |

#### 图片管理OSS（5项）

| # | 测试名称 | 验证点 |
|---|---------|--------|
| 1 | 上传到kb/路径 | key以kb/开头 |
| 2 | 列出kb/目录 | dirs/files/total |
| 3 | 获取签名URL | url以http开头 |
| 4 | 获取公开URL | 返回url |
| 5 | 删除OSS图片 | success=true |

#### 删除与清理（3项）

| # | 测试名称 | 验证点 |
|---|---------|--------|
| 1 | 删除题目 | 二次查询为None |
| 2 | 删除标签 | success |
| 3 | 删除题库 | 先子后根 |

#### 健康检查（1项）

| # | 测试名称 | 验证点 |
|---|---------|--------|
| 1 | GET / | app=frances-allen，status=running |

### 测试数据清理

所有测试数据在删除阶段清理，确保数据库不残留测试记录。

## 3、前端交互测试方案

### 3、1 主题验证

| 检查项 | 预期 |
|--------|------|
| 主色 | #E53935红色 |
| 背景 | #F5F5F5浅灰 |
| 卡片 | 白色，无边框，圆角12 |
| 输入框 | 灰色填充，无边框，聚焦红色border |
| AppBar | 白底，居中标题 |
| Chip选中 | 红色实心，白字 |
| Chip未选中 | 白底，灰字 |
| FAB | 红底圆形 |
| 底部导航栏 | 白底，选中项红色 |

### 3、2 导航验证

| 操作 | 预期 |
|------|------|
| 底部导航切换到"考试" | 显示QaPage，含AppBar+芯片行 |
| 底部导航切换到"图片" | 显示ImageManagePage |
| QaPage AppBar题库图标 | 跳转BankPage全屏管理页 |
| QaPage AppBar标签图标 | 跳转TagPage全屏管理页 |
| QaPage AppBar练习图标 | 跳转PracticePage |
| BankPage返回 | QaPage刷新，芯片行更新 |
| TagPage返回 | QaPage刷新，芯片行更新 |

### 3、3 芯片行筛选验证

| 操作 | 预期 |
|------|------|
| 点击题库chip | 选中变为红色实心，标签行出现，列表刷新 |
| 再次点击同一题库chip | 取消选中，标签行隐藏 |
| 题库行始终可见 | 水平滚动，所有题库可见 |
| 标签行条件显示 | 仅选中题库时出现 |
| 标签chip toggle | 点击选中/取消，列表刷新 |

### 3、4 题目CRUD流程

| 操作 | 预期 |
|------|------|
| 点击FAB | 进入新增题目页面 |
| 新增题目保存 | 返回列表，新题目出现 |
| 点击题目卡片 | 进入详情页 |
| 详情页编辑 | 进入编辑页，数据预填 |
| 编辑保存 | 返回详情页，数据更新 |
| 详情页删除 | 确认对话框，删除后列表刷新 |
| 删除按钮 | 红色颜色 |

### 3、5 练习模式流程

| 操作 | 预期 |
|------|------|
| 从AppBar进入练习 | 显示模式选择页 |
| 选择题库 | 搜索下拉，显示题目数量 |
| 随机模式 | 随机抽取题目，shuffle打乱 |
| 顺序模式 | 按random_int顺序 |
| 错题模式 | 筛选wrong>=N题目 |
| 错题滑块 | 范围1-10 |
| 答题提交 | 精确匹配，绿/红反馈 |
| 统计更新 | total/right/wrong自动更新 |

### 3、6 图片管理流程

| 操作 | 预期 |
|------|------|
| 默认目录 | 显示kb/目录 |
| 文件列表 | 列表/网格视图切换 |
| 点击图片 | 全屏预览，左右滑动 |
| 上传图片 | 选择→预览→命名→上传 |
| 默认路径 | 上传到kb/目录 |
| 命名格式 | {自定义名}-{时间戳}-{随机数}.{扩展名} |
| 删除图片 | 确认删除 |
| 签名URL | 可获取并复制 |

### 3、7 BankPage/TagPage管理

| 操作 | 预期 |
|------|------|
| BankPage AppBar | 返回箭头+"题库管理" |
| 题库层级缩进 | 子题库缩进显示 |
| 父题库选择器 | 下拉选择，防止循环引用 |
| TagPage AppBar | 返回箭头+"标签管理" |
| 返回刷新 | DataCache invalidate |

## 4、桌面端一致性验证

| 检查项 | 预期 |
|--------|------|
| 主题颜色 | 与mobile一致（红色系） |
| 导航布局 | NavigationRail+内容区 |
| 芯片行 | 与mobile一致 |
| OSS前缀 | kb/ |
| DataCache | 与mobile一致 |
| 字体 | Microsoft YaHei |

## 5、已知边界条件

| 场景 | 处理 |
|------|------|
| 空题库 | 显示"暂无题目"图标+文字 |
| 空标签 | 标签行不显示 |
| 无网络 | Loading后显示错误SnackBar |
| 长列表 | 无限滚动，loadingMore指示器 |
| 并发删除 | 二次查询返回null |
| OSS上传失败 | 错误提示+允许重试 |
| 循环引用（题库） | 编辑时排除自身及子孙节点 |
| Dropdown未加载 | CircularProgressIndicator占位 |
