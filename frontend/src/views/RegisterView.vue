<script setup lang="ts">
import { ref, reactive } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import type { FormInstance, FormRules } from 'element-plus'

/**
 * 注册页面
 */

const router = useRouter()
const authStore = useAuthStore()

/** 表单引用 */
const formRef = ref<FormInstance>()

/** 表单数据 */
const formData = reactive({
  username: '',
  email: '',
  password: '',
  confirmPassword: '',
})

/** 密码校验 */
const validatePassword = (_rule: any, value: string, callback: Function) => {
  if (!value) {
    callback(new Error('请输入密码'))
  } else if (value.length < 6) {
    callback(new Error('密码长度至少 6 个字符'))
  } else {
    callback()
  }
}

/** 确认密码校验 */
const validateConfirmPassword = (_rule: any, value: string, callback: Function) => {
  if (!value) {
    callback(new Error('请再次输入密码'))
  } else if (value !== formData.password) {
    callback(new Error('两次输入的密码不一致'))
  } else {
    callback()
  }
}

/** 表单验证规则 */
const rules: FormRules = {
  username: [
    { required: true, message: '请输入用户名', trigger: 'blur' },
    { min: 3, max: 30, message: '用户名长度为 3-30 个字符', trigger: 'blur' },
  ],
  email: [
    { required: true, message: '请输入邮箱', trigger: 'blur' },
    { type: 'email', message: '请输入正确的邮箱格式', trigger: 'blur' },
  ],
  password: [
    { required: true, validator: validatePassword, trigger: 'blur' },
  ],
  confirmPassword: [
    { required: true, validator: validateConfirmPassword, trigger: 'blur' },
  ],
}

/** 注册 loading */
const loading = ref(false)

/** 错误信息 */
const errorMsg = ref('')

/**
 * 提交注册
 */
async function handleRegister() {
  if (!formRef.value) return

  try {
    await formRef.value.validate()
  } catch {
    return
  }

  loading.value = true
  errorMsg.value = ''

  try {
    await authStore.register({
      username: formData.username,
      email: formData.email,
      password: formData.password,
      confirm_password: formData.confirmPassword,
    })

    // 注册成功后直接登录，跳转首页
    await authStore.login({
      username: formData.username,
      password: formData.password,
    })
    router.push('/')
  } catch (err: any) {
    errorMsg.value = err?.response?.data?.detail || err?.response?.data?.message || '注册失败，请重试'
  } finally {
    loading.value = false
  }
}

/**
 * 跳转登录页
 */
function goToLogin() {
  router.push('/login')
}
</script>

<template>
  <div class="register-page">
    <div class="register-card card">
      <!-- Logo 和标题 -->
      <div class="register-header">
        <img class="logo" src="/logo.png" alt="智能面试助手" />
        <h1 class="title">创建账号</h1>
        <p class="subtitle">开启您的智能面试之旅</p>
      </div>

      <!-- 表单 -->
      <el-form
        ref="formRef"
        :model="formData"
        :rules="rules"
        class="register-form"
        @submit.prevent="handleRegister"
      >
        <el-form-item prop="username">
          <el-input
            v-model="formData.username"
            placeholder="请输入用户名"
            :prefix-icon="'User'"
            size="large"
          />
        </el-form-item>

        <el-form-item prop="email">
          <el-input
            v-model="formData.email"
            placeholder="请输入邮箱"
            :prefix-icon="'Message'"
            size="large"
          />
        </el-form-item>

        <el-form-item prop="password">
          <el-input
            v-model="formData.password"
            type="password"
            placeholder="请输入密码（至少6位）"
            :prefix-icon="'Lock'"
            size="large"
            show-password
          />
        </el-form-item>

        <el-form-item prop="confirmPassword">
          <el-input
            v-model="formData.confirmPassword"
            type="password"
            placeholder="请再次输入密码"
            :prefix-icon="'Lock'"
            size="large"
            show-password
            @keyup.enter="handleRegister"
          />
        </el-form-item>

        <!-- 错误提示 -->
        <el-alert
          v-if="errorMsg"
          :title="errorMsg"
          type="error"
          show-icon
          :closable="false"
          class="register-error"
        />

        <el-form-item>
          <el-button
            type="primary"
            size="large"
            class="w-full"
            :loading="loading"
            @click="handleRegister"
          >
            注 册
          </el-button>
        </el-form-item>
      </el-form>

      <!-- 登录链接 -->
      <div class="register-footer">
        <span class="text-secondary">已有账号？</span>
        <el-button link type="primary" @click="goToLogin">立即登录</el-button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.register-page {
  width: 100%;
  height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #f5f5f7 0%, #e8e6f8 100%);
}

.register-card {
  width: 420px;
  padding: var(--spacing-xl);
}

/* ========== 头部 ========== */
.register-header {
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
.register-form {
  margin-top: var(--spacing-lg);
}

.register-error {
  margin-bottom: var(--spacing-md);
}

/* ========== 底部 ========== */
.register-footer {
  text-align: center;
  font-size: var(--font-sm);
}
</style>
