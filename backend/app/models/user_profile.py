"""
用户扩展信息表 ORM 模型
存储年龄、性别、专业、年级、大学等求职信息
"""
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class UserProfile(Base):
    """用户扩展信息表（一对一关联 User）"""
    __tablename__ = "user_profiles"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True, comment="主键")
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
        comment="关联用户ID（一对一）",
    )
    age: Mapped[int | None] = mapped_column(
        default=None,
        nullable=True,
        comment="年龄",
    )
    gender: Mapped[str | None] = mapped_column(
        String(10),
        default=None,
        nullable=True,
        comment="性别",
    )
    major: Mapped[str | None] = mapped_column(
        String(128),
        default=None,
        nullable=True,
        comment="专业",
    )
    grade: Mapped[str | None] = mapped_column(
        String(32),
        default=None,
        nullable=True,
        comment="年级（大一/大二/大三/大四/研一/研二/研三/已毕业）",
    )
    university: Mapped[str | None] = mapped_column(
        String(128),
        default=None,
        nullable=True,
        comment="就读大学",
    )
    allow_ai_use: Mapped[bool] = mapped_column(
        default=True,
        nullable=False,
        comment="是否允许 AI 在对话中使用个人信息",
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime, server_default=func.now(), nullable=False, comment="创建时间"
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
        comment="更新时间",
    )

    # ── 关联关系 ──
    user: Mapped["User"] = relationship("User", back_populates="profile")

    def __repr__(self) -> str:
        return f"<UserProfile(id={self.id}, user_id={self.user_id})>"
