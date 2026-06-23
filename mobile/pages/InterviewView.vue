<!--
  InterviewView.vue — AI 模拟面试页面
  整合 ChatMessage + VoiceMessageBubble + MobileInputBar
  支持文字和语音混合回答，统一评分流程
-->
<script setup lang="ts">
import { ref, onMounted, nextTick, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import { useInterviewStore } from '@/stores/interview'
import { getVoiceAnalysisApi } from '@/api/voice'
import ChatMessage from '@/components/ChatMessage.vue'
import MobileInputBar from '@/components/MobileInputBar.vue'
import VoiceMessageBubble from '@/components/VoiceMessageBubble.vue'
import type { VoiceRecorderResult } from '@/composables/useVoiceRecorder'
import type { ChatMessage as ChatMessageType } from '@/types'

const route = useRoute()
const router = useRouter()
const store = useInterviewStore()

const sessionId = Number(route.params.sessionId)
const messageListRef = ref<HTMLElement | null>(null)
const isInitializing = ref(true)

// ── 消息列表（混合展示 AI 问题、用户回答、语音消息、评分反馈） ──
interface DisplayMessage {
  id: string
  role: 'ai' | 'user' | 'system'
  type: 'question' | 'answer-text' | 'answer-voice' | 'feedback' | 'system'
  content: string
  audioUrl?: string
  durationSeconds?: number
  transcript?: string | null
  transcriptStatus?: 'pending' | 'converting' | 'completed' | 'failed'
  recordingId?: number
  createdAt: number
}

const messages = ref<DisplayMessage[]>([])
let nextMessageId = 1

function addMessage(msg: Omit<DisplayMessage, 'id' | 'createdAt'>) {
  messages.value.push({
    ...msg,
    id: String(nextMessageId++),
    createdAt: Date.now(),
  })
}

function scrollToBottom() {
  nextTick(() => {
    if (messageListRef.value) {
      messageListRef.value.scrollTop = messageListRef.value.scrollHeight
    }
  })
}

// ── 初始化：开始面试 ──
onMounted(async () => {
  try {
    await store.startSession(sessionId)
    const currentTurn = store.currentTurn
    if (currentTurn) {
      addMessage({
        role: 'ai',
        type: 'question',
        content: currentTurn.question,
      })
      scrollToBottom()
    }
  } catch (err: any) {
    ElMessage.error(err.response?.data?.detail || '加载面试失败')
    router.replace('/interview-history')
  } finally {
    isInitializing.value = false
  }
})

// ── 发送文字回答 ──
async function handleSendText(text: string) {
  try {
    addMessage({
      role: 'user',
      type: 'answer-text',
      content: text,
    })

    const result = await store.submitAnswer({
      answer_text: text,
    })

    const answeredTurn = result.turns.find(
      (t) => t.question_index === (store.answeredTurns.length)
    )
    if (answeredTurn) {
      addMessage({
        role: 'system',
        type: 'feedback',
        content: answeredTurn.feedback || '评分完成',
      })
    }

    // 下一题
    const nextTurn = result.turns.find((t) => t.answered_at === null)
    if (nextTurn) {
      addMessage({
        role: 'ai',
        type: 'question',
        content: nextTurn.question,
      })
    } else {
      // 没有下一题，自动结束
      await handleFinish()
    }
  } catch (err: any) {
    ElMessage.error(err.response?.data?.detail || '提交失败')
    // 移除失败的消息
    messages.value.pop()
  }
  scrollToBottom()
}

// ── 语音回答 ──
async function handleVoiceResult(result: VoiceRecorderResult) {
  const transcript = result.extra.transcript || ''
  const audioUrl = result.extra.audio_url || ''

  // 防空保护：如果既没有转写文本也没有音频地址，提示用户
  if (!transcript && !audioUrl) {
    ElMessage.warning('语音上传成功，但转写结果暂未就绪。请稍后重试或使用文字输入。')
    // 仍然展示语音气泡
    addMessage({
      role: 'user',
      type: 'answer-voice',
      content: '',
      audioUrl: result.audioBlob ? URL.createObjectURL(result.audioBlob) : '',
      durationSeconds: result.duration,
      transcript: null,
      transcriptStatus: 'pending',
      recordingId: result.extra.recording_id || 0,
    })
    scrollToBottom()
    return
  }

  try {
    addMessage({
      role: 'user',
      type: 'answer-voice',
      content: '',
      audioUrl: result.audioBlob ? URL.createObjectURL(result.audioBlob) : audioUrl,
      durationSeconds: result.duration,
      transcript: transcript || null,
      transcriptStatus: transcript ? 'completed' : 'pending',
      recordingId: result.extra.recording_id || 0,
    })

    const params: any = { answer_duration_seconds: result.duration }
    // 优先用转写文本，没有时留空让后端通过 audioUrl 处理
    if (transcript) {
      params.answer_text = transcript
    }
    if (audioUrl) {
      params.answer_audio_url = audioUrl
    }
    if (result.extra.recording_id) {
      params.recording_id = result.extra.recording_id
    }

    const sessionResult = await store.submitAnswer(params)

    const answeredTurn = sessionResult.turns.find(
      (t) => t.question_index === (store.answeredTurns.length)
    )
    if (answeredTurn) {
      addMessage({
        role: 'system',
        type: 'feedback',
        content: answeredTurn.feedback || '评分完成',
      })
    }

    const nextTurn = sessionResult.turns.find((t) => t.answered_at === null)
    if (nextTurn) {
      addMessage({
        role: 'ai',
        type: 'question',
        content: nextTurn.question,
      })
    } else {
      await handleFinish()
    }
  } catch (err: any) {
    ElMessage.error(err.response?.data?.detail || '提交失败')
    messages.value.pop()
  }
  scrollToBottom()
}

// ── 语音错误 ──
function handleVoiceError(msg: string) {
  ElMessage.warning(msg)
}

// ── 语音转文字（长按触发） ──
async function handleRequestTranscript(msgId: string, recordingId: number) {
  if (recordingId <= 0) {
    ElMessage.warning('录音未成功上传，无法转文字')
    return
  }

  // 找到对应消息并标记为转写中
  const msgIndex = messages.value.findIndex((m) => m.id === msgId)
  if (msgIndex === -1) return
  messages.value[msgIndex] = {
    ...messages.value[msgIndex],
    transcriptStatus: 'converting',
  }

  try {
    const res = await getVoiceAnalysisApi(recordingId)
    const transcript = res.data?.transcript || ''

    if (transcript) {
      messages.value[msgIndex] = {
        ...messages.value[msgIndex],
        transcript,
        transcriptStatus: 'completed',
      }
      ElMessage.success('转写完成')
    } else {
      messages.value[msgIndex] = {
        ...messages.value[msgIndex],
        transcriptStatus: 'failed',
      }
      ElMessage.warning('暂未获取到转写结果，请稍后重试')
    }
  } catch (err: any) {
    messages.value[msgIndex] = {
      ...messages.value[msgIndex],
      transcriptStatus: 'failed',
    }
    ElMessage.error(err.response?.data?.detail || '转写失败，请稍后重试')
  }
}

// ── 结束面试 ──
async function handleFinish() {
  try {
    await ElMessageBox.confirm('确认结束面试？结束后将生成报告。', '结束面试', {
      confirmButtonText: '确认结束',
      cancelButtonText: '继续答题',
    })
    const report = await store.finishSession(sessionId)
    addMessage({
      role: 'system',
      type: 'system',
      content: `面试结束！总分：${report.total_score} 分`,
    })
    scrollToBottom()
    // 延迟跳转到报告页
    setTimeout(() => {
      router.push(`/interview/${sessionId}/report`)
    }, 1500)
  } catch {
    // 用户取消
  }
}

// ── 转换消息为 ChatMessage 兼容格式 ──
function toChatMessage(msg: DisplayMessage): ChatMessageType {
  return {
    id: msg.id,
    conversation_id: sessionId,
    role: msg.role as any,
    content: msg.content,
    message_type: msg.type === 'answer-voice' ? 'text' as any : 'text',
    created_at: new Date(msg.createdAt).toISOString(),
  } as ChatMessageType
}

watch(() => messages.value.length, scrollToBottom)
</script>

<template>
  <div class="interview-view">
    <!-- 顶部栏 -->
    <header class="interview-header">
      <button class="back-btn" @click="router.push('/interview-history')">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <polyline points="15,18 9,12 15,6" />
        </svg>
      </button>
      <div class="header-info">
        <h2 class="header-title">AI 模拟面试</h2>
        <div class="header-progress">
          <div class="progress-bar">
            <div class="progress-fill" :style="{ width: store.progress + '%' }" />
          </div>
          <span class="progress-text">{{ store.answeredTurns.length }}/{{ store.currentSession?.question_count || 0 }}</span>
        </div>
      </div>
      <button class="finish-btn" @click="handleFinish">结束</button>
    </header>

    <!-- 消息列表 -->
    <div v-if="isInitializing" class="loading-state">
      <div class="loading-spinner" />
      <span>正在准备面试...</span>
    </div>

    <div v-else ref="messageListRef" class="message-area">
      <template v-for="msg in messages" :key="msg.id">
        <!-- AI 问题：使用 ChatMessage -->
        <div v-if="msg.role === 'ai' || msg.role === 'system'" class="message-wrapper ai-message">
          <ChatMessage :message="toChatMessage(msg)" />
        </div>

        <!-- 用户文字回答 -->
        <div v-else-if="msg.type === 'answer-text'" class="message-wrapper user-message">
          <div class="user-bubble">
            <div class="user-text">{{ msg.content }}</div>
          </div>
        </div>

        <!-- 用户语音回答 -->
        <div v-else-if="msg.type === 'answer-voice'" class="message-wrapper user-message">
          <div class="user-voice-bubble">
            <VoiceMessageBubble
              :audio-url="msg.audioUrl || ''"
              :duration-seconds="msg.durationSeconds || 0"
              :transcript="msg.transcript || null"
              :transcript-status="msg.transcriptStatus || 'pending'"
              :recording-id="msg.recordingId || 0"
              @request-transcript="handleRequestTranscript(msg.id, $event)"
            />
          </div>
        </div>
      </template>
    </div>

    <!-- 底部输入栏 -->
    <footer class="interview-footer">
      <MobileInputBar
        :disabled="store.isFinished || store.isSubmitting"
        :loading="store.isSubmitting"
        @send-text="handleSendText"
        @voice-result="handleVoiceResult"
        @voice-error="handleVoiceError"
      />
    </footer>
  </div>
</template>

<style scoped>
.interview-view {
  display: flex;
  flex-direction: column;
  height: 100vh;
  max-width: 768px;
  margin: 0 auto;
  background: #F5F7FA;
}

/* 顶部 */
.interview-header {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 16px;
  background: #fff;
  border-bottom: 1px solid #EBEEF5;
  flex-shrink: 0;
}

.back-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 36px;
  height: 36px;
  border: none;
  border-radius: 50%;
  background: transparent;
  color: #606266;
  cursor: pointer;
  transition: background 0.2s;
  flex-shrink: 0;
}

