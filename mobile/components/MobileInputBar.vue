<!--
  MobileInputBar.vue — 移动端输入栏
  支持文字输入和语音输入在同一面试页面中切换
-->
<script setup lang="ts">
import { ref, computed } from 'vue'
import VoiceRecorder from './VoiceRecorder.vue'

const emit = defineEmits<{
  (e: 'send-text', text: string): void
  (e: 'voice-result', result: any): void
  (e: 'voice-error', message: string): void
}>()

const props = withDefaults(defineProps<{
  disabled?: boolean
  loading?: boolean
}>(), {
  disabled: false,
  loading: false,
})

type InputMode = 'text' | 'voice'
const inputMode = ref<InputMode>('text')
const inputText = ref('')

const canSend = computed(() => inputText.value.trim().length > 0 && !props.disabled)

function handleSend() {
  const text = inputText.value.trim()
  if (!text || props.disabled) return
  emit('send-text', text)
  inputText.value = ''
}

function handleKeyDown(e: KeyboardEvent) {
  if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault()
    handleSend()
  }
}

function handleVoiceResult(result: any) {
  emit('voice-result', result)
}

function handleVoiceError(msg: string) {
  emit('voice-error', msg)
}
</script>

<template>
  <div class="mobile-input-bar">
    <!-- 文字输入模式 -->
    <div v-if="inputMode === 'text'" class="text-mode">
      <div class="text-input-row">
        <input
          v-model="inputText"
          type="text"
          class="text-input"
          placeholder="输入你的回答..."
          :disabled="disabled"
          @keydown="handleKeyDown"
        />
        <button
          class="send-button"
          :class="{ disabled: !canSend }"
          :disabled="!canSend || loading"
          @click="handleSend"
        >
          <span v-if="loading" class="loading-dot">...</span>
          <span v-else>发送</span>
        </button>
      </div>
    </div>

    <!-- 语音输入模式 -->
    <div v-else class="voice-mode">
      <VoiceRecorder
        @result="handleVoiceResult"
        @error="handleVoiceError"
      />
    </div>

    <!-- 切换按钮 -->
    <div class="mode-toggle">
      <button
        class="toggle-btn"
        :class="{ active: inputMode === 'text' }"
        @click="inputMode = 'text'"
      >
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <polyline points="4 7 4 4 20 4 20 7" />
          <line x1="9.5" y1="20" x2="14.5" y2="20" />
          <line x1="12" y1="4" x2="12" y2="20" />
        </svg>
        <span>文字</span>
      </button>
      <button
        class="toggle-btn"
        :class="{ active: inputMode === 'voice' }"
        @click="inputMode = 'voice'"
      >
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z" />
          <path d="M19 10v2a7 7 0 0 1-14 0v-2" />
          <line x1="12" y1="19" x2="12" y2="23" />
          <line x1="8" y1="23" x2="16" y2="23" />
        </svg>
        <span>语音</span>
      </button>
    </div>
  </div>
</template>

<style scoped>
.mobile-input-bar {
  display: flex;
  flex-direction: column;
  gap: 8px;
  width: 100%;
  padding: 8px 0;
}

/* 文字模式 */
.text-mode {
  width: 100%;
}

.text-input-row {
  display: flex;
  align-items: center;
  gap: 8px;
}

.text-input {
  flex: 1;
  height: 44px;
  padding: 0 16px;
  border: 1px solid #DCDFE6;
  border-radius: 22px;
  font-size: 15px;
  color: #303133;
  background: #fff;
  outline: none;
  transition: border-color 0.2s;
}

.text-input:focus {
  border-color: #534AB7;
}

.text-input:disabled {
  background: #F5F7FA;
  cursor: not-allowed;
}

.text-input::placeholder {
  color: #C0C4CC;
}

.send-button {
  flex-shrink: 0;
  height: 44px;
  padding: 0 20px;
  border: none;
  border-radius: 22px;
  background: linear-gradient(135deg, #534AB7, #6366F1);
  color: #fff;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.send-button:hover {
  opacity: 0.9;
}

.send-button:active {
  transform: scale(0.96);
}

.send-button.disabled {
  background: #C0C4CC;
  cursor: not-allowed;
}

.send-button:disabled {
  background: #C0C4CC;
  cursor: not-allowed;
}

/* 语音模式 */
.voice-mode {
  width: 100%;
}

/* 切换按钮 */
.mode-toggle {
  display: flex;
  justify-content: center;
  gap: 4px;
  padding: 4px;
  background: #F5F7FA;
  border-radius: 20px;
  width: fit-content;
  margin: 0 auto;
}

.toggle-btn {
  display: flex;
  align-items: center;
  gap: 4px;
  padding: 6px 16px;
  border: none;
  border-radius: 16px;
  background: transparent;
  font-size: 13px;
  color: #909399;
  cursor: pointer;
  transition: all 0.2s;
}

.toggle-btn.active {
  background: #fff;
  color: #534AB7;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.08);
}

.toggle-btn:hover:not(.active) {
  color: #606266;
}
</style>
