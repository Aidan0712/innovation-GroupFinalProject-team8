/**
 * 语音录制与消息相关类型
 */

/** 录音状态 */
export type VoiceRecorderState =
  | 'idle'       // 空闲
  | 'recording'  // 录音中
  | 'cancelling' // 上滑取消中
  | 'cancelled'  // 已取消
  | 'too_short'  // 录音过短

/** 语音消息额外数据 */
export interface VoiceMessageExtra {
  audio_url: string
  duration_seconds: number
  recording_id: number
  transcript: string | null
  transcript_status: 'pending' | 'transcribing' | 'completed' | 'failed'
}

/** 录音上传响应 */
export interface VoiceUploadResponse {
  id: number
  file_name: string
  file_path: string
  status: string
  file_url?: string
}

/** 录音状态查询 */
export interface VoiceStatusResponse {
  id: number
  status: string
  file_name: string
}

/** 转写结果 */
export interface VoiceTranscriptResult {
  recording_id: number
  transcript: string | null
  duration_seconds: number
}
