from typing import Optional
from pydantic import BaseModel, Field


# ============ BO（业务输入）===========

class BankCreateBO(BaseModel):
    name: str = Field(..., max_length=128, description="题库名称")
    parent_id: Optional[str] = Field(None, description="父题库ID")


class BankUpdateBO(BaseModel):
    name: Optional[str] = Field(None, max_length=128, description="题库名称")
    parent_id: Optional[str] = Field(None, description="父题库ID")


# ============ VO（视图输出）===========

class BankVO(BaseModel):
    id: str
    create_time: str
    update_time: str
    name: str
    parent_id: Optional[str] = None

    model_config = {"from_attributes": True}


class BankTreeVO(BaseModel):
    id: str
    name: str
    parent_id: Optional[str] = None
    children: list["BankTreeVO"] = []

    model_config = {"from_attributes": True}
