<script setup lang="ts">
import { ref, onMounted, nextTick, watch, computed } from 'vue'
import { ElMessage } from 'element-plus'
import { useChatStore } from '@/stores/chat'
import Sidebar from '@/components/Sidebar.vue'
import AppHeader from '@/components/AppHeader.vue'
import ChatMessage from '@/components/ChatMessage.vue'

/**
 * 对话主界面（核心页面）
 * 统一入口：功能标签 + 对话框 + 文件上传
 */

const chatStore = useChatStore()

/** 消息列表容器引用 */
const messageListRef = ref<HTMLElement | null>(null)

/** 输入框内容 */
const inputText = ref('')

/** 文件输入引用 */
const resumeInputRef = ref<HTMLInputElement | null>(null)
const recordingInputRef = ref<HTMLInputElement | null>(null)
const questionResumeInputRef = ref<HTMLInputElement | null>(null)

/** 是否正在拖拽 */
const isDragOver = ref(false)
/** 拖拽计数器（解决子元素冒泡导致的闪烁） */
const dragCounter = ref(0)

/** 功能标签配置 */
const featureTags = [
  { key: 'resume', label: '简历评估', icon: 'Document', accept: '.pdf,.doc,.docx,.jpg,.jpeg,.png' },
  { key: 'recording', label: '录音分析', icon: 'Microphone', accept: '.mp3,.wav,.m4a,.aac,.ogg,.flac,.mp4,.avi,.mov' },
  { key: 'question', label: '面试题生成', icon: 'EditPen', accept: '.pdf,.doc,.docx' },
]

/** 当前激活的标签 */
const activeTag = computed(() => chatStore.activeAgentType)

/**
 * 滚动到底部
 */
function scrollToBottom() {
  nextTick(() => {
    if (messageListRef.value) {
      messageListRef.value.scrollTop = messageListRef.value.scrollHeight
    }
  })
}

/**
 * 点击功能标签
 */
function handleTagClick(tag: typeof featureTags[0]) {
  // 如果当前标签已激活，取消选中
  if (activeTag.value === tag.key) {
    chatStore.activeAgentType = 'general'
    return
  }
  // 如果有文件类型要求，打开文件选择器
  if (tag.accept) {
    if (tag.key === 'resume') {
      chatStore.activeAgentType = tag.key
      resumeInputRef.value?.click()
    } else if (tag.key === 'recording') {
      chatStore.activeAgentType = tag.key
      recordingInputRef.value?.click()
    } else if (tag.key === 'question') {
      chatStore.activeAgentType = tag.key
      questionResumeInputRef.value?.click()
    }
  } else {
    // 题目生成不需要文件，直接准备对话
    chatStore.activeAgentType = tag.key
    // 如果没有对话就创建一个
    if (!chatStore.currentConversationId) {
      chatStore.createConversation('面试题生成', 'question')
    }
  }
}

/**
 * 处理简历文件选择
 */
async function handleResumeSelect(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (file) {
    await handleFileSelected(file, 'resume')
  }
  input.value = ''
}

/**
 * 处理录音文件选择
 */
async function handleRecordingSelect(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (file) {
    await handleFileSelected(file, 'recording')
  }
  input.value = ''
}

async function handleQuestionResumeSelect(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (file) {
    await handleFileSelected(file, 'question')
  }
  input.value = ''
}

/**
 * 处理文件选中后上传
 */
async function handleFileSelected(file: File, agentType: string) {
  try {
    chatStore.activeAgentType = agentType
    await chatStore.addPendingFile(file)
    ElMessage.success(`${file.name} 上传成功，可输入补充文字后点击发送`)
    // 不自动发送，保留在 pendingFiles 中等用户手动点击发送
  } catch (error) {
    ElMessage.error('文件上传失败，请重试')
  }
}

/**
 * 发送消息
 */
async function handleSend() {
  const content = inputText.value.trim()
  if ((!content && chatStore.pendingFiles.length === 0) || chatStore.isSending) return

  // 如果有待发送文件，优先使用文件的 agent 类型
  let agentType = chatStore.activeAgentType || 'general'
  let fileUrl: string | undefined

  if (chatStore.pendingFiles.length > 0) {
    fileUrl = chatStore.pendingFiles[0].fileUrl
  }

  inputText.value = ''

  try {
    // 如果没有活跃对话，先创建
    if (!chatStore.currentConversationId) {
      const title = agentType === 'resume' ? '简历评估' :
                    agentType === 'recording' ? '录音分析' :
                    agentType === 'question' ? '面试题生成' : '新对话'
      await chatStore.createConversation(title, agentType)
    }

    // 使用流式对话（传文件 URL）
    await chatStore.streamChat(content || '分析上传的文件', agentType, fileUrl)
    scrollToBottom()
  } catch (error) {
    ElMessage.error('发送失败，请重试')
  }
}

