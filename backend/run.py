#!/usr/bin/env python
"""启动脚本"""
import os
import uvicorn

# 强制从 .env 加载环境变量
if __name__ == "__main__":
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    uvicorn.run("app.main:app", host="127.0.0.1", port=8000, reload=False)
