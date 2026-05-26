<script setup lang="ts">
import { ref, reactive, onMounted, computed, watch } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import { useAuthStore } from '@/stores/auth'
import { useAppStore } from '@/stores/app'
import type { UserInfo } from '@/types'
import {
  getProfileApi,
  updateProfileApi,
  changePasswordApi,
  changeUsernameApi,
  uploadAvatarApi,
  toggleAiUseApi,
} from '@/api/profile'

/**
 * 个人中心页面（独立布局）
 * 左侧导航栏：账号信息 / 个人信息 / 账号安全
 */

const router = useRouter()
const authStore = useAuthStore()
const appStore = useAppStore()

// ========== 导航 Tab ==========

type TabKey = 'account' | 'profile' | 'security'

const activeTab = ref<TabKey>('account')

interface NavItem {
  key: TabKey
  label: string
  icon: string
}

const navItems: NavItem[] = [
  { key: 'account', label: '账号信息', icon: 'User' },
  { key: 'profile', label: '个人信息', icon: 'EditPen' },
  { key: 'security', label: '账号安全', icon: 'Lock' },
]

// ========== 状态 ==========

/** 用户完整信息 */
const userInfo = ref<UserInfo | null>(null)

/** 个人信息表单 */
const profileForm = reactive({
  age: null as number | null,
  gender: '' as string,
  major: '',
  grade: '',
  university: '',
})

/** 个人资料是否正在保存 */
const profileSaving = ref(false)

// ========== 修改密码 ==========

const passwordDialogVisible = ref(false)
const passwordForm = reactive({
  old_password: '',
  new_password: '',
  confirm_password: '',
})
const passwordSubmitting = ref(false)

// ========== 修改用户名 ==========

const usernameDialogVisible = ref(false)
const newUsername = ref('')
const usernameSubmitting = ref(false)

// ========== AI 设置 ==========

const aiToggling = ref(false)

// ========== 头像 ==========

const avatarUploading = ref(false)
const avatarInputRef = ref<HTMLInputElement | null>(null)

// ========== 计算属性 ==========

/** 头像缓存破坏时间戳 */
const avatarTimestamp = ref(Date.now())

watch(
  () => authStore.user?.avatar_url,
  () => { avatarTimestamp.value = Date.now() }
)

/** 头像 URL（带缓存破坏） */
const avatarUrl = computed(() => {
  if (!userInfo.value?.avatar_url) return ''
  const url = userInfo.value.avatar_url
  return url.includes('?') ? `${url}&t=${avatarTimestamp.value}` : `${url}?t=${avatarTimestamp.value}`
})

/** 顶部栏头像 URL */
const headerAvatarUrl = computed(() => {
  const url = authStore.currentUser?.avatar_url
  if (!url) return ''
  return url.includes('?') ? `${url}&t=${avatarTimestamp.value}` : `${url}?t=${avatarTimestamp.value}`
})

/** AI 开关状态 */
const aiSwitchValue = computed({
  get: () => userInfo.value?.profile?.allow_ai_use ?? true,
  set: async (val: boolean) => {
    await handleToggleAi(val)
  },
})

// ========== 方法 ==========

function goBack() {
  router.push('/')
}

function goToMyQuestions() {
  router.push('/my-questions')
}

async function loadUserInfo() {
  try {
    const res = await getProfileApi()
    userInfo.value = res.data
    if (res.data.profile) {
      const p = res.data.profile
      profileForm.age = p.age ?? null
      profileForm.gender = p.gender ?? ''
      profileForm.major = p.major ?? ''
      profileForm.grade = p.grade ?? ''
      profileForm.university = p.university ?? ''
    }
  } catch {
    ElMessage.error('加载个人信息失败')
  }
}

async function handleSaveProfile() {
  profileSaving.value = true
  try {
    const data: Record<string, any> = {}
    if (profileForm.age !== null) data.age = profileForm.age
    if (profileForm.gender) data.gender = profileForm.gender
    if (profileForm.major !== undefined) data.major = profileForm.major
    if (profileForm.grade !== undefined) data.grade = profileForm.grade
    if (profileForm.university !== undefined) data.university = profileForm.university

    await updateProfileApi(data)
    ElMessage.success('个人资料保存成功')
    await loadUserInfo()
  } catch {
    ElMessage.error('保存失败，请重试')
  } finally {
    profileSaving.value = false
  }
}

