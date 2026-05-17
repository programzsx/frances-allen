from sqlalchemy import Column, String, Integer, Text
from app.database import Base


class DouyinMovie(Base):
    __tablename__ = "douyin_movie"

    id = Column(String(64), primary_key=True, comment="雪花ID")
    create_time = Column(String(32), nullable=False, comment="创建时间")
    update_time = Column(String(32), nullable=False, comment="更新时间")
    name = Column(String(256), nullable=False, comment="电影名称，同时是 OSS 一级目录名")
    description = Column(Text, nullable=True, comment="简介")
    cover_url = Column(String(512), nullable=True, comment="封面URL")
    sort_order = Column(Integer, default=0, comment="排序序号，值越小越靠前")
    video_count = Column(Integer, default=0, comment="剧集/视频数量")
