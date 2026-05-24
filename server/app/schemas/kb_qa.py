from typing import Optional
from pydantic import BaseModel, Field


# ============ BO（业务输入）===========

class QaCreateBO(BaseModel):
    question: str = Field(..., description="问题题目，___表示填空")
    answer: list[str] = Field(..., description="答案列表")
    image_url: Optional[str] = Field(None, max_length=512, description="图片OSS URL")
    category_id: Optional[str] = Field(None, description="所属题库ID")
    tag_id: Optional[list[str]] = Field(None, description="标签ID列表")


class QaUpdateBO(BaseModel):
    question: Optional[str] = Field(None, description="问题题目")
    answer: Optional[list[str]] = Field(None, description="答案列表")
    image_url: Optional[str] = Field(None, max_length=512, description="图片OSS URL")
    category_id: Optional[str] = Field(None, description="所属题库ID")
    tag_id: Optional[list[str]] = Field(None, description="标签ID列表")
    total: Optional[int] = Field(None, ge=0, description="总答题次数")
    right: Optional[int] = Field(None, ge=0, description="答对次数")
    wrong: Optional[int] = Field(None, ge=0, description="答错次数")


# ============ VO（视图输出）===========

class QaVO(BaseModel):
    id: str
    create_time: str
    update_time: str
    question: str
    answer: list[str]
    image_url: Optional[str] = None
    total: int = 0
    right: int = 0
    wrong: int = 0
    category_id: Optional[str] = None
    tag_id: Optional[list[str]] = None

    model_config = {"from_attributes": True}


# ============ 通用分页 ============

class PageRequest(BaseModel):
    current_page: int = Field(1, ge=1, description="当前页码")
    page_size: int = Field(10, ge=1, le=100, description="每页条数")


class PageResponse(BaseModel):
    items: list
    total: int
    current_page: int
    page_size: int