// 头像
function handleAvatarClick() {
  avatarInputRef.value?.click()
}

async function handleAvatarChange(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (!file) return

  const allowedTypes = ['image/jpeg', 'image/png', 'image/gif', 'image/webp']
  if (!allowedTypes.includes(file.type)) {
    ElMessage.error('仅支持 JPG、PNG、GIF、WebP 格式的头像')
    input.value = ''
    return
  }
  if (file.size > 5 * 1024 * 1024) {
    ElMessage.error('头像文件不能超过 5MB')
    input.value = ''
    return
  }

  avatarUploading.value = true
  try {
    const res = await uploadAvatarApi(file)
    // 同步更新 authStore 和本地 userInfo
    const newAvatarUrl = res.data.avatar_url
    if (authStore.user) {
      authStore.user.avatar_url = newAvatarUrl
      localStorage.setItem('user', JSON.stringify(authStore.user))
    }
    if (userInfo.value) {
      userInfo.value.avatar_url = newAvatarUrl
    }
    ElMessage.success('头像上传成功')
  } catch {
    ElMessage.error('头像上传失败')
  } finally {
    avatarUploading.value = false
    input.value = ''
  }
}

// 用户名
function openUsernameDialog() {
  newUsername.value = userInfo.value?.username || ''
  usernameDialogVisible.value = true
}

async function handleChangeUsername() {
  if (!newUsername.value.trim()) {
    ElMessage.warning('用户名不能为空')
    return
  }
  if (newUsername.value.trim() === userInfo.value?.username) {
    usernameDialogVisible.value = false
    return
  }

  usernameSubmitting.value = true
  try {
    const res = await changeUsernameApi({ new_username: newUsername.value.trim() })
    authStore.user = res.data as any
    localStorage.setItem('user', JSON.stringify(res.data))
    userInfo.value = res.data
    ElMessage.success('用户名修改成功')
    usernameDialogVisible.value = false
  } catch {
    ElMessage.error('用户名修改失败')
  } finally {
    usernameSubmitting.value = false
  }
}

// 密码
function openPasswordDialog() {
  passwordForm.old_password = ''
  passwordForm.new_password = ''
  passwordForm.confirm_password = ''
  passwordDialogVisible.value = true
}

async function handleChangePassword() {
  if (!passwordForm.old_password) {
    ElMessage.warning('请输入旧密码')
    return
  }
  if (passwordForm.new_password.length < 6) {
    ElMessage.warning('新密码长度不能少于 6 位')
    return
  }
  if (passwordForm.new_password !== passwordForm.confirm_password) {
    ElMessage.warning('两次输入的新密码不一致')
    return
  }

  passwordSubmitting.value = true
  try {
    await changePasswordApi({
      old_password: passwordForm.old_password,
      new_password: passwordForm.new_password,
    })
    ElMessage.success('密码修改成功，请重新登录')
    passwordDialogVisible.value = false
    setTimeout(() => {
      authStore.logout()
    }, 1500)
  } catch {
    ElMessage.error('密码修改失败，请检查旧密码是否正确')
  } finally {
    passwordSubmitting.value = false
  }
}

// AI 开关
async function handleToggleAi(val: boolean) {
  aiToggling.value = true
  try {
    await toggleAiUseApi({ allow_ai_use: val })
    ElMessage.success(val ? '已开启 AI 个性化' : '已关闭 AI 个性化')
    if (userInfo.value?.profile) {
      userInfo.value.profile.allow_ai_use = val
    }
  } catch {
    ElMessage.error('设置失败')
  } finally {
    aiToggling.value = false
  }
}

// 退出登录
function handleLogout() {
  ElMessageBox.confirm('确定要退出登录吗？', '提示', {
    confirmButtonText: '确定',
    cancelButtonText: '取消',
    type: 'warning',
  }).then(() => {
    authStore.logout()
  }).catch(() => {})
}

// ========== 生命周期 ==========

onMounted(() => {
  loadUserInfo()
})
</script>

