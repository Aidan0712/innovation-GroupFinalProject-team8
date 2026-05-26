<script setup lang="ts">
import { onMounted } from 'vue'
import { useAuthStore } from '@/stores/auth'

const authStore = useAuthStore()

/**
 * 初始化认证状态：从 localStorage 恢复 + 请求最新用户信息
 */
onMounted(async () => {
  authStore.initAuth()
  if (authStore.isLoggedIn) {
    try {
      await authStore.fetchUserInfo()
    } catch {
      // 获取失败说明 Token 已过期，保持未登录状态
      authStore.logout()
    }
  }
})
</script>

<template>
  <div class="app-container">
    <!-- 已登录：显示完整布局（包含侧边栏+顶部导航） -->
    <template v-if="authStore.isLoggedIn">
      <router-view />
    </template>
    <!-- 未登录：独立页面（登录/注册） -->
    <template v-else>
      <router-view />
    </template>
  </div>
</template>

<style scoped>
.app-container {
  width: 100%;
  height: 100vh;
  overflow: hidden;
}
</style>
