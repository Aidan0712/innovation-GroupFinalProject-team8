/**
 * 语音录制相关 API
 * 对接已有的 POST /v1/recording/upload、GET /v1/recording/{id}/status、GET /v1/recording/{id}
 */
import request from './request'
import type { APIResponse, Recording, RecordingResult } from '@/types'

/** 上传录音文件到后端 */
export function uploadVoiceApi(file: File): Promise<APIResponse<Recording>> {
  const formData = new FormData()
  formData.append('file', file)
  return request.post('/v1/recording/upload', formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  })
}

/** 查询录音处理状态 */
export function getVoiceStatusApi(recordingId: number): Promise<APIResponse<{ id: number; status: string; file_name: string }>> {
  return request.get(`/v1/recording/${recordingId}/status`)
}

/** 获取录音详情（含转写文本） */
export function getVoiceDetailApi(recordingId: number): Promise<APIResponse<Recording>> {
  return request.get(`/v1/recording/${recordingId}`)
}

/** 获取录音分析结果 */
export function getVoiceAnalysisApi(recordingId: number): Promise<APIResponse<RecordingResult>> {
  return request.get(`/v1/recording/${recordingId}/analysis`)
}
