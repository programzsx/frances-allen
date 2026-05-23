# 部署说明

## 启动后端

```bash
# 1. 检查端口 8000 是否被占用
netstat -ano | grep ":8000" | grep LISTEN

# 2. 如果没有进程在监听，进入 backend 目录启动
cd backend
python run.py

# 3. 如果端口被占用，说明已有进程运行，无需重复启动
```

## 启动前端

```bash
# 1. 终止所有 Chrome 进程，避免端口冲突
taskkill //F //IM chrome.exe

# 2. 检查端口 3000 是否被占用
netstat -ano | grep ":3000" | grep LISTEN

# 3. 如果有进程占用 3000 端口，终止它
taskkill //F //PID <PID号>

# 4. 启动 Flutter Web 服务
cd frontend
flutter run -d web-server --web-port=3000

# 5. 验证前端已启动
curl -s http://localhost:3000

# 6. 打开 Chrome 访问 http://localhost:3000
```

## 服务地址

- 后端 API: http://127.0.0.1:8000
- 前端 Web: http://localhost:3000

## 注意事项

- Flutter 的 `flutter run -d chrome` 模式会自动尝试启动 Chrome，但有时会失败
- 使用 `flutter run -d web-server` 模式更稳定，手动用 Chrome 打开即可
- 后端使用 uvicorn，每次代码修改后需重启进程
- 前端 Flutter 使用热重载，代码修改会自动生效