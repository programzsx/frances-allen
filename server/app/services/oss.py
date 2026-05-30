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
    """列出指定前缀下的所有对象，用 delimiter 做目录分层"""
    bucket = _get_bucket()
    dirs = []
    files = []

    if prefix:
        norm_prefix = prefix.rstrip("/") + "/"
        # 使用 bucket.list_objects + delimiter 获取一级子目录和当前目录下的文件
        marker = None
        while True:
            resp = bucket.list_objects(prefix=norm_prefix, delimiter="/", marker=marker)
            # 子目录来自 prefix_list（字符串列表）
            for p in (resp.prefix_list or []):
                dirs.append({
                    "key": p,
                    "size": 0,
                    "last_modified": "",
                    "is_dir": True,
                })
            # 文件来自 objectList
            for obj in (resp.object_list or []):
                files.append({
                    "key": obj.key,
                    "size": obj.size,
                    "last_modified": obj.last_modified,
                    "is_dir": False,
                })
            if resp.is_truncated:
                marker = resp.next_marker
            else:
                break
    else:
        # 根目录：遍历所有对象，提取顶层目录
        first_dirs = set()
        marker = None
        while True:
            resp = bucket.list_objects(marker=marker)
            for obj in (resp.object_list or []):
                key = obj.key
                if key.endswith("/"):
                    first_dirs.add(key.rstrip("/"))
                else:
                    parts = key.rstrip("/").split("/")
                    if len(parts) > 1:
                        first_dirs.add(parts[0])
            if resp.is_truncated:
                marker = resp.next_marker
            else:
                break
        dirs = [{'key': d + "/", 'size': 0, 'last_modified': '', 'is_dir': True} for d in sorted(first_dirs)]

    dirs.sort(key=lambda x: x['key'])
    files.sort(key=lambda x: x['key'])
    return dirs + files


def upload_image(file: UploadFile, prefix: str = "kb", filename: str = None) -> str:
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
