# zsx-design-03：抖音式电影学习 — 数据库设计与字段详解

## 一、核心理念

### 1.1 项目定位：查看与编辑

视频数据的生产流程全部在项目外部完成：
1. **下载视频**：离线完成（B站/Youtube/种子等），与本项目无关
2. **切分视频**：本地用 FFmpeg 按 30s 等单位切割
3. **上传 OSS**：将切好的片段上传到阿里云 OSS（bucket: `zsx-movie`）
4. **写入数据库**：拿到几百个 OSS URL，写入数据库

**frances-allen 项目只负责两件事：查看已有数据、编辑已有数据。**
不设计"新增"功能。所有数据的增改在外部完成后再导入数据库。

### 1.2 数据层级

```
douyin_movie  →  电影（如"加勒比海盗"）
    └── douyin_video  →  视频/剧集（如"加勒比海盗1"）
        └── douyin_slice  →  切片（30s一段，有顺序）
```

`douyin_comment` 表不需要了。

### 1.3 OSS 路径约定

使用阿里云 OSS bucket `zsx-movie`，路径结构为：
```
zsx-movie/
  {电影name}/
    {视频name}/
      slice_001.mp4
      slice_002.mp4
      ...
```

- **movie 的 name**：代表 OSS 中的第一级目录
- **video 的 name**：代表 OSS 中的第二级目录
- **slice 的 oss_url**：完整视频 URL

---

## 二、douyin_movie（电影表）

按照四段表设计理论，每张表的字段分为：基础字段、业务字段、统计字段、关联字段。

### 2.1 字段设计

| 字段 | 类型 | 段类 | 说明 |
|------|------|------|------|
| id | VARCHAR(64) | 基础 | 雪花ID，主键。与 kb_qa 表保持一致 |
| create_time | VARCHAR(32) | 基础 | 创建时间，时间戳字符串，不区分时区 |
| update_time | VARCHAR(32) | 基础 | 更新时间，时间戳字符串 |
| name | VARCHAR(256) | 业务 | 电影名称，NOT NULL。同时是 OSS 路径的一部分（zsx-movie 下的第一级目录） |
| description | TEXT | 业务 | 电影简介/描述 |
| cover_url | VARCHAR(512) | 业务 | 电影封面图片的 URL |
| sort_order | INT | 业务 | 排序序号，值越小越靠前，默认 0 |
| video_count | INT | 统计 | 该电影包含的视频/剧集数量 |

### 2.2 与 zsx-design-02 的差异

- **title → name**：统一用 name 命名（与 kb_bank 表风格一致）
- **删除 oss_key**：不需要，路径由 name 字段隐式确定
- **删除 total_duration**：不需要
- **删除 status**：不需要（只有查看和编辑，不需要上下架状态）

---

## 三、douyin_video（视频/剧集表）

### 3.1 字段设计

| 字段 | 类型 | 段类 | 说明 |
|------|------|------|------|
| id | VARCHAR(64) | 基础 | 雪花ID，主键。与 kb_qa 表保持一致 |
| create_time | VARCHAR(32) | 基础 | 创建时间，时间戳字符串 |
| update_time | VARCHAR(32) | 基础 | 更新时间，时间戳字符串 |
| movie_id | VARCHAR(64) | 关联 | 所属电影ID，NOT NULL。外键关联 douyin_movie.id |
| name | VARCHAR(256) | 业务 | 视频/剧集名称，NOT NULL。同时是 OSS 路径的一部分（movie name 下的第二级目录） |
| description | TEXT | 业务 | 视频/剧集简介 |
| cover_url | VARCHAR(512) | 业务 | 视频/剧集封面图片的 URL |
| slice_count | INT | 统计 | 该视频包含的切片数量 |
| sort_order | INT | 业务 | 排序序号，用于列表展示时按序排列 |

### 3.2 与 zsx-design-02 的差异

- **title → name**：统一用 name 命名
- **删除 oss_key**：不需要
- **删除 duration**：不需要
- **删除 status**：不需要
- **保留 sort_order**：用于列表排序
- **保留 slice_count**：统计字段，表示有多少个切片

---

## 四、douyin_slice（切片表）

这是重头戏，是核心数据表。

### 4.1 字段设计

