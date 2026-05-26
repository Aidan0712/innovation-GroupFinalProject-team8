<script setup lang="ts">
import { computed, ref } from 'vue'
import { ElMessage } from 'element-plus'
import { Document, Loading, CopyDocument, Check } from '@element-plus/icons-vue'
import { marked } from 'marked'
import DOMPurify from 'dompurify'
import type { ChatMessage } from '@/types'
import ReportCard from './ReportCard.vue'

/**
 * 对话消息气泡组件
 * 根据角色区分用户/AI/系统消息，支持 Markdown 渲染、思考链展示、复制功能
 */

const props = defineProps<{
  message: ChatMessage
}>()

// ========== Markdown 配置 ==========
marked.setOptions({
  breaks: true,
  gfm: true,
})

/** 将 Markdown 文本安全渲染为 HTML */
function renderMarkdown(text: string): string {
  // 如果内容是 JSON 格式，转换为 Markdown 表格和列表
  const processed = convertJsonToMarkdown(text)
  const raw = marked.parse(processed) as string
  return DOMPurify.sanitize(raw)
}

/** 将 JSON 格式的文本转换为可读的 Markdown */
function convertJsonToMarkdown(text: string): string {
  const trimmed = text.trim()
  if (!trimmed.startsWith('{') || !trimmed.endsWith('}')) {
    return text
  }
  try {
    const data = JSON.parse(trimmed)
    if (typeof data !== 'object' || data === null) return text

    let md = ''
    // 综合评分
    if (data.overall_score !== undefined) {
      md += `## 📊 综合评分\n\n**总分：${data.overall_score}/100**\n\n`
    }
    // 分数表格
    if (data.scores && typeof data.scores === 'object') {
      md += '| 评估维度 | 得分 |\n|---------|------|\n'
      const nameMap: Record<string, string> = {
        completeness: '内容完整度', format: '排版规范', highlights: '亮点突出度',
        job_match: '岗位匹配度', language: '语言表达'
      }
      for (const [key, val] of Object.entries(data.scores)) {
        md += `| ${nameMap[key] || key} | ${val} |\n`
      }
      md += '\n'
    }
    // 亮点
    if (Array.isArray(data.strengths) && data.strengths.length > 0) {
      md += '## ✅ 主要亮点\n\n'
      data.strengths.forEach((s: string) => { md += `- ${s}\n` })
      md += '\n'
    }
    // 不足
    if (Array.isArray(data.weaknesses) && data.weaknesses.length > 0) {
      md += '## ⚠️ 不足之处\n\n'
      data.weaknesses.forEach((w: string) => { md += `- ${w}\n` })
      md += '\n'
    }
    // 建议
    if (Array.isArray(data.suggestions) && data.suggestions.length > 0) {
      md += '## 💡 改进建议\n\n'
      data.suggestions.forEach((s: string, i: number) => { md += `${i + 1}. ${s}\n` })
      md += '\n'
    }
    // 详细分析
    if (data.detailed_analysis) {
      md += `## 📝 综合分析\n\n${data.detailed_analysis}\n`
    }
    // 如果上面没匹配到任何已知字段，原样返回
    return md || text
  } catch {
    return text
  }
}

// ========== 复制功能 ==========
const copied = ref(false)

async function copyContent() {
  try {
    await navigator.clipboard.writeText(props.message.content)
    copied.value = true
    ElMessage.success('已复制到剪贴板')
    setTimeout(() => { copied.value = false }, 2000)
  } catch {
    // fallback
    const textarea = document.createElement('textarea')
    textarea.value = props.message.content
    document.body.appendChild(textarea)
    textarea.select()
    document.execCommand('copy')
    document.body.removeChild(textarea)
    copied.value = true
    ElMessage.success('已复制到剪贴板')
    setTimeout(() => { copied.value = false }, 2000)
  }
}

// ========== 计算属性 ==========
const isUser = computed(() => props.message.role === 'user')
const isSystem = computed(() => props.message.role === 'system')
const roleLabel = computed(() => {
  if (isUser.value) return '你'
  if (isSystem.value) return '系统'
  return props.message.agent_name || 'AI 助手'
})

