# Frances Allen — 部署运维规范

> 版本：v2.0 | 更新日期：2026-05-25

---

## 1. 服务地址

| 环境 | 后端API | 说明 |
|------|---------|------|
| 开发环境 | `http://127.0.0.1:8000` | 本地WSL |
| 生产环境 | `http://8.160.174.178:8000` | 阿里云ECS |
| 生产Web | `http://8.160.174.178:3000` | Flutter Web（可选） |

---

## 2. 生产环境信息

- 服务器：阿里云ECS `8.160.174.178`（root）
- 部署目录：`/opt/frances-allen/`
- 服务管理：`systemctl`，服务名 `frances-allen`
- 运行用户：root
- Python环境：`/opt/frances-allen/venv/`
- 数据库：阿里云RDS MySQL `rm-bp148re5az8vk250qyo.mysql.rds.aliyuncs.com:3306`

---

## 3. 后端打包部署

### 3.1 打包

```bash
cd /home/codezsx/frances-allen
tar -czf /tmp/frances-allen-server-v{VERSION}.tar.gz server/
```

### 3.2 上传

```bash
scp /tmp/frances-allen-server-v{VERSION}.tar.gz root@8.160.174.178:/home/server.tar.gz
```

### 3.3 自动部署

```bash
ssh root@8.160.174.178 "cd /opt/frances-allen && tar -xzf /home/server.tar.gz && systemctl restart frances-allen"
```

### 3.4 数据库迁移（如需要）

```bash
ssh root@8.160.174.178 "mysql -h rm-bp148re5az8vk250qyo.mysql.rds.aliyuncs.com -u frances_allen -p'***' frances-allen -e 'ALTER TABLE kb_qa MODIFY category_id VARCHAR(64) NULL;'"
```

### 3.5 验证

```bash
curl -s http://8.160.174.178:8000/
# 预期: {"app":"frances-allen","status":"running"}
```

---

## 4. 前端打包

### 4.1 配置生产环境地址

编辑 `mobile/lib/services/api_config.dart`：

```dart
class ApiConfig {
  static const String baseUrl = 'http://8.160.174.178:8000';
}
```

### 4.2 Android APK 构建

```bash
# 构建目录需要迁移到Windows临时目录（Flutter SDK在Windows端）
cd /home/codezsx/frances-allen
cp -r mobile /mnt/c/temp_frances_allen_mobile

# 在Windows端执行构建
cmd.exe /c "cd C:\temp_frances_allen_mobile && flutter build apk --release"

# 复制产物到WSL
cp /mnt/c/temp_frances_allen_mobile/build/app/outputs/flutter-apk/app-release.apk \
   /home/codezsx/frances-allen/zsx-build-deploy/frances-allen-v{VERSION}.apk
```

### 4.3 Web 构建（可选）

```bash
cmd.exe /c "cd C:\temp_frances_allen_mobile && flutter build web"
```

---

## 5. 版本管理

| 版本号格式 | 说明 |
|-----------|------|
| `v2.0` | 主版本号，重大功能更新 |
| `v2.0.1` | 补丁版本，Bug修复 |

打包制品命名：`frances-allen-v{VERSION}.apk`

---

## 6. 一键部署脚本

参考 `zsx-build-deploy/deploy.sh`，执行流程：

1. 备份 `.env` 配置文件
2. 停止旧服务 `systemctl stop frances-allen`
3. 解压新代码 `tar -xzf`
4. 恢复 `.env`
5. 安装依赖 `pip install -r requirements.txt`
6. 重启服务 `systemctl restart frances-allen`
7. 健康检查 `curl http://127.0.0.1:8000/`

---

## 7. 注意事项

- 生产环境 `.env` 文件包含敏感信息，不要提交到Git
- 部署后会清除 `__pycache__` 以确保新代码生效
- 数据库迁移需在部署新代码后执行
- 前端构建依赖Windows端Flutter SDK（WSL不可直接用）
- 后端使用uvicorn，配置为 `--host 0.0.0.0 --port 8000`
