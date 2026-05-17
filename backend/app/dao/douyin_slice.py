from typing import Optional

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.douyin_slice import DouyinSlice
from app.utils.snowflake import snowflake


def _next_random_int(db: Session) -> int:
    max_val = db.query(func.max(DouyinSlice.random_int)).scalar()
    return (max_val or 0) + 1


def add(db: Session, data: dict) -> DouyinSlice:
    row = DouyinSlice(
        id=snowflake.generate_id(),
        create_time=data["create_time"],
        update_time=data["update_time"],
        video_id=data["video_id"],
        movie_id=data["movie_id"],
        name=data.get("name"),
        comment=data.get("comment"),
        oss_url=data["oss_url"],
        sort_order=data.get("sort_order", 0),
        is_fav=data.get("is_fav", 0),
        random_int=_next_random_int(db),
    )
    db.add(row)
    db.flush()
    return row


def delete(db: Session, slice_id: str) -> bool:
    row = db.query(DouyinSlice).filter(DouyinSlice.id == slice_id).first()
    if not row:
        return False
    db.delete(row)
    db.flush()
    return True


def update(db: Session, slice_id: str, data: dict) -> Optional[DouyinSlice]:
    row = db.query(DouyinSlice).filter(DouyinSlice.id == slice_id).first()
    if not row:
        return None
    for key, value in data.items():
        if value is not None:
            setattr(row, key, value)
    db.flush()
    return row


def get_by_id(db: Session, slice_id: str) -> Optional[DouyinSlice]:
    return db.query(DouyinSlice).filter(DouyinSlice.id == slice_id).first()


def get_by_video_id(db: Session, video_id: str) -> list[DouyinSlice]:
    return (
        db.query(DouyinSlice)
        .filter(DouyinSlice.video_id == video_id)
        .order_by(DouyinSlice.sort_order.asc())
        .all()
    )


def page_query(
    db: Session,
    current_page: int = 1,
    page_size: int = 10,
    video_id: Optional[str] = None,
    movie_id: Optional[str] = None,
) -> tuple[list[DouyinSlice], int]:
    query = db.query(DouyinSlice)
    if video_id:
        query = query.filter(DouyinSlice.video_id == video_id)
    if movie_id:
        query = query.filter(DouyinSlice.movie_id == movie_id)
    total = query.count()
    items = (
        query.order_by(DouyinSlice.sort_order.asc())
        .offset((current_page - 1) * page_size)
        .limit(page_size)
        .all()
    )
    return items, total


def random_query(
    db: Session,
    limit: int = 10,
    movie_id: Optional[str] = None,
    video_id: Optional[str] = None,
) -> list[DouyinSlice]:
    query = db.query(DouyinSlice)
    if movie_id:
        query = query.filter(DouyinSlice.movie_id == movie_id)
    if video_id:
        query = query.filter(DouyinSlice.video_id == video_id)
    return query.order_by(func.rand()).limit(limit).all()


def sequential_query(
    db: Session,
    limit: int = 10,
    movie_id: Optional[str] = None,
    video_id: Optional[str] = None,
    offset_id: Optional[int] = None,
) -> list[DouyinSlice]:
    """按 sort_order 顺序取切片，offset_id 用于跳过已观看的"""
    query = db.query(DouyinSlice)
    if movie_id:
        query = query.filter(DouyinSlice.movie_id == movie_id)
    if video_id:
        query = query.filter(DouyinSlice.video_id == video_id)
    if offset_id is not None:
        query = query.filter(DouyinSlice.sort_order > offset_id)
    return query.order_by(DouyinSlice.sort_order.asc()).limit(limit).all()


def fav_query(
    db: Session,
    limit: int = 50,
    movie_id: Optional[str] = None,
) -> list[DouyinSlice]:
    query = db.query(DouyinSlice).filter(DouyinSlice.is_fav == 1)
    if movie_id:
        query = query.filter(DouyinSlice.movie_id == movie_id)
    return query.order_by(DouyinSlice.update_time.desc()).limit(limit).all()


def count_by_video_id(db: Session, video_id: str) -> int:
    return db.query(func.count(DouyinSlice.id)).filter(
        DouyinSlice.video_id == video_id
    ).scalar()
