<!--
  InterviewHistoryView.vue — 面试历史记录页
  查看历史面试、状态、总分、进入报告
-->
<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useInterviewStore } from '@/stores/interview'

const router = useRouter()
const store = useInterviewStore()
const page = ref(1)
const pageSize = ref(20)

onMounted(() => {
  store.fetchHistory()
})

function loadMore() {
  page.value++
  store.fetchHistory(page.value, pageSize.value)
}

function goToInterview(sessionId: number) {
  router.push(`/interview/${sessionId}`)
}

function goToReport(sessionId: number) {
  router.push(`/interview/${sessionId}/report`)
}

function goToCreate() {
  router.push('/interview-create')
}

const statusMap: Record<string, { label: string; color: string; bg: string }> = {
  pending: { label: '待开始', color: '#E6A23C', bg: '#FDF6EC' },
  in_progress: { label: '进行中', color: '#534AB7', bg: '#F0EFFF' },
  finished: { label: '已完成', color: '#67C23A', bg: '#F0F9EB' },
}

function statusInfo(status: string) {
  return statusMap[status] || { label: status, color: '#909399', bg: '#F5F7FA' }
}

function formatDate(dateStr: string) {
  const d = new Date(dateStr)
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  const h = String(d.getHours()).padStart(2, '0')
  const min = String(d.getMinutes()).padStart(2, '0')
  return `${m}-${day} ${h}:${min}`
}

function getScoreColor(score: number | null) {
  if (score === null) return '#909399'
  if (score >= 85) return '#67C23A'
  if (score >= 70) return '#E6A23C'
  return '#F56C6C'
}
</script>

<template>
  <div class="history-view">
    <!-- 顶部 -->
    <header class="history-header">
      <button class="back-btn" @click="router.push('/')">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <polyline points="15,18 9,12 15,6" />
        </svg>
      </button>
      <h2 class="header-title">面试历史记录</h2>
      <div class="header-spacer" />
    </header>

    <!-- 空状态 -->
    <div v-if="!store.isLoading && store.historyList.length === 0" class="empty-state">
      <svg width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="#DCDFE6" stroke-width="1.5">
        <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
        <polyline points="14 2 14 8 20 8" />
        <line x1="16" y1="13" x2="8" y2="13" />
        <line x1="16" y1="17" x2="8" y2="17" />
        <polyline points="10 9 9 9 8 9" />
      </svg>
      <p class="empty-text">暂无面试记录</p>
      <p class="empty-desc">创建一次 AI 模拟面试开始练习</p>
    </div>

    <!-- 列表 -->
    <div v-else class="history-list">
      <div
        v-for="item in store.historyList"
        :key="item.id"
        class="history-card"
        @click="item.status === 'finished' ? goToReport(item.id) : goToInterview(item.id)"
      >
        <!-- 状态 + 标题 -->
        <div class="card-top">
          <span
            class="status-badge"
            :style="{ color: statusInfo(item.status).color, background: statusInfo(item.status).bg }"
          >
            {{ statusInfo(item.status).label }}
          </span>
          <span class="card-date">{{ formatDate(item.created_at) }}</span>
        </div>

        <h3 class="card-title">{{ item.title }}</h3>

        <div class="card-meta">
          <span class="meta-item">{{ item.target_position }}</span>
          <span class="meta-divider">|</span>
          <span class="meta-item">{{ item.interview_type === 'technical' ? '技术面' : item.interview_type === 'behavioral' ? '行为面' : '综合面' }}</span>
          <span class="meta-divider">|</span>
          <span class="meta-item">{{ { easy: '基础', medium: '进阶', hard: '深入' }[item.difficulty] || item.difficulty }}</span>
        </div>

        <!-- 总分 -->
        <div class="card-score">
          <div class="score-label">总分</div>
          <div class="score-value" :style="{ color: getScoreColor(item.total_score) }">
            {{ item.total_score !== null ? item.total_score + ' 分' : '—' }}
          </div>
          <div class="card-arrow">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#C0C4CC" stroke-width="2">
              <polyline points="9,18 15,12 9,6" />
            </svg>
          </div>
        </div>
      </div>

      <!-- 加载更多 -->
      <div
        v-if="store.historyList.length < store.historyTotal"
        class="load-more"
        @click="loadMore"
      >
        {{ store.isLoading ? '加载中...' : '加载更多' }}
      </div>
    </div>

    <!-- 创建新面试 FAB -->
    <button class="create-fab" @click="goToCreate">
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round">
        <line x1="12" y1="5" x2="12" y2="19" />
        <line x1="5" y1="12" x2="19" y2="12" />
      </svg>
    </button>
  </div>
</template>

<style scoped>
.history-view {
  max-width: 768px;
  margin: 0 auto;
  min-height: 100vh;
  background: #F5F7FA;
}

.history-header {
  display: flex;
  align-items: center;
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
  text-align: center;
  font-size: 17px;
  font-weight: 600;
  color: #303133;
  margin: 0;
}

.header-spacer {
  width: 36px;
}

.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding-top: 120px;
  gap: 8px;
}

.empty-text {
  font-size: 16px;
  color: #909399;
  margin: 0;
}

.empty-desc {
  font-size: 13px;
  color: #C0C4CC;
  margin: 0;
}

.history-list {
  padding: 12px 16px;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.history-card {
  background: #fff;
  border-radius: 12px;
  padding: 16px;
  cursor: pointer;
  transition: box-shadow 0.2s;
  border: 1px solid #EBEEF5;
}

.history-card:hover {
  box-shadow: 0 2px 12px rgba(0, 0, 0, 0.06);
}

.card-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 8px;
}

.status-badge {
  font-size: 11px;
  padding: 2px 10px;
  border-radius: 10px;
  font-weight: 500;
}

.card-date {
  font-size: 12px;
  color: #C0C4CC;
}

.card-title {
  font-size: 15px;
  font-weight: 600;
  color: #303133;
  margin: 0 0 8px;
}

.card-meta {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 12px;
  color: #909399;
  margin-bottom: 12px;
}

.meta-item {
  color: #909399;
}

.meta-divider {
  color: #E4E7ED;
}

.card-score {
  display: flex;
  align-items: center;
  gap: 8px;
  padding-top: 12px;
  border-top: 1px solid #F5F7FA;
}

.score-label {
  font-size: 13px;
  color: #909399;
}

.score-value {
  font-size: 18px;
  font-weight: 700;
  flex: 1;
}

.card-arrow {
  opacity: 0.4;
}

.load-more {
  text-align: center;
  padding: 16px;
  font-size: 14px;
  color: #909399;
  cursor: pointer;
  border-radius: 12px;
}

.load-more:hover {
  background: #fff;
  color: #534AB7;
}

/* 创建 FAB */
.create-fab {
  position: fixed;
  bottom: 24px;
  right: 24px;
  width: 56px;
  height: 56px;
  border: none;
  border-radius: 50%;
  background: linear-gradient(135deg, #534AB7, #6366F1);
  color: #fff;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 4px 16px rgba(83, 74, 183, 0.35);
  transition: transform 0.2s, box-shadow 0.2s;
  z-index: 100;
}

.create-fab:hover {
  transform: scale(1.05);
  box-shadow: 0 6px 20px rgba(83, 74, 183, 0.45);
}

.create-fab:active {
  transform: scale(0.95);
}
</style>
