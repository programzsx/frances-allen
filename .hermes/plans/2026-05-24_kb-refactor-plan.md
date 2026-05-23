# Frances Allen 风格重构实施计划

> **For Hermes:** 逐任务执行，每个阶段完成后提交。

**目标：** 将frances-allen项目整体重构为alan-perlis风格——红色主题、AppBar芯片行导航、DataCache缓存、OSS默认`kb/`路径。

**参考项目：** `/home/codezsx/alan-perlis` — 人物管理系统，红色系主题，AppBar图标+芯片行筛选模式。

---

## Alan Perlis 核心模式分析

### 配色方案

| 用途 | Alan Perlis | Frances Allen当前 |
|------|------------|-------------------|
| 主色 | `#E53935`（Red600） | `#6366F1`（Indigo500） |
| 背景 | `#F5F5F5` | `#F8FAFC`（slate-50） |
| 卡片 | 白色，无边框，elevation=0 | 白色，1px边框 |
| 输入框 | 填充灰色`#F5F5F5`，无边框 | 白色填充，1px边框 |
| Chip | 白色底，选中Red实心 | indigo风格 |
| AppBar | 白底，无elevation，居中标题 | 自有样式 |

### 导航组织

```
PersonListScreen
├── AppBar
│   ├── title: "人物"
│   └── actions: [标签图标按钮, 分类图标按钮]
└── body: Column
    ├── 搜索框
    ├── 分类chip行（水平滚动，始终显示）
    ├── 标签chip行（仅当选了分类时显示，较小号）
    ├── Divider
    └── 人物卡片列表（无限滚动）
```

- 图标按钮 → 跳转全屏管理页（TagScreen / CategoryScreen），返回后`invalidate`缓存
- Chip toggle：点击选中，再点取消（不是"全部"按钮）
- 标签行只在选了分类后出现（条件渲染）

### 缓存模式

`DataCache`单例（ChangeNotifier）：
- `ensureCategories()` — 懒加载分类树
- `ensureTags()` — 懒加载标签列表
- `invalidate()` — 管理页返回后调用，清缓存强制刷新

### OSS默认路径

后端`upload_image`：prefix参数默认值=`"images"`
应改为：prefix默认值=`"kb"`（类似alan-perlis用`"oa"`作为默认应用级路径）

---

## 阶段A：主题重构（mobile）

### A1：重写 app_theme.dart

**文件：** `mobile/lib/theme/app_theme.dart`

改为Alan Perlis红色系：

```dart
class AppTheme {
  static const primary   = Color(0xFFE53935); // Red 600
  static const primaryBg = Color(0xFFFFEBEE); // Red 50
  static const surface   = Color(0xFFFFFFFF);
  static const bg        = Color(0xFFF5F5F5);
  static const textMain  = Color(0xFF212121);
  static const textSoft  = Color(0xFF757575);
  static const textHint  = Color(0xFFBDBDBD);
  static const accent    = Color(0xFFFFA000);
  static const danger    = Color(0xFFD32F2F);
  static const success   = Color(0xFF43A047);
  static const divider   = Color(0xFFEEEEEE);
  static const bgSection = Color(0xFFF1F5F9);
  
  // 兼容旧代码的别名
  static const indigo50  = Color(0xFFFFEBEE); // → red50
  static const indigo100 = Color(0xFFFFCDD2); // → red100
  static const indigo700 = Color(0xFFD32F2F); // → red700
  
  static const bgPrimary    = bg;
  static const bgCard       = surface;
  static const textPrimary  = textMain;
  static const textSecondary = textSoft;
  static const textTertiary  = textHint;
  static const border       = divider;
  static const green        = success;
  static const red          = danger;
  static const orange       = accent;
  
  // 保留 lightTheme getter，内容改为红色系
}
```

关键ThemeData改动（完全匹配alan-perlis）：
- `scaffoldBackgroundColor: bg` — `#F5F5F5`
- `appBarTheme` — 白底，无elevation，居中标题
- `cardTheme` — 白底，elevation=0，无边框，radius=12
- `inputDecorationTheme` — 填充`#F5F5F5`，无边框，focused时红色border
- `chipTheme` — 白底，选中时红色实心，无边框
- `elevatedButtonTheme` — 红色按钮，白字
- `floatingActionButtonTheme` — 红色圆形FAB

### A2：清理文件中的直接颜色引用

搜索`mobile/lib/`下所有`.dart`文件中直接使用`AppTheme.indigo50`、`AppTheme.indigo100`的地方。这些颜色已通过别名重定向，无需改动。但需确认所有语义颜色（primary/textMain等）用法正确。

---

## 阶段B：导航重构（mobile）

### B1：重构 QaPage — Alan Perlis芯片行模式

**文件：** `mobile/lib/pages/qa_page.dart`

当前QaPage无AppBar，嵌在ExamHomePage中。重构为独立Scaffold：

