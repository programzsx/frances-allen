#!/usr/bin/env python
"""启动脚本"""
import os
import uvicorn

# 强制从 .env 加载环境变量
if __name__ == "__main__":
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    host = os.environ.get("UVICORN_HOST", "127.0.0.1")
    port = int(os.environ.get("UVICORN_PORT", "8000"))
    uvicorn.run("app.main:app", host=host, port=port, reload=False)
