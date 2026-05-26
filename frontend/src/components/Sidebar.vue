<script setup lang="ts">
import { computed } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { ElMessageBox, ElMessage } from 'element-plus'
import { useChatStore } from '@/stores/chat'
import { useAuthStore } from '@/stores/auth'
import { useAppStore } from '@/stores/app'
import { formatRelativeTime } from '@/utils'

/**
 * 左侧边栏组件
 * 显示对话列表、新建对话按钮、后台管理入口
 */

const router = useRouter()
const route = useRoute()
const chatStore = useChatStore()
const authStore = useAuthStore()
const appStore = useAppStore()

/** 侧边栏宽度样式 */
const sidebarWidth = computed(() =>
  appStore.sidebarCollapsed ? '64px' : 'var(--sidebar-width)'
)

/**
 * 新建对话
 */
async function handleNewChat() {
  try {
    await chatStore.createConversation('新对话', 'general')
  } catch {
    // 创建失败时不阻塞
  }
}

/**
 * 切换对话
 */
function handleSelectConversation(conversationId: number | string) {
  chatStore.switchConversation(conversationId)
}

/**
 * 跳转后台管理
 */
function goToAdmin() {
  router.push('/admin')
}

/**
 * 判断当前是否在后台管理页面
 */
const isInAdmin = computed(() => route.path.startsWith('/admin'))

/**
 * 删除对话
 */
async function handleDeleteConversation(e: Event, conversationId: number | string) {
  e.stopPropagation() // 防止触发切换对话
  try {
    await ElMessageBox.confirm('确定要删除这条对话记录吗？删除后不可恢复。', '删除对话', {
      confirmButtonText: '删除',
      cancelButtonText: '取消',
      type: 'warning',
    })
    await chatStore.deleteConversation(conversationId)
    ElMessage.success('对话已删除')
  } catch {
    // 用户取消或删除失败，忽略
  }
}
</script>

<template>
  <aside class="sidebar" :style="{ width: sidebarWidth }">
    <!-- 顶部：新建对话（仅展开时显示） -->
    <div v-if="!appStore.sidebarCollapsed" class="sidebar-header">
      <el-button
        type="primary"
        :icon="'Plus'"
        class="new-chat-btn"
        @click="handleNewChat()"
      >
        新建对话
      </el-button>
    </div>

    <!-- 对话列表 -->
    <div v-if="!appStore.sidebarCollapsed" class="conversations-section">
      <div class="section-title">对话历史</div>

      <div class="conversations-list">
        <!-- 空状态 -->
        <div v-if="chatStore.conversations.length === 0" class="empty-state">
          <el-icon :size="24" color="#9E9D9A"><ChatLineRound /></el-icon>
          <span>暂无对话记录</span>
        </div>

        <!-- 对话列表项 -->
        <div
          v-for="conv in chatStore.conversations"
          :key="conv.id"
          class="conversation-item"
          :class="{ active: conv.id === chatStore.currentConversationId }"
          @click="handleSelectConversation(conv.id)"
        >
          <div class="conv-header flex-between">
            <span class="conv-title text-ellipsis">{{ conv.title }}</span>
            <div class="conv-header-actions">
              <span class="conv-time">{{ formatRelativeTime(conv.updated_at) }}</span>
              <el-icon
                class="conv-delete-btn"
                :size="14"
                @click="handleDeleteConversation($event, conv.id)"
              ><Delete /></el-icon>
            </div>
          </div>
          <div class="conv-preview text-ellipsis">
            {{ conv.last_message || '暂无消息' }}
          </div>
          <div class="conv-meta">
            <span class="conv-count">共 {{ conv.message_count }} 条</span>
          </div>
        </div>
      </div>
    </div>

    <!-- 底部操作区 -->
    <div class="sidebar-footer">
      <!-- 后台管理入口（仅管理员可见） -->
      <div
        v-if="authStore.isAdmin && !appStore.sidebarCollapsed"
        class="footer-item"
        :class="{ active: isInAdmin }"
        @click="goToAdmin"
      >
        <el-icon :size="18"><Setting /></el-icon>
        <span>后台管理</span>
      </div>

      <!-- 折叠/展开按钮 -->
      <div class="footer-item" @click="appStore.toggleSidebar()">
        <el-icon :size="18">
          <Fold v-if="!appStore.sidebarCollapsed" />
          <Expand v-else />
        </el-icon>
        <span v-if="!appStore.sidebarCollapsed">收起侧栏</span>
      </div>
    </div>
  </aside>
</template>

<style scoped>
.sidebar {
  height: calc(100vh - var(--header-height));
  display: flex;
  flex-direction: column;
  background: var(--color-card);
  border-right: 1px solid var(--color-border-light);
  transition: width 0.3s ease;
  overflow: hidden;
}

/* ========== 顶部 ========== */
.sidebar-header {
  padding: var(--spacing-md);
  border-bottom: 1px solid var(--color-border-light);
}

.new-chat-btn {
  width: 100%;
}

/* ========== 对话列表 ========== */
.conversations-section {
  flex: 1;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.section-title {
  font-size: var(--font-xs);
  font-weight: 600;
  color: var(--color-text-placeholder);
  padding: var(--spacing-sm) var(--spacing-md);
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.conversations-list {
  flex: 1;
  overflow-y: auto;
  padding: 0 var(--spacing-sm);
}

/* 空状态 */
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: var(--spacing-sm);
  padding: var(--spacing-xl);
  color: var(--color-text-placeholder);
  font-size: var(--font-sm);
}

/* 对话列表项 */
.conversation-item {
  padding: 10px 12px;
  border-radius: var(--radius-sm);
  cursor: pointer;
  transition: background 0.2s;
  margin-bottom: 2px;
}

.conversation-item:hover {
  background: var(--color-bg);
}

.conversation-item.active {
  background: var(--color-primary-lighter);
}

.conv-header {
  margin-bottom: 4px;
}

.conv-title {
  font-size: var(--font-sm);
  font-weight: 500;
  color: var(--color-text);
  max-width: 70%;
}

.conv-time {
  font-size: 11px;
  color: var(--color-text-placeholder);
  flex-shrink: 0;
}

.conv-header-actions {
  display: flex;
  align-items: center;
  gap: 4px;
  flex-shrink: 0;
}

.conv-delete-btn {
  opacity: 0;
  cursor: pointer;
  color: var(--color-text-placeholder);
  transition: all 0.2s;
  padding: 2px;
  border-radius: 4px;
}

.conv-delete-btn:hover {
  color: var(--color-danger);
  background: rgba(245, 108, 108, 0.1);
}

.conversation-item:hover .conv-delete-btn {
  opacity: 1;
}

.conv-preview {
  font-size: var(--font-xs);
  color: var(--color-text-secondary);
  margin-bottom: 4px;
}

.conv-meta {
  display: flex;
  align-items: center;
  gap: var(--spacing-sm);
}

.conv-count {
  font-size: 11px;
  color: var(--color-text-placeholder);
}

/* ========== 底部操作区 ========== */
.sidebar-footer {
  padding: var(--spacing-sm) 0;
  border-top: 1px solid var(--color-border-light);
  margin-top: auto; /* 始终推到底部 */
}

.footer-item {
  display: flex;
  align-items: center;
  gap: var(--spacing-sm);
  padding: 8px var(--spacing-md);
  cursor: pointer;
  transition: all 0.2s;
  color: var(--color-text-secondary);
  font-size: var(--font-sm);
}

.footer-item:hover,
.footer-item.active {
  background: var(--color-bg);
  color: var(--color-primary);
}
</style>