```
QaPage (Scaffold)
├── AppBar
│   ├── title: "题目"
│   └── actions: [标签图标, 题库图标]  ← 跳转管理页，返回后刷新
└── body: Column
    ├── 搜索框 (padding: 12,10,12,0)
    ├── 题库chip行 (高44，水平滚动)
    ├── 标签chip行 (高38，仅当选了题库时显示，小号)
    ├── Divider
    └── 题目卡片列表 (无限滚动)
```

关键改动：
- 题库chip行：从DataCache获取全量题库，展平树，渲染为水平ChoiceChip
- 标签chip行：条件渲染（selBank != null），只显示该题库下的标签
- Toggle行为：`_toggleBank(id)` — `_bid = _bid == id ? null : id; _tid = null;`
- AppBar actions跳转到BankPage/TagPage独立全屏页，返回后`DataCache().invalidate()`

### B2：重构 ExamHomePage → 精简

**文件：** `mobile/lib/pages/home_page.dart`

保留底部导航栏不变。将考试页改为只含一个QaPage（带AppBar），不再有顶部tab切换器。

新结构：
```
HomePage (Scaffold + bottom nav)
├── 考试 tab → QaPage (带自己的AppBar+芯片行)
└── 图片 tab → ImageManagePage
```

QaPage的AppBar actions添加"练习"入口按钮（可选，或放在FAB）。

练习页通过QaPage的AppBar action按钮进入，`Navigator.push` → PracticePage。

### B3：重构 PracticePage

**文件：** `mobile/lib/pages/practice_page.dart`

- 改为通过Navigator.push访问（不再嵌在tab内）
- 接收当前选中的bankId作为初始参数（可选）
- 保留三种模式切换

### B4：BankPage/TagPage 改为独立全屏页

当前BankPage和TagPage是嵌在ExamHomePage的tab内的子widget。改为独立全屏Scaffold：

- BankPage：独立AppBar（"题库管理"标题，返回箭头），返回时触发DataCache invalidate
- TagPage：独立AppBar（"标签管理"标题，返回箭头），返回时触发DataCache invalidate

QaPage中AppBar的题库/标签图标按钮：
```dart
IconButton(
  icon: Icon(Icons.folder_outlined),
  onPressed: () => Navigator.push(context, MaterialPageRoute(
    builder: (_) => BankPage()
  )).then((_) { DataCache().invalidate(); _refresh(); }),
)
```

---

## 阶段C：DataCache缓存模式

### C1：创建 DataCache 单例

**新建文件：** `mobile/lib/services/data_cache.dart`

完全参照alan-perlis的DataCache：
- 单例模式
- `ensureBanks()` — 懒加载题库树
- `ensureTags()` — 懒加载标签列表
- `allBanks` / `bankTree` — getter
- `allTags` — getter
- `invalidate()` — 清空缓存

### C2：ApiService 集成DataCache

修改`ApiService`的`getBanks()`和`getTags()`方法，使用DataCache做一级缓存。移除ApiService中散落的`_cachedBanks`/`_cachedTags`静态变量。

---

## 阶段D：OSS默认路径 images→kb

### D1：后端 upload接口

**文件：** `server/app/routers/oss.py:29`

```python
prefix: str = Query("kb", description="存储目录前缀"),
```

### D2：后端 upload_image函数

**文件：** `server/app/services/oss.py:73`

```python
def upload_image(file: UploadFile, prefix: str = "kb", filename: str = None) -> str:
```

### D3：前端 ApiService

**文件：** `mobile/lib/services/api_service.dart`

所有`prefix`参数默认值从`"images"`改为`"kb"`：
- `listImages({String prefix = "kb"})`
- `uploadImage(..., {String prefix = "kb", ...})`
- `uploadImageBytes(..., {String prefix = "kb", ...})`

### D4：ImageManagePage

**文件：** `mobile/lib/pages/image_manage_page.dart`

- 初始`_currentPrefix`从`""`改为`"kb/"`（默认展示kb目录）
- 上传时`currentPrefix`默认值改为`"kb"`

---

## 阶段E：图片上传命名规范优化

### E1：检查上传对话框

**文件：** `mobile/lib/pages/image_manage_page.dart`中的`_UploadDialog`

检查当前命名逻辑是否满足：
- 格式：`{自定义名}-{年}-{月}-{日}-{时}-{分}-{秒}-{8位随机数}.{扩展名}`
- 不足两位补零
- 自定义名可为空（默认用原始文件名）

### E2：路径解析优化

确保`_navigateToDir`、`_getDisplayName`、`_getParentPrefix`正确处理`kb/`前缀路径。

---

## 阶段F：桌面端同步重构

**目录：** `desktop/lib/`

