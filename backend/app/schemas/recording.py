"""
录音相关 Pydantic Schema
"""

from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field


class RecordingResponse(BaseModel):
    """录音响应"""
    id: int
    user_id: int
    file_name: str
    file_url: str = ""
    duration_seconds: int | None = None
    transcript: str | None = None
    analysis_result: dict | None = None
    collected_questions: dict | None = None
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}

    @classmethod
    def model_validate(cls, obj: Any, **kwargs: Any) -> "RecordingResponse":
        """从 ORM 模型构造时自动计算 file_url"""
        from app.config import BASE_DIR
        instance = super().model_validate(obj, **kwargs)
        # 从 file_path 构造可访问的 URL
        # file_path 形如 backend/uploads/recordings/2026/06/uuid.webm
        # 静态挂载 /uploads → backend/uploads
        if hasattr(obj, 'file_path'):
            file_path = obj.file_path
            # 去掉 BASE_DIR 前缀，构造 /uploads/... 路径
            base_dir_str = str(BASE_DIR.resolve())
            if file_path.startswith(base_dir_str):
                rel = file_path[len(base_dir_str):].lstrip('/').lstrip('\\')
            else:
                # 备用：从 uploads 子目录提取
                rel = file_path
            # Windows 路径转 URL
            rel = rel.replace('\\', '/')
            instance.file_url = f"/{rel}"
        return instance


class RecordingAnalysisResponse(BaseModel):
    """录音分析结果响应"""
    recording_id: int = Field(..., description="录音ID")
    transcript: str | None = Field(default=None, description="转写文本")
    duration_seconds: int = Field(..., description="时长（秒）")
    fluency_score: float | None = Field(default=None, description="流畅度评分")
    speech_rate: float | None = Field(default=None, description="语速（字/分钟）")
    key_points: list[str] = Field(default_factory=list, description="关键信息点")
    suggestions: list[str] = Field(default_factory=list, description="改进建议")
    collected_questions: list[dict] | None = Field(default=None, description="收集的面试题")


class RecordingListResponse(BaseModel):
    """录音列表响应"""
    recordings: list[RecordingResponse]
    total: int
