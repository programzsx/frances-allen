#!/bin/bash
# ============================================================
# Frances Allen Auto-Deploy Script
# Usage: ./auto-deploy.sh [--skip-test] [--skip-migration]
# ============================================================
set -e

ECS_HOST="root@8.160.174.178"
ECS_DEPLOY_DIR="/home/frances-allen"
SERVER_TAR="server.tar.gz"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

SKIP_TEST=false
SKIP_MIGRATION=false

for arg in "$@"; do
    case $arg in
        --skip-test) SKIP_TEST=true ;;
        --skip-migration) SKIP_MIGRATION=true ;;
    esac
done

echo "============================================"
echo "  Frances Allen Auto-Deploy"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================"

# ── Step 1: Git commit & push ──
echo ""
echo "[1/7] Git commit & push..."
cd "$PROJECT_DIR"
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "  Uncommitted changes detected. Commit message:"
    read -p "  Enter commit message (or Enter to skip): " MSG
    if [ -n "$MSG" ]; then
        git add -A
        git commit -m "$MSG"
    fi
fi
git push
echo "  ✓ Pushed"

# ── Step 2: Package server ──
echo ""
echo "[2/7] Packaging server..."
cd "$PROJECT_DIR"
tar -czf "zsx-build-deploy/$SERVER_TAR" server/ --exclude='__pycache__' --exclude='*.pyc'
echo "  ✓ Packaged: $(ls -lh zsx-build-deploy/$SERVER_TAR | awk '{print $5}')"

# ── Step 3: Upload to ECS ──
echo ""
echo "[3/7] Uploading to ECS..."
scp "zsx-build-deploy/$SERVER_TAR" "zsx-build-deploy/deploy.sh" "$ECS_HOST:/home/"
echo "  ✓ Uploaded"

# ── Step 4: Run deploy.sh on ECS ──
echo ""
echo "[4/7] Deploying on ECS..."
ssh "$ECS_HOST" "bash /home/deploy.sh"
echo "  ✓ Deployed"

# ── Step 5: Run database migrations ──
if [ "$SKIP_MIGRATION" = false ]; then
    echo ""
    echo "[5/7] Running database migrations..."
    MIGRATION_DIR="$PROJECT_DIR/zsx-sql-migeration"
    if [ -d "$MIGRATION_DIR" ]; then
        for sql in "$MIGRATION_DIR"/*.sql; do
            if [ -f "$sql" ]; then
                fname=$(basename "$sql")
                echo "  Running: $fname"
                scp "$sql" "$ECS_HOST:/tmp/$fname" > /dev/null 2>&1
                ssh "$ECS_HOST" "
                    source /home/frances-allen/server/.env 2>/dev/null
                    mysql -h \"\$DB_HOST\" -u \"\$DB_USER\" -p\"\$DB_PASSWORD\" \"\$DB_NAME\" < /tmp/$fname 2>&1 || echo '  (may already be applied)'
                " 2>/dev/null
            fi
        done
        echo "  ✓ Migrations done"
    else
        echo "  ⚠ No migration directory found: $MIGRATION_DIR"
    fi
else
    echo ""
    echo "[5/7] Skipping migrations (--skip-migration)"
fi

# ── Step 6: Run tests ──
if [ "$SKIP_TEST" = false ]; then
    echo ""
    echo "[6/7] Running API tests..."
    TEST_SCRIPT="$SCRIPT_DIR/test_api.py"
    scp "$TEST_SCRIPT" "$ECS_HOST:/tmp/test_api.py" > /dev/null 2>&1
    ssh "$ECS_HOST" "python3 /tmp/test_api.py"
    echo "  ✓ Tests complete"
else
    echo ""
    echo "[6/7] Skipping tests (--skip-test)"
fi

# ── Step 7: Generate report ──
echo ""
echo "[7/7] Generating deploy report..."
REPORT="$SCRIPT_DIR/deploy-report-$(date +%Y-%m-%d).md"
cat > "$REPORT" << EOF
# Frances Allen Deploy Report

> Time: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
> Server: 8.160.174.178:8000
> Git: $(cd "$PROJECT_DIR" && git log --oneline -1)

## Deploy Status

- Package: $SERVER_TAR
- ECS: $ECS_HOST
- Deploy dir: $ECS_DEPLOY_DIR

See test output above for detailed results.
EOF
echo "  ✓ Report: $REPORT"

echo ""
echo "============================================"
echo "  Deploy Complete!"
echo "============================================"
echo "  API: http://8.160.174.178:8000"
echo "  Report: $REPORT"
