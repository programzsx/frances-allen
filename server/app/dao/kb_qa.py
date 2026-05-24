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
        image_url=data.get("image_url"),
        total=data.get("total", 0),
        right=data.get("right", 0),
        wrong=data.get("wrong", 0),
        random_int=_next_random_int(db),
        category_id=data.get("category_id"),
        tag_id=json.dumps(data["tag_id"], ensure_ascii=False) if data.get("tag_id") else None,
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
            elif key == "tag_id" and isinstance(value, (list, dict)):
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
) -> tuple[list[KbQa], int]:
    query = db.query(KbQa)
    if category_id:
        query = query.filter(KbQa.category_id == category_id)
    if keyword:
        query = query.filter(KbQa.question.like(f"%{keyword}%"))
    if tag_id:
        query = query.filter(KbQa.tag_id.like(f'%"{tag_id}"%'))
    total = query.count()
    items = (
        query.order_by(KbQa.update_time.desc())
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
    """按 random_int 顺序取题，offset_id 用于跳过已答题目"""
    query = db.query(KbQa)
    if category_id:
        query = query.filter(KbQa.category_id == category_id)
    if offset_id is not None:
        query = query.filter(KbQa.random_int > offset_id)
    return query.order_by(KbQa.random_int.asc()).limit(limit).all()


def wrong_query(
    db: Session, limit: int = 10, category_id: Optional[str] = None, min_wrong: int = 1
) -> list[KbQa]:
    """按错题筛选，min_wrong 为最小错误次数"""
    query = db.query(KbQa).filter(KbQa.wrong >= min_wrong)
    if category_id:
        query = query.filter(KbQa.category_id == category_id)
    return query.order_by(KbQa.wrong.desc()).limit(limit).all()


def count_by_tag(db: Session) -> dict[str, int]:
    """统计每个标签关联的题目数量"""
    rows = db.query(KbQa.tag_id).all()
    tag_counts: dict[str, int] = {}
    for row in rows:
        if row.tag_id:
            try:
                tag_ids = json.loads(row.tag_id)
                for tid in tag_ids:
                    tag_counts[tid] = tag_counts.get(tid, 0) + 1
            except (json.JSONDecodeError, TypeError):
                pass
    return tag_counts
