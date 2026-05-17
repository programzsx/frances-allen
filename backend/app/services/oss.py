import oss2
import random
from fastapi import UploadFile
from typing import Optional

from app.config import settings


def _get_bucket():
    auth = oss2.Auth(settings.OSS_ACCESS_KEY_ID, settings.OSS_ACCESS_KEY_SECRET)
    bucket = oss2.Bucket(auth, settings.OSS_ENDPOINT, settings.OSS_BUCKET)
    print(f"[OSS] Using endpoint={settings.OSS_ENDPOINT}, bucket={settings.OSS_BUCKET}")
    return bucket


def list_objects(prefix: str = "") -> list[dict]:
    """列出指定前缀下的所有对象（目录和文件）"""
    bucket = _get_bucket()

    if prefix:
        # 子目录：遍历该前缀下的所有对象
        subdir_set = set()
        files = []
        for obj in oss2.ObjectIterator(bucket, prefix=prefix):
            key = obj.key
            # 跳过目录自身标记
            stripped = key.rstrip("/")
            if stripped == prefix.rstrip("/"):
                continue
            if key.endswith("/"):
                subdir_set.add(stripped + "/")
            else:
                files.append({
                    "key": key,
                    "size": obj.size,
                    "last_modified": obj.last_modified,
                    "is_dir": False,
                })
        dirs = [{'key': k, 'size': 0, 'last_modified': '', 'is_dir': True} for k in sorted(subdir_set)]
        files.sort(key=lambda x: x['key'])
        return dirs + files
    else:
        # 根目录：遍历所有对象，从路径中提取顶层目录
        first_dirs = set()
        files = []
        for obj in oss2.ObjectIterator(bucket, prefix=None):
            key = obj.key
            if key.endswith("/"):
                first_dirs.add(key.rstrip("/"))
            else:
                parts = key.rstrip("/").split("/")
                if len(parts) > 1:
                    first_dirs.add(parts[0])

        dirs = [{'key': d + "/", 'size': 0, 'last_modified': '', 'is_dir': True} for d in sorted(first_dirs)]
        dirs.sort(key=lambda x: x['key'])
        files.sort(key=lambda x: x['key'])
        return dirs + files


def upload_image(file: UploadFile, prefix: str = "images", filename: str = None) -> str:
    """上传图片到OSS指定目录"""
    bucket = _get_bucket()
    if prefix and not prefix.endswith("/"):
        prefix = prefix + "/"
    if filename:
        # Only add extension if filename doesn't already have one
        if "." in filename:
            key = f"{prefix}{filename}"
        else:
            ext = file.filename.rsplit(".", 1)[-1] if "." in file.filename else "jpg"
            key = f"{prefix}{filename}.{ext}"
    else:
        key = f"{prefix}{file.filename}"
    bucket.put_object(key, file.file)
    return f"https://{settings.OSS_BUCKET}.{settings.OSS_ENDPOINT}/{key}"


def delete_object(key: str) -> bool:
    """删除OSS中的对象"""
    bucket = _get_bucket()
    if key.endswith("/"):
        try:
            bucket.delete_object(key)
            return True
        except:
            return False
    result = bucket.delete_object(key)
    return result.status == 204


def get_signed_url(key: str, expires: int = 3600) -> str:
    """获取签名URL"""
    bucket = _get_bucket()
    return bucket.sign_url("GET", key, expires)


def get_public_url(key: str) -> str:
    """获取公共URL"""
    return f"https://{settings.OSS_BUCKET}.{settings.OSS_ENDPOINT}/{key}"


def list_videos(prefix: str = "") -> list[dict]:
    """列出指定前缀下的视频文件(.mp4)"""
    objects = list_objects(prefix)
    return [obj for obj in objects if not obj["is_dir"] and obj["key"].endswith(".mp4")]