| 字段 | 类型 | 段类 | 说明 |
|------|------|------|------|
| id | VARCHAR(64) | 基础 | 雪花ID，主键。与 kb_qa 表保持一致 |
| create_time | VARCHAR(32) | 基础 | 创建时间，时间戳字符串 |
| update_time | VARCHAR(32) | 基础 | 更新时间，时间戳字符串 |
| video_id | VARCHAR(64) | 关联 | 所属视频ID，NOT NULL。外键关联 douyin_video.id |
| movie_id | VARCHAR(64) | 关联 | 所属电影ID，NOT NULL。冗余字段，便于跨表查询 |
| name | VARCHAR(256) | 业务 | 切片名称/标题 |
| comment | TEXT | 业务 | 备注/评论/学习笔记 |
| oss_url | VARCHAR(512) | 业务 | 视频文件的完整 OSS URL，NOT NULL |
| sort_order | INT | 业务 | 排序序号，用于顺序播放时按序排列 |
| is_fav | INT | 业务 | 是否收藏：0=否，1=是 |
| random_int | INT | 业务 | 随机排序用，递增整数 |
| watch_count | INT | 统计 | 该切片的播放次数计数 |

### 4.2 与 zsx-design-02 的差异

- **title → name**：统一用 name 命名
- **删除 oss_key**：不需要，已有 oss_url 完整 URL
- **删除 duration**：不需要
- **新增 watch_count**：统计字段，记录播放次数
- **删除 douyin_comment 表**：评论内容直接存在 slice 的 comment 字段中

---

## 五、与 kb_qa 表的一致性

所有表的基础字段与 kb_qa 表保持一致：

| 字段 | kb_qa | douyin_movie | douyin_video | douyin_slice |
|------|-------|-------------|-------------|-------------|
| id | VARCHAR(64) | VARCHAR(64) | VARCHAR(64) | VARCHAR(64) |
| create_time | VARCHAR(32) | VARCHAR(32) | VARCHAR(32) | VARCHAR(32) |
| update_time | VARCHAR(32) | VARCHAR(32) | VARCHAR(32) | VARCHAR(32) |

---

## 六、四段表设计理论回顾

| 段类 | 含义 | douyin_movie 示例 | douyin_video 示例 | douyin_slice 示例 |
|------|------|------------------|------------------|------------------|
| **基础字段** | 每张表必备 | id, create_time, update_time | id, create_time, update_time | id, create_time, update_time |
| **业务字段** | 核心存储内容 | name, description, cover_url, sort_order | name, description, cover_url, sort_order | name, comment, oss_url, sort_order, is_fav, random_int |
| **统计字段** | 计时/计量数据 | video_count | slice_count | watch_count |
| **关联字段** | 与其他表的关联 | 无 | movie_id | video_id, movie_id |

---

## 七、数据库变更：douyin_movie 新增 sort_order

在 `douyin_movie` 表新增 `sort_order INT` 字段，用于控制电影列表的排序优先级。

| 字段 | 类型 | 段类 | 说明 |
|------|------|------|------|
| sort_order | INT | 业务 | 排序序号，值越小越靠前，默认 0 |

**同步更新要求**：
- ORM 模型（`backend/app/models/douyin_movie.py`）
- Pydantic Schema（`backend/app/schemas/douyin_movie.py`）
- DAO 层排序逻辑（`backend/app/dao/douyin_movie.py`）
- 前端模型（`frontend/lib/models/models.dart`）

---

## 八、前端交互逻辑设计

### 8.1 底部 TabBar 导航

#### 8.1.1 Tab 排序与配置

底部导航栏采用 Material 3 `NavigationBar` 组件，从左到右三个 Tab：

| 序号 | 标签 | 图标（未选中/选中） | 对应页面 |
|------|------|---------------------|----------|
| 0 | 考试 | quiz_outlined / quiz | ExamHomePage |
| 1 | 图片 | image_outlined / image | ImageManagePage |
| 2 | 抖音 | smart_display_outlined / smart_display | VideoFeedPage |

- `_currentIndex` 默认值为 0（考试为首页）
- 点击"抖音" Tab → 直接进入 `VideoFeedPage`（全屏随机播放模式）

#### 8.1.2 导航链路