/**
 * 回车发送消息
 */
function handleKeyDown(e: KeyboardEvent) {
  if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault()
    handleSend()
  }
}

/**
 * 拖拽事件处理
 */
function handleDragEnter(e: DragEvent) {
  e.preventDefault()
  dragCounter.value++
  if (dragCounter.value === 1) {
    isDragOver.value = true
  }
}

function handleDragLeave(e: DragEvent) {
  e.preventDefault()
  dragCounter.value--
  if (dragCounter.value <= 0) {
    dragCounter.value = 0
    isDragOver.value = false
  }
}

function handleDragOver(e: DragEvent) {
  e.preventDefault()
}

async function handleDrop(e: DragEvent) {
  e.preventDefault()
  dragCounter.value = 0
  isDragOver.value = false

  const files = e.dataTransfer?.files
  if (!files || files.length === 0) return

  const file = files[0]
  chatStore.activeAgentType = 'general'
  await handleFileSelected(file, 'general')
}

/** 监听消息变化，自动滚动 */
watch(() => chatStore.messages.length, () => {
  scrollToBottom()
})

/** 监听 Agent 状态变化 */
watch(() => chatStore.agentStatus, () => {
  scrollToBottom()
})

onMounted(() => {
  // 初始化：加载对话列表
  chatStore.fetchConversations()
})
</script>

