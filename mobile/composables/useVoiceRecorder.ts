/**
 * useVoiceRecorder — 微信式语音录制逻辑
 *
 * 简化版：单次 getUserMedia，避免双重调用消耗用户手势
 * 功能：按住说话/松开发送/上滑取消/时长显示/过短提示
 */
import { ref, computed, onUnmounted } from 'vue'
import { uploadVoiceApi, getVoiceStatusApi, getVoiceDetailApi, getVoiceAnalysisApi } from '@/api/voice'
import type { VoiceRecorderState, VoiceMessageExtra } from '@/types/voice'

export interface VoiceRecorderResult {
  audioBlob: Blob
  duration: number
  extra: VoiceMessageExtra
}

const MIN_RECORD_DURATION = 1
const CANCEL_DISTANCE = 80
const POLL_INTERVAL = 2000
const MAX_POLL_TIME = 180000  // 增加到 180 秒（3 分钟）

export function useVoiceRecorder() {
  const state = ref<VoiceRecorderState>('idle')
  const duration = ref(0)
  const mediaRecorder = ref<MediaRecorder | null>(null)
  const streamRef = ref<MediaStream | null>(null)
  const chunks = ref<Blob[]>([])
  const startY = ref(0)
  const startX = ref(0)
  const timer = ref<ReturnType<typeof setInterval> | null>(null)
  const isProcessing = ref(false)
  const lastError = ref('')

  const isRecording = computed(() => state.value === 'recording')
  const isCancelling = computed(() => state.value === 'cancelling')
  const durationText = computed(() => {
    const secs = Math.floor(duration.value)
    const mins = Math.floor(secs / 60)
    const remainSecs = secs % 60
    return `${mins.toString().padStart(2, '0')}:${remainSecs.toString().padStart(2, '0')}`
  })

  /** 选取最佳 MIME 类型（不用带 codecs 后缀，避免后端匹配失败） */
  function getBestMimeType(): string {
    if (MediaRecorder.isTypeSupported('audio/webm')) return 'audio/webm'
    if (MediaRecorder.isTypeSupported('audio/mp4')) return 'audio/mp4'
    if (MediaRecorder.isTypeSupported('audio/ogg')) return 'audio/ogg'
    return ''
  }

  /** 生成安全的文件名 */
  function getFileName(mimeType: string): string {
    if (mimeType.includes('mp4') || mimeType.includes('m4a')) return `voice_${Date.now()}.mp4`
    if (mimeType.includes('ogg')) return `voice_${Date.now()}.ogg`
    return `voice_${Date.now()}.webm`
  }

  /** -- 内部: 释放流 -- */
  function stopStreamTracks() {
    if (streamRef.value) {
      streamRef.value.getTracks().forEach((t) => t.stop())
      streamRef.value = null
    }
  }

  /** -- 内部: 清除计时器 -- */
  function clearTimer() {
    if (timer.value) { clearInterval(timer.value); timer.value = null }
  }

  /** -- 开始录音（核心：只调一次 getUserMedia） -- */
  async function startRecording(): Promise<void> {
    if (state.value !== 'idle') return
    if (isProcessing.value) return

    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      streamRef.value = stream

      const mimeType = getBestMimeType()
      const recorder = mimeType
        ? new MediaRecorder(stream, { mimeType })
        : new MediaRecorder(stream)
      chunks.value = []

      recorder.ondataavailable = (e) => {
        if (e.data.size > 0) chunks.value.push(e.data)
      }

      recorder.start(1000)
      mediaRecorder.value = recorder
      state.value = 'recording'
      duration.value = 0
      timer.value = setInterval(() => { duration.value += 1 }, 1000)
    } catch (err: any) {
      if (err.name === 'NotAllowedError' || err.name === 'PermissionDeniedError') {
        lastError.value = '麦克风权限被拒绝，请在浏览器设置中允许访问麦克风。\n提示：手机端访问需使用 HTTPS 或 localhost。'
      } else if (err.name === 'NotFoundError') {
        lastError.value = '未检测到麦克风设备'
      } else if (err.name === 'NotReadableError') {
        lastError.value = '麦克风被其他应用占用'
      } else {
        lastError.value = `无法启动录音：${err.message || '未知错误'}`
      }
      state.value = 'idle'
      throw new Error(lastError.value)
    }
  }

  /** -- 处理移动 -- */
  function handleMove(clientY: number) {
    if (state.value !== 'recording' && state.value !== 'cancelling') return
    const deltaY = startY.value - clientY
    state.value = deltaY > CANCEL_DISTANCE ? 'cancelling' : 'recording'
  }

  /** -- 设置起始位置 -- */
  function setStartPosition(x: number, y: number) {
    startX.value = x; startY.value = y
  }

  /** -- 停止录音 -- */
  async function stopRecording(): Promise<VoiceRecorderResult | null> {
    if (!mediaRecorder.value) return null
    if (isProcessing.value) return null

    isProcessing.value = true
    clearTimer()

    const wasCancelling = state.value === 'cancelling'
    const dur = duration.value
    const savedChunks = [...chunks.value]
    const recorder = mediaRecorder.value
    const mimeType = recorder.mimeType || 'audio/webm'
    mediaRecorder.value = null

    return new Promise((resolve) => {
      recorder.onstop = async () => {
        stopStreamTracks()

        if (wasCancelling) {
          state.value = 'cancelled'
          isProcessing.value = false
          resolve(null)
          setTimeout(() => { state.value = 'idle'; duration.value = 0 }, 1500)
          return
        }

        if (dur < MIN_RECORD_DURATION) {
          state.value = 'too_short'
          isProcessing.value = false
          resolve(null)
          setTimeout(() => { state.value = 'idle'; duration.value = 0 }, 2000)
          return
        }

        state.value = 'idle'
        duration.value = 0

        let audioBlob: Blob | null = null
        try {
          audioBlob = new Blob(savedChunks, { type: mimeType })
          const recordingId = await uploadAndPoll(audioBlob, mimeType)
          
          if (recordingId !== null) {
            // 获取录音详情（file_url）
            const detail = await getVoiceDetailApi(recordingId)
            // 轮询获取转写结果（最多等待30秒）
            const transcription = await pollForTranscript(recordingId)
            
            resolve({
              audioBlob,
              duration: dur,
              extra: {
                audio_url: detail.data.file_url || '',
                duration_seconds: dur,
                recording_id: recordingId,
                transcript: transcription || '',
                transcript_status: transcription ? 'completed' : 'pending',
              },
            })
          } else {
            // 上传或转写失败，但仍返回音频 blob 供本地播放
            resolve({
              audioBlob,
              duration: dur,
              extra: {
                audio_url: '',
                duration_seconds: dur,
                recording_id: 0,
                transcript: '',
                transcript_status: 'failed',
              },
            })
          }
        } catch (err: any) {
          console.error('[VoiceRecorder] 上传/转写异常:', err)
          resolve({
            audioBlob: audioBlob || new Blob(savedChunks, { type: mimeType }),
            duration: dur,
            extra: {
              audio_url: '',
              duration_seconds: dur,
              recording_id: 0,
              transcript: '',
              transcript_status: 'failed',
            },
          })
        }
        isProcessing.value = false
      }

      if (recorder.state === 'recording') {
        recorder.requestData()
        recorder.stop()
      } else {
        recorder.dispatchEvent(new Event('stop'))
      }
    })
  }

  /** -- 上传 + 轮询 -- */
  async function uploadAndPoll(blob: Blob, mimeType: string): Promise<number | null> {
    try {
      const fileName = getFileName(mimeType)
      const audioFile = new File([blob], fileName, { type: mimeType })
      const uploadRes = await uploadVoiceApi(audioFile)
      const recordingId = uploadRes.data.id

      const startTime = Date.now()
      while (Date.now() - startTime < MAX_POLL_TIME) {
        await new Promise((r) => setTimeout(r, POLL_INTERVAL))
        try {
          const statusRes = await getVoiceStatusApi(recordingId)
          const s = statusRes.data.status
          if (s === 'completed' || s === 'transcribed' || s === 'failed') return recordingId
        } catch { continue }
      }
      return recordingId
    } catch (err) {
      console.error('[VoiceRecorder] 上传失败:', err)
      return null
    }
  }

  /** -- 轮询转写结果（最多等 90 秒） -- */
  async function pollForTranscript(recordingId: number, maxWaitMs = 90000): Promise<string> {
    const startTime = Date.now()
    while (Date.now() - startTime < maxWaitMs) {
      try {
        const analysisRes = await getVoiceAnalysisApi(recordingId)
        const transcript = analysisRes.data?.transcript || ''
        if (transcript) return transcript
      } catch { }
      await new Promise((r) => setTimeout(r, 2000))
    }
    return ''
  }

  /** -- 重置 -- */
  function reset() {
    clearTimer()
    stopStreamTracks()
    if (mediaRecorder.value && mediaRecorder.value.state === 'recording') {
      mediaRecorder.value.stop()
    }
    mediaRecorder.value = null
    state.value = 'idle'
    duration.value = 0
    chunks.value = []
    isProcessing.value = false
    lastError.value = ''
  }

  onUnmounted(() => reset())

  return {
    state, duration, durationText, isRecording, isCancelling, isProcessing, lastError,
    startRecording, stopRecording, handleMove, setStartPosition, reset,
    MIN_RECORD_DURATION,
  }
}