```
TabBar ──[点击"抖音"]──→ VideoFeedPage（随机全屏播放）
VideoFeedPage ──[点击🏠回到主页]──→ MovieListPage
MovieListPage ──[点击电影卡片]──→ MovieDetailPage(movieId)
MovieDetailPage ──[点击视频行]──→ SliceListPage(videoId)
SliceListPage ──[点击切片行]──→ VideoFeedPage（限定该视频的切片）
VideoFeedPage ──[点击💬评论]──→ CommentSheet（BottomSheet）
```

### 8.2 VideoFeedPage — 全屏视频流页面

#### 8.2.1 进入方式

- 方式 1：点击底部"抖音" Tab → 全局随机切片播放
- 方式 2：从 SliceListPage 点击切片行 → 进入该视频的切片播放

#### 8.2.2 叠加层布局

```
Stack
  ├── VideoPlayer（全屏，底层）
  ├── 顶部操作栏
  │   ├── 播放模式选择器（右上角）：随机🔀 / 顺序📋 / 收藏⭐
  │   └── 回到主页🏠（左上角）：点击跳转 MovieListPage
  ├── 暂停指示器（居中，半透明播放图标，暂停时显示）
  ├── 底部信息区（左下角）
  │   ├── 切片名称（白色加粗，最多2行）
  │   └── 评论/笔记文本（白色半透明，最多3行）
  └── 右侧操作栏
      ├── 收藏 ❤️/♡（点击切换 is_fav）
      └── 评论 💬（打开 CommentSheet）
```

#### 8.2.3 手势操作

| 手势 | 行为 |
|------|------|
| 单击（onTap） | 暂停 / 继续播放 |
| 双击（onDoubleTap） | 暂停 / 继续播放 |
| 长按（onLongPress） | 快进 10 秒 |
| 长按结束（onLongPressEnd） | 恢复播放 |
| 上滑 | 切换到下一个切片 |
| 下滑 | 切换到上一个切片 |

#### 8.2.4 播放模式

| 模式 | API | 排序方式 |
|------|-----|----------|
| 随机 | `GET /api/slices/random/list?limit=50` | ORDER BY RAND() |
| 顺序 | `GET /api/slices/sequential/list?limit=50` | ORDER BY sort_order ASC |
| 收藏 | `GET /api/slices/fav/list?limit=50` | WHERE is_fav = 1 |

#### 8.2.5 内存管理

仅保留 3 个 `VideoPlayerController`（当前页、前一页、后一页），超出范围自动 dispose。

### 8.3 MovieListPage — 电影列表页

#### 8.3.1 数据来源

调用 `GET /api/movies` 查询 `douyin_movie` 表，按 `sort_order ASC` 排序。

#### 8.3.2 页面布局

- `GridView.builder`，2 列网格布局
- 每个卡片：
  - 封面图（cover_url，无封面时显示默认电影图标）
  - 电影名称（name）
  - 视频数量（video_count）
- 点击卡片 → 跳转 `MovieDetailPage(movieId)`

#### 8.3.3 进入方式

- 从 VideoFeedPage 点击"回到主页"图标 → 进入此页面

### 8.4 MovieDetailPage — 电影详情页

#### 8.4.1 数据展示

展示 `douyin_movie` 全部字段：

| 字段 | 展示方式 |
|------|----------|
| cover_url | 顶部大图（240px 高度） |
| name | 大标题文字 |
| description | 描述文本区域（可编辑） |
| video_count | 统计信息标签 |
| sort_order | 排序信息（仅展示） |

#### 8.4.2 description 编辑功能

- description 区域右侧放置编辑图标（edit 图标按钮）
- 点击编辑图标 → 弹出 `showDialog` 对话框
- 对话框内：
  - 多行文本输入框（TextField + maxLines），预填当前 description
  - 保存按钮 → 调用 `PUT /api/movies/{id}` 仅更新 description 字段
  - 取消按钮 → 关闭对话框，不修改数据
- 保存成功后刷新页面状态

#### 8.4.3 视频列表区

位于电影信息下方：

- `ListView.builder` 有序列表
- 每行：
  - 序号徽章（蓝色圆角方块，显示 sort_order 或序号）
  - 视频名称（name）
  - 切片数量（slice_count，灰色小字）
  - 右箭头（chevron_right 图标）
- 数据源：`GET /api/videos/by-movie/{movieId}`，按 `sort_order ASC` 排序
- 点击行 → 跳转 `SliceListPage(videoId)`