const timeStr = computed(() => {
  const date = new Date(props.message.created_at)
  if (isNaN(date.getTime())) return ''
  return date.toLocaleTimeString('zh-CN', {
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
    timeZone: Intl.DateTimeFormat().resolvedOptions().timeZone,
  })
})

/** 是否有思考内容 */
const hasThinking = computed(() => !!props.message.thinking)

/** 根据文件扩展名返回对应图标 */
const fileIcon = computed(() => {
  const name = props.message.file_name || ''
  const ext = name.split('.').pop()?.toLowerCase() || ''
  const audioExts = ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac']
  const videoExts = ['mp4', 'avi', 'mov', 'mkv', 'webm', 'wmv']
  if (audioExts.includes(ext)) return 'Microphone'
  if (videoExts.includes(ext)) return 'Film'
  return 'Document'
})

/** 渲染后的 Markdown HTML */
const renderedContent = computed(() => renderMarkdown(props.message.content || ''))
</script>

<template>
  <!-- 系统消息：居中显示 -->
  <div v-if="isSystem" class="message-system">
    <span class="system-text">{{ message.content }}</span>
  </div>

  <!-- 用户消息：右对齐 -->
  <div v-else-if="isUser" class="message-wrapper message-right">
    <div class="message-body">
      <div class="message-meta">
        <span class="message-time">{{ timeStr }}</span>
      </div>
      <div class="message-bubble message-bubble-user">
        <template v-if="message.message_type === 'file' && message.file_name">
          <!-- 文件 + 可选文字 -->
          <div class="user-file-attachment">
            <el-icon :size="20"><component :is="fileIcon" /></el-icon>
            <span class="user-file-name">{{ message.file_name }}</span>
          </div>
          <div v-if="message.content" class="user-file-text">{{ message.content }}</div>
        </template>
        <template v-else>
          <div class="bubble-text">{{ message.content }}</div>
        </template>
      </div>
      <div v-if="message.status === 'sending'" class="message-status">
        <el-icon class="is-loading"><Loading /></el-icon>
      </div>
      <div v-else-if="message.status === 'error'" class="message-status message-error">
        发送失败
      </div>
    </div>
  </div>

  <!-- AI 助手消息：左对齐 -->
  <div v-else class="message-wrapper message-left">
    <div class="message-avatar">
      <el-avatar :size="32" :style="{ backgroundColor: '#534AB7' }">
        {{ roleLabel.charAt(0) }}
      </el-avatar>
    </div>
    <div class="message-body">
      <div class="message-meta">
        <span class="message-role">{{ roleLabel }}</span>
        <span class="message-time">{{ timeStr }}</span>
      </div>

      <!-- 思考过程：气泡外独立展示 -->
      <div v-if="hasThinking" class="thinking-section">
        <div class="thinking-header">
          <span class="thinking-dot"></span>
          <span class="thinking-label">{{ message.isThinking ? '正在思考中...' : '思考过程' }}</span>
        </div>
        <div class="thinking-content">{{ message.thinking }}</div>
      </div>

      <div class="message-bubble message-bubble-ai">
        <!-- 流式消息：打字动画 -->
        <template v-if="message.streaming">
          <div class="bubble-text markdown-body" v-html="renderedContent"></div>
          <span v-if="message.isThinking" class="thinking-indicator">
            <span class="thinking-dot"></span>正在思考
          </span>
          <span v-else class="typing-cursor">|</span>
        </template>
        <!-- 普通文本消息 -->
        <template v-else-if="message.message_type === 'text'">
          <div class="bubble-text markdown-body" v-html="renderedContent"></div>
        </template>
        <!-- 报告消息 -->
        <template v-else-if="message.message_type === 'report' && message.report_data">
          <ReportCard
            :report="message.report_data"
            :title="message.report_data?.title || '分析报告'"
          />
        </template>
        <!-- 文件消息 -->
        <template v-else-if="message.message_type === 'file'">
          <div class="bubble-file">
            <el-icon><Document /></el-icon>
            <a v-if="message.file_url" :href="message.file_url" target="_blank">
              {{ message.file_name || '下载文件' }}
            </a>
            <span v-else>{{ message.file_name || '文件' }}</span>
          </div>
        </template>
        <!-- 其他未知类型 -->
        <template v-else>
          <div class="bubble-text">{{ message.content }}</div>
        </template>
      </div>

      <!-- 复制按钮 -->
      <div v-if="message.content && !message.streaming" class="message-actions">
        <button class="copy-btn" :class="{ copied }" @click="copyContent" title="复制内容">
          <el-icon :size="14">
            <Check v-if="copied" />
            <CopyDocument v-else />
          </el-icon>
          <span>{{ copied ? '已复制' : '复制' }}</span>
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* ========== 系统消息 ========== */
.message-system {
  display: flex;
  justify-content: center;
  padding: var(--spacing-sm) 0;
}

