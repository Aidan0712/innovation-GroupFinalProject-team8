import { computed, onUnmounted, ref } from 'vue'
import {
  getRecordingAnalysisApi,
  getRecordingDetailApi,
  getRecordingStatusApi,
  uploadRecordingApi,
} from '@/api/recording'

export interface VoiceRecorderExtra {
  audio_url: string
  duration_seconds: number
  recording_id: number
  transcript: string
  transcript_status: 'pending' | 'completed' | 'failed'
}

export interface VoiceRecorderResult {
  audioBlob: Blob
  duration: number
  extra: VoiceRecorderExtra
}

export type VoiceRecorderState =
  | 'idle'
  | 'recording'
  | 'cancelling'
  | 'too_short'
  | 'cancelled'

const MIN_RECORD_DURATION = 1
const CANCEL_DISTANCE = 80
const POLL_INTERVAL_MS = 2000
const MAX_POLL_TIME_MS = 180000
const MAX_TRANSCRIPT_WAIT_MS = 90000

export function useVoiceRecorder() {
  const state = ref<VoiceRecorderState>('idle')
  const duration = ref(0)
  const mediaRecorder = ref<MediaRecorder | null>(null)
  const streamRef = ref<MediaStream | null>(null)
  const chunks = ref<Blob[]>([])
  const startY = ref(0)
  const timer = ref<ReturnType<typeof setInterval> | null>(null)
  const isProcessing = ref(false)
  const lastError = ref('')

  const isRecording = computed(() => state.value === 'recording')
  const isCancelling = computed(() => state.value === 'cancelling')
  const isSecureCaptureSupported = computed(() => {
    if (typeof window === 'undefined') return false
    if (window.isSecureContext) return true
    return ['localhost', '127.0.0.1'].includes(window.location.hostname)
  })
  const durationText = computed(() => {
    const totalSeconds = Math.max(0, Math.floor(duration.value))
    const minutes = Math.floor(totalSeconds / 60)
    const seconds = totalSeconds % 60
    return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`
  })

  function getBestMimeType() {
    if (typeof MediaRecorder === 'undefined') return ''
    if (MediaRecorder.isTypeSupported('audio/webm')) return 'audio/webm'
    if (MediaRecorder.isTypeSupported('audio/mp4')) return 'audio/mp4'
    if (MediaRecorder.isTypeSupported('audio/ogg')) return 'audio/ogg'
    return ''
  }

  function getFileName(mimeType: string) {
    if (mimeType.includes('mp4') || mimeType.includes('m4a')) return `voice_${Date.now()}.mp4`
    if (mimeType.includes('ogg')) return `voice_${Date.now()}.ogg`
    return `voice_${Date.now()}.webm`
  }

  function setStartPosition(y: number) {
    startY.value = y
  }

  function handleMove(y: number) {
    if (state.value !== 'recording' && state.value !== 'cancelling') return
    state.value = startY.value - y > CANCEL_DISTANCE ? 'cancelling' : 'recording'
  }

  function stopStreamTracks() {
    if (!streamRef.value) return
    streamRef.value.getTracks().forEach((track) => track.stop())
    streamRef.value = null
  }

  function clearTimer() {
    if (!timer.value) return
    clearInterval(timer.value)
    timer.value = null
  }

  async function startRecording() {
    if (state.value !== 'idle' || isProcessing.value) return
    if (!isSecureCaptureSupported.value) {
      lastError.value = '当前页面不是安全上下文。手机浏览器录音通常需要 HTTPS，localhost 例外。'
      throw new Error(lastError.value)
    }
    if (!navigator.mediaDevices?.getUserMedia) {
      lastError.value = '当前浏览器不支持麦克风录音'
      throw new Error(lastError.value)
    }

    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      streamRef.value = stream
      const mimeType = getBestMimeType()
      const recorder = mimeType
        ? new MediaRecorder(stream, { mimeType })
        : new MediaRecorder(stream)

      chunks.value = []
      recorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          chunks.value.push(event.data)
        }
      }

      recorder.start(1000)
      mediaRecorder.value = recorder
      duration.value = 0
      state.value = 'recording'
      timer.value = setInterval(() => {
        duration.value += 1
      }, 1000)
    } catch (error: any) {
      const errorName = error?.name ?? ''
      if (errorName === 'NotAllowedError' || errorName === 'PermissionDeniedError') {
        lastError.value = '麦克风权限被拒绝，请在浏览器设置中允许访问麦克风。'
      } else if (errorName === 'NotFoundError') {
        lastError.value = '未检测到可用的麦克风设备。'
      } else if (errorName === 'NotReadableError') {
        lastError.value = '麦克风正在被其他应用占用。'
      } else {
        lastError.value = error?.message || '无法启动录音，请稍后重试。'
      }
      state.value = 'idle'
      stopStreamTracks()
      throw new Error(lastError.value)
    }
  }

  async function stopRecording(): Promise<VoiceRecorderResult | null> {
    if (!mediaRecorder.value || isProcessing.value) return null

    isProcessing.value = true
    clearTimer()

    const wasCancelling = state.value === 'cancelling'
    const recordedDuration = duration.value
    const savedChunks = [...chunks.value]
    const recorder = mediaRecorder.value
    const mimeType = recorder.mimeType || getBestMimeType() || 'audio/webm'
    mediaRecorder.value = null

    return new Promise((resolve) => {
      recorder.onstop = async () => {
        stopStreamTracks()

        if (wasCancelling) {
          state.value = 'cancelled'
          duration.value = 0
          isProcessing.value = false
          resolve(null)
          setTimeout(() => {
            state.value = 'idle'
          }, 1200)
          return
        }

        if (recordedDuration < MIN_RECORD_DURATION) {
          state.value = 'too_short'
          duration.value = 0
          isProcessing.value = false
          resolve(null)
          setTimeout(() => {
            state.value = 'idle'
          }, 1500)
          return
        }

        state.value = 'idle'
        duration.value = 0

        let audioBlob = new Blob(savedChunks, { type: mimeType })
        try {
          const recordingId = await uploadAndPoll(audioBlob, mimeType)
          if (!recordingId) {
            resolve({
              audioBlob,
              duration: recordedDuration,
              extra: {
                audio_url: '',
                duration_seconds: recordedDuration,
                recording_id: 0,
                transcript: '',
                transcript_status: 'failed',
              },
            })
            return
          }

          const detail = await getRecordingDetailApi(recordingId)
          const transcript = await pollForTranscript(recordingId)
          resolve({
            audioBlob,
            duration: recordedDuration,
            extra: {
              audio_url: detail.data.file_url || '',
              duration_seconds: recordedDuration,
              recording_id: recordingId,
              transcript,
              transcript_status: transcript ? 'completed' : 'failed',
            },
          })
        } catch (error) {
          console.error('[useVoiceRecorder] upload or transcription failed', error)
          resolve({
            audioBlob,
            duration: recordedDuration,
            extra: {
              audio_url: '',
              duration_seconds: recordedDuration,
              recording_id: 0,
              transcript: '',
              transcript_status: 'failed',
            },
          })
        } finally {
          isProcessing.value = false
        }
      }

      if (recorder.state === 'recording') {
        recorder.requestData()
        recorder.stop()
      } else {
        isProcessing.value = false
        resolve(null)
      }
    })
  }

  async function uploadAndPoll(blob: Blob, mimeType: string) {
    const file = new File([blob], getFileName(mimeType), { type: mimeType })
    const uploadRes = await uploadRecordingApi(file)
    const recordingId = uploadRes.data.id
    const startedAt = Date.now()

    while (Date.now() - startedAt < MAX_POLL_TIME_MS) {
      await sleep(POLL_INTERVAL_MS)
      try {
        const statusRes = await getRecordingStatusApi(recordingId)
        const currentStatus = (statusRes.data as any)?.status
        if (currentStatus === 'completed') return recordingId
        if (currentStatus === 'failed') return recordingId
      } catch (error) {
        console.warn('[useVoiceRecorder] status poll failed', error)
      }
    }

    return recordingId
  }

  async function pollForTranscript(recordingId: number) {
    const startedAt = Date.now()

    while (Date.now() - startedAt < MAX_TRANSCRIPT_WAIT_MS) {
      try {
        const analysisRes = await getRecordingAnalysisApi(recordingId)
        const transcript = analysisRes.data?.transcript || ''
        if (transcript) return transcript
      } catch (error) {
        console.warn('[useVoiceRecorder] transcript poll failed', error)
      }

      try {
        const detailRes = await getRecordingDetailApi(recordingId)
        const transcript = detailRes.data?.transcript || ''
        if (transcript) return transcript
      } catch (error) {
        console.warn('[useVoiceRecorder] detail poll failed', error)
      }

      await sleep(POLL_INTERVAL_MS)
    }

    return ''
  }

  function reset() {
    clearTimer()
    stopStreamTracks()
    if (mediaRecorder.value?.state === 'recording') {
      mediaRecorder.value.stop()
    }
    mediaRecorder.value = null
    duration.value = 0
    chunks.value = []
    isProcessing.value = false
    lastError.value = ''
    state.value = 'idle'
  }

  onUnmounted(reset)

  return {
    durationText,
    isCancelling,
    isProcessing,
    isRecording,
    isSecureCaptureSupported,
    lastError,
    setStartPosition,
    handleMove,
    reset,
    startRecording,
    state,
    stopRecording,
  }
}

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms))
}
