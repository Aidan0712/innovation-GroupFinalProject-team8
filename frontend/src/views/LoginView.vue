<script setup lang="ts">
import { ref, reactive } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import type { FormInstance, FormRules } from 'element-plus'

/**
 * 登录页面
 */

const router = useRouter()
const route = useRoute()
const authStore = useAuthStore()

/** 表单引用 */
const formRef = ref<FormInstance>()

/** 表单数据 */
const formData = reactive({
  username: '',
  password: '',
})

/** 表单验证规则 */
const rules: FormRules = {
  username: [
    { required: true, message: '请输入用户名', trigger: 'blur' },
    { min: 3, max: 30, message: '用户名长度为 3-30 个字符', trigger: 'blur' },
  ],
  password: [
    { required: true, message: '请输入密码', trigger: 'blur' },
    { min: 6, max: 50, message: '密码长度至少 6 个字符', trigger: 'blur' },
  ],
}

/** 登录 loading */
const loading = ref(false)

/** 错误信息 */
const errorMsg = ref('')

/**
 * 提交登录
 */
async function handleLogin() {
  if (!formRef.value) return

  try {
    await formRef.value.validate()
  } catch {
    return
  }

  loading.value = true
  errorMsg.value = ''

  try {
    await authStore.login({
      username: formData.username,
      password: formData.password,
    })

    // 登录成功后跳转到重定向页面或首页
    const redirect = (route.query.redirect as string) || '/'
    router.push(redirect)
  } catch (err: any) {
    errorMsg.value = err?.response?.data?.message || '登录失败，请重试'
  } finally {
    loading.value = false
  }
}

/**
 * 跳转注册页
 */
function goToRegister() {
  router.push('/register')
}
</script>

<template>
  <div class="login-page">
    <div class="login-card card">
      <!-- Logo 和标题 -->
      <div class="login-header">
        <img class="logo" src="/logo.png" alt="智能面试助手" />
        <h1 class="title">智能面试助手</h1>
        <p class="subtitle">AI 驱动的智能面试平台</p>
      </div>

      <!-- 表单 -->
      <el-form
        ref="formRef"
        :model="formData"
        :rules="rules"
        class="login-form"
        @submit.prevent="handleLogin"
      >
        <el-form-item prop="username">
          <el-input
            v-model="formData.username"
            placeholder="请输入用户名"
            :prefix-icon="'User'"
            size="large"
          />
        </el-form-item>

        <el-form-item prop="password">
          <el-input
            v-model="formData.password"
            type="password"
            placeholder="请输入密码"
            :prefix-icon="'Lock'"
            size="large"
            show-password
            @keyup.enter="handleLogin"
          />
        </el-form-item>

        <!-- 错误提示 -->
        <el-alert
          v-if="errorMsg"
          :title="errorMsg"
          type="error"
          show-icon
          :closable="false"
          class="login-error"
        />

        <el-form-item>
          <el-button
            type="primary"
            size="large"
            class="w-full"
            :loading="loading"
            @click="handleLogin"
          >
            登 录
          </el-button>
        </el-form-item>
      </el-form>

      <!-- 注册链接 -->
      <div class="login-footer">
        <span class="text-secondary">还没有账号？</span>
        <el-button link type="primary" @click="goToRegister">立即注册</el-button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.login-page {
  width: 100%;
  height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #f5f5f7 0%, #e8e6f8 100%);
}

.login-card {
  width: 420px;
  padding: var(--spacing-xl);
}

/* ========== 头部 ========== */
.login-header {
  text-align: center;
  margin-bottom: var(--spacing-xl);
}

.logo {
  width: 56px;
  height: 56px;
  margin: 0 auto var(--spacing-md);
  object-fit: cover;
  border-radius: var(--radius-lg);
}

.title {
  font-size: var(--font-title);
  font-weight: 700;
  color: var(--color-text);
  margin-bottom: var(--spacing-xs);
}

.subtitle {
  font-size: var(--font-sm);
  color: var(--color-text-secondary);
}

/* ========== 表单 ========== */
.login-form {
  margin-top: var(--spacing-lg);
}

.login-error {
  margin-bottom: var(--spacing-md);
}

/* ========== 底部 ========== */
.login-footer {
  text-align: center;
  font-size: var(--font-sm);
}
</style>