.system-text {
  font-size: var(--font-xs);
  color: var(--color-text-placeholder);
  background: var(--color-bg-dark);
  padding: 4px 12px;
  border-radius: var(--radius-sm);
}

/* ========== 消息气泡容器 ========== */
.message-wrapper {
  display: flex;
  margin-bottom: var(--spacing-md);
  padding: 0 var(--spacing-md);
}

.message-left {
  justify-content: flex-start;
}

.message-right {
  justify-content: flex-end;
}

.message-avatar {
  flex-shrink: 0;
  margin-right: var(--spacing-sm);
  margin-top: 4px;
}

/* ========== 消息主体 ========== */
.message-body {
  max-width: 75%;
  display: flex;
  flex-direction: column;
}

.message-right .message-body {
  align-items: flex-end;
}

.message-meta {
  display: flex;
  align-items: center;
  gap: var(--spacing-sm);
  margin-bottom: 4px;
  padding: 0 4px;
}

.message-role {
  font-size: var(--font-xs);
  font-weight: 500;
  color: var(--color-text-secondary);
}

.message-time {
  font-size: 11px;
  color: var(--color-text-placeholder);
}

/* ========== 思考过程区域 ========== */
.thinking-section {
  margin-bottom: 8px;
  padding: 8px 12px;
  background: #f8f7ff;
  border: 1px solid #ebe7ff;
  border-radius: 8px;
  max-width: 600px;
}

.thinking-header {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-bottom: 4px;
}

.thinking-dot {
  display: inline-block;
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: #8b7fc7;
  animation: pulse 1.5s ease-in-out infinite;
}

.thinking-label {
  font-size: 12px;
  color: #8b7fc7;
  font-weight: 500;
}

.thinking-content {
  font-size: 12px;
  color: #9994c0;
  line-height: 1.5;
  white-space: pre-wrap;
  word-break: break-word;
  max-height: 120px;
  overflow-y: auto;
}

/* 思考内容滚动条 */
.thinking-content::-webkit-scrollbar {
  width: 4px;
}
.thinking-content::-webkit-scrollbar-thumb {
  background: #d4cfff;
  border-radius: 2px;
}

/* ========== 气泡样式 ========== */
.message-bubble {
  padding: 10px 16px;
  border-radius: var(--radius-md);
  line-height: 1.6;
  word-break: break-word;
}

.message-bubble-user {
  background: var(--color-primary);
  color: var(--color-text-inverse);
  border-bottom-right-radius: 4px;
}

.message-bubble-ai {
  background: var(--color-card);
  border: 1px solid var(--color-border-light);
  border-bottom-left-radius: 4px;
  box-shadow: var(--shadow-sm);
}

/* ========== Markdown 渲染样式 ========== */
.markdown-body {
  font-size: var(--font-md);
  line-height: 1.7;
}

.markdown-body :deep(h1),
.markdown-body :deep(h2),
.markdown-body :deep(h3) {
  margin: 12px 0 8px;
  font-weight: 600;
  line-height: 1.4;
}

.markdown-body :deep(h1) { font-size: 1.3em; }
.markdown-body :deep(h2) { font-size: 1.15em; }
.markdown-body :deep(h3) { font-size: 1.05em; }

