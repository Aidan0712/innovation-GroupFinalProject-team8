<!--
  VoiceRecorder.vue — 微信式按住说话按钮
  支持：按住说话 / 松开发送 / 上滑取消 / 录音时长 / 过短提示
  简化版：单次 getUserMedia，即时视觉反馈，完整错误处理
-->
<script setup lang="ts">
import { computed } from 'vue'
import { useVoiceRecorder } from '@/composables/useVoiceRecorder'

const emit = defineEmits<{
  (e: 'result', result: any): void
  (e: 'error', message: string): void
}>()

const {
  state, durationText, isRecording, isCancelling, lastError,
  startRecording, stopRecording, handleMove, setStartPosition,
  MIN_RECORD_DURATION,
} = useVoiceRecorder()

// ── 触屏后禁止 mouse 事件（防止双击触发） ──
let preventMouse = false
let mouseBlockTimer: ReturnType<typeof setTimeout> | null = null

function blockMouse() {
  preventMouse = true
  if (mouseBlockTimer) clearTimeout(mouseBlockTimer)
  mouseBlockTimer = setTimeout(() => { preventMouse = false }, 600)
}

// ── 按下开始 ──
async function onPressStart(e: TouchEvent | MouseEvent, isTouch: boolean) {
  e.preventDefault()
  if (isTouch) blockMouse()
  if (!isTouch && preventMouse) return

  // 防止重复触发
  if (state.value !== 'idle') return

  // 记录起始位置（用于上滑检测）
  const clientX = isTouch ? (e as TouchEvent).touches[0].clientX : (e as MouseEvent).clientX
  const clientY = isTouch ? (e as TouchEvent).touches[0].clientY : (e as MouseEvent).clientY
  setStartPosition(clientX, clientY)

  // 开始录音（内部处理所有错误）
  try {
    await startRecording()
  } catch (err: any) {
    // startRecording 抛出错误表示 getUserMedia 失败
    emit('error', err.message || lastError.value || '无法启动录音')
  }
}

// ── 移动中 ──
function onPressMove(e: TouchEvent | MouseEvent, isTouch: boolean) {
  if (!isTouch && preventMouse) return
  if (state.value !== 'recording' && state.value !== 'cancelling') return

  const clientY = isTouch ? (e as TouchEvent).touches[0].clientY : (e as MouseEvent).clientY
  handleMove(clientY)
}

// ── 松开 ──
async function onPressEnd(isTouch: boolean) {
  if (!isTouch && preventMouse) return
  if (state.value === 'idle') return

  const result = await stopRecording()
  if (result) emit('result', result)
}

// ── 标签 ──
const label = computed(() => ({
  idle: '按住 说话',
  recording: '松开 发送',
  cancelling: '松开 取消',
  cancelled: '已取消',
  too_short: '说话时间太短',
}[state.value] || '按住 说话'))
</script>

<template>
  <div class="voice-recorder">
    <!-- 录音状态指示条 -->
    <div v-if="isRecording || isCancelling" class="recording-bar">
      <div class="recording-wave">
        <span v-for="i in 5" :key="i" class="bar" :class="{ red: isCancelling }" />
      </div>
      <span class="recording-time">{{ durationText }}</span>
      <span class="recording-hint">{{ isCancelling ? '松开取消' : '上滑取消' }}</span>
    </div>

    <!-- 过短/取消提示 -->
    <div v-if="state === 'too_short'" class="toast warn">
      说话时间太短（不足 {{ MIN_RECORD_DURATION }} 秒）
    </div>
    <div v-else-if="state === 'cancelled'" class="toast">
      已取消
    </div>

    <!-- 按住说话按钮 -->
    <button
      class="record-btn"
      :class="{ active: isRecording, danger: isCancelling }"
      @mousedown="onPressStart($event, false)"
      @mousemove="onPressMove($event, false)"
      @mouseup="onPressEnd(false)"
      @mouseleave="onPressEnd(false)"
      @touchstart.prevent="onPressStart($event, true)"
      @touchmove.prevent="onPressMove($event, true)"
      @touchend.prevent="onPressEnd(true)"
      @touchcancel.prevent="onPressEnd(true)"
    >
      {{ label }}
    </button>
  </div>
</template>

<style scoped>
.voice-recorder {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  width: 100%;
}

/* 录音指示 */
.recording-bar {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 6px 16px;
  background: rgba(83, 74, 183, 0.08);
  border: 1px solid rgba(83, 74, 183, 0.15);
  border-radius: 20px;
  font-size: 12px;
  color: #534AB7;
}
.recording-wave { display: flex; align-items: center; gap: 2px; height: 20px; }
.bar {
  width: 3px; min-height: 4px;
  background: #534AB7; border-radius: 2px;
  animation: wave 0.6s ease-in-out infinite;
}
.bar:nth-child(2) { animation-delay: 0.1s; }
.bar:nth-child(3) { animation-delay: 0.2s; }
.bar:nth-child(4) { animation-delay: 0.3s; }
.bar:nth-child(5) { animation-delay: 0.4s; }
.bar.red { background: #F56C6C; }
@keyframes wave {
  0%, 100% { height: 4px; }
  50% { height: 16px; }
}
.recording-time { font-weight: 600; font-variant-numeric: tabular-nums; min-width: 36px; }
.recording-hint { font-size: 11px; color: #999; }

/* 提示 toast */
.toast {
  padding: 4px 16px;
  background: rgba(144, 147, 153, 0.1);
  border: 1px solid rgba(144, 147, 153, 0.2);
  border-radius: 20px;
  font-size: 12px;
  color: #909399;
}
.toast.warn {
  background: rgba(245, 108, 108, 0.08);
  border-color: rgba(245, 108, 108, 0.2);
  color: #F56C6C;
}

/* 按钮 */
.record-btn {
  width: 100%;
  max-width: 320px;
  height: 48px;
  border: 1px solid #DCDFE6;
  border-radius: 24px;
  background: #fff;
  font-size: 16px;
  color: #606266;
  cursor: pointer;
  user-select: none;
  -webkit-user-select: none;
  touch-action: none;
  -webkit-touch-callout: none;
  transition: all 0.15s ease;
}
.record-btn:active {
  background: #f0f0f0;
  transform: scale(0.97);
}
.record-btn.active {
  background: #534AB7;
  color: #fff;
  border-color: #534AB7;
}
.record-btn.danger {
  background: #F56C6C;
  color: #fff;
  border-color: #F56C6C;
}
</style>
