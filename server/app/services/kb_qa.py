import json
from typing import Optional

from sqlalchemy.orm import Session

from app.dao import kb_qa as qa_dao
from app.dao import kb_bank as bank_dao
from app.schemas.kb_qa import QaCreateBO, QaUpdateBO


def _qa_to_dict(row) -> dict:
    d = {c.name: getattr(row, c.name) for c in row.__table__.columns}
    if d.get("answer"):
        d["answer"] = json.loads(d["answer"])
    return d


def create_qa(db: Session, bo: QaCreateBO) -> dict:
    if qa_dao.get_by_question(db, bo.question):
        raise ValueError(f"题目已存在")
    # 校验 category_id 存在
    bank = bank_dao.get_by_id(db, bo.category_id)
    if not bank:
        raise ValueError(f"知识分类 {bo.category_id} 不存在")

    now = _now()
    data = {
        "create_time": now,
        "update_time": now,
        "question": bo.question,
        "answer": bo.answer,
        "sort_order": bo.sort_order,
        "score": bo.score,
        "category_id": bo.category_id,
        "tag_id": bo.tag_id,
    }
    row = qa_dao.add(db, data)
    return _qa_to_dict(row)


def delete_qa(db: Session, qa_id: str) -> bool:
    return qa_dao.delete(db, qa_id)


def update_qa(db: Session, qa_id: str, bo: QaUpdateBO) -> Optional[dict]:
    if bo.category_id is not None:
        bank = bank_dao.get_by_id(db, bo.category_id)
        if not bank:
            raise ValueError(f"知识分类 {bo.category_id} 不存在")

    update_data = bo.model_dump(exclude_unset=True)
    update_data["update_time"] = _now()

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
    category_id: Optional[str] = None,
    keyword: Optional[str] = None,
    tag_id: Optional[str] = None,
    score: Optional[int] = None,
) -> dict:
    items, total = qa_dao.page_query(db, current_page, page_size, category_id, keyword, tag_id, score)
    return {
        "items": [_qa_to_dict(item) for item in items],
        "total": total,
        "current_page": current_page,
        "page_size": page_size,
    }


def random_qa(db: Session, limit: int = 10, category_id: Optional[str] = None) -> list[dict]:
    items = qa_dao.random_query(db, limit, category_id)
    return [_qa_to_dict(item) for item in items]


def sequential_qa(
    db: Session, limit: int = 10, category_id: Optional[str] = None, offset_id: Optional[int] = None
) -> list[dict]:
    items = qa_dao.sequential_query(db, limit, category_id, offset_id)
    return [_qa_to_dict(item) for item in items]


def wrong_qa(
    db: Session, limit: int = 10, category_id: Optional[str] = None, min_score: int = 0
) -> list[dict]:
    items = qa_dao.wrong_query(db, limit, category_id, min_score)
    return [_qa_to_dict(item) for item in items]


def _now() -> str:
    from datetime import datetime, timezone
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
