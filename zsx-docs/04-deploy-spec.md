# Frances Allen — 部署运维规范

---

## 1. 服务地址

- 后端API：`http://127.0.0.1:8000`
- 前端Web：`http://localhost:3000`

---

## 2. 启动后端

```bash
# 检查端口8000是否被占用
netstat -ano | grep ":8000" | grep LISTEN

# 如果没有进程在监听，进入server目录启动
cd server
python run.py

# 如果端口被占用，说明已有进程运行，无需重复启动
```

---

## 3. 启动前端

```bash
# 终止所有Chrome进程，避免端口冲突
taskkill //F //IM chrome.exe

# 检查端口3000是否被占用
netstat -ano | grep ":3000" | grep LISTEN

# 如果有进程占用3000端口，终止它
taskkill //F //PID <PID号>

# 启动Flutter Web服务
cd mobile
flutter run -d web-server --web-port=3000

# 验证前端已启动
curl -s http://localhost:3000

# 打开Chrome访问 http://localhost:3000
```

---

## 4. 一键部署

```bash
# 打包server目录为server.tar.gz，上传到服务器/home/
# 在服务器上执行:
chmod +x deploy.sh && ./deploy.sh
```

`deploy.sh`自动完成：停止旧进程→备份.env→解压代码→恢复配置→安装依赖→启动服务→健康检查。

---

## 5. 注意事项

- Flutter的`flutter run -d chrome`模式会自动尝试启动Chrome，但有时会失败
- 使用`flutter run -d web-server`模式更稳定，手动用Chrome打开即可
- 后端使用uvicorn，每次代码修改后需重启进程
- 前端Flutter使用热重载，代码修改会自动生效

---

## 6. 部署验证测试

### 6.1 后端健康检查

| # | 测试名称 | 验证点 |
|---|---------|--------|
| 1 | GET / | app=frances-allen，status=running |

### 6.2 前端导航验证

| 操作 | 预期 |
|------|------|
| 底部导航切换到"考试" | 显示QaPage，含AppBar+芯片行 |
| 底部导航切换到"图片" | 显示ImageManagePage |
| QaPage AppBar题库图标 | 跳转BankPage全屏管理页 |
| QaPage AppBar标签图标 | 跳转TagPage全屏管理页 |
| QaPage AppBar练习图标 | 跳转PracticePage |
| BankPage返回 | QaPage刷新，芯片行更新 |
| TagPage返回 | QaPage刷新，芯片行更新 |

### 6.3 桌面端一致性验证

| 检查项 | 预期 |
|--------|------|
| 主题颜色 | 与mobile一致（红色系） |
| 导航布局 | NavigationRail+内容区 |
| 芯片行 | 与mobile一致 |
| OSS前缀 | kb/ |
| DataCache | 与mobile一致 |
| 字体 | Microsoft YaHei |

### 6.4 图片管理部署验证

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

### 6.5 已知边界条件（部署环境）

| 场景 | 处理 |
|------|------|
| 空题库 | 显示"暂无题目"图标+文字 |
| 空标签 | 标签行不显示 |
| 无网络 | Loading后显示错误SnackBar |
| 长列表 | 无限滚动，loadingMore指示器 |
| OSS上传失败 | 错误提示+允许重试 |
| Dropdown未加载 | CircularProgressIndicator占位 |
