from typing import Optional, Union
from pydantic import BaseModel, Field, field_validator


# ============ BO（业务输入）============

class QaCreateBO(BaseModel):
    question: str = Field(..., description="问题题目，___表示填空")
    answer: list[str] = Field(..., description="答案列表")
    category_id: Optional[str] = Field(None, description="所属知识分类ID")
    tag_id: Optional[Union[str, list[str]]] = Field(None, description="标签ID")
    sort_order: int = Field(0, description="排序值")
    score: int = Field(0, ge=-1, le=1, description="掌握程度 -1/0/1")


class QaUpdateBO(BaseModel):
    question: Optional[str] = Field(None, description="问题题目")
    answer: Optional[list[str]] = Field(None, description="答案列表")
    category_id: Optional[str] = Field(None, description="所属知识分类ID")
    tag_id: Optional[Union[str, list[str]]] = Field(None, description="标签ID")
    sort_order: Optional[int] = Field(None, description="排序值")
    score: Optional[int] = Field(None, ge=-1, le=1, description="掌握程度 -1/0/1")
    total: Optional[int] = Field(None, ge=0, description="总练习次数")
    right: Optional[int] = Field(None, ge=0, description="答对次数")
    wrong: Optional[int] = Field(None, ge=0, description="答错次数")

    @field_validator("tag_id", mode="before")
    @classmethod
    def coerce_tag_id(cls, v):
        """将列表转为 JSON 字符串存储"""
        if isinstance(v, list):
            import json
            return json.dumps(v, ensure_ascii=False)
        return v


# ============ VO（视图输出）============

class QaVO(BaseModel):
    id: str
    create_time: str
    update_time: str
    question: str
    answer: list[str]
    sort_order: int = 0
    random_int: int = 0
    score: int = 0
    total: int = 0
    right: int = 0
    wrong: int = 0
    category_id: str
    tag_id: Optional[str] = None

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
