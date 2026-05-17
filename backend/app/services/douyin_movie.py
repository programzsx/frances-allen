from typing import Optional

from sqlalchemy.orm import Session

from app.dao import douyin_movie as movie_dao
from app.dao import douyin_video as video_dao
from app.schemas.douyin_movie import MovieCreateBO, MovieUpdateBO


def _now() -> str:
    from datetime import datetime, timezone
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")


def _movie_to_dict(row) -> dict:
    return {c.name: getattr(row, c.name) for c in row.__table__.columns}


def create_movie(db: Session, bo: MovieCreateBO) -> dict:
    now = _now()
    data = {
        "create_time": now,
        "update_time": now,
        "name": bo.name,
        "description": bo.description,
        "cover_url": bo.cover_url,
        "sort_order": bo.sort_order,
        "video_count": 0,
    }
    row = movie_dao.add(db, data)
    return _movie_to_dict(row)


def delete_movie(db: Session, movie_id: str) -> bool:
    return movie_dao.delete(db, movie_id)


def update_movie(db: Session, movie_id: str, bo: MovieUpdateBO) -> Optional[dict]:
    update_data = bo.model_dump(exclude_unset=True)
    if not update_data:
        return _movie_to_dict(movie_dao.get_by_id(db, movie_id))
    update_data["update_time"] = _now()
    row = movie_dao.update(db, movie_id, update_data)
    if not row:
        return None
    return _movie_to_dict(row)


def get_movie(db: Session, movie_id: str) -> Optional[dict]:
    row = movie_dao.get_by_id(db, movie_id)
    if not row:
        return None
    d = _movie_to_dict(row)
    # 实时更新 video_count
    videos = video_dao.get_by_movie_id(db, movie_id)
    d["video_count"] = len(videos)
    return d


def page_movie(
    db: Session,
    current_page: int = 1,
    page_size: int = 10,
    keyword: Optional[str] = None,
) -> dict:
    items, total = movie_dao.page_query(db, current_page, page_size, keyword)
    return {
        "items": [_movie_to_dict(item) for item in items],
        "total": total,
        "current_page": current_page,
        "page_size": page_size,
    }
