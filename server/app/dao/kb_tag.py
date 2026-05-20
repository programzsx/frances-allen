from typing import Optional

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.kb_tag import KbTag
from app.utils.snowflake import snowflake


def add(db: Session, data: dict) -> KbTag:
    row = KbTag(
        id=snowflake.generate_id(),
        create_time=data["create_time"],
        update_time=data["update_time"],
        name=data["name"],
    )
    db.add(row)
    db.flush()
    return row


def delete(db: Session, tag_id: str) -> bool:
    row = db.query(KbTag).filter(KbTag.id == tag_id).first()
    if not row:
        return False
    db.delete(row)
    db.flush()
    return True


def update(db: Session, tag_id: str, data: dict) -> Optional[KbTag]:
    row = db.query(KbTag).filter(KbTag.id == tag_id).first()
    if not row:
        return None
    for key, value in data.items():
        if value is not None:
            setattr(row, key, value)
    db.flush()
    return row


def get_by_id(db: Session, tag_id: str) -> Optional[KbTag]:
    return db.query(KbTag).filter(KbTag.id == tag_id).first()


def get_by_name(db: Session, name: str) -> Optional[KbTag]:
    return db.query(KbTag).filter(KbTag.name == name).first()


def count(db: Session, keyword: Optional[str] = None) -> int:
    query = db.query(func.count(KbTag.id))
    if keyword:
        query = query.filter(KbTag.name.like(f"%{keyword}%"))
    return query.scalar()


def page_query(
    db: Session,
    current_page: int = 1,
    page_size: int = 10,
    keyword: Optional[str] = None,
) -> tuple[list[KbTag], int]:
    query = db.query(KbTag)
    if keyword:
        query = query.filter(KbTag.name.like(f"%{keyword}%"))
    total = query.count()
    items = (
        query.order_by(KbTag.create_time.desc())
        .offset((current_page - 1) * page_size)
        .limit(page_size)
        .all()
    )
    return items, total


def get_by_ids(db: Session, tag_ids: list[str]) -> list[KbTag]:
    return db.query(KbTag).filter(KbTag.id.in_(tag_ids)).all()