### 8.5 SliceListPage — 切片列表页

#### 8.5.1 数据来源

调用 `GET /api/slices/by-video/{videoId}` 查询 `douyin_slice` 表，按 `sort_order ASC` 排序。

#### 8.5.2 三种展示模式

顶部设三栏切换器（SegmentedButton 或 TabBar），支持三种视图：

**模式一：列表视图**

- `ListView.builder`
- 每行：序号 + 切片名称 + 播放次数（👁 watch_count） + 收藏星（⭐/☆） + 右箭头
- 切片 name 为空时，显示 `#` + sort_order 编号（如 `#01`、`#02`）

**模式二：网格/图标视图**

- `GridView.builder`，3 列网格
- 每个卡片：视频缩略帧（或默认图标） + 切片名称 + 播放次数
- 适合快速浏览和选择

**模式三：瀑布流视图**

- 使用 `flutter_staggered_grid_view` 或自定义布局
- 卡片高度根据内容自适应（如根据备注文本长度）
- 适合内容丰富的切片展示

#### 8.5.3 切片命名规则

- 有 name 字段：直接显示 name
- 无 name 字段（为空或 null）：自动生成 `#` + 两位数编号（如 `#01`、`#15`）
- 编号基于 sort_order 值生成

#### 8.5.4 播放次数展示

每个切片项均展示 `watch_count`：

- 图标：👁（visibility 图标）
- 文字：数字，如 `128`
- 无播放记录时显示 `0`

#### 8.5.5 交互

- 点击切片行 → 进入 `VideoFeedPage`（限定为该视频的切片列表）
- 收藏按钮 → 切换 `is_fav` 状态，调用 `PUT /api/slices/{id}`

### 8.6 CommentSheet — 评论/笔记底部面板

- `showModalBottomSheet` + `isScrollControlled: true`，占屏幕 70%
- 顶部：评论数量标题 + 关闭按钮
- 中间：已有评论列表（标题加粗 + 内容 + 时间）
- 底部：表单
  - 标题输入框（TextField，单行）
  - 内容输入框（TextField，最多 3 行）
  - 保存按钮 → `POST /api/comments`，成功后更新切片标题

---

## 九、frances-allen-douyin 桌面端管理工具设计

### 9.1 项目定位

| 维度 | 说明 |
|------|------|
| **项目路径** | `C:\Users\codezsx\frances-allen-douyin` |
| **技术栈** | Flutter Desktop for Windows |
| **代码风格** | 与 frances-allen 一致（Material 3、flutter_screenutil、StatefulWidget + setState） |
| **用途** | 生产端管理工具：本地视频切割 → OSS 上传 → 数据库写入 |
| **运行平台** | Windows 桌面，不涉及移动端 |

### 9.2 与 frances-allen 的关系

| 维度 | frances-allen | frances-allen-douyin |
|------|---------------|---------------------|
| 定位 | 消费端（查看 + 播放 + 笔记） | 生产端（切割 + 上传 + 入库） |
| 平台 | Flutter Android/跨端 | Flutter Windows Desktop |
| 数据库 | 通过后端 API 读写 | 通过同一后端 API 写入 |
| OSS | 通过后端 API 访问 | 客户端直传（oss_dart_sdk） |
| FFmpeg | 不使用 | 本地调用 |
| 共享 | 代码风格、M3 主题 | 复用相同设计系统 |

### 9.3 核心流程

```
选择本地视频文件
  → 录入电影信息（name, description, cover）
  → 创建电影记录（POST /api/movies）
  → 录入视频信息（name, sort_order）
  → 创建视频记录（POST /api/videos）
  → 配置切割参数（切片时长，默认 30s）
  → 调用 FFmpeg 切割视频
  → 批量上传切片到 OSS（zsx-movie/{movie_name}/{video_name}/）
  → 批量创建切片记录（POST /api/slices）
  → 完成
```

### 9.4 页面结构

```
MainWindow（Scaffold + NavigationRail）
  ├── Sidebar（左侧导航栏）
  │   ├── 电影管理（Icons.movie_outlined）
  │   ├── 视频处理（Icons.cut）
  │   └── 设置（Icons.settings_outlined）
  └── Content Area
      ├── MovieManagePage：电影列表、新增/编辑电影
      ├── VideoProcessPage：向导式流程（切割 → 上传 → 入库）
      └── SettingsPage：OSS 配置、后端地址、FFmpeg 路径
```

