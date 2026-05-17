import json
from typing import Optional

from sqlalchemy.orm import Session

from app.dao import kb_qa as qa_dao
from app.dao import kb_bank as bank_dao
from app.dao import kb_tag as tag_dao
from app.schemas.kb_qa import QaCreateBO, QaUpdateBO


def _qa_to_dict(row) -> dict:
    """将ORM对象转换为带反序列化字段的dict"""
    d = {c.name: getattr(row, c.name) for c in row.__table__.columns}
    if d.get("answer"):
        d["answer"] = json.loads(d["answer"])
    if d.get("tag_id"):
        d["tag_id"] = json.loads(d["tag_id"])
    return d


def create_qa(db: Session, bo: QaCreateBO) -> dict:
    # 校验题目唯一性
    if qa_dao.get_by_question(db, bo.question):
        raise ValueError(f"题目「{bo.question.substring(0, min(20, bo.question.length))}...」已存在")
    now = _now()
    data = {
        "create_time": now,
        "update_time": now,
        "question": bo.question,
        "answer": bo.answer,
        "image_url": bo.image_url,
        "bank_id": bo.bank_id,
        "tag_id": bo.tag_id,
    }
    # 校验 bank_id 存在
    if bo.bank_id:
        bank = bank_dao.get_by_id(db, bo.bank_id)
        if not bank:
            raise ValueError(f"题库 {bo.bank_id} 不存在")
    # 校验 tag_id 存在
    if bo.tag_id:
        tags = tag_dao.get_by_ids(db, bo.tag_id)
        if len(tags) != len(bo.tag_id):
            raise ValueError("部分标签不存在")

    row = qa_dao.add(db, data)
    return _qa_to_dict(row)


def delete_qa(db: Session, qa_id: str) -> bool:
    return qa_dao.delete(db, qa_id)


def update_qa(db: Session, qa_id: str, bo: QaUpdateBO) -> Optional[dict]:
    # 校验 bank_id 存在
    if bo.bank_id is not None:
        bank = bank_dao.get_by_id(db, bo.bank_id)
        if not bank:
            raise ValueError(f"题库 {bo.bank_id} 不存在")
    # 校验 tag_id 存在
    if bo.tag_id is not None:
        tags = tag_dao.get_by_ids(db, bo.tag_id)
        if len(tags) != len(bo.tag_id):
            raise ValueError("部分标签不存在")

    update_data = bo.model_dump(exclude_unset=True)

    # 统计字段约束：强制 total = right + wrong
    stat_fields = {"total", "right", "wrong"}
    if any(k in update_data for k in stat_fields):
        existing = qa_dao.get_by_id(db, qa_id)
        if not existing:
            return None
        right = update_data.get("right", existing.right)
        wrong = update_data.get("wrong", existing.wrong)
        update_data["right"] = right
        update_data["wrong"] = wrong
        update_data["total"] = right + wrong

    now = _now()
    update_data["update_time"] = now

    row = qa_dao.update(db, qa_id, update_data)
    if not row:
        return None
    return _qa_to_dict(row)


def get_qa(db: Session, qa_id: str) -> Optional[dict]:
    row = qa_dao.get_by_id(db, qa_id)
    if not row:
        return None
    return _qa_to_dict(row)


def page_qa(
    db: Session,
    current_page: int = 1,
    page_size: int = 10,
    bank_id: Optional[str] = None,
    keyword: Optional[str] = None,
    tag_id: Optional[str] = None,
) -> dict:
    items, total = qa_dao.page_query(db, current_page, page_size, bank_id, keyword, tag_id)
    return {
        "items": [_qa_to_dict(item) for item in items],
        "total": total,
        "current_page": current_page,
        "page_size": page_size,
    }


def random_qa(db: Session, limit: int = 10, bank_id: Optional[str] = None) -> list[dict]:
    items = qa_dao.random_query(db, limit, bank_id)
    return [_qa_to_dict(item) for item in items]


def sequential_qa(
    db: Session, limit: int = 10, bank_id: Optional[str] = None, offset_id: Optional[int] = None
) -> list[dict]:
    items = qa_dao.sequential_query(db, limit, bank_id, offset_id)
    return [_qa_to_dict(item) for item in items]


def wrong_qa(
    db: Session, limit: int = 10, bank_id: Optional[str] = None, min_wrong: int = 1
) -> list[dict]:
    items = qa_dao.wrong_query(db, limit, bank_id, min_wrong)
    return [_qa_to_dict(item) for item in items]


def tag_counts(db: Session) -> dict[str, int]:
    return qa_dao.count_by_tag(db)


def _now() -> str:
    from datetime import datetime, timezone
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
