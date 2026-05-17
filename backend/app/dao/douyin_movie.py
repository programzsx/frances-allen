from typing import Optional

from sqlalchemy.orm import Session

from app.models.douyin_movie import DouyinMovie
from app.utils.snowflake import snowflake


def add(db: Session, data: dict) -> DouyinMovie:
    row = DouyinMovie(
        id=snowflake.generate_id(),
        create_time=data["create_time"],
        update_time=data["update_time"],
        name=data["name"],
        description=data.get("description"),
        cover_url=data.get("cover_url"),
        sort_order=data.get("sort_order", 0),
        video_count=data.get("video_count", 0),
    )
    db.add(row)
    db.flush()
    return row


def delete(db: Session, movie_id: str) -> bool:
    row = db.query(DouyinMovie).filter(DouyinMovie.id == movie_id).first()
    if not row:
        return False
    db.delete(row)
    db.flush()
    return True


def update(db: Session, movie_id: str, data: dict) -> Optional[DouyinMovie]:
    row = db.query(DouyinMovie).filter(DouyinMovie.id == movie_id).first()
    if not row:
        return None
    for key, value in data.items():
        if value is not None:
            setattr(row, key, value)
    db.flush()
    return row


def get_by_id(db: Session, movie_id: str) -> Optional[DouyinMovie]:
    return db.query(DouyinMovie).filter(DouyinMovie.id == movie_id).first()


def page_query(
    db: Session,
    current_page: int = 1,
    page_size: int = 10,
    keyword: Optional[str] = None,
) -> tuple[list[DouyinMovie], int]:
    query = db.query(DouyinMovie)
    if keyword:
        query = query.filter(DouyinMovie.name.like(f"%{keyword}%"))
    total = query.count()
    items = (
        query.order_by(DouyinMovie.sort_order.asc(), DouyinMovie.update_time.desc())
        .offset((current_page - 1) * page_size)
        .limit(page_size)
        .all()
    )
    return items, total
