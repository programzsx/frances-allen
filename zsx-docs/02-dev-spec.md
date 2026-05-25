# Frances Allen — 开发设计规范

> 数据设计 / 接口设计 / 开发规范

---

## 1. 数据设计理论

面向MySQL数据表设计，我认为字段有四段。这是我的四段数据设计理论。

- **基础字段**：每张表都必备的字段，如`id`（雪花ID）、`create_time`（时间戳字符串）、`update_time`（时间戳字符串）
- **业务字段**：每张表的核心存储，业务是什么就设计什么字段。如问答对表的`question`和`answer`。字段设计尽量原子性
- **统计字段**：方便数据治理。统计是计时和计量——计时是duration，计量是计数。如每道题回答次数、答对次数、答错次数。是否设计计时和计量，要具体问题具体分析
- **关联字段**：关联其他表的ID。如标签ID、题库ID

total、right、wrong三者存在约束（right+wrong = total），统一建议在代码中做约束校验而非数据库层面。

---

## 2. 数据建模设计

### kb_qa表（问答对表）

kb代表knowledge_base（知识库），qa是question和answer（问答对）。

- 基础字段：`id`、`create_time`、`update_time`
  - `id`为雪花ID
  - `create_time`为时间戳字符串，不区分时区
  - `update_time`为时间戳字符串
- 业务字段：`question`、`answer`、`image_url`
  - `question`：字符串，用三个连续下划线`___`表示填空空白。如`杨幂出生于___年，毕业于___。`
  - `image_url`：字符串，OSS图片URL。每个题目最多一张图片，可无图片
  - `answer`：JSON数组，每个元素为字符串。如`["1986","北京电影学院"]`
- 统计字段：`total`、`right`、`wrong`、`random_int`
  - `total`：一共练习/回答次数
  - `right`：答对次数
  - `wrong`：答错次数
  - `random_int`：自增整数，用于排序和随机
- 关联字段：`category_id`、`tag_id`
  - `category_id`：字符串，所属知识分类ID。每个题目只能属于一个分类
  - `tag_id`：JSON数组，关联标签ID列表。一个题目可以有多个标签

### kb_bank表（题库表）

- 基础字段：`id`、`create_time`、`update_time`
- 业务字段：`name`：题库名字，如"Java"、"公务员"
- 关联字段：`parent_id`：父题库ID，指向同一张表的id，用于层级化控制

### kb_tag表（标签表）

- 基础字段：`id`、`create_time`、`update_time`
- 业务字段：`name`：标签名字

---

## 3. 题目管理设计

### 导航链路

题目管理采用三级导航：

```
题目列表 (QaPage) → 题目详情 (QaDetailPage) → 题目编辑 (QaFormPage)
```

- **题目列表页**：展示题目卡片列表，点击进入详情
- **题目详情页**：展示完整信息（题目、答案、图片、统计），右上角提供编辑和删除按钮
- **题目编辑页**：表单编辑，支持新增和编辑两种场景

### 题目详情页内容

- 顶部标签：题库名称Chip + 标签名称Chip列表
- 题目：使用`QuestionRichText`渲染，支持所有富文本标记
- 答案：绿色背景卡片，编号列表展示
- 图片：如有图片则展示，点击可全屏预览
- 统计：三列统计卡片（总次数/正确/错误）+ 正确率展示

### 编辑功能

#### 填空快速输入

题目中使用三个连续下划线`___`表示填空空白。支持两种快捷输入：

- 空格触发：输入三个连续空格自动转换为`___`
- 按钮插入：点击"填空"按钮在光标位置插入`___`

#### 答案框自动生成

系统自动检测题目中`___`的数量，自动生成对应数量的答案输入框：

- 检测`___`在题目文本中出现的次数
- 当检测到数量变化时，自动同步调整答案输入框数量
- 手动添加的答案框不受自动生成逻辑影响

#### 快捷输入工具栏

在题目编辑页面的快捷输入区域，新增五个按钮：

