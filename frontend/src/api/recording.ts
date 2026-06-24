import request from './request'
import type { Recording, RecordingResult, APIResponse } from '@/types'

export function uploadRecordingApi(file: File): Promise<APIResponse<Recording>> {
  const formData = new FormData()
  formData.append('file', file)
  return request.post('/v1/recording/upload', formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  })
}

export function getRecordingStatusApi(recordingId: number): Promise<APIResponse<Recording>> {
  return request.get(`/v1/recording/${recordingId}/status`)
}

export function getRecordingDetailApi(recordingId: number): Promise<APIResponse<Recording>> {
  return request.get(`/v1/recording/${recordingId}`)
}

export function getRecordingAnalysisApi(recordingId: number): Promise<APIResponse<RecordingResult>> {
  return request.get(`/v1/recording/${recordingId}/analysis`)
}

export function getRecordingsApi(): Promise<APIResponse<Recording[]>> {
  return request.get('/v1/recording/list')
}

export function deleteRecordingApi(recordingId: number): Promise<APIResponse<null>> {
  return request.delete(`/v1/recording/${recordingId}`)
}