所有mobile端的改动需同步到desktop端：
- `desktop/lib/theme/desktop_theme.dart` → 红色主题
- `desktop/lib/pages/home_page.dart` → 底部导航+QaPage芯片行
- `desktop/lib/pages/qa_page.dart` → AppBar芯片行模式
- `desktop/lib/services/api_service.dart` → DataCache集成+OSS prefix="kb"

桌面端的`api_service.dart`可用软链接或直接复制mobile版本（内容相同）。

---

## 阶段G：测试方案 kb-test-spec.md

### G1：测试文档结构

```
kb-test-spec.md
├── 1、测试范围与策略
├── 2、后端API测试
│   ├── 题库CRUD测试
│   ├── 标签CRUD测试
│   ├── 题目CRUD测试
│   ├── 练习模式API测试（随机/顺序/错题）
│   ├── 图片管理API测试（上传/列表/删除/签名URL）
│   └── OSS路径kb/验证
├── 3、前端交互测试
│   ├── 主题验证（红色系一致性）
│   ├── 底部导航切换
│   ├── QaPage芯片行筛选（题库toggle/标签条件显示）
│   ├── 题目CRUD流程
│   ├── 练习模式完整流程
│   ├── 图片管理（上传/预览/删除/命名规范/默认路径kb/）
│   └── BankPage/TagPage管理页返回刷新
├── 4、桌面端一致性测试
└── 5、已知边界条件
```

### G2：后端API测试用例

**文件：** `server/tests/test_api.py`

当前已有基础框架，需扩展：
- `test_create_bank` — 创建题库
- `test_create_tag` — 创建标签
- `test_create_qa` — 创建题目（含填空+答案数组）
- `test_page_qas` — 分页查询（含筛选条件）
- `test_random_qas` — 随机取题
- `test_sequential_qas` — 顺序取题
- `test_wrong_qas` — 错题筛选
- `test_upload_image_to_kb` — 上传到kb/路径
- `test_list_images_kb` — 列出kb/下文件
- `test_delete_image` — 删除图片

---

## 阶段H：测试用例编写

### H1：后端测试

使用`pytest` + `httpx` (TestClient)：
- 每个测试独立创建→验证→清理
- 数据库操作测试后回滚

### H2：前端测试

- `flutter analyze` — 静态分析（mobile + desktop）
- Widget测试 — 关键页面渲染验证
- Web构建验证 — `flutter build web`

---

## 阶段I：构建验证

```bash
# Mobile Web构建
cd mobile && flutter build web

# Desktop构建（仅在Windows Flutter环境）
cd desktop && flutter build windows

# Analyze
flutter analyze
```

---

## 文件变更清单

| 操作 | 文件 | 说明 |
|------|------|------|
| 重写 | `mobile/lib/theme/app_theme.dart` | Indigo→Red |
| 创建 | `mobile/lib/services/data_cache.dart` | DataCache单例 |
| 重写 | `mobile/lib/pages/qa_page.dart` | AppBar+芯片行 |
| 重写 | `mobile/lib/pages/home_page.dart` | 精简考试tab |
| 重写 | `mobile/lib/pages/practice_page.dart` | 独立页面 |
| 修改 | `mobile/lib/pages/bank_page.dart` | 独立Scaffold |
| 修改 | `mobile/lib/pages/tag_page.dart` | 独立Scaffold |
| 修改 | `mobile/lib/services/api_service.dart` | DataCache+prefix="kb" |
| 修改 | `mobile/lib/pages/image_manage_page.dart` | prefix="kb" |
| 修改 | `mobile/lib/pages/qa_form_page.dart` | 红色主题适配 |
| 修改 | `mobile/lib/pages/qa_detail_page.dart` | 红色主题适配 |
| 修改 | `mobile/lib/pages/question_rich_text.dart` | 红色主题适配 |
| 重写 | `desktop/lib/theme/desktop_theme.dart` | Indigo→Red |
| 同步 | `desktop/lib/pages/*.dart` | 所有页面同步重构 |
| 同步 | `desktop/lib/services/api_service.dart` | 同步mobile改动 |
| 创建 | `desktop/lib/services/data_cache.dart` | DataCache单例 |
| 修改 | `server/app/routers/oss.py` | prefix="kb" |
| 修改 | `server/app/services/oss.py` | prefix="kb" |
| 扩展 | `server/tests/test_api.py` | 完整测试用例 |
| 创建 | `kb-test-spec.md` | 测试方案文档 |
| 更新 | `kb-design-spec.md` | 补充重构后设计说明 |

---

## 风险与注意事项

- 桌面端`api_service.dart`与mobile完全一致，考虑共享（软链接或pub workspace）
- 芯片行数据源从DataCache获取，需确保首次渲染时缓存已就绪
- QaPage的AppBar actions图标按钮跳转到全屏管理页后，返回时必须触发刷新
- 旧代码中对`AppTheme.indigo*`的引用已通过别名兼容，无需逐个修改
- 桌面端构建依赖Windows Flutter SDK，WSL环境需通过cmd.exe调用
