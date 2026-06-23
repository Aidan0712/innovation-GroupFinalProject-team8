/**
 * AI 面试状态管理
 * 
 * 管理面试流程：创建 → 开始 → 回答 → 评分 → 下一题 → 结束 → 报告
 */
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import {
  createInterviewApi,
  startInterviewSessionApi,
  submitInterviewAnswerApi,
  finishInterviewSessionApi,
  getInterviewReportApi,
  getInterviewSessionApi,
  listInterviewSessionsApi,
} from '@/api/interview'
import type {
  InterviewSession,
  InterviewSessionDetail,
  InterviewCreateParams,
  InterviewAnswerParams,
  InterviewReport,
  InterviewTurn,
} from '@/types/interview'
import { ElMessage } from 'element-plus'

export const useInterviewStore = defineStore('interview', () => {
  // ── 状态 ──
  const currentSession = ref<InterviewSessionDetail | null>(null)
  const currentReport = ref<InterviewReport | null>(null)
  const historyList = ref<InterviewSession[]>([])
  const historyTotal = ref(0)
  const isLoading = ref(false)
  const isSubmitting = ref(false)

  // ── 计算属性 ──
  const currentTurn = computed<InterviewTurn | null>(() => {
    if (!currentSession.value) return null
    return (
      currentSession.value.turns.find((t) => t.answered_at === null) ||
      currentSession.value.turns[currentSession.value.turns.length - 1] ||
      null
    )
  })

  const answeredTurns = computed(() =>
    currentSession.value?.turns.filter((t) => t.answered_at !== null) || []
  )

  const progress = computed(() => {
    if (!currentSession.value) return 0
    return Math.round(
      (answeredTurns.value.length / currentSession.value.question_count) * 100
    )
  })

  const isFinished = computed(() => currentSession.value?.status === 'finished')
  const isInProgress = computed(() => currentSession.value?.status === 'in_progress')

  // ── 操作 ──

  /** 创建面试会话 */
  async function createSession(params: InterviewCreateParams) {
    isLoading.value = true
    try {
      const res = await createInterviewApi(params)
      currentSession.value = res.data as InterviewSessionDetail
      return res.data
    } finally {
      isLoading.value = false
    }
  }

  /** 开始面试（获取第一题） */
  async function startSession(sessionId: number) {
    isLoading.value = true
    try {
      const res = await startInterviewSessionApi(sessionId)
      currentSession.value = res.data
      return res.data
    } finally {
      isLoading.value = false
    }
  }

  /** 提交回答 */
  async function submitAnswer(answer: InterviewAnswerParams) {
    if (!currentSession.value) throw new Error('没有活跃的面试会话')
    isSubmitting.value = true
    try {
      const res = await submitInterviewAnswerApi(currentSession.value.id, answer)
      currentSession.value = res.data
      ElMessage.success('回答提交成功')
      return res.data
    } finally {
      isSubmitting.value = false
    }
  }

  /** 结束面试 */
  async function finishSession(sessionId?: number) {
    const id = sessionId || currentSession.value?.id
    if (!id) throw new Error('没有活跃的面试会话')
    isLoading.value = true
    try {
      const res = await finishInterviewSessionApi(id)
      currentReport.value = res.data
      if (currentSession.value) {
        currentSession.value.status = 'finished'
        currentSession.value.report = res.data as any
      }
      ElMessage.success('面试已结束，报告生成成功')
      return res.data
    } finally {
      isLoading.value = false
    }
  }

  /** 获取面试报告 */
  async function fetchReport(sessionId: number) {
    isLoading.value = true
    try {
      const res = await getInterviewReportApi(sessionId)
      currentReport.value = res.data
      return res.data
    } finally {
      isLoading.value = false
    }
  }

  /** 获取会话详情 */
  async function fetchSession(sessionId: number) {
    isLoading.value = true
    try {
      const res = await getInterviewSessionApi(sessionId)
      currentSession.value = res.data
      return res.data
    } finally {
      isLoading.value = false
    }
  }

  /** 获取历史记录列表 */
  async function fetchHistory(page = 1, pageSize = 20) {
    isLoading.value = true
    try {
      const res = await listInterviewSessionsApi(page, pageSize)
      historyList.value = res.data.items || []
      historyTotal.value = res.data.total || 0
    } finally {
      isLoading.value = false
    }
  }

  /** 清空当前会话 */
  function clearCurrent() {
    currentSession.value = null
    currentReport.value = null
  }

  return {
    // state
    currentSession,
    currentReport,
    historyList,
    historyTotal,
    isLoading,
    isSubmitting,
    // computed
    currentTurn,
    answeredTurns,
    progress,
    isFinished,
    isInProgress,
    // actions
    createSession,
    startSession,
    submitAnswer,
    finishSession,
    fetchReport,
    fetchSession,
    fetchHistory,
    clearCurrent,
  }
})
