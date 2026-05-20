from sqlalchemy import Column, String, Text

from app.database import Base


class KbTag(Base):
    __tablename__ = "kb_tag"

    # 基础字段
    id = Column(String(64), primary_key=True, comment="雪花ID")
    create_time = Column(String(32), nullable=False, comment="创建时间")
    update_time = Column(String(32), nullable=False, comment="更新时间")

    # 业务字段
    name = Column(String(128), nullable=False, comment="标签名称")
