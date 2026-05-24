from sqlalchemy import Column, String, Integer, Text

from app.database import Base


class KbQa(Base):
    __tablename__ = "kb_qa"

    # 基础字段
    id = Column(String(64), primary_key=True, comment="雪花ID")
    create_time = Column(String(32), nullable=False, comment="创建时间")
    update_time = Column(String(32), nullable=False, comment="更新时间")

    # 业务字段
    question = Column(Text, nullable=False, comment="问题")
    answer = Column(Text, nullable=False, comment="答案")

    # 统计字段
    sort_order = Column(Integer, nullable=False, default=0, comment="排序值")
    random_int = Column(Integer, nullable=False, unique=True, comment="随机值自增")
    score = Column(Integer, nullable=False, default=0, comment="掌握程度 -1/0/1")

    # 关联字段
    category_id = Column(String(64), nullable=False, comment="所属知识分类ID")
    tag_id = Column(String(64), nullable=True, comment="标签ID")
