from typing import Optional

from sqlalchemy.orm import Session

from app.dao import kb_tag as tag_dao
from app.schemas.kb_tag import TagCreateBO, TagUpdateBO


def create_tag(db: Session, bo: TagCreateBO) -> dict:
    # 校验名称唯一性
    if tag_dao.get_by_name(db, bo.name):
        raise ValueError(f"标签「{bo.name}」已存在")
    now = _now()
    data = {
        "create_time": now,
        "update_time": now,
        "name": bo.name,
    }
    row = tag_dao.add(db, data)
    return _tag_to_dict(row)


def delete_tag(db: Session, tag_id: str) -> bool:
    return tag_dao.delete(db, tag_id)


def update_tag(db: Session, tag_id: str, bo: TagUpdateBO) -> Optional[dict]:
    update_data = bo.model_dump(exclude_unset=True)
    now = _now()
    update_data["update_time"] = now

    # 校验名称唯一性（排除自身）
    if "name" in update_data and update_data["name"]:
        existing = tag_dao.get_by_name(db, update_data["name"])
        if existing and existing.id != tag_id:
            raise ValueError(f"标签「{update_data['name']}」已存在")

    row = tag_dao.update(db, tag_id, update_data)
    if not row:
        return None
    return _tag_to_dict(row)


def get_tag(db: Session, tag_id: str) -> Optional[dict]:
    row = tag_dao.get_by_id(db, tag_id)
    if not row:
        return None
    return _tag_to_dict(row)


def page_tag(
    db: Session,
    current_page: int = 1,
    page_size: int = 10,
    keyword: Optional[str] = None,
) -> dict:
    items, total = tag_dao.page_query(db, current_page, page_size, keyword)
    return {
        "items": [_tag_to_dict(item) for item in items],
        "total": total,
        "current_page": current_page,
        "page_size": page_size,
    }


def get_tags_batch(db: Session, ids: list[str]) -> list[dict]:
    tags = tag_dao.get_by_ids(db, ids)
    return [_tag_to_dict(tag) for tag in tags]


def _tag_to_dict(row) -> dict:
    return {c.name: getattr(row, c.name) for c in row.__table__.columns}


def _now() -> str:
    from datetime import datetime, timezone
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
