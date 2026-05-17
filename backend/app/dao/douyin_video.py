from typing import Optional

from sqlalchemy.orm import Session

from app.models.douyin_video import DouyinVideo
from app.utils.snowflake import snowflake


def add(db: Session, data: dict) -> DouyinVideo:
    row = DouyinVideo(
        id=snowflake.generate_id(),
        create_time=data["create_time"],
        update_time=data["update_time"],
        movie_id=data["movie_id"],
        name=data["name"],
        description=data.get("description"),
        cover_url=data.get("cover_url"),
        duration=data.get("duration", 0),
        slice_count=data.get("slice_count", 0),
        sort_order=data.get("sort_order", 0),
        status=data.get("status", 1),
    )
    db.add(row)
    db.flush()
    return row


def delete(db: Session, video_id: str) -> bool:
    row = db.query(DouyinVideo).filter(DouyinVideo.id == video_id).first()
    if not row:
        return False
    db.delete(row)
    db.flush()
    return True


def update(db: Session, video_id: str, data: dict) -> Optional[DouyinVideo]:
    row = db.query(DouyinVideo).filter(DouyinVideo.id == video_id).first()
    if not row:
        return None
    for key, value in data.items():
        if value is not None:
            setattr(row, key, value)
    db.flush()
    return row


def get_by_id(db: Session, video_id: str) -> Optional[DouyinVideo]:
    return db.query(DouyinVideo).filter(DouyinVideo.id == video_id).first()


def get_by_movie_id(db: Session, movie_id: str) -> list[DouyinVideo]:
    return (
        db.query(DouyinVideo)
        .filter(DouyinVideo.movie_id == movie_id)
        .order_by(DouyinVideo.sort_order.asc())
        .all()
    )


def page_query(
    db: Session,
    current_page: int = 1,
    page_size: int = 10,
    movie_id: Optional[str] = None,
) -> tuple[list[DouyinVideo], int]:
    query = db.query(DouyinVideo)
    if movie_id:
        query = query.filter(DouyinVideo.movie_id == movie_id)
    total = query.count()
    items = (
        query.order_by(DouyinVideo.sort_order.asc())
        .offset((current_page - 1) * page_size)
        .limit(page_size)
        .all()
    )
    return items, total
