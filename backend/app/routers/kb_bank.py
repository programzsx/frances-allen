from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.services import kb_bank as bank_service
from app.schemas.kb_bank import BankCreateBO, BankUpdateBO

router = APIRouter(prefix="/api/banks", tags=["题库管理"])


@router.post("", summary="新增题库")
def create_bank(bo: BankCreateBO, db: Session = Depends(get_db)):
    data = bank_service.create_bank(db, bo)
    db.commit()
    return data


@router.delete("/{bank_id}", summary="删除题库")
def delete_bank(bank_id: str, db: Session = Depends(get_db)):
    ok = bank_service.delete_bank(db, bank_id)
    db.commit()
    return {"success": ok}


@router.put("/{bank_id}", summary="更新题库")
def update_bank(bank_id: str, bo: BankUpdateBO, db: Session = Depends(get_db)):
    data = bank_service.update_bank(db, bank_id, bo)
    db.commit()
    return data


@router.get("", summary="分页查询题库")
def page_bank(
    current_page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    keyword: Optional[str] = Query(None),
    db: Session = Depends(get_db),
):
    return bank_service.page_bank(db, current_page, page_size, keyword)


@router.get("/tree", summary="题库树形结构")
def bank_tree(db: Session = Depends(get_db)):
    return bank_service.get_bank_tree(db)
