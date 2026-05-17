from sqlalchemy import Column, String, Integer, Text
from app.database import Base


class DouyinSlice(Base):
    __tablename__ = "douyin_slice"

    id = Column(String(64), primary_key=True, comment="雪花ID")
    create_time = Column(String(32), nullable=False, comment="创建时间")
    update_time = Column(String(32), nullable=False, comment="更新时间")
    video_id = Column(String(64), nullable=False, comment="所属视频ID")
    movie_id = Column(String(64), nullable=False, comment="所属电影ID(冗余)")
    name = Column(String(256), nullable=True, comment="切片名称")
    comment = Column(Text, nullable=True, comment="备注/评论")
    oss_url = Column(String(512), nullable=False, comment="视频URL")
    sort_order = Column(Integer, default=0, comment="排序序号")
    is_fav = Column(Integer, default=0, comment="是否收藏: 0否 1是")
    random_int = Column(Integer, default=0, comment="随机排序用")
    watch_count = Column(Integer, default=0, comment="播放次数")
