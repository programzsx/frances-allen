from sqlalchemy import Column, String, Integer, Text
from app.database import Base


class DouyinVideo(Base):
    __tablename__ = "douyin_video"

    id = Column(String(64), primary_key=True, comment="雪花ID")
    create_time = Column(String(32), nullable=False, comment="创建时间")
    update_time = Column(String(32), nullable=False, comment="更新时间")
    movie_id = Column(String(64), nullable=False, comment="所属电影ID")
    name = Column(String(256), nullable=False, comment="剧集/视频名称")
    description = Column(Text, nullable=True, comment="简介")
    cover_url = Column(String(512), nullable=True, comment="封面URL")
    duration = Column(Integer, default=0, comment="时长(秒)")
    slice_count = Column(Integer, default=0, comment="切片数量")
    sort_order = Column(Integer, default=0, comment="排序序号")
    status = Column(Integer, default=1, comment="状态: 0下架 1上架")