<template>
  <div class="chat-layout" @dragenter="handleDragEnter" @dragleave="handleDragLeave" @dragover="handleDragOver" @drop="handleDrop">
    <!-- 顶部导航（占据整页宽度） -->
    <AppHeader />

    <!-- 下方区域：左侧边栏 + 右侧内容 -->
    <div class="chat-body">
      <!-- 左侧边栏 -->
      <Sidebar />

      <!-- 右侧主区域 -->
      <div class="chat-main">

      <!-- 消息列表区域 -->
      <div class="chat-content">
        <!-- 空状态 -->
        <div v-if="!chatStore.currentConversationId" class="empty-state">
          <div class="empty-icon">
            <el-icon :size="64" color="#9E9D9A"><ChatDotRound /></el-icon>
          </div>
          <h2 class="empty-title">智能面试助手</h2>
          <p class="empty-desc">选择功能标签或发送消息开始对话</p>
          <div class="feature-tags-inline">
            <div
              v-for="tag in featureTags"
              :key="tag.key"
              class="feature-tag-card"
              @click="handleTagClick(tag)"
            >
              <el-icon :size="28" color="#534AB7"><component :is="tag.icon" /></el-icon>
              <span class="tag-label">{{ tag.label }}</span>
            </div>
          </div>
        </div>

        <!-- 消息列表 -->
        <div
          v-else
          ref="messageListRef"
          class="message-list"
        >
          <!-- 加载对话信息 -->
          <div v-if="chatStore.messages.length === 0 && !chatStore.isSending" class="empty-conversation">
            <p>发送消息开始对话，或使用下方功能标签</p>
          </div>

          <!-- 消息列表 -->
          <template v-for="msg in chatStore.sortedMessages" :key="msg.id">
            <ChatMessage :message="msg" />
          </template>

          <!-- Agent 执行进度 -->
          <div v-if="chatStore.agentStatus" class="agent-status-area">
            <div class="agent-status-card">
              <el-icon :size="16" class="is-loading" color="#534AB7"><Loading /></el-icon>
              <span class="agent-status-text">{{ chatStore.agentStatus.agent_name }} - {{ chatStore.agentStatus.message || '处理中...' }}</span>
              <el-progress
                v-if="chatStore.agentStatus.progress"
                :percentage="chatStore.agentStatus.progress"
                :stroke-width="4"
                :show-text="false"
                style="width: 80px"
              />
            </div>
          </div>
        </div>
      </div>

      <!-- 输入区域 -->
      <div class="chat-input-area">
        <!-- 拖拽遮罩 -->
        <div v-if="isDragOver" class="drag-overlay">
          <el-icon :size="48" color="#534AB7"><Upload /></el-icon>
          <span>释放文件上传</span>
        </div>

        <!-- 待发送文件预览 -->
        <div v-if="chatStore.pendingFiles.length > 0" class="pending-files">
          <div
            v-for="(pf, index) in chatStore.pendingFiles"
            :key="index"
            class="pending-file-item"
          >
            <el-icon :size="18" color="#534AB7">
              <component :is="chatStore.activeAgentType === 'recording' ? 'Headset' : 'Document'" />
            </el-icon>
            <span class="pending-file-name text-ellipsis">{{ pf.fileName }}</span>
            <el-icon
              :size="16"
              class="pending-file-remove"
              @click="chatStore.removePendingFile(index)"
            ><Close /></el-icon>
          </div>
        </div>

        <!-- Agent 状态标签 -->
        <div v-if="chatStore.agentStatus" class="agent-hint">
          <el-icon :size="14" class="is-loading" color="#534AB7"><Loading /></el-icon>
          <span>{{ chatStore.agentStatus.agent_name }} 正在处理...</span>
        </div>

        <!-- 功能标签 -->
        <div class="feature-tags">
          <div
            v-for="tag in featureTags"
            :key="tag.key"
            class="feature-tag"
            :class="{ active: activeTag === tag.key }"
            @click="handleTagClick(tag)"
          >
            <el-icon :size="14"><component :is="tag.icon" /></el-icon>
            <span>{{ tag.label }}</span>
          </div>
        </div>

        <!-- 输入工具栏 -->
        <div class="input-row">
          <div class="input-tools">
            <el-tooltip content="上传简历（PDF/Word/图片）" placement="top">
              <el-button
                :icon="'Document'"
                circle
                :type="activeTag === 'resume' ? 'primary' : 'default'"
                @click="resumeInputRef?.click()"
              />
            </el-tooltip>
            <el-tooltip content="上传录音（音频/视频）" placement="top">
              <el-button
                :icon="'Microphone'"
                circle
                :type="activeTag === 'recording' ? 'primary' : 'default'"
                @click="recordingInputRef?.click()"
              />
            </el-tooltip>
          </div>
          <textarea
            v-model="inputText"
            class="chat-textarea"
            :placeholder="activeTag === 'question' ? '输入岗位方向，生成面试题...' : '输入您的问题，按 Enter 发送，Shift+Enter 换行...'"
            rows="1"
            :disabled="chatStore.isSending"
            @keydown="handleKeyDown"
            @input="(e: Event) => {
              const target = e.target as HTMLTextAreaElement
              target.style.height = 'auto'
              target.style.height = Math.min(target.scrollHeight, 150) + 'px'
            }"
          ></textarea>
          <el-button
            type="primary"
            :icon="'Promotion'"
            :disabled="(!inputText.trim() && chatStore.pendingFiles.length === 0) || chatStore.isSending"
            :loading="chatStore.isSending"
            @click="handleSend"
          >
            发送
          </el-button>
        </div>

        <!-- 隐藏的文件输入 -->
        <input
          ref="resumeInputRef"
          type="file"
          accept=".pdf,.doc,.docx,.jpg,.jpeg,.png"
          style="display: none"
          @change="handleResumeSelect"
        />
        <input
          ref="recordingInputRef"
          type="file"
          accept=".mp3,.wav,.m4a,.aac,.ogg,.flac,.mp4,.avi,.mov"
          style="display: none"
          @change="handleRecordingSelect"
        />
        <input
          ref="questionResumeInputRef"
          type="file"
          accept=".pdf,.doc,.docx"
          style="display: none"
          @change="handleQuestionResumeSelect"
        />
      </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.chat-layout {
  display: flex;
  flex-direction: column;
  height: 100vh;
  overflow: hidden;
}

/* ========== 下方区域：侧栏 + 主内容 ========== */
.chat-body {
  display: flex;
  flex: 1;
  overflow: hidden;
}

/* ========== 右侧主区域 ========== */
.chat-main {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-width: 0;
  overflow: hidden;
}

/* ========== 消息区域 ========== */
.chat-content {
  flex: 1;
  overflow: hidden;
  background: var(--color-bg);
}

/* 空状态（无活跃对话） */
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 100%;
  gap: var(--spacing-md);
}

.empty-icon {
  opacity: 0.4;
}

.empty-title {
  font-size: var(--font-title);
  font-weight: 700;
  color: var(--color-text);
}

