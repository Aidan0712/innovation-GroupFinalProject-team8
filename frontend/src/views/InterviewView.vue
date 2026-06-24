<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { useChatStore } from '@/stores/chat'
import AppHeader from '@/components/AppHeader.vue'
import Sidebar from '@/components/Sidebar.vue'
import InterviewAnswerBar from '@/components/interview/InterviewAnswerBar.vue'
import type { VoiceRecorderResult } from '@/composables/useVoiceRecorder'
import {
  answerInterviewSessionApi,
  createInterviewSessionApi,
  finishInterviewSessionApi,
  getInterviewReportApi,
  getInterviewReportDownloadUrl,
  getInterviewSessionDetailApi,
  startInterviewSessionApi,
  type InterviewAnswerParams,
  type InterviewReport,
  type InterviewSession,
  type InterviewTurn,
} from '@/api/interview'

const route = useRoute()
const router = useRouter()
const chatStore = useChatStore()

const loading = ref(false)
const downloading = ref(false)
const session = ref<InterviewSession | null>(null)
const report = ref<InterviewReport | null>(null)
const selectedHistoryId = ref<number | null>(null)
const answerStartedAt = ref<number | null>(null)

const form = reactive({
  target_position: '前端开发工程师',
  interview_type: 'technical' as 'technical' | 'behavioral' | 'comprehensive',
  difficulty: 'medium' as 'easy' | 'medium' | 'hard',
  question_count: 5,
})

const interviewTypeOptions = [
  { label: '技术面试', value: 'technical' },
  { label: '行为面试', value: 'behavioral' },
  { label: '综合面试', value: 'comprehensive' },
]

const difficultyOptions = [
  { label: '基础', value: 'easy' },
  { label: '进阶', value: 'medium' },
  { label: '深入', value: 'hard' },
]

const dimensionMax: Record<string, number> = {
  岗位相关性: 18,
  技术深度: 24,
  逻辑结构: 18,
  案例与结果: 18,
  表达沟通: 12,
  时间控制: 10,
}

const currentConversationId = computed<number | undefined>(() => {
  const queryId = Number(route.query.conversation_id)
  const storeId = Number(chatStore.currentConversationId)
  if (Number.isFinite(queryId) && queryId > 0) return queryId
  if (Number.isFinite(storeId) && storeId > 0) return storeId
  return undefined
})

const answeredTurns = computed(() => {
  return (session.value?.turns || []).filter((item) => item.answered_at)
})

const activeTurn = computed<InterviewTurn | null>(() => {
  if (session.value?.status === 'finished') return null
  const turns = session.value?.turns || []
  return turns.find((item) => !item.answered_at) || null
})

const isAllAnswered = computed(() => {
  return !!session.value && answeredTurns.value.length >= session.value.question_count
})

const reportReady = computed(() => session.value?.status === 'finished' && !!report.value)

function resetAnswerTimer() {
  answerStartedAt.value = Date.now()
}

function goBackToChat() {
  router.push('/')
}

function resetInterview() {
  session.value = null
  report.value = null
  selectedHistoryId.value = null
  answerStartedAt.value = null
}

function formatStatus(value: string) {
  if (value === 'finished') return '已结束'
  if (value === 'in_progress') return '进行中'
  return '未开始'
}

function scoreStatus(score?: number | null) {
  if (score == null) return 'info'
  if (score >= 85) return 'success'
  if (score >= 70) return 'warning'
  return 'danger'
}

function notifyInterviewHistoryUpdated() {
  window.dispatchEvent(new Event('interview-history-updated'))
}

async function ensureConversationContext() {
  if (currentConversationId.value) return currentConversationId.value
  await chatStore.createConversation('AI面试', 'interview')
  const id = Number(chatStore.currentConversationId)
  if (Number.isFinite(id) && id > 0) {
    await router.replace({
      path: '/interview',
      query: { conversation_id: String(id) },
    })
    return id
  }
  return undefined
}

async function openHistoryById(sessionId: number) {
  if (!Number.isFinite(sessionId) || sessionId <= 0) return
  loading.value = true
  selectedHistoryId.value = sessionId
  try {
    const detail = await getInterviewSessionDetailApi(sessionId)
    session.value = detail.data
    report.value = detail.data.report || null
    if (detail.data.status === 'finished') {
      try {
        const reportRes = await getInterviewReportApi(sessionId)
        report.value = reportRes.data
      } catch {
        report.value = detail.data.report || null
      }
    } else {
      resetAnswerTimer()
    }
  } finally {
    loading.value = false
  }
}