| 按钮 | 功能 | 选中文字行为 | 未选中文字行为 |
|------|------|-------------|---------------|
| 填空 | 插入`___` | 替换选中文本为`___` | 在光标处插入`___` |
| 加粗 | 插入`**` | 包裹选中文本为`**XX**` | 插入`****`光标居中 |
| 高亮 | 插入`==` | 包裹选中文本为`==XX==` | 插入`====`光标居中 |
| 代码 | 插入`` ` `` | 包裹选中文本为`` `XX` `` | 插入`` `` ``光标居中 |
| 分割线 | 插入`----` | 替换为换行+`----`+换行 | 插入换行+`----`+换行 |

#### 题目预览功能

在编辑页面AppBar右侧添加"预览"按钮（visibility图标），点击弹出对话框：

- 顶部：标题栏（"题目预览"+关闭按钮）
- 题库标签：显示当前选择题库名称Chip
- 题目详情：使用`QuestionRichText`渲染题目文本
- 答案区域：绿色背景卡片，编号列表展示所有答案
- 图片：通过`![url]`标记或单独渲染，点击可全屏预览

预览对话框使用`Dialog`组件，最大高度为屏幕高度的80%，内容可滚动。

---

## 4. 题库管理设计

### 层级管理

`kb_bank`表存在`parent_id`字段，题库支持层级关系（父题库→子题库→孙子题库）。

需求：

- 题库列表按层级关系缩进展示，根节点靠左，子节点逐级缩进
- 父题库改为下拉选择器，从已有题库中选择
- 编辑题库时不能将当前题库自身或其子孙题库设为父题库（防止循环引用）
- 无`parent_id`的题库为根节点

### 实现方式

后端：

- `GET /api/banks/tree`端点返回嵌套树形结构
- 前端通过`ApiService.getBankTree()`获取树数据，填充下拉选项
- 列表页获取全量数据，前端本地按`parent_id`构建树并展平为缩进列表

前端BankPage列表：

- `_loadBanks()`调用`ApiService.getBanks()`获取全量数据
- 构建`Map<String, List<KbBank>>`（parentId→children）
- 从根节点（`parentId == null`）开始递归遍历，展平为带`depth`字段的一维列表
- 渲染时每行按`depth`缩进（`Padding(left: depth * 24.w)`），前缀显示树形符号（`├─`/`└─`）

父题库选择器：

- 用`DropdownButton<String?>`替换`TextField`
- `items`从`getBankTree()`返回的树形结构递归展平生成（带缩进空格）
- 编辑模式下排除当前节点及其子孙节点
- 第一项为"无（根题库）"，值为`null`

---

## 5. 标签管理设计

标签采用扁平列表管理，CRUD操作与题库类似。标签与题目多对多关联，通过`kb_qa`表的`tag_id` JSON数组存储。标签列表页、标签表单页的设计模式与题库一致。

---

## 6. 图片管理设计

### 概述

图片管理基于阿里云OSS实现，管理`zsx-r7000p`桶中的目录和文件。

OSS配置：

- AccessKey ID和Secret通过环境变量配置
- Endpoint：`oss-cn-beijing.aliyuncs.com`
- Bucket：`zsx-r7000p`

### 功能列表

#### 目录浏览

- 进入图片管理页面，默认展示桶根目录
- 显示当前目录下的所有子目录和文件（图片）
- 支持进入子目录查看

#### 视图切换

- 列表视图：每行显示名称、修改时间、大小等信息
- 图标/瀑布流视图：以网格形式展示图片缩略图

#### 图片预览（全屏）

- 点击图片进入全屏预览模式
- 支持左右滑动切换查看同一目录下的其他图片
- 预览模式下提供两个操作按钮：
  - 删除：从OSS中删除该图片
  - 复制：复制该图片的外链访问URL

#### 图片上传（本地→OSS）

上传流程：

- 选择图片：从本地文件选择器选择图片，选择后不自动上传，进入待上传状态
- 预览确认：显示选择的图片预览图，可重新选择替换
- 上传执行：点击上传按钮开始上传到OSS指定目录，显示loading状态
- 结果处理：成功显示URL并提供复制按钮，失败显示错误提示并允许重试

#### 上传功能增强

- 图片预览：选择图片后在上传对话框中显示预览图
- 全屏预览：点击预览图可全屏查看，支持缩放（InteractiveViewer）
- 取消/重新选择：提供按钮取消当前选择并重新选择图片
- 自定义重命名：提供输入框让用户输入文件名前缀

重命名规范：`{自定义名}-{年}-{月}-{日}-{时}-{分}-{秒}-{8位随机数}.{扩展名}`

示例：`杨幂-2026-04-12-14-18-23-62566940.jpg`

- 自定义名：用户在输入框中填写
- 时间戳：上传时的本地时间，月/日/时/分/秒不足两位补零
- 8位随机数：00000000-99999999
- 扩展名：原始文件的扩展名

上传对话框布局：

- 顶部：标题栏（标题+关闭按钮）
- 中部：图片预览区（点击可全屏预览，右下角有"点击全屏"提示）
- 下部：操作区
  - 文件名输入框（labelText:"文件名（不含扩展名）"）
  - 存储目录输入框
  - "选择图片"/"重新选择"按钮
  - "取消选择"按钮（删除图标）
  - "上传"按钮（未选择图片时禁用）

### 前端页面结构

`ImageManagePage`页面包含：

- 顶部导航栏（标题：图片管理）
- 视图切换按钮（列表/图标）
- 目录面包屑导航（可点击返回上级目录）
- 文件列表（目录列表+文件列表）
- 悬浮上传按钮（点击进入上传流程）
- 全屏预览组件（带删除、复制功能）
- 上传组件（图片选择→预览→上传→复制URL）

### 后端API设计

新增路由`/api/images`：

- `GET /api/images/list`：获取指定目录下的文件和目录列表
- `POST /api/images/upload`：上传图片到OSS（支持指定目录）
- `DELETE /api/images/{key}`：删除OSS中的文件
- `GET /api/images/{key}/signed-url`：获取文件的签名访问URL

---

## 7. 状态管理设计

### 核心原则

APP 内所有页面必须具备跨页面状态保持能力。用户在同一会话内离开页面再返回，页面状态应与离开时一致，不应重新加载数据或重置滚动位置。只有 APP 完全退出后重新进入，状态才应重建。

### 页面分类

#### A 类：底部导航页（IndexedStack 自动保持）

`HomePage` 使用 `IndexedStack` 包裹 `PracticePage` 和 `QaPage`。`IndexedStack` 保留所有子 Widget 的 State，切换 Tab 不会触发 `initState` 重建。

- **练习页**：State 自然保持，无需额外处理
- **考试页**：State 自然保持；从题库/标签管理返回后通过 `.then()` 回调触发 `_fetchMeta()` + `_fetch()` 刷新题目列表，属于预期的主动刷新

#### B 类：管理页面（DataCache 单例缓存）

`BankPage`、`TagPage`、`ImageManagePage` 通过 `Navigator.push` 进入，每次进入创建新 State 实例。使用全局单例 `DataCache` 解决状态丢失问题。

**DataCache 设计**：

```
DataCache (ChangeNotifier 单例)
├── ensureBanks()    → 并行请求 banks + tree + counts
├── ensureTags()     → 请求 tags
├── getCachedImages(prefix) / cacheImages(prefix, data)
└── invalidate()     → 清除所有缓存，通知监听者刷新
```

**页面使用模式**：

```
initState:
  _cache = DataCache()
  _cache.addListener(_onCacheUpdate)  ← 监听缓存变化
  if _cache.hasBanks → 直接渲染缓存数据
  else               → _cache.ensureBanks() → 渲染

