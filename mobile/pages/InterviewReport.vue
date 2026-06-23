<!--
  InterviewReportView.vue — 面试报告详情页
  查看每题回答、评分反馈，支持下载/复制报告
-->
<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useInterviewStore } from '@/stores/interview'
import { ElMessage } from 'element-plus'

const route = useRoute()
const router = useRouter()
const store = useInterviewStore()

const sessionId = Number(route.params.sessionId)
const isCopying = ref(false)
const isDownloading = ref(false)

onMounted(async () => {
  try {
    await store.fetchReport(sessionId)
    // 同时也获取会话详情以得到每题信息
    await store.fetchSession(sessionId)
  } catch (err: any) {
    ElMessage.error(err.response?.data?.detail || '加载报告失败')
  }
})

function getScoreColor(score: number) {
  if (score >= 85) return '#67C23A'
  if (score >= 70) return '#E6A23C'
  return '#F56C6C'
}

function getScoreLevel(score: number) {
  if (score >= 85) return '优秀'
  if (score >= 70) return '良好'
  if (score >= 60) return '一般'
  return '需提升'
}

// ── 下载报告 ──
async function downloadReport() {
  if (!store.currentReport) return
  isDownloading.value = true
  try {
    const report = store.currentReport
    let markdown = `# 面试报告\n\n`
    markdown += `**总分**: ${report.total_score} 分 | **状态**: ${report.status}\n\n`
    markdown += `## 综合总结\n\n${report.summary}\n\n`
    markdown += `## 每题表现\n\n`
    for (const tp of report.turn_performance) {
      markdown += `### 第 ${tp.question_index} 题\n\n`
      markdown += `**问题**: ${tp.question}\n\n`
      markdown += `**得分**: ${tp.score} / 100\n\n`
      markdown += `**反馈**: ${tp.feedback}\n\n`
      markdown += `**建议**: ${tp.suggestion}\n\n---\n\n`
    }
    markdown += `## 改进建议\n\n`
    for (const s of report.suggestions) {
      markdown += `- ${s}\n`
    }

    const blob = new Blob([markdown], { type: 'text/markdown' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `面试报告_${sessionId}.md`
    a.click()
    URL.revokeObjectURL(url)
    ElMessage.success('报告下载成功')
  } catch {
    ElMessage.error('下载失败')
  } finally {
    isDownloading.value = false
  }
}

// ── 复制报告 ──
async function copyReport() {
  if (!store.currentReport) return
  isCopying.value = true
  try {
    const report = store.currentReport
    let text = `面试报告\n`
    text += `总分: ${report.total_score} 分\n\n`
    text += `综合总结: ${report.summary}\n\n`
    for (const tp of report.turn_performance) {
      text += `第 ${tp.question_index} 题: ${tp.question}\n`
      text += `得分: ${tp.score} | 反馈: ${tp.feedback}\n`
      text += `建议: ${tp.suggestion}\n\n`
    }
    await navigator.clipboard.writeText(text)
    ElMessage.success('已复制到剪贴板')
  } catch {
    ElMessage.error('复制失败，请手动复制')
  } finally {
    isCopying.value = false
  }
}
</script>

<template>
  <div class="report-view">
    <!-- 顶部 -->
    <header class="report-header">
      <button class="back-btn" @click="router.back()">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <polyline points="15,18 9,12 15,6" />
        </svg>
      </button>
      <h2 class="header-title">面试报告</h2>
      <div class="header-actions">
        <button class="action-btn" :disabled="isCopying" @click="copyReport">
          {{ isCopying ? '...' : '复制' }}
        </button>
        <button class="action-btn primary" :disabled="isDownloading" @click="downloadReport">
          {{ isDownloading ? '...' : '下载' }}
        </button>
      </div>
    </header>

    <!-- 加载 -->
    <div v-if="store.isLoading" class="loading-state">
      <div class="loading-spinner" />
      <span>加载报告中...</span>
    </div>

    <div v-else-if="!store.currentReport" class="empty-state">
      <p>报告数据不可用</p>
    </div>

    <!-- 报告内容 -->
    <div v-else class="report-content">
      <!-- 总分卡片 -->
      <div class="score-card">
        <div class="score-gauge" :style="{ color: getScoreColor(store.currentReport.total_score) }">
          <span class="score-number">{{ store.currentReport.total_score }}</span>
          <span class="score-unit">分</span>
        </div>
        <div class="score-level" :style="{ color: getScoreColor(store.currentReport.total_score) }">
          {{ getScoreLevel(store.currentReport.total_score) }}
        </div>
        <div class="score-summary">{{ store.currentReport.summary }}</div>
      </div>

      <!-- 每题表现 -->
      <div class="turns-section">
        <h3 class="section-title">每题表现</h3>
        <div
          v-for="tp in store.currentReport.turn_performance"
          :key="tp.question_index"
          class="turn-card"
        >
          <div class="turn-header">
            <span class="turn-num">第 {{ tp.question_index }} 题</span>
            <span class="turn-score" :style="{ color: getScoreColor(tp.score) }">
              {{ tp.score }} 分
            </span>
          </div>
          <div class="turn-question">{{ tp.question }}</div>
          <div class="turn-feedback">
            <div class="feedback-label">反馈</div>
            <div class="feedback-text">{{ tp.feedback }}</div>
          </div>
          <div class="turn-suggestion">
            <div class="suggestion-label">建议</div>
            <div class="suggestion-text">{{ tp.suggestion }}</div>
          </div>
        </div>
      </div>

      <!-- 改进建议汇总 -->
      <div class="suggestions-section">
        <h3 class="section-title">改进建议</h3>
        <ul class="suggestions-list">
          <li v-for="(s, i) in store.currentReport.suggestions" :key="i" class="suggestion-item">
            <span class="suggestion-num">{{ i + 1 }}.</span>
            <span>{{ s }}</span>
          </li>
        </ul>
      </div>
    </div>
  </div>
</template>

<style scoped>
.report-view {
  max-width: 768px;
  margin: 0 auto;
  min-height: 100vh;
  background: #F5F7FA;
}

.report-header {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 16px;
  background: #fff;
  border-bottom: 1px solid #EBEEF5;
  position: sticky;
  top: 0;
  z-index: 10;
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
}

.back-btn:hover {
  background: #F5F7FA;
}

.header-title {
  flex: 1;
  font-size: 17px;
  font-weight: 600;
  color: #303133;
  margin: 0;
}

.header-actions {
  display: flex;
  gap: 8px;
}

.action-btn {
  padding: 6px 14px;
  border: 1px solid #DCDFE6;
  border-radius: 14px;
  background: #fff;
  font-size: 13px;
  color: #606266;
  cursor: pointer;
}

.action-btn.primary {
  border-color: #534AB7;
  color: #534AB7;
}

.action-btn:disabled {
  opacity: 0.5;
}

.loading-state,
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding-top: 120px;
  color: #909399;
  gap: 16px;
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

.report-content {
  padding: 16px;
  display: flex;
  flex-direction: column;
  gap: 16px;
}

/* 总分卡片 */
.score-card {
  background: #fff;
  border-radius: 16px;
  padding: 28px 20px;
  text-align: center;
  border: 1px solid #EBEEF5;
}

.score-gauge {
  display: flex;
  align-items: baseline;
  justify-content: center;
  gap: 4px;
  margin-bottom: 8px;
}

.score-number {
  font-size: 48px;
  font-weight: 700;
  line-height: 1;
}

.score-unit {
  font-size: 18px;
  font-weight: 500;
}

.score-level {
  font-size: 16px;
  font-weight: 600;
  margin-bottom: 12px;
}

.score-summary {
  font-size: 14px;
  color: #606266;
  line-height: 1.6;
}

/* 每题表现 */
.turns-section {
  background: #fff;
  border-radius: 12px;
  padding: 16px;
  border: 1px solid #EBEEF5;
}

.section-title {
  font-size: 16px;
  font-weight: 600;
  color: #303133;
  margin: 0 0 12px;
}

.turn-card {
  padding: 14px 0;
  border-bottom: 1px solid #F5F7FA;
}

.turn-card:last-child {
  border-bottom: none;
}

.turn-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 6px;
}

.turn-num {
  font-size: 13px;
  color: #909399;
  font-weight: 500;
}

.turn-score {
  font-size: 15px;
  font-weight: 600;
}

.turn-question {
  font-size: 14px;
  color: #303133;
  line-height: 1.5;
  margin-bottom: 10px;
}

.feedback-label,
.suggestion-label {
  font-size: 11px;
  color: #C0C4CC;
  margin-bottom: 2px;
}

.feedback-text {
  font-size: 13px;
  color: #606266;
  line-height: 1.6;
  margin-bottom: 8px;
}

.suggestion-text {
  font-size: 13px;
  color: #534AB7;
  line-height: 1.6;
}

/* 改进建议汇总 */
.suggestions-section {
  background: #fff;
  border-radius: 12px;
  padding: 16px;
  border: 1px solid #EBEEF5;
  margin-bottom: 24px;
}

.suggestions-list {
  list-style: none;
  padding: 0;
  margin: 0;
}

.suggestion-item {
  display: flex;
  gap: 6px;
  padding: 8px 0;
  font-size: 14px;
  color: #303133;
  line-height: 1.5;
  border-bottom: 1px solid #FAFAFA;
}

.suggestion-item:last-child {
  border-bottom: none;
}

.suggestion-num {
  color: #534AB7;
  font-weight: 500;
  flex-shrink: 0;
}
</style>