async function createAndStartInterview() {
  if (!form.target_position.trim()) {
    ElMessage.warning('请输入目标岗位')
    return
  }

  loading.value = true
  report.value = null
  try {
    const created = await createInterviewSessionApi({
      title: `${form.target_position} AI面试`,
      conversation_id: await ensureConversationContext(),
      target_position: form.target_position.trim(),
      interview_type: form.interview_type,
      difficulty: form.difficulty,
      question_count: form.question_count,
      answer_mode: 'mixed',
    })
    const started = await startInterviewSessionApi(created.data.id)
    session.value = started.data
    selectedHistoryId.value = started.data.id
    resetAnswerTimer()
    const conversationId = started.data.conversation_id || currentConversationId.value
    if (conversationId) {
      await router.replace({
        path: '/interview',
        query: {
          conversation_id: String(conversationId),
          session_id: String(started.data.id),
        },
      })
    }
    notifyInterviewHistoryUpdated()
    ElMessage.success('AI 面试已开始')
  } finally {
    loading.value = false
  }
}

async function submitAnswerPayload(payload: InterviewAnswerParams, successMessage: string) {
  if (!session.value || !activeTurn.value) return

  const duration = answerStartedAt.value
    ? Math.max(1, Math.round((Date.now() - answerStartedAt.value) / 1000))
    : payload.answer_duration_seconds

  loading.value = true
  try {
    const res = await answerInterviewSessionApi(session.value.id, {
      ...payload,
      answer_duration_seconds: duration,
    })
    session.value = res.data
    resetAnswerTimer()
    notifyInterviewHistoryUpdated()
    ElMessage.success(successMessage)
  } finally {
    loading.value = false
  }
}

async function handleTextAnswer(text: string) {
  await submitAnswerPayload({ answer_text: text }, '文字回答已提交，评分已更新')
}

async function handleVoiceResult(result: VoiceRecorderResult) {
  const payload: InterviewAnswerParams = {
    answer_duration_seconds: result.duration,
  }

  if (result.extra.transcript) {
    payload.answer_text = result.extra.transcript
  }
  if (result.extra.audio_url) {
    payload.answer_audio_url = result.extra.audio_url
  }
  if (result.extra.recording_id > 0) {
    payload.recording_id = result.extra.recording_id
  }

  if (!payload.answer_text && !payload.answer_audio_url && !payload.recording_id) {
    ElMessage.warning('本次录音未能成功上传，请重试一次')
    return
  }

  await submitAnswerPayload(payload, '语音回答已提交，评分已更新')
}

function handleVoiceError(message: string) {
  ElMessage.warning(message)
}

async function finishInterview() {
  if (!session.value) return
  loading.value = true
  try {
    const res = await finishInterviewSessionApi(session.value.id)
    report.value = res.data
    session.value = {
      ...session.value,
      status: 'finished',
      total_score: res.data.total_score,
      report: res.data,
    }
    notifyInterviewHistoryUpdated()
    ElMessage.success('面试报告已生成')
  } finally {
    loading.value = false
  }
}

async function downloadReport() {
  if (!session.value) return
  downloading.value = true
  try {
    const token = localStorage.getItem('access_token')
    const response = await fetch(getInterviewReportDownloadUrl(session.value.id), {
      headers: token ? { Authorization: `Bearer ${token}` } : undefined,
    })
    if (!response.ok) {
      ElMessage.error('报告下载失败')
      return
    }
    const blob = await response.blob()
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = `${session.value.title}-面试报告.docx`
    link.click()
    URL.revokeObjectURL(url)
  } finally {
    downloading.value = false
  }
}

watch(
  () => Number(route.query.session_id) || null,
  (sessionId) => {
    if (sessionId && selectedHistoryId.value !== sessionId) {
      openHistoryById(sessionId)
    }
  },
  { immediate: true },
)

watch(currentConversationId, () => {
  if (!route.query.session_id) {
    resetInterview()
  }
})

onMounted(() => {
  notifyInterviewHistoryUpdated()
})
</script>

