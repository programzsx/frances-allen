from typing import Optional

from sqlalchemy.orm import Session

from app.dao import douyin_video as video_dao
from app.dao import douyin_movie as movie_dao
from app.schemas.douyin_video import VideoCreateBO, VideoUpdateBO


def _now() -> str:
    from datetime import datetime, timezone
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")


def _video_to_dict(row) -> dict:
    return {c.name: getattr(row, c.name) for c in row.__table__.columns}


def create_video(db: Session, bo: VideoCreateBO) -> dict:
    if not movie_dao.get_by_id(db, bo.movie_id):
        raise ValueError(f"电影 {bo.movie_id} 不存在")
    now = _now()
    data = {
        "create_time": now,
        "update_time": now,
        "movie_id": bo.movie_id,
        "name": bo.name,
        "description": bo.description,
        "cover_url": bo.cover_url,
        "duration": bo.duration or 0,
        "slice_count": 0,
        "sort_order": bo.sort_order or 0,
        "status": 1,
    }
    row = video_dao.add(db, data)
    return _video_to_dict(row)


def delete_video(db: Session, video_id: str) -> bool:
    return video_dao.delete(db, video_id)


def update_video(db: Session, video_id: str, bo: VideoUpdateBO) -> Optional[dict]:
    update_data = bo.model_dump(exclude_unset=True)
    if not update_data:
        return _video_to_dict(video_dao.get_by_id(db, video_id))
    update_data["update_time"] = _now()
    row = video_dao.update(db, video_id, update_data)
    if not row:
        return None
    return _video_to_dict(row)


def get_video(db: Session, video_id: str) -> Optional[dict]:
    row = video_dao.get_by_id(db, video_id)
    if not row:
        return None
    return _video_to_dict(row)


def get_videos_by_movie(db: Session, movie_id: str) -> list[dict]:
    items = video_dao.get_by_movie_id(db, movie_id)
    return [_video_to_dict(item) for item in items]


def page_video(
    db: Session,
    current_page: int = 1,
    page_size: int = 10,
    movie_id: Optional[str] = None,
) -> dict:
    items, total = video_dao.page_query(db, current_page, page_size, movie_id)
    return {
        "items": [_video_to_dict(item) for item in items],
        "total": total,
        "current_page": current_page,
        "page_size": page_size,
    }
