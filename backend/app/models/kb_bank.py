from sqlalchemy import Column, String

from app.database import Base


class KbBank(Base):
    __tablename__ = "kb_bank"

    # 基础字段
    id = Column(String(64), primary_key=True, comment="雪花ID")
    create_time = Column(String(32), nullable=False, comment="创建时间")
    update_time = Column(String(32), nullable=False, comment="更新时间")

    # 业务字段
    name = Column(String(128), nullable=False, comment="题库名称")

    # 关联字段 - 父题库ID，纯逻辑关联（数据库无FK约束）
    parent_id = Column(String(64), nullable=True, comment="父题库ID")
