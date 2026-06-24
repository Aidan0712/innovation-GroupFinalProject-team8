<script setup lang="ts">
import { computed, ref } from 'vue'
import type { VoiceRecorderResult } from '@/composables/useVoiceRecorder'
import VoiceRecordButton from './VoiceRecordButton.vue'

const props = withDefaults(defineProps<{
  disabled?: boolean
  loading?: boolean
}>(), {
  disabled: false,
  loading: false,
})

const emit = defineEmits<{
  (e: 'send-text', text: string): void
  (e: 'voice-result', result: VoiceRecorderResult): void
  (e: 'voice-error', message: string): void
}>()

const inputMode = ref<'text' | 'voice'>('text')
const textValue = ref('')

const canSend = computed(() => textValue.value.trim().length > 0 && !props.disabled && !props.loading)
const showSecurityHint = computed(() => {
  if (typeof window === 'undefined') return false
  if (window.isSecureContext) return false
  return !['localhost', '127.0.0.1'].includes(window.location.hostname)
})

function sendText() {
  const text = textValue.value.trim()
  if (!text || !canSend.value) return
  emit('send-text', text)
  textValue.value = ''
}

function handleKeydown(event: KeyboardEvent) {
  if (event.key === 'Enter' && !event.shiftKey) {
    event.preventDefault()
    sendText()
  }
}

function handleVoiceResult(result: VoiceRecorderResult) {
  emit('voice-result', result)
}

function handleVoiceError(message: string) {
  emit('voice-error', message)
}
</script>

<template>
  <div class="answer-bar">
    <div class="mode-switch">
      <button
        class="mode-chip"
        :class="{ active: inputMode === 'text' }"
        type="button"
        @click="inputMode = 'text'"
      >
        文字回答
      </button>
      <button
        class="mode-chip"
        :class="{ active: inputMode === 'voice' }"
        type="button"
        @click="inputMode = 'voice'"
      >
        语音回答
      </button>
    </div>

    <div v-if="inputMode === 'text'" class="text-panel">
      <textarea
        v-model="textValue"
        class="answer-textarea"
        :disabled="disabled || loading"
        placeholder="建议按 STAR 结构回答：背景、任务、行动、结果，并补充技术细节和量化成果。"
        rows="6"
        @keydown="handleKeydown"
      />
      <div class="text-actions">
        <span class="text-hint">Enter 发送，Shift + Enter 换行</span>
        <button
          class="submit-button"
          :disabled="!canSend"
          type="button"
          @click="sendText"
        >
          {{ loading ? '提交中...' : '提交回答并评分' }}
        </button>
      </div>
    </div>

    <div v-else class="voice-panel">
      <div v-if="showSecurityHint" class="security-tip">
        当前地址不是 HTTPS。手机浏览器通常会拦截麦克风权限，如果要在手机上录音，请优先使用 HTTPS 页面。
      </div>
      <VoiceRecordButton
        :disabled="disabled || loading"
        @result="handleVoiceResult"
        @error="handleVoiceError"
      />
    </div>
  </div>
</template>

<style scoped>
.answer-bar {
  display: grid;
  gap: 14px;
}

.mode-switch {
  display: inline-flex;
  gap: 8px;
  padding: 6px;
  border-radius: 999px;
  background: rgba(15, 23, 42, 0.04);
  width: fit-content;
}

.mode-chip {
  border: none;
  border-radius: 999px;
  background: transparent;
  color: var(--color-text-secondary);
  padding: 8px 14px;
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
  transition: background 0.18s ease, color 0.18s ease;
}

.mode-chip.active {
  background: #fff;
  color: var(--color-primary);
  box-shadow: 0 6px 18px rgba(15, 23, 42, 0.08);
}

.text-panel,
.voice-panel {
  display: grid;
  gap: 12px;
}

.answer-textarea {
  width: 100%;
  resize: vertical;
  min-height: 148px;
  border: 1px solid var(--color-border);
  border-radius: 18px;
  padding: 14px 16px;
  font: inherit;
  line-height: 1.6;
  background: rgba(255, 255, 255, 0.92);
  color: var(--color-text);
  outline: none;
}

.answer-textarea:focus {
  border-color: rgba(83, 74, 183, 0.42);
  box-shadow: 0 0 0 4px rgba(83, 74, 183, 0.08);
}

.text-actions {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  flex-wrap: wrap;
}

.text-hint,
.security-tip {
  color: var(--color-text-secondary);
  font-size: 13px;
  line-height: 1.5;
}

.security-tip {
  padding: 12px 14px;
  border-radius: 14px;
  background: rgba(245, 108, 108, 0.08);
  color: #b93838;
}

.submit-button {
  border: none;
  border-radius: 14px;
  padding: 12px 18px;
  background: var(--theme-gradient);
  color: #fff;
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
  box-shadow: 0 10px 20px rgba(83, 74, 183, 0.18);
}

.submit-button:disabled {
  cursor: not-allowed;
  opacity: 0.65;
  box-shadow: none;
}

@media (max-width: 768px) {
  .mode-switch {
    width: 100%;
    justify-content: space-between;
  }

  .mode-chip {
    flex: 1;
  }

  .text-actions {
    align-items: stretch;
  }

  .submit-button {
    width: 100%;
  }
}
</style>
