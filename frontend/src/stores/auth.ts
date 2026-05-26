import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { User, LoginParams, RegisterParams } from '@/types'
import { loginApi, registerApi, getUserInfoApi } from '@/api/auth'

/**
 * 用户认证状态管理
 */
export const useAuthStore = defineStore('auth', () => {
  // ========== State ==========
  const user = ref<User | null>(null)
  const token = ref<string>(localStorage.getItem('access_token') || '')

  // ========== Getters ==========

  /** 是否已登录 */
  const isLoggedIn = computed(() => !!token.value)

  /** 是否为管理员 */
  const isAdmin = computed(() => user.value?.role === 'admin')

  /** 当前用户信息 */
  const currentUser = computed(() => user.value)

  // ========== Actions ==========

  /**
   * 用户登录
   */
  async function login(params: LoginParams) {
    try {
      const res = await loginApi(params)
      token.value = res.data.access_token
      user.value = res.data.user

      // 持久化存储
      localStorage.setItem('access_token', res.data.access_token)
      localStorage.setItem('user', JSON.stringify(res.data.user))

      return res
    } catch (error) {
      throw error
    }
  }

  /**
   * 用户注册
   */
  async function register(params: RegisterParams) {
    try {
      const res = await registerApi(params)
      return res
    } catch (error) {
      throw error
    }
  }

  /**
   * 获取用户信息
   */
  async function fetchUserInfo() {
    try {
      const res = await getUserInfoApi()
      user.value = res.data
      localStorage.setItem('user', JSON.stringify(res.data))
      return res
    } catch (error) {
      throw error
    }
  }

  /**
   * 退出登录
   */
  function logout() {
    token.value = ''
    user.value = null
    localStorage.removeItem('access_token')
    localStorage.removeItem('user')
    // 跳转到登录页
    window.location.href = '/login'
  }

  /**
   * 初始化：从 localStorage 恢复用户状态
   */
  function initAuth() {
    const savedToken = localStorage.getItem('access_token')
    const savedUser = localStorage.getItem('user')

    if (savedToken) {
      token.value = savedToken
    }
    if (savedUser) {
      try {
        user.value = JSON.parse(savedUser)
      } catch {
        localStorage.removeItem('user')
      }
    }
  }

  return {
    // State
    user,
    token,
    // Getters
    isLoggedIn,
    isAdmin,
    currentUser,
    // Actions
    login,
    register,
    fetchUserInfo,
    logout,
    initAuth,
  }
})
