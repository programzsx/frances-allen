from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.douyin_slice import SliceCreateBO, SliceUpdateBO
from app.services import douyin_slice as slice_service

router = APIRouter(prefix="/api/slices", tags=["切片管理"])


@router.post("", summary="创建切片")
def create_slice(bo: SliceCreateBO, db: Session = Depends(get_db)):
    data = slice_service.create_slice(db, bo)
    db.commit()
    return {"success": True, "data": data}


@router.delete("/{slice_id}", summary="删除切片")
def delete_slice(slice_id: str, db: Session = Depends(get_db)):
    ok = slice_service.delete_slice(db, slice_id)
    db.commit()
    return {"success": ok}


@router.put("/{slice_id}", summary="更新切片")
def update_slice(slice_id: str, bo: SliceUpdateBO, db: Session = Depends(get_db)):
    result = slice_service.update_slice(db, slice_id, bo)
    db.commit()
    return {"success": result is not None, "data": result}


@router.get("/{slice_id}", summary="获取切片详情")
def get_slice(slice_id: str, db: Session = Depends(get_db)):
    result = slice_service.get_slice(db, slice_id)
    if not result:
        return {"success": False, "error": "切片不存在"}
    return {"success": True, "data": result}


@router.get("", summary="分页获取切片列表")
def page_slices(
    current_page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    video_id: str = Query(None, description="所属视频ID"),
    movie_id: str = Query(None, description="所属电影ID"),
    db: Session = Depends(get_db),
):
    return slice_service.page_slice(db, current_page, page_size, video_id, movie_id)


@router.get("/by-video/{video_id}", summary="获取视频下的所有切片")
def get_slices_by_video(video_id: str, db: Session = Depends(get_db)):
    return {"success": True, "data": slice_service.get_slices_by_video(db, video_id)}


@router.get("/random/list", summary="随机播放切片")
def random_slices(
    limit: int = Query(50, ge=1, le=200),
    movie_id: str = Query(None, description="所属电影ID"),
    video_id: str = Query(None, description="所属视频ID"),
    db: Session = Depends(get_db),
):
    return slice_service.random_slices(db, limit, movie_id, video_id)


@router.get("/sequential/list", summary="顺序播放切片")
def sequential_slices(
    limit: int = Query(50, ge=1, le=200),
    movie_id: str = Query(None, description="所属电影ID"),
    video_id: str = Query(None, description="所属视频ID"),
    offset_id: int = Query(None, description="跳过已观看的排序序号"),
    db: Session = Depends(get_db),
):
    return slice_service.sequential_slices(db, limit, movie_id, video_id, offset_id)


@router.get("/fav/list", summary="收藏的切片")
def fav_slices(
    limit: int = Query(50, ge=1, le=200),
    movie_id: str = Query(None, description="所属电影ID"),
    db: Session = Depends(get_db),
):
    return slice_service.fav_slices(db, limit, movie_id)
