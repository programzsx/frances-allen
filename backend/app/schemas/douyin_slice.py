from typing import Optional
from pydantic import BaseModel, Field


class SliceCreateBO(BaseModel):
    video_id: str = Field(..., description="所属视频ID")
    movie_id: str = Field(..., description="所属电影ID")
    oss_url: str = Field(..., max_length=512, description="视频URL")
    name: Optional[str] = Field(None, max_length=256, description="切片名称")
    comment: Optional[str] = Field(None, description="备注/评论")
    sort_order: Optional[int] = Field(0, description="排序序号")


class SliceUpdateBO(BaseModel):
    name: Optional[str] = Field(None, max_length=256, description="切片名称")
    comment: Optional[str] = Field(None, description="备注/评论")
    sort_order: Optional[int] = Field(None, description="排序序号")
    is_fav: Optional[int] = Field(None, description="是否收藏: 0否 1是")
    status: Optional[int] = Field(None, description="状态")


class SliceVO(BaseModel):
    id: str
    create_time: str
    update_time: str
    video_id: str
    movie_id: str
    name: Optional[str] = None
    comment: Optional[str] = None
    oss_url: str
    sort_order: int = 0
    is_fav: bool = False
    watch_count: int = 0

    model_config = {"from_attributes": True}
