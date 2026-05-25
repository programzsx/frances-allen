from typing import Optional

from sqlalchemy.orm import Session

from app.dao import kb_bank as bank_dao
from app.schemas.kb_bank import BankCreateBO, BankUpdateBO


def create_bank(db: Session, bo: BankCreateBO) -> dict:
    # 校验名称唯一性
    if bank_dao.get_by_name(db, bo.name):
        raise ValueError(f"题库「{bo.name}」已存在")
    now = _now()
    data = {
        "create_time": now,
        "update_time": now,
        "name": bo.name,
        "parent_id": bo.parent_id,
        "sort_order": bo.sort_order,
    }
    # 校验 parent_id 存在
    if bo.parent_id:
        parent = bank_dao.get_by_id(db, bo.parent_id)
        if not parent:
            raise ValueError(f"父题库 {bo.parent_id} 不存在")

    row = bank_dao.add(db, data)
    return _bank_to_dict(row)


def delete_bank(db: Session, bank_id: str) -> bool:
    if bank_dao.has_qas(db, bank_id):
        raise ValueError(f"题库 {bank_id} 下存在题目，无法删除")
    return bank_dao.delete(db, bank_id)


def update_bank(db: Session, bank_id: str, bo: BankUpdateBO) -> Optional[dict]:
    update_data = bo.model_dump(exclude_unset=True)
    now = _now()
    update_data["update_time"] = now

    # 校验名称唯一性（排除自身）
    if "name" in update_data and update_data["name"]:
        existing = bank_dao.get_by_name(db, update_data["name"])
        if existing and existing.id != bank_id:
            raise ValueError(f"题库「{update_data['name']}」已存在")

    # 校验 parent_id 存在
    if "parent_id" in update_data and update_data["parent_id"]:
        parent = bank_dao.get_by_id(db, update_data["parent_id"])
        if not parent:
            raise ValueError(f"父题库 {update_data['parent_id']} 不存在")

    row = bank_dao.update(db, bank_id, update_data)
    if not row:
        return None
    return _bank_to_dict(row)


def get_bank(db: Session, bank_id: str) -> Optional[dict]:
    row = bank_dao.get_by_id(db, bank_id)
    if not row:
        return None
    return _bank_to_dict(row)


def page_bank(
    db: Session,
    current_page: int = 1,
    page_size: int = 10,
    keyword: Optional[str] = None,
) -> dict:
    items, total = bank_dao.page_query(db, current_page, page_size, keyword)
    return {
        "items": [_bank_to_dict(item) for item in items],
        "total": total,
        "current_page": current_page,
        "page_size": page_size,
    }


def get_bank_tree(db: Session) -> list[dict]:
    all_banks = bank_dao.get_all(db)
    bank_map = {}
    for bank in all_banks:
        d = _bank_to_dict(bank)
        d["children"] = []
        bank_map[d["id"]] = d

    tree = []
    for bank in all_banks:
        d = bank_map[bank.id]
        if d["parent_id"] and d["parent_id"] in bank_map:
            bank_map[d["parent_id"]]["children"].append(d)
        else:
            tree.append(d)
    return tree


def get_question_counts(db: Session) -> dict[str, int]:
    """返回 {bank_id: question_count} 的批量统计（仅直接题目）"""
    return bank_dao.question_counts(db)


def get_descendant_counts(db: Session) -> dict[str, int]:
    """返回 {bank_id: total_question_count} 的批量统计（含所有后代聚合）"""
    return bank_dao.descendant_counts(db)


def _bank_to_dict(row) -> dict:
    return {c.name: getattr(row, c.name) for c in row.__table__.columns}


def _now() -> str:
    from datetime import datetime, timezone
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
