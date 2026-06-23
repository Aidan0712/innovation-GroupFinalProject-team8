<!--
  VoiceMessageBubble.vue — 语音消息气泡（播放、波形动画、转写文本）
  支持微信式长按「转文字」：长按气泡 → 弹出菜单 → 点「转文字」查询后端 ASR 结果
-->
<script setup lang="ts">
import { ref, computed, onUnmounted } from 'vue'

const emit = defineEmits<{
  (e: 'request-transcript', recordingId: number): void
}>()

const props = defineProps<{
  audioUrl: string
  durationSeconds: number
  transcript: string | null
  transcriptStatus?: 'pending' | 'converting' | 'completed' | 'failed'
  recordingId?: number
}>()

const isPlaying = ref(false)
const audioRef = ref<HTMLAudioElement | null>(null)
const currentTime = ref(0)
const progressPct = ref(0)

// ── 长按上下文菜单 ──
const showMenu = ref(false)
const menuX = ref(0)
const menuY = ref(0)
let longPressTimer: ReturnType<typeof setTimeout> | null = null
let isLongPress = false
let touchMoved = false

function clearLongPressTimer() {
  if (longPressTimer) { clearTimeout(longPressTimer); longPressTimer = null }
}

function onTouchStart(e: TouchEvent) {
  isLongPress = false
  touchMoved = false
  if (showMenu.value) { showMenu.value = false; return }
  clearLongPressTimer()
  longPressTimer = setTimeout(() => {
    isLongPress = true
    const touch = e.touches[0] || e.changedTouches[0]
    menuX.value = touch.clientX
    menuY.value = touch.clientY
    showMenu.value = true
  }, 500)
}

function onTouchMove() {
  touchMoved = true
  if (touchMoved) clearLongPressTimer()
}

function onTouchEnd() {
  clearLongPressTimer()
}

function closeMenu() {
  showMenu.value = false
}

function onConvertToText() {
  closeMenu()
  if (props.recordingId && props.recordingId > 0) {
    emit('request-transcript', props.recordingId)
  }
}

const durationText = computed(() => formatDuration(props.durationSeconds))