### 9.5 功能模块详述

#### 9.5.1 SettingsPage — 设置页

持久化配置项（使用 `shared_preferences`）：

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| 后端地址 | `http://127.0.0.1:8000` | frances-allen FastAPI 后端地址 |
| OSS Endpoint | `oss-cn-beijing.aliyuncs.com` | 阿里云 OSS 端点 |
| OSS AccessKey ID | 用户填写 | AccessKey ID |
| OSS AccessKey Secret | 用户填写 | AccessKey Secret |
| OSS Bucket | `zsx-movie` | 存储桶名称 |
| FFmpeg 路径 | 自动检测 PATH | FFmpeg 可执行文件路径 |

#### 9.5.2 MovieManagePage — 电影管理页

**电影列表**：
- 调用 `GET /api/movies` 获取已有电影列表
- 表格展示：name、cover_url（缩略图）、video_count、sort_order
- 操作：编辑、删除

**新增电影**：
- 表单字段：
  - 电影名称（name）→ 必填 → 同时作为 OSS 一级目录名
  - 电影简介（description）→ 选填 → 多行文本
  - 封面上传 → 选择本地图片 → 直传 OSS → 获取 URL
  - 排序值（sort_order）→ 数字输入，默认 0
- 提交 → `POST /api/movies` → 创建成功

#### 9.5.3 VideoProcessPage — 视频处理页（向导式）

**Step 1：选择视频文件**

- 按钮：`file_picker` 选择本地视频（支持 .mp4, .mkv, .avi）
- 显示文件名和文件大小

**Step 2：录入视频信息**

- 所属电影：下拉选择（从已有电影列表选择）
- 视频名称（name）→ 必填 → 作为 OSS 二级目录名
- 排序值（sort_order）→ 数字输入

**Step 3：切割配置**

- 切片时长：Slider 或输入框，默认 30 秒
- 输出目录：默认系统临时目录，可自定义
- 文件名格式：`video-%03d.mp4`（三位数补零，如 video-001.mp4）

**Step 4：执行切割**

- 调用本地 FFmpeg：
  ```
  ffmpeg -i {input_file} -c copy -f segment \
    -segment_time {duration} -reset_timestamps 1 \
    {output_dir}/video-%03d.mp4
  ```
- 实时解析 FFmpeg 输出，显示进度百分比
- 切割完成后展示切片文件列表

**Step 5：上传到 OSS**

- 上传路径：`{movie_name}/{video_name}/video-001.mp4`
- 批量上传，显示整体进度（当前 N/M）
- 上传完成后收集每个文件的 OSS URL

**Step 6：写入数据库**

- 创建视频记录：`POST /api/videos` → 获取 video_id
- 批量创建切片记录：逐个调用 `POST /api/slices`
  - video_id、movie_id（冗余）
  - oss_url：OSS 返回的完整 URL
  - sort_order：按文件顺序递增（1, 2, 3...）
  - name：默认使用 `#` + sort_order
- 更新电影 video_count 和视频 slice_count 统计

### 9.6 OSS 上传实现

**方式一：客户端直传（推荐）**

- 使用 `aliyun-oss-dart-sdk` 包
- 直接在客户端签名并上传，不经过后端中转
- 优势：上传速度快，不占用后端带宽
- 路径拼接规则：`{movie.name}/{video.name}/{filename}`

**方式二：通过后端上传（备选）**

- 调用 `POST /api/images/videos/upload`
- 通过后端中转上传到 OSS
- 适合没有 OSS SDK 或安全要求的场景

### 9.7 项目文件结构

```
frances-allen-douyin/
  lib/
    main.dart                  # 入口，初始化 ScreenUtil
    models/
      models.dart              # DouyinMovie, DouyinVideo, DouyinSlice 等
    services/
      api_service.dart         # 后端 API 调用
      oss_service.dart         # OSS 直传服务
      ffmpeg_service.dart      # FFmpeg 调用服务
    pages/
      main_window.dart         # 主窗口 + NavigationRail
      movie_manage_page.dart   # 电影管理
      video_process_page.dart  # 视频处理向导
      settings_page.dart       # 设置页
    theme/
      app_theme.dart           # 主题（与 frances-allen 一致）
  pubspec.yaml                 # 依赖配置
```

