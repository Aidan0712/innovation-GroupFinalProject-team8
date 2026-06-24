<script setup lang="ts">
import { computed, ref } from 'vue'
import { ElMessage } from 'element-plus'
import {
  useVoiceRecorder,
  type VoiceRecorderResult,
} from '@/composables/useVoiceRecorder'

const props = withDefaults(defineProps<{
  disabled?: boolean
}>(), {
  disabled: false,
})

const emit = defineEmits<{
  (e: 'result', result: VoiceRecorderResult): void
  (e: 'error', message: string): void
}>()

const recorder = useVoiceRecorder()
const activePointerId = ref<number | null>(null)

const buttonLabel = computed(() => {
  if (recorder.isProcessing.value) return '正在上传并转写录音'
  if (recorder.isCancelling.value) return '松手取消发送'
  if (recorder.isRecording.value) return `松开发送 ${recorder.durationText.value}`
  return '按住说话'
})

const helperText = computed(() => {
  if (!recorder.isSecureCaptureSupported.value) {
    return '手机浏览器通常需要 HTTPS 才能启用麦克风'
  }
  if (recorder.isCancelling.value) return '上滑松手可取消本次录音'
  if (recorder.isRecording.value) return '继续按住，松开发送'
  return '按住开始录音，上滑取消，松开发送'
})

async function handlePointerDown(event: PointerEvent) {
  if (props.disabled || recorder.isProcessing.value) return
  activePointerId.value = event.pointerId
  ;(event.currentTarget as HTMLElement | null)?.setPointerCapture?.(event.pointerId)
  recorder.setStartPosition(event.clientY)

  try {
    await recorder.startRecording()
  } catch (error: any) {
    const message = error?.message || recorder.lastError.value || '录音启动失败，请稍后重试'
    emit('error', message)
    ElMessage.warning(message)
  }
}

function handlePointerMove(event: PointerEvent) {
  if (activePointerId.value !== event.pointerId) return
  recorder.handleMove(event.clientY)
}

async function finishRecording(pointerId: number) {
  if (activePointerId.value !== pointerId) return
  activePointerId.value = null
  const result = await recorder.stopRecording()
  if (result) {
    emit('result', result)
    return
  }
  if (recorder.state.value === 'too_short') {
    emit('error', '录音时间过短，请重新录制')
  } else if (recorder.state.value === 'cancelled') {
    emit('error', '已取消录音')
  }
}

async function handlePointerUp(event: PointerEvent) {
  await finishRecording(event.pointerId)
}

async function handlePointerCancel(event: PointerEvent) {
  await finishRecording(event.pointerId)
}
</script>

<template>
  <div class="voice-record-card">
    <button
      class="voice-record-button"
      :class="{
        recording: recorder.isRecording.value,
        cancelling: recorder.isCancelling.value,
        processing: recorder.isProcessing.value,
      }"
      :disabled="disabled || recorder.isProcessing.value"
      type="button"
      @pointerdown.prevent="handlePointerDown"
      @pointermove.prevent="handlePointerMove"
      @pointerup.prevent="handlePointerUp"
      @pointercancel.prevent="handlePointerCancel"
      @lostpointercapture="handlePointerCancel"
    >
      <span class="voice-record-icon">●</span>
      <span>{{ buttonLabel }}</span>
    </button>
    <p class="voice-record-hint">{{ helperText }}</p>
  </div>
</template>

<style scoped>
.voice-record-card {
  display: grid;
  gap: 10px;
}

.voice-record-button {
  width: 100%;
  min-height: 56px;
  border: 1px dashed rgba(83, 74, 183, 0.35);
  border-radius: 18px;
  background: rgba(83, 74, 183, 0.06);
  color: var(--color-primary);
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 10px;
  padding: 14px 18px;
  font-size: 15px;
  font-weight: 600;
  cursor: pointer;
  transition: transform 0.18s ease, background 0.18s ease, border-color 0.18s ease;
  touch-action: none;
  user-select: none;
}

.voice-record-button:disabled {
  cursor: not-allowed;
  opacity: 0.72;
}

.voice-record-button.recording {
  background: rgba(83, 74, 183, 0.14);
  border-color: rgba(83, 74, 183, 0.58);
  transform: scale(0.99);
}

.voice-record-button.cancelling {
  background: rgba(245, 108, 108, 0.1);
  border-color: rgba(245, 108, 108, 0.45);
  color: var(--color-danger);
}

.voice-record-button.processing {
  background: rgba(83, 74, 183, 0.12);
}

.voice-record-icon {
  font-size: 20px;
  line-height: 1;
}

.voice-record-hint {
  margin: 0;
  color: var(--color-text-secondary);
  font-size: 13px;
  text-align: center;
}
</style>
