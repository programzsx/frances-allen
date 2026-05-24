import json
from typing import Optional

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.kb_qa import KbQa
from app.utils.snowflake import snowflake


def _next_random_int(db: Session) -> int:
    max_val = db.query(func.max(KbQa.random_int)).scalar()
    return (max_val or 0) + 1


def add(db: Session, data: dict) -> KbQa:
    row = KbQa(
        id=snowflake.generate_id(),
        create_time=data["create_time"],
        update_time=data["update_time"],
        question=data["question"],
        answer=json.dumps(data["answer"], ensure_ascii=False),
        sort_order=data.get("sort_order", 0),
        random_int=_next_random_int(db),
        score=data.get("score", 0),
        category_id=data["category_id"],
        tag_id=data.get("tag_id"),
    )
    db.add(row)
    db.flush()
    return row


def delete(db: Session, qa_id: str) -> bool:
    row = db.query(KbQa).filter(KbQa.id == qa_id).first()
    if not row:
        return False
    db.delete(row)
    db.flush()
    return True


def update(db: Session, qa_id: str, data: dict) -> Optional[KbQa]:
    row = db.query(KbQa).filter(KbQa.id == qa_id).first()
    if not row:
        return None
    for key, value in data.items():
        if value is not None:
            if key == "answer" and isinstance(value, (list, dict)):
                value = json.dumps(value, ensure_ascii=False)
            setattr(row, key, value)
    db.flush()
    return row


def get_by_id(db: Session, qa_id: str) -> Optional[KbQa]:
    return db.query(KbQa).filter(KbQa.id == qa_id).first()


def get_by_question(db: Session, question: str) -> Optional[KbQa]:
    return db.query(KbQa).filter(KbQa.question == question).first()


def count(db: Session, category_id: Optional[str] = None, keyword: Optional[str] = None) -> int:
    query = db.query(func.count(KbQa.id))
    if category_id:
        query = query.filter(KbQa.category_id == category_id)
    if keyword:
        query = query.filter(KbQa.question.like(f"%{keyword}%"))
    return query.scalar()


def page_query(
    db: Session,
    current_page: int = 1,
    page_size: int = 10,
    category_id: Optional[str] = None,
    keyword: Optional[str] = None,
    tag_id: Optional[str] = None,
    score: Optional[int] = None,
) -> tuple[list[KbQa], int]:
    query = db.query(KbQa)
    if category_id:
        query = query.filter(KbQa.category_id == category_id)
    if keyword:
        query = query.filter(KbQa.question.like(f"%{keyword}%"))
    if tag_id:
        query = query.filter(KbQa.tag_id == tag_id)
    if score is not None:
        query = query.filter(KbQa.score == score)
    total = query.count()
    items = (
        query.order_by(KbQa.sort_order.desc(), KbQa.update_time.desc())
        .offset((current_page - 1) * page_size)
        .limit(page_size)
        .all()
    )
    return items, total


def random_query(db: Session, limit: int = 10, category_id: Optional[str] = None) -> list[KbQa]:
    query = db.query(KbQa)
    if category_id:
        query = query.filter(KbQa.category_id == category_id)
    return query.order_by(func.rand()).limit(limit).all()


def sequential_query(
    db: Session, limit: int = 10, category_id: Optional[str] = None, offset_id: Optional[int] = None
) -> list[KbQa]:
    query = db.query(KbQa)
    if category_id:
        query = query.filter(KbQa.category_id == category_id)
    if offset_id is not None:
        query = query.filter(KbQa.random_int > offset_id)
    return query.order_by(KbQa.random_int.asc()).limit(limit).all()


def wrong_query(
    db: Session, limit: int = 10, category_id: Optional[str] = None, min_score: int = -1
) -> list[KbQa]:
    """按掌握程度筛选，score <= min_score 的题目（不会/模糊）"""
    query = db.query(KbQa).filter(KbQa.score <= min_score)
    if category_id:
        query = query.filter(KbQa.category_id == category_id)
    return query.order_by(KbQa.score.asc()).limit(limit).all()
