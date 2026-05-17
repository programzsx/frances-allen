from typing import Optional
from pydantic import BaseModel, Field


class MovieCreateBO(BaseModel):
    name: str = Field(..., description="电影名称")
    description: Optional[str] = Field(None, description="简介")
    cover_url: Optional[str] = Field(None, max_length=512, description="封面URL")
    sort_order: int = Field(0, ge=0, description="排序序号")


class MovieUpdateBO(BaseModel):
    name: Optional[str] = Field(None, description="电影名称")
    description: Optional[str] = Field(None, description="简介")
    cover_url: Optional[str] = Field(None, max_length=512, description="封面URL")
    sort_order: Optional[int] = Field(None, ge=0, description="排序序号")


class MovieVO(BaseModel):
    id: str
    create_time: str
    update_time: str
    name: str
    description: Optional[str] = None
    cover_url: Optional[str] = None
    sort_order: int = 0
    video_count: int = 0

    model_config = {"from_attributes": True}
