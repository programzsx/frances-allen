#!/bin/bash
set -e

DEPLOY_DIR="/opt/frances-allen"
TARBALL="/home/server.tar.gz"
ENV_BACKUP="/tmp/.env.bak"

echo "=== Frances Allen Backend Deploy ==="
echo "Deploy dir: $DEPLOY_DIR"
echo "Tarball: $TARBALL"

# 1. Check tarball exists
if [ ! -f "$TARBALL" ]; then
    echo "ERROR: $TARBALL not found!"
    exit 1
fi

# 2. Stop old processes
echo "[1/7] Stopping old server processes..."
pkill -f "uvicorn.*app.main" 2>/dev/null || true
pkill -f "python.*run.py" 2>/dev/null || true
sleep 2
echo "  Stopped."

# 3. Backup existing .env if present
echo "[2/7] Backing up existing .env..."
if [ -f "$DEPLOY_DIR/.env" ]; then
    cp "$DEPLOY_DIR/.env" "$ENV_BACKUP"
    echo "  Backed up .env"
else
    echo "  No existing .env found (will need to create one)"
fi

# 4. Extract new code into deploy dir
echo "[3/7] Extracting $TARBALL to $DEPLOY_DIR..."
rm -rf "$DEPLOY_DIR"
mkdir -p "$DEPLOY_DIR"
cd "$DEPLOY_DIR"
tar -xzf "$TARBALL"
echo "  Extracted."

# 5. Restore .env
echo "[4/7] Restoring .env..."
if [ -f "$ENV_BACKUP" ]; then
    cp "$ENV_BACKUP" "$DEPLOY_DIR/.env"
    echo "  .env restored from backup"
elif [ -f "/home/.env" ]; then
    cp /home/.env "$DEPLOY_DIR/.env"
    echo "  .env copied from /home/.env"
else
    echo "  No existing .env found, creating default .env..."
    cat > "$DEPLOY_DIR/.env" << 'ENVEOF'
# MySQL (Alibaba Cloud RDS)
DB_HOST=rm-bp148re5az8vk250qyo.mysql.rds.aliyuncs.com
DB_PORT=3306
DB_USER=frances_allen
DB_PASSWORD=your_db_password
DB_NAME=frances-allen

# Alibaba Cloud OSS
OSS_ACCESS_KEY_ID=your_oss_access_key_id
OSS_ACCESS_KEY_SECRET=your_oss_access_key_secret
OSS_ENDPOINT=oss-cn-beijing.aliyuncs.com
OSS_BUCKET=zsx-r7000p
ENVEOF
    echo "  Default .env created (edit /opt/frances-allen/.env if values change)"
fi

# 6. Clean Python cache
echo "[5/7] Cleaning Python cache..."
find "$DEPLOY_DIR" -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
find "$DEPLOY_DIR" -name '*.pyc' -delete 2>/dev/null || true
echo "  Cleaned."

# 7. Install dependencies
echo "[6/7] Installing dependencies..."
pip install -r "$DEPLOY_DIR/requirements.txt" -q
# Fix pyOpenSSL/cryptography incompatibility: system pyOpenSSL conflicts with newer cryptography
pip install --force-reinstall pyOpenSSL cryptography -q
echo "  Installed."

# 8. Verify key files
echo "[7/7] Verifying code..."
echo "  Checking oss.py list_objects function..."
if grep -q "prefix_list" "$DEPLOY_DIR/app/services/oss.py"; then
    echo "  ✓ oss.py uses prefix_list (correct)"
else
    echo "  ✗ oss.py does NOT use prefix_list (WRONG - old code?)"
    exit 1
fi

if grep -q "CORSMiddleware" "$DEPLOY_DIR/app/main.py"; then
    echo "  ✓ main.py has CORS middleware"
else
    echo "  ✗ main.py missing CORS middleware"
    exit 1
fi

# 9. Start server
echo ""
echo "=== Starting Server ==="
cd "$DEPLOY_DIR"
nohup uvicorn app.main:app --host 0.0.0.0 --port 8000 > server.log 2>&1 &
PID=$!
echo "  Started with PID: $PID"

# 10. Health check
echo ""
echo "=== Server Log (last 20 lines) ==="
sleep 3
tail -20 "$DEPLOY_DIR/server.log"

echo ""
echo "=== Health Check ==="
HEALTH_OK=false
for i in $(seq 1 10); do
    RESP=$(curl -s --connect-timeout 2 http://127.0.0.1:8000/ 2>/dev/null || true)
    if echo "$RESP" | grep -q "running"; then
        echo "✓ Server is running: $RESP"
        HEALTH_OK=true
        break
    fi
    echo "  Waiting for server... (attempt $i)"
    sleep 2
done

if [ "$HEALTH_OK" != "true" ]; then
    echo ""
    echo "✗ Server failed to start. Full log:"
    cat "$DEPLOY_DIR/server.log"
    echo ""
    echo "Hint: Check if .env exists and has correct values:"
    ls -la "$DEPLOY_DIR/.env" 2>/dev/null || echo "  .env NOT FOUND"
    exit 1
fi

# 11. Test CORS
echo ""
echo "=== CORS Check ==="
CORS_HEADERS=$(curl -sI --connect-timeout 2 "http://127.0.0.1:8000/api/tags?current_page=1&page_size=1" -H "Origin: http://localhost:3000" | grep -i "access-control" || true)
if echo "$CORS_HEADERS" | grep -qi "access-control-allow-origin"; then
    echo "✓ CORS headers present:"
    echo "$CORS_HEADERS"
else
    echo "✗ CORS headers missing!"
    echo "  Full response headers:"
    curl -sI --connect-timeout 2 "http://127.0.0.1:8000/api/tags?current_page=1&page_size=1" -H "Origin: http://localhost:3000"
fi

# 12. Test OSS listing
echo ""
echo "=== OSS Listing Test ==="
echo "Root directory:"
curl -s --connect-timeout 5 "http://127.0.0.1:8000/api/images/list" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(f'  dirs: {len(data[\"dirs\"])}, files: {len(data[\"files\"])}')
for d in data['dirs']:
    print(f'    DIR: {d[\"key\"]}')
" 2>/dev/null || echo "  Failed to parse"

echo "images/ directory:"
curl -s --connect-timeout 5 "http://127.0.0.1:8000/api/images/list?prefix=images%2F" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(f'  dirs: {len(data[\"dirs\"])}, files: {len(data[\"files\"])}')
for d in data['dirs']:
    print(f'    DIR: {d[\"key\"]}')
for f in data['files']:
    print(f'    FILE: {f[\"key\"]}')
" 2>/dev/null || echo "  Failed to parse"

echo ""
echo "=== Deploy Complete ==="
echo "Server PID: $PID"
echo "Log file: $DEPLOY_DIR/server.log"