<template>
  <div class="interview-layout">
    <AppHeader />

    <div class="interview-body">
      <Sidebar />

      <main class="interview-main">
        <section class="setup-panel">
          <div class="panel-title">
            <div>
              <h1>AI 面试室</h1>
              <p>按岗位生成问题，支持文字和语音混合回答，结束后自动生成详细报告。</p>
            </div>
            <div class="panel-actions">
              <el-button :icon="'Back'" @click="goBackToChat">返回对话</el-button>
              <el-button type="primary" :loading="loading" :icon="'VideoPlay'" @click="createAndStartInterview">
                开始面试
              </el-button>
            </div>
          </div>

          <el-form :model="form" class="setup-form" label-position="top">
            <el-form-item label="目标岗位">
              <el-input v-model="form.target_position" placeholder="例如：前端开发工程师" />
            </el-form-item>
            <el-form-item label="面试类型">
              <el-segmented v-model="form.interview_type" :options="interviewTypeOptions" />
            </el-form-item>
            <el-form-item label="难度">
              <el-segmented v-model="form.difficulty" :options="difficultyOptions" />
            </el-form-item>
            <el-form-item label="题目数量">
              <el-input-number v-model="form.question_count" :min="1" :max="10" />
            </el-form-item>
          </el-form>
        </section>

        <section v-if="session" class="workspace">
          <div class="question-panel">
            <div class="session-bar">
              <div class="session-bar-main">
                <span class="session-title">{{ session.title }}</span>
                <el-tag :type="session.status === 'finished' ? 'success' : 'primary'">
                  {{ formatStatus(session.status) }}
                </el-tag>
              </div>
              <span class="session-progress">{{ answeredTurns.length }} / {{ session.question_count }}</span>
            </div>

            <div v-if="activeTurn" class="question-box">
              <div class="question-index">第 {{ activeTurn.question_index }} 题</div>
              <p class="question-text">{{ activeTurn.question }}</p>

              <InterviewAnswerBar
                :disabled="loading"
                :loading="loading"
                @send-text="handleTextAnswer"
                @voice-result="handleVoiceResult"
                @voice-error="handleVoiceError"
              />

              <div class="question-actions">
                <el-button
                  :disabled="answeredTurns.length === 0"
                  :loading="loading"
                  :icon="'DocumentChecked'"
                  @click="finishInterview"
                >
                  {{ isAllAnswered ? '结束并生成报告' : '提前结束并生成报告' }}
                </el-button>
              </div>
            </div>

            <div v-else class="finished-box">
              <el-icon :size="42"><CircleCheck /></el-icon>
              <h2>{{ reportReady ? '面试已结束' : '题目已完成' }}</h2>
              <p>
                {{
                  reportReady
                    ? '你已经完成本轮 AI 面试，下面可以查看综合评分和逐题反馈。'
                    : '所有题目已作答完成，点击下方按钮生成最终报告。'
                }}
              </p>
              <div class="question-actions">
                <el-button
                  v-if="session.status !== 'finished'"
                  type="primary"
                  :loading="loading"
                  :icon="'DocumentChecked'"
                  @click="finishInterview"
                >
                  生成面试报告
                </el-button>
                <el-button
                  v-else
                  type="primary"
                  :icon="'VideoPlay'"
                  @click="resetInterview"
                >
                  重新开始
                </el-button>
              </div>
            </div>
          </div>

          <div class="result-panel">
            <div class="result-panel-header">
              <h2>评分记录</h2>
              <span class="result-panel-tip">每次提交都会在这里追加评分</span>
            </div>

            <div v-if="answeredTurns.length === 0" class="empty-result">
              提交第一题后，这里会显示逐题得分、反馈和改进建议。
            </div>

            <div v-for="turn in answeredTurns" :key="turn.id" class="turn-result">
              <div class="turn-head">
                <span>第 {{ turn.question_index }} 题</span>
                <el-tag :type="scoreStatus(turn.score)">{{ turn.score }}/100</el-tag>
              </div>
              <p class="turn-answer" v-if="turn.answer_text">{{ turn.answer_text }}</p>
              <div class="turn-meta" v-if="turn.answer_duration_seconds || turn.answer_audio_url">
                <span v-if="turn.answer_duration_seconds">回答时长 {{ turn.answer_duration_seconds }} 秒</span>
                <span v-if="turn.answer_audio_url">含语音作答</span>
              </div>
              <p class="feedback">{{ turn.feedback }}</p>
              <p class="suggestion">{{ turn.suggestion }}</p>
            </div>
          </div>
        </section>

        <section v-if="report" class="report-panel">
          <div class="report-header">
            <div class="report-score">
              <span>综合评分</span>
              <strong>{{ report.total_score }}</strong>
            </div>

            <div class="report-summary">
              <div class="report-title-row">
                <h2>面试报告</h2>
                <div class="panel-actions">
                  <el-button :icon="'VideoPlay'" @click="resetInterview">重新开始</el-button>
                  <el-button :loading="downloading" :icon="'Download'" @click="downloadReport">
                    下载 Word
                  </el-button>
                </div>
              </div>
              <p>{{ report.summary }}</p>
              <p class="score-basis">{{ report.score_basis }}</p>
            </div>
          </div>

          <div v-if="report.dimension_scores" class="dimension-grid">
            <div v-for="(value, name) in report.dimension_scores" :key="name" class="dimension-item">
              <div class="dimension-line">
                <span>{{ name }}</span>
                <strong>{{ value }}/{{ dimensionMax[name] || 100 }}</strong>
              </div>
              <el-progress
                :percentage="Math.round((value / (dimensionMax[name] || 100)) * 100)"
                :stroke-width="8"
                :show-text="false"
              />
            </div>
          </div>

          <div class="report-columns">
            <div>
              <h3>优势</h3>
              <ul>
                <li v-for="item in report.strengths" :key="item">{{ item }}</li>
              </ul>
            </div>
            <div>
              <h3>不足</h3>
              <ul>
                <li v-for="item in report.weaknesses" :key="item">{{ item }}</li>
              </ul>
            </div>
          </div>

          <div class="turn-analysis">
            <h3>逐题评分依据</h3>
            <div v-for="item in report.turn_performance" :key="item.question_index" class="analysis-card">
              <div class="turn-head">
                <span>第 {{ item.question_index }} 题</span>
                <el-tag :type="scoreStatus(item.score)">{{ item.score }}/100</el-tag>
              </div>
              <p class="question-text">{{ item.question }}</p>
              <p class="time-text">回答时长：{{ item.answer_duration_seconds ?? '未记录' }} 秒</p>
              <div v-if="item.dimensions" class="mini-dimensions">
                <span v-for="(value, name) in item.dimensions" :key="name">
                  {{ name }} {{ value }}/{{ dimensionMax[name] || 100 }}
                </span>
              </div>
              <div class="evidence-grid">
                <div>
                  <h4>评分依据</h4>
                  <ul>
                    <li v-for="evidence in item.evidence" :key="evidence">{{ evidence }}</li>
                  </ul>
                </div>
                <div>
                  <h4>扣分点</h4>
                  <ul>
                    <li v-for="point in item.missing_points" :key="point">{{ point }}</li>
                  </ul>
                </div>
              </div>
              <p class="suggestion">{{ item.suggestion }}</p>
            </div>
          </div>

          <div class="report-columns">
            <div>
              <h3>改进建议</h3>
              <ul>
                <li v-for="item in report.suggestions" :key="item">{{ item }}</li>
              </ul>
            </div>
            <div>
              <h3>训练计划</h3>
              <ol>
                <li v-for="item in report.action_plan" :key="item">{{ item }}</li>
              </ol>
            </div>
          </div>
        </section>
      </main>
    </div>
  </div>