<template>
  <div class="profile-page">
    <!-- 顶部栏 -->
    <header class="profile-header">
      <div class="header-left">
        <el-button text @click="goBack">
          <el-icon><ArrowLeft /></el-icon>
          <span>返回对话</span>
        </el-button>
        <span class="header-divider">|</span>
        <span class="header-title">个人中心</span>
      </div>
      <div class="header-right">
        <el-tooltip :content="appStore.isDark ? '切换亮色模式' : '切换暗色模式'" placement="bottom">
          <el-button
            :icon="appStore.isDark ? 'Sunny' : 'Moon'"
            circle
            @click="appStore.toggleTheme()"
          />
        </el-tooltip>
        <el-dropdown trigger="click">
          <div class="user-info">
            <el-avatar :size="32" :src="headerAvatarUrl" :style="{ backgroundColor: '#534AB7' }">
              {{ authStore.currentUser?.username?.charAt(0)?.toUpperCase() || 'U' }}
            </el-avatar>
            <span class="user-name">{{ authStore.currentUser?.username || '用户' }}</span>
            <el-icon :size="12"><ArrowDown /></el-icon>
          </div>
          <template #dropdown>
            <el-dropdown-menu>
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

    <!-- 主体区域 -->
    <div class="profile-body">
      <!-- 左侧导航 -->
      <aside class="profile-nav">
        <div
          v-for="item in navItems"
          :key="item.key"
          class="nav-item"
          :class="{ active: activeTab === item.key }"
          @click="activeTab = item.key"
        >
          <el-icon :size="18"><component :is="item.icon" /></el-icon>
          <span>{{ item.label }}</span>
        </div>
      </aside>

      <!-- 右侧内容 -->
      <main class="profile-content">
        <!-- ====== 账号信息 ====== -->
        <div v-if="activeTab === 'account'" class="tab-content">
          <h2 class="content-title">账号信息</h2>

          <!-- 头像卡片 -->
          <el-card class="info-card" shadow="never">
            <div class="avatar-section">
              <div class="avatar-wrapper" @click="handleAvatarClick">
                <el-avatar
                  :size="80"
                  :src="avatarUrl"
                  :style="{ backgroundColor: '#534AB7' }"
                >
                  {{ authStore.currentUser?.username?.charAt(0)?.toUpperCase() || 'U' }}
                </el-avatar>
                <div class="avatar-overlay" :class="{ uploading: avatarUploading }">
                  <el-icon :size="20" v-if="!avatarUploading"><Camera /></el-icon>
                  <el-icon :size="20" class="is-loading" v-else><Loading /></el-icon>
                </div>
              </div>
              <span class="avatar-hint">点击更换头像（JPG/PNG/GIF/WebP，5MB内）</span>
            </div>
          </el-card>

          <!-- 基本信息卡片 -->
          <el-card class="info-card" shadow="never">
            <div class="info-list">
              <div class="info-item">
                <span class="info-label">用户名</span>
                <span class="info-value">{{ userInfo?.username }}</span>
                <el-button size="small" text type="primary" @click="openUsernameDialog">修改</el-button>
              </div>
              <div class="info-item">
                <span class="info-label">邮箱</span>
                <span class="info-value">{{ userInfo?.email || '未设置' }}</span>
              </div>
              <div class="info-item">
                <span class="info-label">角色</span>
                <el-tag size="small" :type="authStore.isAdmin ? 'danger' : 'info'">
                  {{ authStore.isAdmin ? '管理员' : '普通用户' }}
                </el-tag>
              </div>
              <div class="info-item">
                <span class="info-label">注册时间</span>
                <span class="info-value">
                  {{ userInfo?.created_at ? new Date(userInfo.created_at).toLocaleDateString('zh-CN') : '-' }}
                </span>
              </div>
            </div>
          </el-card>

        </div>

        <!-- ====== 个人信息 ====== -->
        <div v-if="activeTab === 'profile'" class="tab-content">
          <h2 class="content-title">个人信息</h2>

          <!-- AI 设置卡片 -->
          <el-card class="info-card" shadow="never">
            <div class="info-list">
              <div class="info-item ai-item">
                <div class="ai-info">
                  <span class="info-label" style="font-weight: 500; color: var(--color-text)">允许 AI 使用我的个人信息</span>
                  <span class="ai-desc">
                    开启后，AI 将在对话中结合您的学历背景、专业等信息，提供更有针对性的面试建议和职业规划指导。
                  </span>
                </div>
                <el-switch
                  v-model="aiSwitchValue"
                  :loading="aiToggling"
                  active-color="#534AB7"
                  size="large"
                />
              </div>
            </div>
          </el-card>

          <h2 class="content-title" style="margin-top: var(--spacing-xl)">求职信息</h2>
          <el-card class="info-card" shadow="never">
            <el-form
              :model="profileForm"
              label-width="80px"
              label-position="left"
              class="profile-form"
            >
              <el-row :gutter="24">
                <el-col :span="12">
                  <el-form-item label="年龄">
                    <el-input-number
                      v-model="profileForm.age"
                      :min="1"
                      :max="120"
                      placeholder="请输入年龄"
                      controls-position="right"
                      style="width: 100%"
                    />
                  </el-form-item>
                </el-col>
                <el-col :span="12">
                  <el-form-item label="性别">
                    <el-select v-model="profileForm.gender" placeholder="请选择性别" style="width: 100%">
                      <el-option label="男" value="male" />
                      <el-option label="女" value="female" />
                      <el-option label="其他" value="other" />
                    </el-select>
                  </el-form-item>
                </el-col>
              </el-row>

              <el-row :gutter="24">
                <el-col :span="12">
                  <el-form-item label="就读大学">
                    <el-input v-model="profileForm.university" placeholder="请输入大学名称" />
                  </el-form-item>
                </el-col>
                <el-col :span="12">
                  <el-form-item label="年级">
                    <el-input v-model="profileForm.grade" placeholder="如：大一、研一" />
                  </el-form-item>
                </el-col>
              </el-row>

              <el-row :gutter="24">
                <el-col :span="12">
                  <el-form-item label="专业">
                    <el-input v-model="profileForm.major" placeholder="请输入专业名称" />
                  </el-form-item>
                </el-col>
              </el-row>

              <el-form-item>
                <el-button type="primary" :loading="profileSaving" @click="handleSaveProfile">
                  {{ profileSaving ? '保存中...' : '保存信息' }}
                </el-button>
              </el-form-item>
            </el-form>
          </el-card>
        </div>

        <!-- ====== 账号安全 ====== -->
        <div v-if="activeTab === 'security'" class="tab-content">
          <h2 class="content-title">账号安全</h2>
          <el-card class="info-card" shadow="never">
            <div class="security-list">
              <div class="security-item">
                <div class="security-info">
                  <span class="security-label">登录密码</span>
                  <span class="security-desc">修改后需要重新登录</span>
                </div>
                <el-button size="small" type="primary" plain @click="openPasswordDialog">
                  修改密码
                </el-button>
              </div>
            </div>
          </el-card>
        </div>
      </main>
    </div>

    <!-- 隐藏的头像上传 input -->
    <input
      ref="avatarInputRef"
      type="file"
      accept="image/jpeg,image/png,image/gif,image/webp"
      style="display: none"
      @change="handleAvatarChange"
    />

    <!-- 修改用户名对话框 -->
    <el-dialog
      v-model="usernameDialogVisible"
      title="修改用户名"
      width="420px"
      :close-on-click-modal="false"
    >
      <el-form label-width="80px">
        <el-form-item label="新用户名">
          <el-input
            v-model="newUsername"
            placeholder="请输入新用户名（3-64个字符）"
            :minlength="3"
            :maxlength="64"
          />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="usernameDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="usernameSubmitting" @click="handleChangeUsername">
          确认修改
        </el-button>
      </template>
    </el-dialog>

    <!-- 修改密码对话框 -->
    <el-dialog
      v-model="passwordDialogVisible"
      title="修改密码"
      width="420px"
      :close-on-click-modal="false"
    >
      <el-form label-width="80px">
        <el-form-item label="旧密码">
          <el-input
            v-model="passwordForm.old_password"
            type="password"
            placeholder="请输入旧密码"
            show-password
          />
        </el-form-item>
        <el-form-item label="新密码">
          <el-input
            v-model="passwordForm.new_password"
            type="password"
            placeholder="请输入新密码（至少6位）"
            show-password
          />
        </el-form-item>
        <el-form-item label="确认密码">
          <el-input
            v-model="passwordForm.confirm_password"
            type="password"
            placeholder="再次输入新密码"
            show-password
          />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="passwordDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="passwordSubmitting" @click="handleChangePassword">
          确认修改
        </el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