dispose:
  _cache.removeListener(_onCacheUpdate)

_onCacheUpdate:
  if _cache.hasBanks → _buildFlatList()  ← 被动刷新
```

**缓存失效策略**：
- 增/删/改操作成功后 → `_cache.invalidate()` → `_loadXxx(force: true)`
- 仅清除对应数据，不影响其他页面缓存
- 图片缓存按 prefix 分桶，删除/上传后仅失效该目录

#### C 类：详情/表单页（无需缓存）

`QaDetailPage`、`QaFormPage` 每次进入都是全新的上下文（题目ID不同），无需缓存，始终即时请求。

#### D 类：特殊页面

- **DailyQuizPage**：初始路由，先进入题库选择页（展示根题库 + 后代聚合题数），选库后进入答题。完成后 `pushReplacementNamed('/home')`，不可返回
- **PracticeQuizPage**：从 PracticePage push 进入，练习上下文随 session

### 数据请求原则

- **首次进入页面**：检查 DataCache，缓存命中则直接渲染（无 loading 态），缓存未命中则显示 loading + 请求
- **再次进入页面**：DataCache 命中 → 瞬间渲染，无网络请求
- **修改数据后返回**：调用 `invalidate()` + `force: true` 强制重新请求
- **并行请求**：多个独立接口使用 `Future.wait` 并行化，减少等待时间
- **批量统计**：题目数量统计使用 `GROUP BY` 批量接口一次性返回全部，避免 N+1 问题

---

## 7. 练习模式设计

### 三种练习模式

练习页面提供三种模式，通过顶部三栏选择器切换。

#### 随机模式

- 从选定题库中随机抽取题目
- 无需额外配置，选择题库后点击"开始练习"即可

#### 顺序模式

- 按`random_int`字段升序取题，保证题目顺序固定
- 适合按固定顺序系统练习

#### 错题模式

- 从选定题库中筛选未掌握的题目
- 掌握程度滑块：Slider控件，范围 -1（不会）到 1（掌握），默认值 0（模糊及以下）
- `min_score=0`：筛选 `score <= 0` 的所有未掌握题目
- `min_score=-1`：仅筛选 `score <= -1` 的题目（完全不会）

### 后端API

- `GET /api/qas/random/list?limit=10&category_id=`：随机取题（单选）
- `GET /api/qas/random/list?limit=10&category_ids=a,b,c`：随机取题（多选，逗号分隔）
- `GET /api/qas/sequential/list?limit=10&category_id=&offset_id=`：顺序取题，按`random_int`升序
- `GET /api/qas/wrong/list?limit=10&category_id=&min_score=0`：未掌握题目筛选，`score <= min_score`

### DAO层实现

- `random_query()`：`ORDER BY RAND()`，MySQL随机取题
- `sequential_query()`：`ORDER BY random_int ASC`，支持`offset_id`跳过已答题目
- `wrong_query()`：`WHERE score <= min_score ORDER BY score ASC`，按掌握程度筛选

### 答题交互

- 系统显示题目，包含`___`占位符
- 用户在答案输入框中填写答案
- 点击提交后，系统比较用户答案与正确答案

### 答案校验逻辑

- 精确匹配（不考虑大小写等模糊匹配）
- 答案数量必须与填空数量一致
- 每个位置的答案必须完全匹配

反馈机制：

- 答对：显示绿色成功提示
- 答错：显示红色错误提示，并展示正确答案

---

## 8. 富文本渲染设计

### 标记语法

在题目文本中支持以下标记语法（类Markdown）：

| 标记 | 语法 | 示例 | 说明 |
|------|------|------|------|
| 加粗 | `**文字**` | `**重点**` | 选中文本点击加粗→`**XX**`，未选中→`****`光标在中间 |
| 高亮 | `==文字==` | `==注意==` | 选中文本点击高亮→`==XX==`，未选中→`====`光标在中间 |
| 代码 | `` `文字` `` | `` `代码` `` | 选中文本点击代码→`` `XX` ``，未选中→`` `` ``光标在中间 |
| 分割线 | `----` | 单独一行 | 点击分割线按钮→自动换行插入`----`再换行 |
| 填空 | `___` | 保持不变 | 原有功能 |
| 图片 | `![url]` | `![https://...]` | 单独一行，渲染为全宽图片，点击可全屏预览 |

### 渲染样式

| 标记 | 渲染效果 |
|------|----------|
| `**文字**` | 文字渲染为蓝色（`#0052D9`），加粗 |
| `==文字==` | 添加黄色背景底色（`#FFF9C4`） |
| `` `文字` `` | 添加灰色背景底色（`#F0F0F0`），圆角，文字变红色（`red.shade700`），等宽字体 |
| `----` | 水平分割线（Divider），灰色 |
| `___` | 填空占位符，紫色背景底色（`#E8DEF8`），下划线样式 |
| `![url]` | 全宽图片，圆角，点击全屏预览（InteractiveViewer） |

### 实现方式

共享组件`QuestionRichText`（`lib/pages/question_rich_text.dart`），接收参数：

- `text`：题目原始文本
- `revealed`：是否已揭示答案
- `answers`：答案列表
- `fontSize`：字号

内部通过两阶段解析：

- 按换行符分割为块（Block），识别分割线行和图片行
- 对文本行进行词法分析（Tokenize），识别加粗、高亮、代码、填空标记

使用场景：`QaPage`（题目列表卡片）、`PracticePage`（练习页面题目展示）、`QaFormPage`（预览对话框）。

---

## 9. API 概览

| 路径 | 说明 |
|------|------|
| `GET /` | 健康检查 |
| `GET/POST /api/banks` | 题库列表/创建 |
| `PUT/DELETE /api/banks/:id` | 更新/删除题库 |
| `GET /api/banks/tree` | 题库树 |
| `GET /api/banks/question-counts` | 题库题目数量统计（仅直接题目） |
| `GET /api/banks/descendant-counts` | 题库题目数量统计（含所有后代聚合） |
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

---

## 10. 已知问题修复

### DropdownButton断言错误（红色闪屏）

**现象**：点击题目进入编辑页面时，页面一闪而过出现红色错误页面，随后恢复正常。

**原因**：`QaFormPage`中的`DropdownButtonFormField`（题库选择器）在`_banks`元数据异步加载完成前就被渲染。编辑模式下`_bankId`已有值，但下拉列表的`items`为空。Flutter的`DropdownButton`断言要求`value`必须是`items`中的一个，或`value`为`null`。两者都不满足时触发红色断言错误。

**修复方案**：在`_banks`加载完成前显示`CircularProgressIndicator`占位符，不渲染`DropdownButtonFormField`。标签选择器同样采用此方案，以`_banks.isEmpty`作为元数据加载中的判断条件。

```dart
_banks.isEmpty
    ? const CircularProgressIndicator()
    : DropdownButtonFormField<String>(
        value: _bankId,
        items: [/* 题库列表 */],
      )
```

### 题目列表卡片溢出（黄黑条纹）

**现象**：题目列表卡片底部出现黄黑斜纹条纹，控制台报`RenderFlex overflowed`。

**原因**：原实现使用`ListTile`+`ConstrainedBox`嵌套`QuestionRichText`，`ConstrainedBox`的固定高度约束与`QuestionRichText`内部的多行富文本内容冲突，导致溢出。

**修复方案**：去掉`ListTile`，改用自定义`InkWell`+`Padding`+`Row/Column`布局，让`QuestionRichText`自由布局不限制高度。

### Flutter Web图片预览XMLHttpRequest报错

**现象**：浏览器控制台出现`InvalidStateError: Failed to read the 'responseText' property from 'XMLHttpRequest'`。

**原因**：Flutter Web底层使用`XMLHttpRequest`加载图片时偶尔出现`responseType`类型混淆。这是Flutter Web框架层面的已知问题，与业务代码无关。

**处理方法**：只要图片能正常显示，此错误可忽略。如果图片加载失败，可尝试使用Edge浏览器替代Chrome，或使用`flutter run -d edge`启动前端。

---

## 12. 每日练习题库选择设计

### 入口流程

APP启动 → `DailyQuizPage` → 选择题库 → 答1题 → 进入主页

### 题库选择页面

展示所有根级别题库（`parent_id` 为空的题库），每个题库卡片显示：

- 题库名称
- 聚合题数：**自身题目 + 所有子题库 + 孙子题库……递归求和**

点击题库后，收集该题库及其所有后代题库的ID列表，通过 `category_ids` 参数传给随机题目接口，确保练习覆盖整个题库子树。

### 后端接口

- `GET /api/banks/descendant-counts`：返回 `{bank_id: total_count}`，每个题库的题数 = 自身 + 所有后代递归聚合
- `GET /api/qas/random/list?category_ids=a,b,c`：支持逗号分隔的多个题库ID

### 实现要点

```python
# descendant_counts 递归聚合逻辑
def descendant_counts(db):
    direct = question_counts(db)          # {bank_id: 直接题数}
    banks = get_all(db)                   # 全部题库
    children_map = parent→[child_ids]     # 构建父子映射
    # 递归: bank的total = 直接题数 + Σ(child的total)
    return {b.id: aggregate(b.id) for b in banks}
```

前端通过 `Future.wait` 并行获取 bank tree + descendant counts 后渲染。

MySQL的表字段类型有5类。

- 数值类：TINYINT、SMALLINT、INT、BIGINT、FLOAT、DOUBLE、DECIMAL(m,n)
- 字符串类：CHAR、VARCHAR、TINYTEXT、TEXT、MEDIUMTEXT、LONGTEXT、ENUM、SET
- 时间类：DATE、YEAR、TIME、DATETIME、TIMESTAMP
- 布尔类：BOOLEAN/BOOL
- 二进制类：TINYBLOB、BLOB、MEDIUMBLOB、LONGBLOB
