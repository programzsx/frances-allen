from sqlalchemy import Column, String, Integer, Text

from app.database import Base


class KbQa(Base):
    __tablename__ = "kb_qa"

    # 基础字段
    id = Column(String(64), primary_key=True, comment="雪花ID")
    create_time = Column(String(32), nullable=False, comment="创建时间")
    update_time = Column(String(32), nullable=False, comment="更新时间")

    # 业务字段
    question = Column(Text, nullable=False, comment="问题题目，___表示填空")
    answer = Column(Text, nullable=False, comment="答案JSON数组，如[\"1986\",\"北京电影学院\"]")
    image_url = Column(String(512), nullable=True, comment="关联图片的OSS URL")

    # 统计字段
    total = Column(Integer, nullable=False, default=0, comment="总答题次数")
    right = Column(Integer, nullable=False, default=0, comment="答对次数")
    wrong = Column(Integer, nullable=False, default=0, comment="答错次数")
    random_int = Column(Integer, nullable=False, unique=True, comment="自增整数，用于随机排序")

    # 关联字段
    bank_id = Column(String(64), nullable=True, comment="所属题库ID")
    tag_id = Column(Text, nullable=True, comment="标签ID的JSON数组，如[\"id1\",\"id2\"]")