/* ========== 整体布局 ========== */
.profile-page {
  display: flex;
  flex-direction: column;
  height: 100vh;
  overflow: hidden;
}

/* ========== 顶部栏 ========== */
.profile-header {
  height: var(--header-height);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 var(--spacing-lg);
  background: var(--color-card);
  border-bottom: 1px solid var(--color-border-light);
  flex-shrink: 0;
}

.header-left {
  display: flex;
  align-items: center;
  gap: var(--spacing-sm);
}

.header-divider {
  color: var(--color-border-light);
  margin: 0 4px;
}

.header-title {
  font-size: var(--font-lg);
  font-weight: 600;
  color: var(--color-text);
}

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

/* ========== 主体区域 ========== */
.profile-body {
  display: flex;
  flex: 1;
  overflow: hidden;
}

/* ========== 左侧导航 ========== */
.profile-nav {
  width: 200px;
  flex-shrink: 0;
  background: var(--color-card);
  border-right: 1px solid var(--color-border-light);
  padding: var(--spacing-md) 0;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.nav-item {
  display: flex;
  align-items: center;
  gap: var(--spacing-sm);
  padding: 12px var(--spacing-lg);
  cursor: pointer;
  transition: all 0.2s;
  color: var(--color-text-secondary);
  font-size: var(--font-sm);
  border-left: 3px solid transparent;
}

.nav-item:hover {
  background: var(--color-bg);
  color: var(--color-text);
}

.nav-item.active {
  color: var(--color-primary);
  background: var(--color-primary-lighter);
  border-left-color: var(--color-primary);
  font-weight: 500;
}

/* ========== 右侧内容 ========== */
.profile-content {
  flex: 1;
  overflow-y: auto;
  background: var(--color-bg);
}

.tab-content {
  max-width: 720px;
  margin: 0 auto;
  padding: var(--spacing-lg);
}

.content-title {
  font-size: var(--font-title);
  font-weight: 700;
  color: var(--color-text);
  margin: 0 0 var(--spacing-lg) 0;
}

/* ========== 卡片 ========== */
.info-card {
  margin-bottom: var(--spacing-md);
  border: 1px solid var(--color-border-light);
  border-radius: var(--radius-lg);
}

.info-card :deep(.el-card__body) {
  padding: 20px;
}

/* ========== 头像 ========== */
.avatar-section {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--spacing-sm);
  padding: var(--spacing-md) 0;
}

