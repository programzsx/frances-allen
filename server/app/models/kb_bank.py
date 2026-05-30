from sqlalchemy import Column, String, Integer, Text

from app.database import Base


class KbBank(Base):
    __tablename__ = "kb_category"

    # 基础字段
    id = Column(String(64), primary_key=True, comment="雪花ID")
    create_time = Column(String(32), nullable=False, comment="创建时间")
    update_time = Column(String(32), nullable=False, comment="更新时间")

    # 业务字段
    name = Column(String(128), nullable=False, comment="分类名称")
    description = Column(Text, nullable=True, comment="分类描述")

    # 统计字段
    sort_order = Column(Integer, nullable=False, default=0, comment="排序值")
    random_int = Column(Integer, nullable=False, unique=True, comment="随机值自增")
    count = Column(Integer, nullable=False, default=0, comment="问答条目数")

    # 关联字段
    parent_id = Column(String(64), nullable=True, comment="父分类ID")
