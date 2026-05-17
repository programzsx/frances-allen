import sys
from fastapi import APIRouter, UploadFile, File, Query

from app.services import oss as oss_service

router = APIRouter(prefix="/api/images", tags=["图片管理"])


@router.get("/list", summary="列出目录下的对象")
def list_images(prefix: str = Query("", description="目录前缀")):
    """列出指定目录下的所有子目录和文件"""
    import random
    objects = oss_service.list_objects(prefix)
    # 分离目录和文件
    dirs = [obj for obj in objects if obj["is_dir"]]
    files = [obj for obj in objects if not obj["is_dir"]]
    sys.stderr.write(f"[DEBUG] prefix={prefix!r} objects={len(objects)} dirs={len(dirs)} files={len(files)} rand={random.randint(0,999)}\n")
    sys.stderr.flush()
    return {
        "dirs": dirs,
        "files": files,
        "total": len(dirs) + len(files),
    }


@router.post("/upload", summary="上传图片到OSS")
async def upload_image(
    file: UploadFile = File(...),
    prefix: str = Query("images", description="存储目录前缀"),
    filename: str = Query(None, description="自定义文件名（不含扩展名）"),
):
    """上传图片到OSS指定目录"""
    url = oss_service.upload_image(file, prefix, filename)
    # filename already contains extension, don't add another one
    key = f"{prefix}/{filename}" if prefix else f"{filename}"
    return {"url": url, "key": key}


def _get_ext(original_filename: str) -> str:
    parts = original_filename.rsplit(".", 1)
    return parts[-1] if len(parts) > 1 else "jpg"


@router.delete("/{key:path}", summary="删除OSS中的对象")
def delete_object(key: str):
    """删除OSS中的文件"""
    ok = oss_service.delete_object(key)
    return {"success": ok}


@router.get("/{key:path}/signed-url", summary="获取图片签名URL")
def signed_url(key: str, expires: int = Query(3600, ge=60, le=86400)):
    """获取文件的签名访问URL"""
    url = oss_service.get_signed_url(key, expires)
    return {"url": url}


@router.get("/{key:path}/public-url", summary="获取图片公共URL")
def public_url(key: str):
    """获取文件的公共访问URL"""
    url = oss_service.get_public_url(key)
    return {"url": url}


# ============ 视频OSS操作 ============


@router.get("/videos/list", summary="列出视频文件")
def list_videos(prefix: str = Query("", description="目录前缀")):
    """列出指定前缀下的所有视频文件"""
    objects = oss_service.list_videos(prefix)
    return {
        "files": objects,
        "total": len(objects),
    }


@router.post("/videos/upload", summary="上传视频到OSS")
async def upload_video(
    file: UploadFile = File(...),
    prefix: str = Query("videos", description="存储目录前缀"),
    filename: str = Query(None, description="自定义文件名"),
):
    """上传视频到OSS指定目录"""
    url = oss_service.upload_image(file, prefix, filename)
    # filename already contains extension from client, don't add another one
    key = f"{prefix}/{filename}" if filename else f"{prefix}/{file.filename}"
    return {"url": url, "key": key}


@router.delete("/videos/{key:path}", summary="删除视频")
def delete_video(key: str):
    """删除OSS中的视频文件"""
    ok = oss_service.delete_object(key)
    return {"success": ok}


@router.get("/videos/{key:path}/signed-url", summary="获取视频签名URL")
def video_signed_url(key: str, expires: int = Query(3600, ge=60, le=86400)):
    """获取视频的签名访问URL"""
    url = oss_service.get_signed_url(key, expires)
    return {"url": url}


@router.get("/videos/{key:path}/public-url", summary="获取视频公共URL")
def video_public_url(key: str):
    """获取视频的公共访问URL"""
    url = oss_service.get_public_url(key)
    return {"url": url}