.avatar-wrapper {
  position: relative;
  cursor: pointer;
  border-radius: 50%;
}

.avatar-overlay {
  position: absolute;
  inset: 0;
  border-radius: 50%;
  background: rgba(0, 0, 0, 0.4);
  display: flex;
  align-items: center;
  justify-content: center;
  color: #fff;
  opacity: 0;
  transition: opacity 0.2s;
}

.avatar-overlay.uploading {
  opacity: 1;
}

.avatar-wrapper:hover .avatar-overlay {
  opacity: 1;
}

.avatar-hint {
  font-size: var(--font-xs);
  color: var(--color-text-placeholder);
  text-align: center;
}

/* ========== 信息列表 ========== */
.info-list {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.info-item {
  display: flex;
  align-items: center;
  gap: var(--spacing-sm);
}

.info-label {
  font-size: var(--font-sm);
  color: var(--color-text-secondary);
  min-width: 60px;
}

.info-value {
  font-size: var(--font-sm);
  color: var(--color-text);
  flex: 1;
}

/* ========== AI 设置 ========== */
.ai-item {
  align-items: flex-start !important;
  justify-content: space-between;
}

.ai-info {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 4px;
  margin-right: var(--spacing-lg);
}

.ai-desc {
  font-size: var(--font-xs);
  color: var(--color-text-placeholder);
  line-height: 1.5;
}

/* ========== 账号安全 ========== */
.security-list {
  display: flex;
  flex-direction: column;
}

.security-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 8px 0;
}

.security-info {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.security-label {
  font-size: var(--font-sm);
  font-weight: 500;
  color: var(--color-text);
}

.security-desc {
  font-size: var(--font-xs);
  color: var(--color-text-placeholder);
}

/* ========== 个人信息表单 ========== */
.profile-form :deep(.el-form-item) {
  margin-bottom: 16px;
}

/* ========== 响应式 ========== */
@media (max-width: 768px) {
  .profile-nav {
    width: 160px;
  }

  .header-title {
    display: none;
  }

  .user-name {
    display: none;
  }
}
</style>
