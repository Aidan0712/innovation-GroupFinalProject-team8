/**
 * AI 面试相关类型定义
 */

/** 面试会话 */
export interface InterviewSession {
  id: number
  user_id: number
  title: string
  target_position: string
  interview_type: string
  difficulty: string
  question_count: number
  answer_mode: string
  status: string
  total_score: number | null
  report: Record<string, any> | null
  started_at: string | null
  ended_at: string | null
  created_at: string
}

/** 面试轮次 */
export interface InterviewTurn {
  id: number
  session_id: number
  question_index: number
  question: string
  answer_text: string | null
  answer_audio_url: string | null
  answer_duration_seconds: number | null
  score: number | null
  feedback: string | null
  suggestion: string | null
  created_at: string
  answered_at: string | null
}

/** 面试会话详情（含轮次） */
export interface InterviewSessionDetail extends InterviewSession {
  turns: InterviewTurn[]
}

/** 创建面试参数 */
export interface InterviewCreateParams {
  title?: string
  target_position: string
  interview_type?: string
  difficulty?: 'easy' | 'medium' | 'hard'
  question_count?: number
  answer_mode?: 'text' | 'audio' | 'mixed'
}

/** 提交回答参数 */
export interface InterviewAnswerParams {
  answer_text?: string
  answer_audio_url?: string
  answer_duration_seconds?: number
}

/** 面试报告响应 */
export interface InterviewReport {
  session_id: number
  total_score: number
  status: string
  summary: string
  turn_performance: TurnPerformance[]
  suggestions: string[]
  generated_at: string
}

/** 报告中单轮表现 */
export interface TurnPerformance {
  question_index: number
  question: string
  score: number
  feedback: string
  suggestion: string
}

/** 分页面试列表 */
export interface InterviewListResponse {
  items: InterviewSession[]
  total: number
  page: number
  page_size: number
}
