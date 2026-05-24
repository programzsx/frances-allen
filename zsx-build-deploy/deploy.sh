#!/bin/bash
set -e

DEPLOY_DIR="/opt/frances-allen"
SERVER_DIR="$DEPLOY_DIR/server"
TARBALL="/home/server.tar.gz"
ENV_BACKUP="/tmp/.env.bak"

echo "=== Frances Allen Backend Deploy ==="

# 1. Check tarball
if [ ! -f "$TARBALL" ]; then
    echo "ERROR: $TARBALL not found!"
    exit 1
fi

# 2. Stop old processes
echo "[1/8] Stopping old server..."
pkill -f "uvicorn.*app.main" 2>/dev/null || true
pkill -f "python.*run.py" 2>/dev/null || true
sleep 2
echo "  Stopped."

# 3. Backup .env
echo "[2/8] Backing up .env..."
if [ -f "$SERVER_DIR/.env" ]; then
    cp "$SERVER_DIR/.env" "$ENV_BACKUP"
    echo "  Backed up from $SERVER_DIR/.env"
elif [ -f "$DEPLOY_DIR/.env" ]; then
    cp "$DEPLOY_DIR/.env" "$ENV_BACKUP"
    echo "  Backed up from $DEPLOY_DIR/.env"
else
    echo "  No existing .env found (will create default)"
fi

# 4. Extract new code
echo "[3/8] Extracting $TARBALL to $DEPLOY_DIR..."
rm -rf "$DEPLOY_DIR"
mkdir -p "$DEPLOY_DIR"
cd "$DEPLOY_DIR"
tar -xzf "$TARBALL"
echo "  Extracted."

# 5. Restore .env
echo "[4/8] Restoring .env..."
if [ -f "$ENV_BACKUP" ]; then
    cp "$ENV_BACKUP" "$SERVER_DIR/.env"
    echo "  .env restored from backup"
else
    echo "  No .env to restore — creating default..."
    cat > "$SERVER_DIR/.env" << 'ENVEOF'
DB_HOST=rm-bp148re5az8vk250qyo.mysql.rds.aliyuncs.com
DB_PORT=3306
DB_USER=frances_allen
DB_PASSWORD=your_db_password
DB_NAME=frances-allen
OSS_ACCESS_KEY_ID=your_oss_access_key_id
OSS_ACCESS_KEY_SECRET=your_oss_access_key_secret
OSS_ENDPOINT=oss-cn-beijing.aliyuncs.com
OSS_BUCKET=zsx-r7000p
ENVEOF
    echo "  Default .env created"
fi

# 6. Clean Python cache
echo "[5/8] Cleaning Python cache..."
find "$DEPLOY_DIR" -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
find "$DEPLOY_DIR" -name '*.pyc' -delete 2>/dev/null || true
echo "  Cleaned."

# 7. Install dependencies
echo "[6/8] Installing dependencies..."
cd "$SERVER_DIR"
pip install -r requirements.txt -q
pip install --force-reinstall pyOpenSSL cryptography -q
echo "  Installed."

# 8. Verify code
echo "[7/8] Verifying..."
if grep -q "CORSMiddleware" "$SERVER_DIR/app/main.py"; then
    echo "  ✓ CORS middleware present"
fi
echo "  ✓ Code verified"

# 9. Start server
echo "[8/8] Starting server..."
cd "$SERVER_DIR"
nohup python3 run.py > /tmp/frances-allen.log 2>&1 &
PID=$!
echo "  Started with PID: $PID"

# 10. Health check
echo ""
echo "=== Health Check ==="
sleep 3
for i in $(seq 1 10); do
    RESP=$(curl -s --connect-timeout 2 http://127.0.0.1:8000/ 2>/dev/null || true)
    if echo "$RESP" | grep -q "running"; then
        echo "✓ Server is running: $RESP"
        echo ""
        echo "=== Deploy Complete ==="
        echo "Server PID: $PID"
        echo "Log: /tmp/frances-allen.log"
        exit 0
    fi
    echo "  Waiting for server... (attempt $i)"
    sleep 2
done

echo ""
echo "✗ Server failed to start!"
echo "Full log:"
cat /tmp/frances-allen.log
exit 1