.empty-desc {
  font-size: var(--font-md);
  color: var(--color-text-secondary);
}

/* 空状态下的功能标签卡片 */
.feature-tags-inline {
  display: flex;
  gap: var(--spacing-lg);
  margin-top: var(--spacing-md);
}

.feature-tag-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--spacing-sm);
  padding: var(--spacing-lg) var(--spacing-xl);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  cursor: pointer;
  transition: all 0.3s ease;
  background: var(--color-card);
  min-width: 120px;
}

.feature-tag-card:hover {
  border-color: var(--color-primary);
  background: var(--color-primary-lighter);
  transform: translateY(-2px);
  box-shadow: var(--shadow-md);
}

.tag-label {
  font-size: var(--font-sm);
  font-weight: 500;
  color: var(--color-text);
}

/* 空对话 */
.empty-conversation {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 100%;
  color: var(--color-text-placeholder);
  font-size: var(--font-md);
}

/* 消息列表 */
.message-list {
  height: 100%;
  overflow-y: auto;
  padding: var(--spacing-md) 0;
}

/* Agent 进度区域 */
.agent-status-area {
  padding: 0 var(--spacing-md) var(--spacing-sm);
}

.agent-status-card {
  display: flex;
  align-items: center;
  gap: var(--spacing-sm);
  padding: 10px 16px;
  background: #f8f7ff;
  border: 1px solid #ebe7ff;
  border-radius: 8px;
  font-size: var(--font-sm);
  color: #534AB7;
}

.agent-status-text {
  flex: 1;
}

/* ========== 输入区域 ========== */
.chat-input-area {
  position: relative;
  padding: var(--spacing-md);
  background: var(--color-card);
  border-top: 1px solid var(--color-border-light);
}

/* 拖拽遮罩 */
.drag-overlay {
  position: absolute;
  inset: 0;
  background: rgba(83, 74, 183, 0.08);
  border: 2px dashed var(--color-primary);
  border-radius: var(--radius-md);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: var(--spacing-sm);
  z-index: 10;
  color: var(--color-primary);
  font-size: var(--font-md);
  font-weight: 500;
}

/* 待发送文件预览 */
.pending-files {
  display: flex;
  flex-wrap: wrap;
  gap: var(--spacing-sm);
  margin-bottom: var(--spacing-sm);
}

.pending-file-item {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 6px 12px;
  background: #f8f7ff;
  border: 1px solid #ebe7ff;
  border-radius: 20px;
  font-size: var(--font-sm);
}

.pending-file-name {
  max-width: 160px;
  color: var(--color-text);
}

.pending-file-remove {
  cursor: pointer;
  color: var(--color-text-placeholder);
  transition: color 0.2s;
}

.pending-file-remove:hover {
  color: var(--color-danger);
}

/* 功能标签 */
.feature-tags {
  display: flex;
  gap: var(--spacing-sm);
  margin-bottom: var(--spacing-sm);
}

.feature-tag {
  display: flex;
  align-items: center;
  gap: 4px;
  padding: 5px 14px;
  border: 1px solid var(--color-border);
  border-radius: 20px;
  cursor: pointer;
  font-size: var(--font-sm);
  color: var(--color-text-secondary);
  transition: all 0.2s ease;
  background: var(--color-bg);
  user-select: none;
}

.feature-tag:hover {
  border-color: var(--color-primary);
  color: var(--color-primary);
  background: var(--color-primary-lighter);
}

.feature-tag.active {
  border-color: var(--color-primary);
  color: #fff;
  background: var(--color-primary);
}

.agent-hint {
  display: flex;
  align-items: center;
  gap: var(--spacing-sm);
  padding: 4px 0;
  font-size: var(--font-xs);
  color: var(--color-primary);
}

.input-row {
  display: flex;
  align-items: flex-end;
  gap: var(--spacing-sm);
}

.input-tools {
  display: flex;
  gap: 4px;
}

.chat-textarea {
  flex: 1;
  resize: none;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  padding: 10px 14px;
  font-size: var(--font-md);
  line-height: 1.5;
  color: var(--color-text);
  background: var(--color-bg);
  outline: none;
  max-height: 150px;
  font-family: inherit;
  transition: border-color 0.2s;
}

.chat-textarea:focus {
  border-color: var(--color-primary);
}

.chat-textarea:disabled {
  background: var(--color-bg-dark);
  cursor: not-allowed;
}

.chat-textarea::placeholder {
  color: var(--color-text-placeholder);
}
</style>