.back-btn:hover {
  background: #F5F7FA;
}

.header-info {
  flex: 1;
  min-width: 0;
}

.header-title {
  font-size: 16px;
  font-weight: 600;
  color: #303133;
  margin: 0 0 6px;
}

.header-progress {
  display: flex;
  align-items: center;
  gap: 8px;
}

.progress-bar {
  flex: 1;
  height: 4px;
  background: #EBEEF5;
  border-radius: 2px;
  overflow: hidden;
}

.progress-fill {
  height: 100%;
  background: linear-gradient(90deg, #534AB7, #6366F1);
  border-radius: 2px;
  transition: width 0.4s ease;
}

.progress-text {
  font-size: 12px;
  color: #909399;
  flex-shrink: 0;
}

.finish-btn {
  padding: 6px 16px;
  border: 1px solid #F56C6C;
  border-radius: 16px;
  background: #fff;
  color: #F56C6C;
  font-size: 13px;
  cursor: pointer;
  transition: all 0.2s;
  flex-shrink: 0;
}

.finish-btn:hover {
  background: #FEF0F0;
}

/* 加载 */
.loading-state {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 16px;
  color: #909399;
}

.loading-spinner {
  width: 32px;
  height: 32px;
  border: 3px solid #EBEEF5;
  border-top-color: #534AB7;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

/* 消息区域 */
.message-area {
  flex: 1;
  overflow-y: auto;
  padding: 16px;
  display: flex;
  flex-direction: column;
  gap: 16px;
}

/* 用户消息气泡 */
.message-wrapper {
  max-width: 85%;
}

.message-wrapper.ai-message {
  align-self: flex-start;
  width: 100%;
  max-width: 100%;
}

.message-wrapper.user-message {
  align-self: flex-end;
}

.user-bubble {
  background: linear-gradient(135deg, #534AB7, #6366F1);
  color: #fff;
  padding: 10px 16px;
  border-radius: 16px 4px 16px 16px;
  font-size: 15px;
  line-height: 1.5;
  word-break: break-word;
}

.user-text {
  white-space: pre-wrap;
}

.user-voice-bubble {
  background: #fff;
  padding: 10px 14px;
  border-radius: 16px 4px 16px 16px;
  min-width: 200px;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.06);
}

/* 底部输入 */
.interview-footer {
  flex-shrink: 0;
  padding: 10px 16px;
  padding-bottom: max(10px, env(safe-area-inset-bottom));
  background: #fff;
  border-top: 1px solid #EBEEF5;
}
</style>
