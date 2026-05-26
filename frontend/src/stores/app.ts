import { defineStore } from 'pinia'
import { ref, computed, watch } from 'vue'

type ThemeType = 'light' | 'dark'

/**
 * 应用全局状态管理
 */
export const useAppStore = defineStore('app', () => {
  // ========== State ==========

  /** 侧边栏是否折叠 */
  const sidebarCollapsed = ref(false)

  /** 主题：light | dark */
  const theme = ref<ThemeType>(
    (localStorage.getItem('app-theme') as ThemeType) || 'light'
  )

  /** 全局加载状态 */
  const globalLoading = ref(false)

  /** 全局加载文本 */
  const loadingText = ref('加载中...')

  // ========== Getters ==========

  /** 是否为暗色主题 */
  const isDark = computed(() => theme.value === 'dark')

  // ========== Actions ==========

  /**
   * 切换侧边栏折叠
   */
  function toggleSidebar() {
    sidebarCollapsed.value = !sidebarCollapsed.value
  }

  /**
   * 设置侧边栏折叠状态
   */
  function setSidebarCollapsed(collapsed: boolean) {
    sidebarCollapsed.value = collapsed
  }

  /**
   * 切换主题
   */
  function toggleTheme() {
    theme.value = theme.value === 'light' ? 'dark' : 'light'
  }

  /**
   * 设置主题
   */
  function setTheme(t: ThemeType) {
    theme.value = t
  }

  /**
   * 显示全局加载
   */
  function showLoading(text?: string) {
    globalLoading.value = true
    if (text) loadingText.value = text
  }

  /**
   * 隐藏全局加载
   */
  function hideLoading() {
    globalLoading.value = false
    loadingText.value = '加载中...'
  }

  // ========== 副作用 ==========

  // 监听主题变化，同步到 DOM 和 localStorage
  watch(theme, (val) => {
    document.documentElement.setAttribute('data-theme', val)
    localStorage.setItem('app-theme', val)
  }, { immediate: true })

  return {
    // State
    sidebarCollapsed,
    theme,
    globalLoading,
    loadingText,
    // Getters
    isDark,
    // Actions
    toggleSidebar,
    setSidebarCollapsed,
    toggleTheme,
    setTheme,
    showLoading,
    hideLoading,
  }
})
