<script setup lang="ts">
import { computed, ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import Sidebar from '@/components/Sidebar.vue'
import AppHeader from '@/components/AppHeader.vue'
import { getAdminDashboardApi } from '@/api/admin'
import type { AdminDashboardStats } from '@/api/admin'

/**
 * 数据仪表盘
 * 展示统计数据和图表
 */

const router = useRouter()

/** 统计数据 */
const stats = ref<AdminDashboardStats>({
  total_users: 0,
  active_users_today: 0,
  total_conversations: 0,
  total_resumes: 0,
  total_recordings: 0,
  total_questions: 0,
  total_agent_calls: 0,
  avg_latency_ms: null,
})

/** 加载中 */
const loading = ref(false)

/** 统计卡片配置 */
interface StatCard {
  label: string
  value: string
  icon: string
  color: string
  bgColor: string
}

const statCards = computed<StatCard[]>(() => [
  { label: '总用户数', value: String(stats.value.total_users), icon: 'User', color: '#534AB7', bgColor: '#E8E6F8' },
  { label: '今日活跃', value: String(stats.value.active_users_today), icon: 'UserFilled', color: '#0F6E56', bgColor: '#E6F5F0' },
  { label: '总对话数', value: String(stats.value.total_conversations), icon: 'ChatDotRound', color: '#BA7517', bgColor: '#FFF4E5' },
  { label: 'Agent 调用', value: String(stats.value.total_agent_calls), icon: 'Cpu', color: '#A32D2D', bgColor: '#FBEAEA' },
])

onMounted(() => {
  fetchDashboard()
})

async function fetchDashboard() {
  loading.value = true
  try {
    const res = await getAdminDashboardApi()
    if (res.data) stats.value = res.data
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="admin-layout">
    <Sidebar />
    <div class="admin-main">
      <AppHeader />
      <div class="admin-content">
        <div class="page-header">
          <h2 class="page-title">数据仪表盘</h2>
        </div>

        <!-- 统计卡片 -->
        <div class="stats-grid">
          <div v-for="card in statCards" :key="card.label" class="stat-card card">
            <div class="stat-icon" :style="{ backgroundColor: card.bgColor, color: card.color }">
              <el-icon :size="24">
                <component :is="card.icon" />
              </el-icon>
            </div>
            <div class="stat-info">
              <div class="stat-value">{{ card.value }}</div>
              <div class="stat-label">{{ card.label }}</div>
            </div>
          </div>
        </div>

        <!-- 图表区域（占位） -->
        <div class="charts-grid">
          <div class="chart-card card">
            <div class="chart-header">
              <h3>对话趋势</h3>
            </div>
            <div class="chart-placeholder">
              <el-icon :size="48" color="#9E9D9A"><DataAnalysis /></el-icon>
              <p>图表区域（待接入 ECharts 或类似图表库）</p>
            </div>
          </div>

          <div class="chart-card card">
            <div class="chart-header">
              <h3>Agent 调用分布</h3>
            </div>
            <div class="chart-placeholder">
              <el-icon :size="48" color="#9E9D9A"><PieChart /></el-icon>
              <p>图表区域</p>
            </div>
          </div>
        </div>

        <!-- 快捷入口 -->
        <div class="quick-actions card">
          <h3 class="section-title">快捷入口</h3>
          <div class="actions-grid">
            <el-button :icon="'EditPen'" size="large" @click="router.push('/admin/questions')">题库管理</el-button>
            <el-button :icon="'Collection'" size="large" @click="router.push('/admin/knowledge')">知识库管理</el-button>
            <el-button :icon="'User'" size="large" @click="router.push('/admin/users')">用户管理</el-button>
            <el-button :icon="'Monitor'" size="large" @click="router.push('/admin/agents')">Agent 监控</el-button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.admin-layout {
  display: flex;
  height: 100vh;
  overflow: hidden;
}

.admin-main {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-width: 0;
  overflow: hidden;
}

.admin-content {
  flex: 1;
  overflow-y: auto;
  padding: var(--spacing-lg);
  background: var(--color-bg);
}

.page-header {
  margin-bottom: var(--spacing-lg);
}

.page-title {
  font-size: var(--font-xxl);
  font-weight: 700;
  color: var(--color-text);
}

/* ========== 统计卡片 ========== */
.stats-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: var(--spacing-md);
  margin-bottom: var(--spacing-lg);
}

.stat-card {
  display: flex;
  align-items: center;
  gap: var(--spacing-md);
  padding: var(--spacing-lg);
}

.stat-icon {
  width: 52px;
  height: 52px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: var(--radius-md);
}

.stat-value {
  font-size: var(--font-title);
  font-weight: 700;
  color: var(--color-text);
}

.stat-label {
  font-size: var(--font-sm);
  color: var(--color-text-secondary);
  margin-top: 2px;
}

/* ========== 图表区域 ========== */
.charts-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: var(--spacing-md);
  margin-bottom: var(--spacing-lg);
}

.chart-card {
  padding: var(--spacing-lg);
}

.chart-header {
  margin-bottom: var(--spacing-md);
}

.chart-header h3 {
  font-size: var(--font-lg);
  font-weight: 600;
  color: var(--color-text);
}

.chart-placeholder {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 240px;
  color: var(--color-text-placeholder);
  background: var(--color-bg-dark);
  border-radius: var(--radius-md);
}

.chart-placeholder p {
  margin-top: var(--spacing-sm);
  font-size: var(--font-sm);
}

/* ========== 快捷入口 ========== */
.quick-actions {
  padding: var(--spacing-lg);
}

.section-title {
  font-size: var(--font-lg);
  font-weight: 600;
  color: var(--color-text);
  margin-bottom: var(--spacing-md);
}

.actions-grid {
  display: flex;
  gap: var(--spacing-md);
  flex-wrap: wrap;
}

/* ========== 响应式 ========== */
@media (max-width: 1024px) {
  .stats-grid {
    grid-template-columns: repeat(2, 1fr);
  }

  .charts-grid {
    grid-template-columns: 1fr;
  }
}
</style>
