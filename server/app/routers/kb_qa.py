from typing import Optional

from fastapi import APIRouter, Depends, Query
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session

from app.database import get_db
from app.services import kb_qa as qa_service
from app.schemas.kb_qa import QaCreateBO, QaUpdateBO

router = APIRouter(prefix="/api/qas", tags=["题目管理"])


# --- Specific routes must come before path parameter routes ---

@router.get("/random/list", summary="随机获取题目（练习模式）")
def random_qa(
    limit: int = Query(10, ge=1, le=100),
    category_id: Optional[str] = Query(None),
    db: Session = Depends(get_db),
):
    return qa_service.random_qa(db, limit, category_id)


@router.get("/sequential/list", summary="顺序获取题目（顺序练习）")
def sequential_qa(
    limit: int = Query(10, ge=1, le=100),
    category_id: Optional[str] = Query(None),
    offset_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
):
    return qa_service.sequential_qa(db, limit, category_id, offset_id)


@router.get("/wrong/list", summary="错题列表（错题练习）")
def wrong_qa(
    limit: int = Query(10, ge=1, le=100),
    category_id: Optional[str] = Query(None),
    min_wrong: int = Query(1, ge=1),
    db: Session = Depends(get_db),
):
    return qa_service.wrong_qa(db, limit, category_id, min_wrong)


@router.get("/tag-counts", summary="统计每个标签关联的题目数量")
def tag_counts(db: Session = Depends(get_db)):
    counts = qa_service.tag_counts(db)
    return JSONResponse(content=counts)


@router.get("", summary="分页查询题目")
def page_qa(
    current_page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    category_id: Optional[str] = Query(None),
    keyword: Optional[str] = Query(None),
    tag_id: Optional[str] = Query(None),
    db: Session = Depends(get_db),
):
    return qa_service.page_qa(db, current_page, page_size, category_id, keyword, tag_id)


@router.post("", summary="新增题目")
def create_qa(bo: QaCreateBO, db: Session = Depends(get_db)):
    data = qa_service.create_qa(db, bo)
    db.commit()
    return data


@router.get("/{qa_id}", summary="获取题目详情")
def get_qa(qa_id: str, db: Session = Depends(get_db)):
    return qa_service.get_qa(db, qa_id)


@router.put("/{qa_id}", summary="更新题目")
def update_qa(qa_id: str, bo: QaUpdateBO, db: Session = Depends(get_db)):
    data = qa_service.update_qa(db, qa_id, bo)
    db.commit()
    return data


@router.delete("/{qa_id}", summary="删除题目")
def delete_qa(qa_id: str, db: Session = Depends(get_db)):
    ok = qa_service.delete_qa(db, qa_id)
    db.commit()
    return {"success": ok}
