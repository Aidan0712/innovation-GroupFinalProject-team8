import { createRouter, createWebHistory } from 'vue-router'
import type { RouteRecordRaw } from 'vue-router'

const routes: RouteRecordRaw[] = [
  {
    path: '/',
    name: 'Chat',
    component: () => import('@/views/ChatView.vue'),
    meta: { requiresAuth: true },
  },
  {
    path: '/login',
    name: 'Login',
    component: () => import('@/views/LoginView.vue'),
    meta: { guest: true },
  },
  {
    path: '/register',
    name: 'Register',
    component: () => import('@/views/RegisterView.vue'),
    meta: { guest: true },
  },
  {
    path: '/profile',
    name: 'Profile',
    component: () => import('@/views/ProfileView.vue'),
    meta: { requiresAuth: true },
  },
  {
    path: '/my-questions',
    name: 'MyQuestions',
    component: () => import('@/views/MyQuestionsView.vue'),
    meta: { requiresAuth: true },
  },
  {
    path: '/admin',
    name: 'AdminDashboard',
    component: () => import('@/views/admin/DashboardView.vue'),
    meta: { requiresAuth: true, requiresAdmin: true },
  },
  {
    path: '/admin/questions',
    name: 'QuestionManage',
    component: () => import('@/views/admin/QuestionManage.vue'),
    meta: { requiresAuth: true, requiresAdmin: true },
  },
  {
    path: '/admin/knowledge',
    name: 'KnowledgeManage',
    component: () => import('@/views/admin/KnowledgeManage.vue'),
    meta: { requiresAuth: true, requiresAdmin: true },
  },
  {
    path: '/admin/users',
    name: 'UserManage',
    component: () => import('@/views/admin/UserManage.vue'),
    meta: { requiresAuth: true, requiresAdmin: true },
  },
  {
    path: '/admin/agents',
    name: 'AgentMonitor',
    component: () => import('@/views/admin/AgentMonitor.vue'),
    meta: { requiresAuth: true, requiresAdmin: true },
  },
  {
    path: '/:pathMatch(.*)*',
    name: 'NotFound',
    redirect: '/',
  },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
})

// 路由守卫
router.beforeEach((to, _from, next) => {
  // 从 localStorage 判断是否已登录（简化处理，实际应通过 Pinia store 判断）
  const token = localStorage.getItem('access_token')
  const isLoggedIn = !!token

  // 检查是否为管理员
  const userStr = localStorage.getItem('user')
  let isAdmin = false
  if (userStr) {
    try {
      const user = JSON.parse(userStr)
      isAdmin = user.role === 'admin'
    } catch {
      // ignore
    }
  }

  // 需要登录但未登录 → 跳转登录页
  if (to.meta.requiresAuth && !isLoggedIn) {
    next({ name: 'Login', query: { redirect: to.fullPath } })
    return
  }

  // 已登录但访问游客页面（登录/注册） → 跳转首页
  if (to.meta.guest && isLoggedIn) {
    next({ name: 'Chat' })
    return
  }

  // 需要管理员权限但非管理员 → 跳转首页
  if (to.meta.requiresAdmin && !isAdmin) {
    next({ name: 'Chat' })
    return
  }

  next()
})

export default router