</template>

<style scoped>
.interview-layout {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  background:
    radial-gradient(circle at top, rgba(83, 74, 183, 0.14), transparent 36%),
    var(--color-bg);
}

.interview-body {
  flex: 1;
  min-height: 0;
  display: flex;
}

.interview-main {
  flex: 1;
  min-width: 0;
  overflow-y: auto;
  padding: 24px;
}

.setup-panel,
.question-panel,
.result-panel,
.report-panel {
  background: rgba(255, 255, 255, 0.88);
  border: 1px solid var(--color-border-light);
  border-radius: 24px;
  box-shadow: 0 16px 40px rgba(15, 23, 42, 0.06);
  backdrop-filter: blur(14px);
}

.setup-panel {
  padding: 22px;
  margin-bottom: 16px;
}

.panel-title,
.session-bar,
.turn-head,
.report-title-row,
.dimension-line {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
}

.panel-title h1,
.result-panel h2,
.report-panel h2,
.report-panel h3,
.report-panel h4 {
  margin: 0;
}

.panel-title p,
.score-basis,
.feedback,
.suggestion,
.question-text,
.time-text,
.report-summary p,
.report-panel li,
.turn-answer,
.turn-meta,
.result-panel-tip {
  color: var(--color-text-secondary);
  line-height: 1.65;
}

