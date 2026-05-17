from typing import Optional
from pydantic import BaseModel, Field


class VideoCreateBO(BaseModel):
    movie_id: str = Field(..., description="所属电影ID")
    name: str = Field(..., description="剧集/视频名称")
    description: Optional[str] = Field(None, description="简介")
    cover_url: Optional[str] = Field(None, max_length=512, description="封面URL")
    duration: Optional[int] = Field(0, ge=0, description="时长(秒)")
    sort_order: Optional[int] = Field(0, description="排序序号")


class VideoUpdateBO(BaseModel):
    name: Optional[str] = Field(None, description="剧集/视频名称")
    description: Optional[str] = Field(None, description="简介")
    cover_url: Optional[str] = Field(None, max_length=512, description="封面URL")
    duration: Optional[int] = Field(None, ge=0, description="时长(秒)")
    slice_count: Optional[int] = Field(None, ge=0, description="切片数量")
    sort_order: Optional[int] = Field(None, description="排序序号")
    status: Optional[int] = Field(None, description="状态: 0下架 1上架")


class VideoVO(BaseModel):
    id: str
    create_time: str
    update_time: str
    movie_id: str
    name: str
    description: Optional[str] = None
    cover_url: Optional[str] = None
    duration: int = 0
    slice_count: int = 0
    sort_order: int = 0
    status: int = 1

    model_config = {"from_attributes": True}
