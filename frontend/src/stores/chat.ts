import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { Conversation, ChatMessage, AgentStatusEvent } from '@/types'
import {
  getConversationsApi,
  getMessagesApi,
  sendMessageApi,
  createConversationApi,
} from '@/api/chat'
import request from '@/api/request'

/**
 * 对话状态管理
 */
export const useChatStore = defineStore('chat', () => {
  // ========== State ==========

  /** 对话列表 */
  const conversations = ref<Conversation[]>([])

  /** 当前活跃对话 ID */
  const currentConversationId = ref<number | string | null>(null)

  /** 当前对话消息列表 */
  const messages = ref<ChatMessage[]>([])

  /** 当前 Agent 执行状态 */
  const agentStatus = ref<AgentStatusEvent | null>(null)

  /** 是否正在发送消息 */
  const isSending = ref(false)

  /** 待发送的文件列表 */
  const pendingFiles = ref<{ file: File; fileUrl: string; fileName: string }[]>([])

  /** 当前激活的 Agent 类型 */
  const activeAgentType = ref<string>('general')

  /** SSE EventSource 实例 */
  let eventSource: EventSource | null = null

  // ========== Getters ==========

  /** 当前对话 */
  const currentConversation = computed(() =>
    conversations.value.find((c) => c.id === currentConversationId.value)
  )

  /** 对话消息（按时间排序） */
  const sortedMessages = computed(() =>
    [...messages.value].sort(
      (a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime()
    )
  )

  // ========== Actions ==========

  /**
   * 获取对话列表
   */
  async function fetchConversations() {
    try {
      const res = await getConversationsApi()
      // 后端返回 { conversations: [...], total }，需取 conversations 数组
      const data = res.data as any
      if (data && Array.isArray(data.conversations)) {
        conversations.value = data.conversations
      } else if (Array.isArray(data)) {
        // 兼容：如果后端直接返回数组
        conversations.value = data
      }
    } catch (error) {
      console.error('获取对话列表失败:', error)
    }
  }

  /**
   * 获取对话消息
   */
  async function fetchMessages(conversationId: number | string) {
    try {
      const res = await getMessagesApi(conversationId)
      messages.value = res.data
    } catch (error) {
      console.error('获取消息失败:', error)
    }
  }

  /**
   * 创建新对话
   */
  async function createConversation(title: string, agentType: string = 'general') {
    try {
      const res = await createConversationApi({ title, agent_type: agentType })
      conversations.value.unshift(res.data)
      currentConversationId.value = res.data.id
      messages.value = []
      agentStatus.value = null
      activeAgentType.value = agentType
    } catch (error) {
      console.error('创建对话失败:', error)
      throw error
    }
  }

  /**
   * 上传文件到后端
   */
  async function uploadFile(file: File): Promise<{ fileUrl: string; fileName: string }> {
    const formData = new FormData()
    formData.append('file', file)
    const res: any = await request.post('/v1/chat/upload', formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    })
    // 响应拦截器已经解包了 response.data
    const data = res.data || res
    return {
      fileUrl: data.file_url,
      fileName: data.file_name || file.name,
    }
  }

  /**
   * 添加待发送文件
   */
  async function addPendingFile(file: File) {
    try {
      const { fileUrl, fileName } = await uploadFile(file)
      pendingFiles.value.push({ file, fileUrl, fileName })
    } catch (error) {
      console.error('文件上传失败:', error)
      throw error
    }
  }

  /**
   * 移除待发送文件
   */
  function removePendingFile(index: number) {
    pendingFiles.value.splice(index, 1)
  }

  /**
   * 清空待发送文件
   */
  function clearPendingFiles() {
    pendingFiles.value = []
  }

  /**
   * 发送消息（非流式）
   */
  async function sendMessage(content: string, fileUrl?: string) {
    if (!currentConversationId.value) return

    isSending.value = true
    try {
      // 添加用户消息到列表
      const userMsg: ChatMessage = {
        id: Date.now().toString(),
        conversation_id: currentConversationId.value,
        role: 'user',
        content,
        message_type: 'text',
        status: 'sending',
        created_at: new Date().toISOString(),
      }
      messages.value.push(userMsg)

      const res = await sendMessageApi(currentConversationId.value, {
        content,
        file_url: fileUrl,
      })

      // 更新用户消息状态
      userMsg.status = 'sent'
      userMsg.id = res.data.user_message?.id || userMsg.id

      // 添加 AI 回复
      if (res.data.assistant_message) {
        messages.value.push({
          ...res.data.assistant_message,
          status: 'sent',
        })
      }
    } catch (error) {
      console.error('发送消息失败:', error)
      // 标记最后一条用户消息为失败
      const lastUserMsg = [...messages.value].reverse().find((m: ChatMessage) => m.role === 'user')
      if (lastUserMsg) lastUserMsg.status = 'error'
    } finally {
      isSending.value = false
    }
  }

  /**
   * 流式对话（SSE）
   * @param content 消息内容
   * @param agentType 目标 Agent 类型
   * @param fileUrl 上传文件的 URL（可选）
   */
  function streamChat(
    content: string,
    agentType: string = 'general',
    fileUrl?: string,
  ): Promise<void> {
    return new Promise((resolve, reject) => {
      if (!currentConversationId.value) {
        reject(new Error('没有活跃对话'))
        return
      }

      isSending.value = true

      // 构建用户消息内容
      // content 存用户输入的文字，file_name 存文件名（两者独立）
      const fileNames = pendingFiles.value.map((f) => f.fileName)

      // 添加用户消息
      const userMsg: ChatMessage = {
        id: Date.now().toString(),
        conversation_id: currentConversationId.value,
        role: 'user',
        content: content, // 用户输入的文字（可能为空）
        message_type: fileUrl ? 'file' : 'text',
        file_name: fileNames[0] || undefined,
        file_url: fileUrl || undefined,
        status: 'sending',
        created_at: new Date().toISOString(),
      }
      messages.value.push(userMsg)

      // 创建 AI 消息占位
      const agentName = agentType === 'resume' ? '简历评估' :
                        agentType === 'recording' ? '录音分析' :
                        agentType === 'question' ? '题目生成' : ''
      const aiMsg: ChatMessage = {
        id: (Date.now() + 1).toString(),
        conversation_id: currentConversationId.value,
        role: 'assistant',
        content: '',
        message_type: 'text',
        streaming: true,
        status: 'sent',
        agent_name: agentName,
        thinking: '',
        isThinking: agentType === 'general', // 只有通用对话才显示思考过程
        created_at: new Date().toISOString(),
      }
      messages.value.push(aiMsg)
      // push 后 Vue 会把 aiMsg 包装成 Proxy，后续修改必须通过响应式引用
      const reactiveMsg = messages.value[messages.value.length - 1]

      // 创建 SSE 连接
      const token = localStorage.getItem('access_token')
      const conversationId = currentConversationId.value
      let url = `/api/v1/chat/conversations/${conversationId}/stream?content=${encodeURIComponent(content || '分析上传的文件')}&token=${encodeURIComponent(token || '')}&agent_type=${encodeURIComponent(agentType)}`
      if (fileUrl) {
        url += `&file_url=${encodeURIComponent(fileUrl)}`
      }

      eventSource = new EventSource(url)

      // 监听消息事件 - 接收流式文本
      eventSource.addEventListener('message', (event) => {
        try {
          const data = JSON.parse(event.data)
          const chunkType = data.type

          if (chunkType === 'thinking') {
            // 思考过程：追加到 thinking 字段
            reactiveMsg.thinking = (reactiveMsg.thinking || '') + (data.content || '')
            reactiveMsg.isThinking = true
          } else if (chunkType === 'content') {
            // 正式回复：追加到 content 字段
            if (data.content) {
              reactiveMsg.content += data.content
            }
            // 收到第一个 content 时标记思考结束
            if (reactiveMsg.isThinking) {
              reactiveMsg.isThinking = false
            }
          } else if (chunkType === 'status') {
            // Agent 状态更新
            agentStatus.value = {
              agent_name: data.agent_name || '处理中',
              status: 'processing',
              progress: data.progress || 0,
              message: data.message || '处理中...',
            }
          } else {
            // 兼容旧格式
            if (data.content) {
              reactiveMsg.content += data.content
            }
          }

          if (data.agent_name) {
            reactiveMsg.agent_name = data.agent_name
          }
          if (data.message_type) {
            reactiveMsg.message_type = data.message_type
          }
        } catch {
          reactiveMsg.content += event.data
        }
      })

      // 监听 Agent 状态事件
      eventSource.addEventListener('agent_status', (event) => {
        try {
          const data: AgentStatusEvent = JSON.parse(event.data)
          agentStatus.value = data

          if (data.status === 'completed') {
            reactiveMsg.content += `\n\n--- ${data.agent_name} 阶段完成 ---\n\n`
          } else if (data.status === 'failed') {
            reactiveMsg.content += `\n\n--- ${data.agent_name} 阶段失败: ${data.message || ''} ---\n\n`
          }
        } catch {
          // ignore parse error
        }
      })

      // 监听完成事件
      eventSource.addEventListener('done', () => {
        reactiveMsg.streaming = false
        reactiveMsg.isThinking = false
        isSending.value = false
        agentStatus.value = null
        clearPendingFiles()
        closeSSE()
        resolve()
      })

      // 监听错误事件
      eventSource.addEventListener('error', (event) => {
        console.error('SSE 连接错误:', event)
        reactiveMsg.streaming = false
        // EventSource error 在连接未建立时（如 401/404）不会携带详细信息
        // 只在 reactiveMsg.content 为空时追加提示，避免重复
        if (!reactiveMsg.content) {
          reactiveMsg.content += '\n\n[连接中断，请检查网络或刷新页面重试]'
        }
        isSending.value = false
        // 注意：不在错误时清除 pendingFiles，允许用户重试发送
        closeSSE()
        reject(new Error('SSE 连接错误'))
      })

      // 标记用户消息已发送
      userMsg.status = 'sent'
    })
  }

  /**
   * 使用功能标签快捷操作
   * @param agentType agent 类型
   * @param prompt 预设提示词
   */
  async function useFeatureTag(agentType: string, prompt?: string) {
    activeAgentType.value = agentType
    // 如果没有活跃对话，创建一个
    if (!currentConversationId.value) {
      const title = agentType === 'resume' ? '简历评估' :
                    agentType === 'recording' ? '录音分析' :
                    agentType === 'question' ? '面试题生成' : '新对话'
      await createConversation(title, agentType)
    }
    return { agentType, prompt }
  }

  /**
   * 删除对话
   */
  async function deleteConversation(conversationId: number | string) {
    try {
      await request.delete(`/v1/chat/conversations/${conversationId}`)
      // 从列表中移除
      const idx = conversations.value.findIndex((c) => c.id === conversationId)
      if (idx !== -1) {
        conversations.value.splice(idx, 1)
      }
      // 如果删除的是当前对话，清空状态
      if (currentConversationId.value === conversationId) {
        currentConversationId.value = null
        messages.value = []
        agentStatus.value = null
        activeAgentType.value = 'general'
        closeSSE()
      }
    } catch (error) {
      console.error('删除对话失败:', error)
      throw error
    }
  }

  /**
   * 关闭 SSE 连接
   */
  function closeSSE() {
    if (eventSource) {
      eventSource.close()
      eventSource = null
    }
  }

  /**
   * 切换当前对话
   */
  function switchConversation(conversationId: number | string) {
    const conv = conversations.value.find((c) => c.id === conversationId)
    currentConversationId.value = conversationId
    messages.value = []
    agentStatus.value = null
    // 保留对话本身的 agent_type，而不是一律重置为 general
    activeAgentType.value = (conv?.agent_type as string) || 'general'
    closeSSE()
    fetchMessages(conversationId)
  }

  /**
   * 重置状态
   */
  function reset() {
    conversations.value = []
    currentConversationId.value = null
    messages.value = []
    agentStatus.value = null
    isSending.value = false
    activeAgentType.value = 'general'
    pendingFiles.value = []
    closeSSE()
  }

  return {
    // State
    conversations,
    currentConversationId,
    messages,
    agentStatus,
    isSending,
    pendingFiles,
    activeAgentType,
    // Getters
    currentConversation,
    sortedMessages,
    // Actions
    fetchConversations,
    fetchMessages,
    createConversation,
    sendMessage,
    streamChat,
    uploadFile,
    addPendingFile,
    removePendingFile,
    clearPendingFiles,
    useFeatureTag,
    closeSSE,
    deleteConversation,
    switchConversation,
    reset,
  }
})
