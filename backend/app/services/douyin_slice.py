from typing import Optional

from sqlalchemy.orm import Session

from app.dao import douyin_slice as slice_dao
from app.dao import douyin_video as video_dao
from app.dao import douyin_movie as movie_dao
from app.schemas.douyin_slice import SliceCreateBO, SliceUpdateBO


def _now() -> str:
    from datetime import datetime, timezone
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")


def _slice_to_dict(row) -> dict:
    d = {c.name: getattr(row, c.name) for c in row.__table__.columns}
    d["is_fav"] = bool(d.get("is_fav", 0))
    return d


def create_slice(db: Session, bo: SliceCreateBO) -> dict:
    video = video_dao.get_by_id(db, bo.video_id)
    if not video:
        raise ValueError(f"视频 {bo.video_id} 不存在")
    if not movie_dao.get_by_id(db, bo.movie_id):
        raise ValueError(f"电影 {bo.movie_id} 不存在")
    now = _now()
    data = {
        "create_time": now,
        "update_time": now,
        "video_id": bo.video_id,
        "movie_id": bo.movie_id,
        "name": bo.name,
        "comment": bo.comment,
        "oss_url": bo.oss_url,
        "sort_order": bo.sort_order or 0,
        "is_fav": 0,
    }
    row = slice_dao.add(db, data)
    # 更新 video 的 slice_count
    video_dao.update(db, bo.video_id, {"slice_count": video.slice_count + 1, "update_time": now})
    return _slice_to_dict(row)


def delete_slice(db: Session, slice_id: str) -> bool:
    return slice_dao.delete(db, slice_id)


def update_slice(db: Session, slice_id: str, bo: SliceUpdateBO) -> Optional[dict]:
    update_data = bo.model_dump(exclude_unset=True)
    if not update_data:
        return _slice_to_dict(slice_dao.get_by_id(db, slice_id))
    if "is_fav" in update_data:
        update_data["is_fav"] = 1 if update_data["is_fav"] else 0
    update_data["update_time"] = _now()
    row = slice_dao.update(db, slice_id, update_data)
    if not row:
        return None
    return _slice_to_dict(row)


def get_slice(db: Session, slice_id: str) -> Optional[dict]:
    row = slice_dao.get_by_id(db, slice_id)
    if not row:
        return None
    return _slice_to_dict(row)


def get_slices_by_video(db: Session, video_id: str) -> list[dict]:
    items = slice_dao.get_by_video_id(db, video_id)
    return [_slice_to_dict(item) for item in items]


def page_slice(
    db: Session,
    current_page: int = 1,
    page_size: int = 10,
    video_id: Optional[str] = None,
    movie_id: Optional[str] = None,
) -> dict:
    items, total = slice_dao.page_query(db, current_page, page_size, video_id, movie_id)
    return {
        "items": [_slice_to_dict(item) for item in items],
        "total": total,
        "current_page": current_page,
        "page_size": page_size,
    }


def random_slices(
    db: Session,
    limit: int = 50,
    movie_id: Optional[str] = None,
    video_id: Optional[str] = None,
) -> list[dict]:
    items = slice_dao.random_query(db, limit, movie_id, video_id)
    return [_slice_to_dict(item) for item in items]


def sequential_slices(
    db: Session,
    limit: int = 50,
    movie_id: Optional[str] = None,
    video_id: Optional[str] = None,
    offset_id: Optional[int] = None,
) -> list[dict]:
    items = slice_dao.sequential_query(db, limit, movie_id, video_id, offset_id)
    return [_slice_to_dict(item) for item in items]


def fav_slices(
    db: Session,
    limit: int = 50,
    movie_id: Optional[str] = None,
) -> list[dict]:
    items = slice_dao.fav_query(db, limit, movie_id)
    return [_slice_to_dict(item) for item in items]