.panel-actions {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
}

.setup-form {
  margin-top: 18px;
  display: grid;
  grid-template-columns: minmax(220px, 1.5fr) minmax(260px, 1fr) minmax(180px, 0.8fr) 140px;
  gap: 14px;
  align-items: end;
}

.workspace {
  display: grid;
  grid-template-columns: minmax(0, 1.35fr) minmax(320px, 0.95fr);
  gap: 16px;
}

.question-panel,
.result-panel {
  padding: 20px;
}

.session-bar-main {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
}

.session-title {
  font-size: 18px;
  font-weight: 700;
}

.session-progress {
  color: var(--color-text-secondary);
  font-weight: 600;
}

.question-box {
  margin-top: 18px;
  display: grid;
  gap: 18px;
}

.question-index {
  color: var(--color-primary);
  font-weight: 700;
  font-size: 14px;
}

.question-text {
  margin: 0;
  font-size: 17px;
  color: var(--color-text);
}

.question-actions {
  display: flex;
  justify-content: flex-end;
  gap: 12px;
  flex-wrap: wrap;
}

.finished-box,
.empty-result {
  min-height: 240px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 10px;
  text-align: center;
  color: var(--color-text-secondary);
}

.result-panel {
  display: grid;
  align-content: start;
  gap: 12px;
}

.result-panel-header {
  display: grid;
  gap: 4px;
}

.turn-result {
  padding: 14px 0;
  border-top: 1px solid var(--color-border-light);
}

.turn-result:first-of-type {
  border-top: none;
}

.turn-answer {
  margin: 10px 0 0;
  padding: 12px 14px;
  border-radius: 16px;
  background: rgba(83, 74, 183, 0.06);
  color: var(--color-text);
  white-space: pre-wrap;
  word-break: break-word;
}

.turn-meta {
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
  font-size: 13px;
  margin-top: 8px;
}

.report-panel {
  margin-top: 16px;
  padding: 20px;
}

.report-header {
  display: grid;
  grid-template-columns: 132px minmax(0, 1fr);
  gap: 20px;
  align-items: start;
}

.report-score {
  min-height: 116px;
  border-radius: 20px;
  background: linear-gradient(180deg, rgba(83, 74, 183, 0.16), rgba(83, 74, 183, 0.06));
  color: var(--color-primary);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
}

.report-score strong {
  font-size: 40px;
  line-height: 1;
}

.dimension-grid {
  margin-top: 18px;
  display: grid;
  grid-template-columns: repeat(5, minmax(150px, 1fr));
  gap: 12px;
}

.dimension-item,
.analysis-card {
  border: 1px solid var(--color-border-light);
  border-radius: 20px;
  padding: 14px;
}

.dimension-line {
  margin-bottom: 8px;
  font-size: var(--font-sm);
}

.report-columns,
.evidence-grid {
  margin-top: 18px;
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 18px;
}

.turn-analysis {
  margin-top: 18px;
}

.analysis-card {
  margin-top: 12px;
}

.mini-dimensions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin: 10px 0;
}

.mini-dimensions span {
  padding: 4px 9px;
  border-radius: 999px;
  background: rgba(15, 23, 42, 0.05);
  color: var(--color-text-secondary);
  font-size: 12px;
}

@media (max-width: 1200px) {
  .dimension-grid {
    grid-template-columns: repeat(3, minmax(150px, 1fr));
  }
}

@media (max-width: 980px) {
  .interview-body :deep(.sidebar) {
    display: none;
  }

  .interview-main {
    padding: 14px;
  }

  .setup-form,
  .workspace,
  .report-header,
  .report-columns,
  .evidence-grid {
    grid-template-columns: 1fr;
  }

  .panel-title,
  .report-title-row,
  .session-bar {
    flex-direction: column;
    align-items: stretch;
  }

  .dimension-grid {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 640px) {
  .setup-panel,
  .question-panel,
  .result-panel,
  .report-panel {
    border-radius: 18px;
  }

  .setup-panel,
  .question-panel,
  .result-panel,
  .report-panel,
  .interview-main {
    padding-inline: 12px;
  }

  .report-score {
    min-height: 104px;
  }

  .question-text {
    font-size: 16px;
  }
}
</style>