.markdown-body :deep(p) {
  margin: 6px 0;
}

.markdown-body :deep(ul),
.markdown-body :deep(ol) {
  margin: 6px 0;
  padding-left: 20px;
}

.markdown-body :deep(li) {
  margin: 3px 0;
}

.markdown-body :deep(strong) {
  font-weight: 600;
}

.markdown-body :deep(code) {
  background: rgba(0, 0, 0, 0.06);
  padding: 1px 5px;
  border-radius: 4px;
  font-size: 0.9em;
  font-family: 'Menlo', 'Monaco', 'Courier New', monospace;
}

.markdown-body :deep(pre) {
  background: #f5f5f5;
  padding: 12px;
  border-radius: 8px;
  overflow-x: auto;
  margin: 8px 0;
}

.markdown-body :deep(pre code) {
  background: none;
  padding: 0;
  font-size: 0.88em;
  line-height: 1.5;
}

.markdown-body :deep(blockquote) {
  border-left: 3px solid var(--color-primary);
  padding-left: 12px;
  margin: 8px 0;
  color: #666;
}

.markdown-body :deep(hr) {
  border: none;
  border-top: 1px solid #eee;
  margin: 12px 0;
}

.markdown-body :deep(table) {
  border-collapse: collapse;
  margin: 8px 0;
  width: 100%;
}

.markdown-body :deep(th),
.markdown-body :deep(td) {
  border: 1px solid #e0e0e0;
  padding: 6px 10px;
  text-align: left;
}

.markdown-body :deep(th) {
  background: #f5f5f5;
  font-weight: 600;
}

/* ========== 文本内容 ========== */
.bubble-text {
  font-size: var(--font-md);
  line-height: 1.7;
}

/* ========== 文件气泡 ========== */
.bubble-file {
  display: flex;
  align-items: center;
  gap: var(--spacing-sm);
  font-size: var(--font-sm);
}

.bubble-file a {
  color: var(--color-primary);
  text-decoration: underline;
}

/* ========== 用户消息文件附件 ========== */
.user-file-attachment {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 8px 14px;
  background: rgba(255, 255, 255, 0.15);
  border-radius: 8px;
  margin-bottom: 6px;
  font-size: var(--font-sm);
  max-width: 100%;
}

.user-file-name {
  flex: 1;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  max-width: 240px;
}

.user-file-text {
  font-size: var(--font-sm);
  opacity: 0.9;
  word-break: break-word;
  white-space: pre-wrap;
}

/* ========== 流式消息指示器 ========== */
.typing-cursor {
  display: inline-block;
  animation: blink 1s step-end infinite;
  color: var(--color-primary);
  font-weight: bold;
}

.thinking-indicator {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-size: 12px;
  color: #8b7fc7;
  animation: fadeInOut 1.5s ease-in-out infinite;
}

@keyframes blink {
  0%, 100% { opacity: 1; }
  50% { opacity: 0; }
}

@keyframes pulse {
  0%, 100% { opacity: 1; transform: scale(1); }
  50% { opacity: 0.5; transform: scale(0.8); }
}

@keyframes fadeInOut {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.6; }
}

/* ========== 复制按钮 ========== */
.message-actions {
  display: flex;
  justify-content: flex-end;
  margin-top: 4px;
  padding-right: 4px;
  opacity: 0;
  transition: opacity 0.2s;
}

.message-body:hover .message-actions {
  opacity: 1;
}

.copy-btn {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 3px 8px;
  border: none;
  background: none;
  color: #999;
  font-size: 12px;
  cursor: pointer;
  border-radius: 4px;
  transition: all 0.2s;
}

.copy-btn:hover {
  background: #f0f0f0;
  color: #666;
}

.copy-btn.copied {
  color: #67c23a;
}

/* ========== 消息状态 ========== */
.message-status {
  font-size: var(--font-xs);
  color: var(--color-text-placeholder);
  padding: 2px 4px;
  margin-top: 2px;
}

.message-error {
  color: var(--color-danger);
}
</style>