function formatDuration(seconds: number): string {
  const m = Math.floor(seconds / 60)
  const s = Math.floor(seconds % 60)
  return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`
}

function togglePlay() {
  // 长按后不触发播放
  if (isLongPress) return
  if (!audioRef.value) return

  if (isPlaying.value) {
    audioRef.value.pause()
    isPlaying.value = false
  } else {
    audioRef.value.currentTime = 0
    audioRef.value.play().catch(() => {
      isPlaying.value = false
    })
    isPlaying.value = true
  }
}

function onTimeUpdate() {
  if (audioRef.value) {
    currentTime.value = audioRef.value.currentTime
    if (audioRef.value.duration) {
      progressPct.value = (audioRef.value.currentTime / audioRef.value.duration) * 100
    }
  }
}

function onEnded() {
  isPlaying.value = false
  progressPct.value = 0
}

onUnmounted(() => {
  if (audioRef.value) {
    audioRef.value.pause()
    audioRef.value = null
  }
})
</script>

<template>
  <div
    class="voice-bubble"
    @touchstart.passive="onTouchStart"
    @touchmove.passive="onTouchMove"
    @touchend="onTouchEnd"
    @touchcancel="onTouchEnd"
  >
    <!-- 播放按钮 + 波形条 -->
    <div class="voice-play-row" @click.stop="togglePlay">
      <div class="play-icon" :class="{ playing: isPlaying }">
        <svg v-if="!isPlaying" width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
          <polygon points="5,3 19,12 5,21" />
        </svg>
        <svg v-else width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
          <rect x="6" y="4" width="4" height="16" />
          <rect x="14" y="4" width="4" height="16" />
        </svg>
      </div>
      <div class="waveform">
        <span
          v-for="i in 12"
          :key="i"
          class="wave-bar-static"
          :class="{ active: isPlaying && (i / 12 * 100 <= progressPct) }"
          :style="{ height: `${10 + Math.sin(i * 0.8) * 8}px` }"
        />
      </div>
      <span class="voice-duration">{{ durationText }}</span>
    </div>

    <!-- 转写文本 -->
    <div v-if="transcript" class="transcript-area">
      <div class="transcript-label">转写文本</div>
      <div class="transcript-text">{{ transcript }}</div>
    </div>
    <div v-else-if="transcriptStatus === 'converting'" class="transcript-area">
      <div class="transcript-loading">
        <span class="loading-dot-bounce" />
        转写中...
      </div>
    </div>
    <div v-else-if="transcriptStatus === 'failed'" class="transcript-area">
      <div class="transcript-failed">
        转写失败
        <button
          v-if="recordingId && recordingId > 0"
          class="retry-link"
          @click.stop="onConvertToText"
        >重试</button>
      </div>
    </div>

    <!-- 转文字入口（微信式链接） -->
    <div
      v-if="!transcript && transcriptStatus !== 'converting' && recordingId && recordingId > 0"
      class="convert-entry"
      @click.stop="onConvertToText"
    >
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M12 20h9" />
        <path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4L16.5 3.5z" />
      </svg>
      <span>转文字</span>
    </div>

    <!-- 长按上下文菜单（覆盖层） -->
    <Teleport to="body">
      <div v-if="showMenu" class="context-overlay" @click.stop="closeMenu" @touchstart.stop="closeMenu">
        <div
          class="context-menu"
          :style="{ left: menuX + 'px', top: menuY + 'px' }"
          @click.stop
          @touchstart.stop
        >
          <div class="menu-item" @click.stop="onConvertToText">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M12 20h9" />
              <path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4L16.5 3.5z" />
            </svg>
            <span>转文字</span>
          </div>
          <div class="menu-item divider" @click.stop="closeMenu">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <line x1="18" y1="6" x2="6" y2="18" />
              <line x1="6" y1="6" x2="18" y2="18" />
            </svg>
            <span>取消</span>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- 隐藏的 audio 元素 -->
    <audio
      ref="audioRef"
      :src="audioUrl"
      preload="auto"
      @timeupdate="onTimeUpdate"
      @ended="onEnded"
    />
  </div>
</template>

<style scoped>
.voice-bubble {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.voice-play-row {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 12px;
  background: rgba(83, 74, 183, 0.06);
  border-radius: 12px;
  cursor: pointer;
  user-select: none;
  transition: background 0.2s;
}

.voice-play-row:hover {
  background: rgba(83, 74, 183, 0.1);
}

.play-icon {
  width: 28px;
  height: 28px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  background: #534AB7;
  color: #fff;
  flex-shrink: 0;
}

.play-icon.playing {
  background: #909399;
}

.waveform {
  display: flex;
  align-items: flex-end;
  gap: 2px;
  flex: 1;
  height: 28px;
}

.wave-bar-static {
  flex: 1;
  background: #DCDFE6;
  border-radius: 1px;
  transition: background 0.15s;
}

.wave-bar-static.active {
  background: #534AB7;
}

.voice-duration {
  font-size: 12px;
  color: #909399;
  min-width: 36px;
  text-align: right;
  font-variant-numeric: tabular-nums;
}

.transcript-area {
  padding: 10px 12px;
  background: #F5F7FA;
  border-radius: 10px;
}

.transcript-label {
  font-size: 11px;
  color: #909399;
  margin-bottom: 4px;
}

.transcript-text {
  font-size: 14px;
  color: #303133;
  line-height: 1.6;
  white-space: pre-wrap;
  word-break: break-word;
}

.transcript-failed {
  font-size: 13px;
  color: #F56C6C;
  text-align: center;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
}

.retry-link {
  padding: 2px 10px;
  border: 1px solid #534AB7;
  border-radius: 12px;
  background: transparent;
  color: #534AB7;
  font-size: 12px;
  cursor: pointer;
  transition: all 0.2s;
}

.retry-link:hover {
  background: rgba(83, 74, 183, 0.06);
}

/* 转文字入口链接 */
.convert-entry {
  display: flex;
  align-items: center;
  gap: 4px;
  padding: 4px 0;
  color: #534AB7;
  font-size: 12px;
  cursor: pointer;
  user-select: none;
  -webkit-user-select: none;
  opacity: 0.85;
  transition: opacity 0.2s;
}

.convert-entry:hover {
  opacity: 1;
}

.convert-entry svg {
  flex-shrink: 0;
}

/* 长按转写中 loading */
.transcript-loading {
  font-size: 13px;
  color: #909399;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
}

.loading-dot-bounce {
  width: 12px;
  height: 12px;
  border: 2px solid #EBEEF5;
  border-top-color: #534AB7;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
  display: inline-block;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

/* ── 长按上下文菜单 ── */
.context-overlay {
  position: fixed;
  inset: 0;
  z-index: 9999;
  background: rgba(0, 0, 0, 0.15);
}

.context-menu {
  position: fixed;
  z-index: 10000;
  transform: translate(-50%, calc(-100% - 8px));
  background: #fff;
  border-radius: 12px;
  box-shadow: 0 8px 30px rgba(0, 0, 0, 0.18);
  overflow: hidden;
  min-width: 140px;
  animation: menu-in 0.2s ease;
}

@keyframes menu-in {
  from { opacity: 0; transform: translate(-50%, calc(-100% - 4px)) scale(0.95); }
  to   { opacity: 1; transform: translate(-50%, calc(-100% - 8px)) scale(1); }
}

.menu-item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 14px 20px;
  font-size: 15px;
  color: #303133;
  cursor: pointer;
  user-select: none;
  -webkit-user-select: none;
  transition: background 0.15s;
}

.menu-item:hover {
  background: #F5F7FA;
}

.menu-item:active {
  background: #EBEEF5;
}

.menu-item.divider {
  border-top: 1px solid #EBEEF5;
}

.menu-item svg {
  flex-shrink: 0;
  color: #534AB7;
}
</style>
