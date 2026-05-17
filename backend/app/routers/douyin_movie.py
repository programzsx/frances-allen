from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.douyin_movie import MovieCreateBO, MovieUpdateBO
from app.services import douyin_movie as movie_service

router = APIRouter(prefix="/api/movies", tags=["电影管理"])


@router.post("", summary="创建电影")
def create_movie(bo: MovieCreateBO, db: Session = Depends(get_db)):
    data = movie_service.create_movie(db, bo)
    db.commit()
    return {"success": True, "data": data}


@router.delete("/{movie_id}", summary="删除电影")
def delete_movie(movie_id: str, db: Session = Depends(get_db)):
    ok = movie_service.delete_movie(db, movie_id)
    db.commit()
    return {"success": ok}


@router.put("/{movie_id}", summary="更新电影")
def update_movie(movie_id: str, bo: MovieUpdateBO, db: Session = Depends(get_db)):
    result = movie_service.update_movie(db, movie_id, bo)
    db.commit()
    return {"success": result is not None, "data": result}


@router.get("/{movie_id}", summary="获取电影详情")
def get_movie(movie_id: str, db: Session = Depends(get_db)):
    result = movie_service.get_movie(db, movie_id)
    if not result:
        return {"success": False, "error": "电影不存在"}
    return {"success": True, "data": result}


@router.get("", summary="分页获取电影列表")
def page_movies(
    current_page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    keyword: str = Query(None, description="搜索关键词"),
    db: Session = Depends(get_db),
):
    return movie_service.page_movie(db, current_page, page_size, keyword)