### 9.8 技术选型

| 层级 | 技术 | 说明 |
|------|------|------|
| 框架 | Flutter Desktop (Windows) | SDK ^3.10.4 |
| UI 组件 | Material 3 | 与 frances-allen 一致 |
| 屏幕适配 | flutter_screenutil | 统一适配 |
| 文件选择 | file_picker | 本地文件选择 |
| OSS SDK | aliyun-oss-dart-sdk | 阿里云 OSS Dart SDK |
| HTTP | http | HTTP 请求 |
| 本地存储 | shared_preferences | 配置持久化 |
| FFmpeg | Process.run | 调用本地 FFmpeg 命令 |

### 9.9 注意事项

1. **FFmpeg 依赖**：用户需预先安装 FFmpeg，或在设置中手动指定路径。应用启动时检测 FFmpeg 可用性。
2. **大文件上传**：视频切片文件可能较大，上传时需要考虑超时和重试机制。
3. **并发控制**：批量上传时限制并发数（建议 3-5），避免网络拥塞。
4. **错误处理**：每一步都需要完善的错误处理和用户提示。
5. **日志记录**：操作日志输出到 UI 和文件，方便排查问题。

---

## 九、标签页交互优化（V2）

### 9.1 标签页去边框气泡设计

**问题**：气泡式标签在数量多时难以筛选和浏览。

**解决方案**：改用列表式布局，每行显示：首字母圆形头像 + 标签名 + 题目数量 + 右侧箭头。

**交互**：
- **点击行** → 进入该标签关联的题目列表页面（`QaPage`）
- **长按行** → 编辑标签
- **搜索框** → 实时过滤（`onChanged`），无需按回车

**样式**：
- 每行背景透明，底部分隔线（`AppTheme.border`，50% 透明度）
- 选中行有浅紫色背景（`AppTheme.primary`，8% 透明度）
- 右侧箭头图标表示可点击跳转

### 9.2 标签点击 → 题目列表页

点击任意标签后，`QaPage` 接收 `tagId` 和 `tagName` 参数：

| 参数 | 说明 |
|------|------|
| `initialTagId` | 标签 ID，用于过滤题目 |
| `initialTagName` | 标签名称，用于页面标题显示 |

页面顶部 Header 显示标签名称 + 题目总数，有返回按钮。

### 9.3 后端 tag_id 过滤

`GET /api/qas` 新增 `tag_id` 参数，按标签 ID 过滤题目（模糊匹配 `tag_id` JSON 字段）。

---

## 十、字段命名规范（title → name）

### 10.1 数据库字段对照

| 表名 | 旧字段（已废弃） | 新字段 | 说明 |
|------|-----------------|--------|------|
| `douyin_video` | `title` | `name` | 视频名称 |
| `douyin_slice` | `title` | `name` | 切片名称 |

**注意**：数据库中已使用 `name` 字段，代码中的 `title` 引用需全部替换为 `name`。

### 10.2 涉及的代码文件

- `backend/app/models/douyin_video.py` — ORM 模型
- `backend/app/models/douyin_slice.py` — ORM 模型
- `backend/app/schemas/douyin_video.py` — Pydantic Schema
- `backend/app/schemas/douyin_slice.py` — Pydantic Schema
- `backend/app/services/douyin_video.py` — Service 层
- `backend/app/services/douyin_slice.py` — Service 层
- `backend/app/dao/douyin_video.py` — DAO 层
- `backend/app/dao/douyin_slice.py` — DAO 层
- `frontend/lib/models/models.dart` — Dart 模型

---

## 十一、Docker 部署设计

### 11.1 部署架构

