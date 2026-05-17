from typing import Optional
from pydantic import BaseModel, Field


# ============ BO（业务输入）===========

class TagCreateBO(BaseModel):
    name: str = Field(..., max_length=128, description="标签名称")


class TagUpdateBO(BaseModel):
    name: Optional[str] = Field(None, max_length=128, description="标签名称")


class TagBatchGetBO(BaseModel):
    ids: list[str] = Field(..., description="标签ID列表")


# ============ VO（视图输出）===========

class TagVO(BaseModel):
    id: str
    create_time: str
    update_time: str
    name: str

    model_config = {"from_attributes": True}
