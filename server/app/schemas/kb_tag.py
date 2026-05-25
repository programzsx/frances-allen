from typing import Optional
from pydantic import BaseModel, Field


# ============ BO（业务输入）===========

class TagCreateBO(BaseModel):
    name: str = Field(..., max_length=128, description="标签名称")
    sort_order: int = Field(0, description="排序值")


class TagUpdateBO(BaseModel):
    name: Optional[str] = Field(None, max_length=128, description="标签名称")
    sort_order: Optional[int] = Field(None, description="排序值")


class TagBatchGetBO(BaseModel):
    ids: list[str] = Field(..., description="标签ID列表")


# ============ VO（视图输出）===========

class TagVO(BaseModel):
    id: str
    create_time: str
    update_time: str
    name: str
    sort_order: int = 0

    model_config = {"from_attributes": True}
