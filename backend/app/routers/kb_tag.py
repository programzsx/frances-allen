from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.services import kb_tag as tag_service
from app.schemas.kb_tag import TagCreateBO, TagUpdateBO, TagBatchGetBO

router = APIRouter(prefix="/api/tags", tags=["标签管理"])


@router.post("", summary="新增标签")
def create_tag(bo: TagCreateBO, db: Session = Depends(get_db)):
    data = tag_service.create_tag(db, bo)
    db.commit()
    return data


@router.delete("/{tag_id}", summary="删除标签")
def delete_tag(tag_id: str, db: Session = Depends(get_db)):
    ok = tag_service.delete_tag(db, tag_id)
    db.commit()
    return {"success": ok}


@router.put("/{tag_id}", summary="更新标签")
def update_tag(tag_id: str, bo: TagUpdateBO, db: Session = Depends(get_db)):
    data = tag_service.update_tag(db, tag_id, bo)
    db.commit()
    return data


@router.get("", summary="分页查询标签")
def page_tag(
    current_page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    keyword: Optional[str] = Query(None),
    db: Session = Depends(get_db),
):
    return tag_service.page_tag(db, current_page, page_size, keyword)


@router.post("/batch", summary="批量查询标签")
def get_tags_batch(
    bo: TagBatchGetBO,
    db: Session = Depends(get_db),
):
    return tag_service.get_tags_batch(db, bo.ids)
