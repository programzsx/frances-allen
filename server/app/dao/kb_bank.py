from typing import Optional

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.kb_bank import KbBank
from app.utils.snowflake import snowflake


def add(db: Session, data: dict) -> KbBank:
    row = KbBank(
        id=snowflake.generate_id(),
        create_time=data["create_time"],
        update_time=data["update_time"],
        name=data["name"],
        parent_id=data.get("parent_id"),
        sort_order=data.get("sort_order", 0),
    )
    db.add(row)
    db.flush()
    return row


def delete(db: Session, bank_id: str) -> bool:
    row = db.query(KbBank).filter(KbBank.id == bank_id).first()
    if not row:
        return False
    db.delete(row)
    db.flush()
    return True


def update(db: Session, bank_id: str, data: dict) -> Optional[KbBank]:
    row = db.query(KbBank).filter(KbBank.id == bank_id).first()
    if not row:
        return None
    for key, value in data.items():
        if value is not None:
            setattr(row, key, value)
    db.flush()
    return row


def get_by_id(db: Session, bank_id: str) -> Optional[KbBank]:
    return db.query(KbBank).filter(KbBank.id == bank_id).first()


def get_by_name(db: Session, name: str) -> Optional[KbBank]:
    return db.query(KbBank).filter(KbBank.name == name).first()


def count(db: Session, keyword: Optional[str] = None) -> int:
    query = db.query(func.count(KbBank.id))
    if keyword:
        query = query.filter(KbBank.name.like(f"%{keyword}%"))
    return query.scalar()


def page_query(
    db: Session,
    current_page: int = 1,
    page_size: int = 10,
    keyword: Optional[str] = None,
) -> tuple[list[KbBank], int]:
    query = db.query(KbBank)
    if keyword:
        query = query.filter(KbBank.name.like(f"%{keyword}%"))
    total = query.count()
    items = (
        query.order_by(KbBank.create_time.desc())
        .offset((current_page - 1) * page_size)
        .limit(page_size)
        .all()
    )
    return items, total


def get_all(db: Session) -> list[KbBank]:
    return db.query(KbBank).order_by(KbBank.create_time.desc()).all()


def has_qas(db: Session, bank_id: str) -> bool:
    from app.models.kb_qa import KbQa
    return db.query(KbQa).filter(KbQa.category_id == bank_id).first() is not None


def question_counts(db: Session) -> dict[str, int]:
    """批量统计每个题库的直接题目数量"""
    from app.models.kb_qa import KbQa
    from sqlalchemy import func
    rows = (
        db.query(KbQa.category_id, func.count(KbQa.id))
        .group_by(KbQa.category_id)
        .all()
    )
    return {row[0]: row[1] for row in rows if row[0] is not None}


def descendant_counts(db: Session) -> dict[str, int]:
    """每个题库含所有后代的总题数（递归聚合）"""
    direct = question_counts(db)
    banks = get_all(db)

    # 构建 parent_id → children 映射
    children_map: dict[str, list[str]] = {}
    for b in banks:
        pid = b.parent_id
        children_map.setdefault(pid, []).append(b.id)

    def aggregate(bank_id: str) -> int:
        total = direct.get(bank_id, 0)
        for child_id in children_map.get(bank_id, []):
            total += aggregate(child_id)
        return total

    return {b.id: aggregate(b.id) for b in banks}
