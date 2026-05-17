from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.douyin_video import VideoCreateBO, VideoUpdateBO
from app.services import douyin_video as video_service

router = APIRouter(prefix="/api/videos", tags=["视频(剧集)管理"])


@router.post("", summary="创建视频")
def create_video(bo: VideoCreateBO, db: Session = Depends(get_db)):
    data = video_service.create_video(db, bo)
    db.commit()
    return {"success": True, "data": data}


@router.delete("/{video_id}", summary="删除视频")
def delete_video(video_id: str, db: Session = Depends(get_db)):
    ok = video_service.delete_video(db, video_id)
    db.commit()
    return {"success": ok}


@router.put("/{video_id}", summary="更新视频")
def update_video(video_id: str, bo: VideoUpdateBO, db: Session = Depends(get_db)):
    result = video_service.update_video(db, video_id, bo)
    db.commit()
    return {"success": result is not None, "data": result}


@router.get("/{video_id}", summary="获取视频详情")
def get_video(video_id: str, db: Session = Depends(get_db)):
    result = video_service.get_video(db, video_id)
    if not result:
        return {"success": False, "error": "视频不存在"}
    return {"success": True, "data": result}


@router.get("", summary="分页获取视频列表")
def page_videos(
    current_page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    movie_id: str = Query(None, description="所属电影ID"),
    db: Session = Depends(get_db),
):
    return video_service.page_video(db, current_page, page_size, movie_id)


@router.get("/by-movie/{movie_id}", summary="获取电影下的所有视频")
def get_videos_by_movie(movie_id: str, db: Session = Depends(get_db)):
    return {"success": True, "data": video_service.get_videos_by_movie(db, movie_id)}
