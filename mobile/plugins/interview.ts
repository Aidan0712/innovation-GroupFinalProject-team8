/**
 * 面试路由插件
 * 通过 router.addRoute() 动态注册面试相关路由，不修改 router/index.ts
 *
 * 在 main.ts 中添加：
 *   import { interviewPlugin } from '@/plugins/interview'
 *   app.use(interviewPlugin)
 */
import type { App } from 'vue'
import type { Router } from 'vue-router'

export const interviewPlugin = {
  install(app: App) {
    // 通过 provide/inject 方式访问 router
    const router = app.config.globalProperties.$router as Router
    if (!router) {
      console.warn('[interview-plugin] 未找到 router 实例，面试路由未注册')
      return
    }

    // 动态添加路由
    router.addRoute({
      path: '/interview-history',
      name: 'InterviewHistory',
      component: () => import('@/views/InterviewHistoryView.vue'),
      meta: { requiresAuth: true },
    })

    router.addRoute({
      path: '/interview-create',
      name: 'InterviewCreate',
      component: () => import('@/views/InterviewCreateView.vue'),
      meta: { requiresAuth: true },
    })

    router.addRoute({
      path: '/interview/:sessionId',
      name: 'Interview',
      component: () => import('@/views/InterviewView.vue'),
      meta: { requiresAuth: true },
    })

    router.addRoute({
      path: '/interview/:sessionId/report',
      name: 'InterviewReport',
      component: () => import('@/views/InterviewReportView.vue'),
      meta: { requiresAuth: true },
    })
  },
}
