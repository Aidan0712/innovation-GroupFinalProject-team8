<script setup lang="ts">
import { ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useAppStore } from '@/stores/app'
import { ElMessageBox } from 'element-plus'

/**
 * 顶部导航栏
 * 左侧：应用标题，右侧：用户头像、主题切换、退出
 */

const router = useRouter()
const authStore = useAuthStore()
const appStore = useAppStore()

/**
 * 头像缓存破坏时间戳（响应式，确保 el-avatar 重新渲染）
 */
const avatarTimestamp = ref(Date.now())

watch(
  () => authStore.user?.avatar_url,
  () => { avatarTimestamp.value = Date.now() }
)

/**
 * 头像 URL（拼接时间戳破坏浏览器缓存）
 */
function getAvatarUrl(): string {
  const url = authStore.currentUser?.avatar_url
  if (!url) return ''
  return url.includes('?') ? `${url}&t=${avatarTimestamp.value}` : `${url}?t=${avatarTimestamp.value}`
}

/**
 * 切换主题
 */
function handleToggleTheme() {
  appStore.toggleTheme()
}

/**
 * 跳转个人中心
 */
function goToProfile() {
  router.push('/profile')
}

function goToMyQuestions() {
  router.push('/my-questions')
}

/**
 * 退出登录
 */
function handleLogout() {
  ElMessageBox.confirm('确定要退出登录吗？', '提示', {
    confirmButtonText: '确定',
    cancelButtonText: '取消',
    type: 'warning',
  }).then(() => {
    authStore.logout()
  }).catch(() => {
    // 取消退出
  })
}
</script>

<template>
  <header class="app-header">
    <div class="header-left">
      <img class="app-logo" src="/logo.png" alt="logo" />
      <span class="app-title">智能面试助手</span>
    </div>

    <div class="header-right">
      <!-- 主题切换 -->
      <el-tooltip :content="appStore.isDark ? '切换亮色模式' : '切换暗色模式'" placement="bottom">
        <el-button
          :icon="appStore.isDark ? 'Sunny' : 'Moon'"
          circle
          @click="handleToggleTheme"
        />
      </el-tooltip>

      <!-- 用户信息 -->
      <el-dropdown trigger="click">
        <div class="user-info">
          <el-avatar :size="32" :src="getAvatarUrl()" :key="avatarTimestamp" :style="{ backgroundColor: '#534AB7' }">
            {{ authStore.currentUser?.username?.charAt(0)?.toUpperCase() || 'U' }}
          </el-avatar>
          <span class="user-name">{{ authStore.currentUser?.username || '用户' }}</span>
          <el-icon :size="12"><ArrowDown /></el-icon>
        </div>
        <template #dropdown>
          <el-dropdown-menu>
            <el-dropdown-item @click="goToProfile">
              <el-icon><User /></el-icon>
              个人中心
            </el-dropdown-item>
            <el-dropdown-item @click="goToMyQuestions">
              <el-icon><Collection /></el-icon>
              我的题库
            </el-dropdown-item>
            <el-dropdown-item divided @click="handleLogout">
              <el-icon><SwitchButton /></el-icon>
              退出登录
            </el-dropdown-item>
          </el-dropdown-menu>
        </template>
      </el-dropdown>
    </div>
  </header>
</template>

<style scoped>
.app-header {
  height: var(--header-height);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 var(--spacing-lg);
  background: var(--color-card);
  border-bottom: 1px solid var(--color-border-light);
  flex-shrink: 0;
}

/* ========== 左侧 ========== */
.header-left {
  display: flex;
  align-items: center;
  gap: var(--spacing-sm);
}

.app-logo {
  width: 32px;
  height: 32px;
  border-radius: var(--radius-sm);
  object-fit: cover;
}

.app-title {
  font-size: var(--font-lg);
  font-weight: 600;
  color: var(--color-text);
}

/* ========== 右侧 ========== */
.header-right {
  display: flex;
  align-items: center;
  gap: var(--spacing-sm);
}

.user-info {
  display: flex;
  align-items: center;
  gap: var(--spacing-sm);
  padding: 4px 8px;
  border-radius: var(--radius-md);
  cursor: pointer;
  transition: background 0.2s;
}

.user-info:hover {
  background: var(--color-bg);
}

.user-name {
  font-size: var(--font-sm);
  color: var(--color-text);
  max-width: 120px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* ========== 响应式 ========== */
@media (max-width: 768px) {
  .app-title {
    display: none;
  }

  .user-name {
    display: none;
  }
}
</style>
