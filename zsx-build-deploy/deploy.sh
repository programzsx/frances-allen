#!/bin/bash
set -e

DEPLOY_DIR="/opt/frances-allen"
SERVER_DIR="$DEPLOY_DIR/server"
VENV_DIR="$DEPLOY_DIR/venv"
TARBALL="/home/server.tar.gz"
ENV_BACKUP="/tmp/.env.bak"
SERVICE_NAME="frances-allen"

echo "=== Frances Allen Backend Deploy ==="

# 1. Check tarball
if [ ! -f "$TARBALL" ]; then
    echo "ERROR: $TARBALL not found!"
    exit 1
fi

# 2. Backup .env
echo "[1/7] Backing up .env..."
if [ -f "$SERVER_DIR/.env" ]; then
    cp "$SERVER_DIR/.env" "$ENV_BACKUP"
    echo "  Backed up from $SERVER_DIR/.env"
elif [ -f "$DEPLOY_DIR/.env" ]; then
    cp "$DEPLOY_DIR/.env" "$ENV_BACKUP"
    echo "  Backed up from $DEPLOY_DIR/.env"
else
    echo "  No existing .env found (will create default)"
fi

# 3. Stop old service
echo "[2/7] Stopping service..."
systemctl stop "$SERVICE_NAME" 2>/dev/null || true
echo "  Stopped."

# 4. Extract new code
echo "[3/7] Extracting $TARBALL to $DEPLOY_DIR..."
rm -rf "$SERVER_DIR"
mkdir -p "$DEPLOY_DIR"
cd "$DEPLOY_DIR"
tar -xzf "$TARBALL"
echo "  Extracted."

# 5. Restore / create .env
echo "[4/7] Restoring .env..."
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

# 6. Setup venv & install dependencies
echo "[5/7] Setting up venv & installing dependencies..."
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
    echo "  venv created at $VENV_DIR"
fi
cd "$SERVER_DIR"
"$VENV_DIR/bin/pip" install -r requirements.txt -q
echo "  Installed."

# 7. Start service
echo "[6/7] Starting service..."
systemctl restart "$SERVICE_NAME"
echo "  Restarted."

# 8. Health check
echo ""
echo "=== Health Check ==="
sleep 3
for i in $(seq 1 10); do
    RESP=$(curl -s --connect-timeout 2 http://127.0.0.1:8000/ 2>/dev/null || true)
    if echo "$RESP" | grep -q "running"; then
        echo "✓ Server is running: $RESP"
        echo ""
        echo "=== Deploy Complete ==="
        systemctl status "$SERVICE_NAME" --no-pager -l 2>/dev/null | head -5
        exit 0
    fi
    echo "  Waiting for server... (attempt $i)"
    sleep 2
done

echo ""
echo "✗ Server failed to start!"
echo "Service status:"
systemctl status "$SERVICE_NAME" --no-pager -l 2>/dev/null || true
echo "Recent log:"
journalctl -u "$SERVICE_NAME" --no-pager -n 20 2>/dev/null || true
exit 1