```
┌─────────────────────────────────────────────────────┐
│                    阿里云 ECS                         │
│                  Ubuntu 22.04                        │
│                 公网 IP: 8.160.174.178               │
│                                                      │
│  ┌─────────────────────────────────────────────┐    │
│  │              Docker Container                │    │
│  │                                              │    │
│  │   ┌─────────────────────────────────────┐   │    │
│  │   │        FastAPI Backend               │   │    │
│  │   │        (frances-allen backend)       │   │    │
│  │   │        端口: 8000                    │   │    │
│  │   └─────────────────────────────────────┘   │    │
│  │                      │                       │    │
│  │                      │                       │    │
│  │   ┌─────────────────────────────────────┐   │    │
│  │   │           MySQL 8.0                  │   │    │
│  │   │        端口: 3306                    │   │    │
│  │   └─────────────────────────────────────┘   │    │
│  │                                              │    │
│  └─────────────────────────────────────────────┘    │
│                         │                           │
│              ┌──────────┴──────────┐                │
│              │   Docker Network   │                │
│              │  backend-network   │                │
│              └────────────────────┘                │
└─────────────────────────────────────────────────────┘
                         │
                         │ Docker Port Mapping
                         │ 8000:8000, 3306:3306
                         ▼
              ┌─────────────────────┐
              │   公网访问          │
              │  8.160.174.178:8000 │
              └─────────────────────┘
```

### 10.2 服务器环境要求

| 项目 | 要求 |
|------|------|
| 操作系统 | Ubuntu 22.04 64 位 |
| 公网 IP | 8.160.174.178 |
| Docker | 已安装（docker --version 验证） |
| Docker Compose | 推荐安装（docker-compose --version 验证） |
| 开放端口 | 8000（后端 API）、3306（MySQL，仅内网） |

### 10.3 Docker 配置

#### 10.3.1 目录结构

在 ECS 服务器上创建部署目录：

```
/opt/frances-allen/
├── docker-compose.yml          # Docker Compose 配置
├── Dockerfile                  # 后端镜像构建
├── config/
│   └── config.yaml             # 应用配置文件
├── mysql/
│   └── init.sql                # 数据库初始化脚本
└── logs/                       # 日志目录
```

#### 10.3.2 Dockerfile

```dockerfile
FROM python:3.10-slim

WORKDIR /app

# 安装系统依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# 复制依赖文件
COPY backend/requirements.txt .

# 安装 Python 依赖
RUN pip install --no-cache-dir -r requirements.txt -i https://mirrors.aliyun.com/pypi/simple/

# 复制后端代码
COPY backend/ .

# 创建日志目录
RUN mkdir -p /app/logs

# 暴露端口
EXPOSE 8000

# 启动命令
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

#### 10.3.3 docker-compose.yml

```yaml
version: '3.8'

services:
  backend:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: frances-allen-backend
    ports:
      - "8000:8000"
    volumes:
      - ./logs:/app/logs
      - ./config:/app/config
    environment:
      - DB_HOST=mysql
      - DB_PORT=3306
      - DB_USER=frances
      - DB_PASSWORD=${DB_PASSWORD}
      - DB_NAME=francesAllen
    depends_on:
      mysql:
        condition: service_healthy
    networks:
      - backend-network
    restart: unless-stopped

  mysql:
    image: mysql:8.0
    container_name: frances-allen-mysql
    ports:
      - "3306:3306"
    volumes:
      - mysql-data:/var/lib/mysql
      - ./mysql/init.sql:/docker-entrypoint-initdb.d/init.sql
    environment:
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
      - MYSQL_DATABASE=francesAllen
      - MYSQL_USER=frances
      - MYSQL_PASSWORD=${DB_PASSWORD}
    networks:
      - backend-network
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

volumes:
  mysql-data:

networks:
  backend-network:
    driver: bridge
```

#### 10.3.4 数据库初始化脚本 (mysql/init.sql)

```sql
-- 创建数据库（如果不存在）
CREATE DATABASE IF NOT EXISTS francesAllen DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE francesAllen;

