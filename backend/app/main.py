from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.database import engine, Base
from app.routers import kb_bank, kb_tag, kb_qa, oss, douyin_movie, douyin_video, douyin_slice

app = FastAPI(
    title="Frances Allen API",
    description="知识问答练习 App 后端服务",
    version="1.0.0",
)


@app.on_event("startup")
def startup():
    try:
        Base.metadata.create_all(bind=engine)
        print("✓ 数据库表同步完成")
    except Exception as e:
        print(f"✗ 数据库连接失败: {e}")
        print("  请检查: 1) RDS白名单是否已添加本机IP  2) 账号密码是否正确")


@app.exception_handler(ValueError)
async def value_error_handler(request: Request, exc: ValueError):
    return JSONResponse(status_code=400, content={"success": False, "error": str(exc)})


@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    return JSONResponse(status_code=500, content={"success": False, "error": str(exc)})

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# 注册路由
app.include_router(kb_bank.router)
app.include_router(kb_tag.router)
app.include_router(kb_qa.router)
app.include_router(oss.router)
app.include_router(douyin_movie.router)
app.include_router(douyin_video.router)
app.include_router(douyin_slice.router)


@app.get("/", summary="健康检查")
def root():
    return {"app": "frances-allen", "status": "running"}


@app.get("/api/test-settings", summary="测试配置")
def test_settings():
    from app.config import settings
    return {
        "OSS_ENDPOINT": settings.OSS_ENDPOINT,
        "OSS_BUCKET": settings.OSS_BUCKET,
    }