-- douyin_movie 表
CREATE TABLE IF NOT EXISTS douyin_movie (
    id VARCHAR(64) PRIMARY KEY,
    create_time VARCHAR(32) NOT NULL,
    update_time VARCHAR(32) NOT NULL,
    name VARCHAR(256) NOT NULL,
    description TEXT,
    cover_url VARCHAR(512),
    sort_order INT DEFAULT 0,
    video_count INT DEFAULT 0,
    INDEX idx_sort_order (sort_order),
    INDEX idx_create_time (create_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- douyin_video 表
CREATE TABLE IF NOT EXISTS douyin_video (
    id VARCHAR(64) PRIMARY KEY,
    create_time VARCHAR(32) NOT NULL,
    update_time VARCHAR(32) NOT NULL,
    movie_id VARCHAR(64) NOT NULL,
    name VARCHAR(256) NOT NULL,
    description TEXT,
    cover_url VARCHAR(512),
    slice_count INT DEFAULT 0,
    sort_order INT DEFAULT 0,
    INDEX idx_movie_id (movie_id),
    INDEX idx_sort_order (sort_order),
    FOREIGN KEY (movie_id) REFERENCES douyin_movie(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- douyin_slice 表
CREATE TABLE IF NOT EXISTS douyin_slice (
    id VARCHAR(64) PRIMARY KEY,
    create_time VARCHAR(32) NOT NULL,
    update_time VARCHAR(32) NOT NULL,
    video_id VARCHAR(64) NOT NULL,
    movie_id VARCHAR(64) NOT NULL,
    name VARCHAR(256),
    comment TEXT,
    oss_url VARCHAR(512) NOT NULL,
    sort_order INT DEFAULT 0,
    is_fav INT DEFAULT 0,
    random_int INT DEFAULT 0,
    watch_count INT DEFAULT 0,
    INDEX idx_video_id (video_id),
    INDEX idx_movie_id (movie_id),
    INDEX idx_is_fav (is_fav),
    INDEX idx_random_int (random_int),
    FOREIGN KEY (video_id) REFERENCES douyin_video(id) ON DELETE CASCADE,
    FOREIGN KEY (movie_id) REFERENCES douyin_movie(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 10.4 部署步骤

#### 10.4.1 服务器端操作

**Step 1：连接服务器**
```bash
ssh root@8.160.174.178
```

**Step 2：创建部署目录**
```bash
mkdir -p /opt/frances-allen
cd /opt/frances-allen
```

**Step 3：上传项目文件**

方式一：使用 scp 从本地传输
```bash
# 在本地执行
scp -r backend/ root@8.160.174.178:/opt/frances-allen/
scp -r frontend/ root@8.160.174.178:/opt/frances-allen/
scp Dockerfile docker-compose.yml root@8.160.174.178:/opt/frances-allen/
```

方式二：使用 git 克隆
```bash
cd /opt/frances-allen
git clone https://github.com/your-repo/frances-allen.git .
```

**Step 4：配置环境变量**
```bash
# 创建 .env 文件
cat > /opt/frances-allen/.env << EOF
MYSQL_ROOT_PASSWORD=your_root_password_here
DB_PASSWORD=your_db_password_here
EOF
```

**Step 5：构建并启动**
```bash
cd /opt/frances-allen
docker-compose build
docker-compose up -d
```

**Step 6：验证服务**
```bash
# 检查容器状态
docker-compose ps

# 查看日志
docker-compose logs -f backend

# 测试 API
curl http://localhost:8000/api/movies
```

#### 10.4.2 本地开发到部署流程

```
┌─────────────────┐
│   本地开发       │
│  (Windows)      │
└────────┬────────┘
         │
         │ git push
         ▼
┌─────────────────┐
│   GitHub         │
└────────┬────────┘
         │
         │ ssh + git clone
         ▼
┌─────────────────┐
│   阿里云 ECS     │
│  /opt/frances   │
│     -allen       │
└────────┬────────┘
         │
         │ docker-compose up
         ▼
┌─────────────────┐
│   运行容器       │
│  backend + mysql │
└─────────────────┘
```

### 10.5 运维命令

| 操作 | 命令 |
|------|------|
| 启动服务 | `docker-compose up -d` |
| 停止服务 | `docker-compose down` |
| 查看状态 | `docker-compose ps` |
| 查看日志 | `docker-compose logs -f backend` |
| 重启后端 | `docker-compose restart backend` |
| 重新构建 | `docker-compose build --no-cache` |
| 进入容器 | `docker exec -it frances-allen-backend /bin/bash` |
| 查看 MySQL 日志 | `docker-compose logs mysql` |

### 10.6 数据库备份与恢复

**备份**
```bash
docker exec frances-allen-mysql mysqldump -u frances -p${DB_PASSWORD} francesAllen > backup_$(date +%Y%m%d).sql
```

**恢复**
```bash
cat backup_20240101.sql | docker exec -i frances-allen-mysql mysql -u frances -p${DB_PASSWORD} francesAllen
```

### 10.7 更新部署流程

```bash
cd /opt/frances-allen

# 拉取最新代码
git pull origin main

# 重新构建并启动
docker-compose build backend
docker-compose up -d backend

# 查看更新日志
docker-compose logs -f backend
```
