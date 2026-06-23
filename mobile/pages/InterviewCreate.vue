<!--
  InterviewCreateView.vue — 创建 AI 模拟面试
  选择岗位、面试类型、难度、题数后创建会话
-->
<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useInterviewStore } from '@/stores/interview'
import { ElMessage } from 'element-plus'

const router = useRouter()
const store = useInterviewStore()

const form = ref({
  target_position: '',
  interview_type: 'technical' as 'technical' | 'behavioral' | 'comprehensive',
  difficulty: 'medium' as 'easy' | 'medium' | 'hard',
  question_count: 5,
})

const isCreating = ref(false)

const typeOptions = [
  { value: 'technical', label: '技术面试' },
  { value: 'behavioral', label: '行为面试' },
  { value: 'comprehensive', label: '综合面试' },
]

const difficultyOptions = [
  { value: 'easy', label: '基础' },
  { value: 'medium', label: '进阶' },
  { value: 'hard', label: '深入' },
]

async function handleCreate() {
  if (!form.value.target_position.trim()) {
    ElMessage.warning('请输入目标岗位')
    return
  }

  isCreating.value = true
  try {
    const session = await store.createSession({
      target_position: form.value.target_position.trim(),
      interview_type: form.value.interview_type,
      difficulty: form.value.difficulty,
      question_count: form.value.question_count,
      answer_mode: 'mixed',
    })

    ElMessage.success('面试创建成功，开始答题！')
    router.push(`/interview/${session.id}`)
  } catch (err: any) {
    ElMessage.error(err.response?.data?.detail || '创建面试失败，请重试')
  } finally {
    isCreating.value = false
  }
}
</script>

<template>
  <div class="create-view">
    <header class="create-header">
      <button class="back-btn" @click="router.push('/interview-history')">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <polyline points="15,18 9,12 15,6" />
        </svg>
      </button>
      <h2 class="header-title">创建 AI 模拟面试</h2>
      <div class="header-spacer" />
    </header>

    <div class="create-form">
      <!-- 目标岗位 -->
      <div class="form-item">
        <label class="form-label">目标岗位</label>
        <input
          v-model="form.target_position"
          class="form-input"
          placeholder="如：前端工程师、Java 开发..."
        />
      </div>

      <!-- 面试类型 -->
      <div class="form-item">
        <label class="form-label">面试类型</label>
        <div class="option-group">
          <button
            v-for="opt in typeOptions"
            :key="opt.value"
            class="option-btn"
            :class="{ active: form.interview_type === opt.value }"
            @click="form.interview_type = opt.value as any"
          >
            {{ opt.label }}
          </button>
        </div>
      </div>

      <!-- 难度 -->
      <div class="form-item">
        <label class="form-label">难度等级</label>
        <div class="option-group">
          <button
            v-for="opt in difficultyOptions"
            :key="opt.value"
            class="option-btn"
            :class="{ active: form.difficulty === opt.value }"
            @click="form.difficulty = opt.value as any"
          >
            {{ opt.label }}
          </button>
        </div>
      </div>

      <!-- 题目数量 -->
      <div class="form-item">
        <label class="form-label">题目数量：{{ form.question_count }} 题</label>
        <input
          v-model.number="form.question_count"
          type="range"
          min="3"
          max="10"
          step="1"
          class="form-slider"
        />
        <div class="slider-labels">
          <span>3</span>
          <span>5</span>
          <span>7</span>
          <span>10</span>
        </div>
      </div>

      <!-- 创建按钮 -->
      <button
        class="create-btn"
        :disabled="isCreating || !form.target_position.trim()"
        @click="handleCreate"
      >
        {{ isCreating ? '创建中...' : '开始面试' }}
      </button>
    </div>
  </div>
</template>

<style scoped>
.create-view {
  max-width: 768px;
  margin: 0 auto;
  min-height: 100vh;
  background: #F5F7FA;
}

.create-header {
  display: flex;
  align-items: center;
  padding: 12px 16px;
  background: #fff;
  border-bottom: 1px solid #EBEEF5;
  position: sticky;
  top: 0;
  z-index: 10;
}

.back-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 36px;
  height: 36px;
  border: none;
  border-radius: 50%;
  background: transparent;
  color: #606266;
  cursor: pointer;
}

.back-btn:hover {
  background: #F5F7FA;
}

.header-title {
  flex: 1;
  text-align: center;
  font-size: 17px;
  font-weight: 600;
  color: #303133;
  margin: 0;
}

.header-spacer {
  width: 36px;
}

.create-form {
  padding: 24px 16px;
  display: flex;
  flex-direction: column;
  gap: 24px;
}

.form-item {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.form-label {
  font-size: 15px;
  font-weight: 600;
  color: #303133;
}

.form-input {
  width: 100%;
  height: 44px;
  padding: 0 16px;
  border: 1px solid #DCDFE6;
  border-radius: 12px;
  font-size: 15px;
  color: #303133;
  background: #fff;
  outline: none;
  transition: border-color 0.2s;
  box-sizing: border-box;
}

.form-input:focus {
  border-color: #534AB7;
}

.option-group {
  display: flex;
  gap: 10px;
}

.option-btn {
  flex: 1;
  height: 40px;
  border: 1px solid #DCDFE6;
  border-radius: 10px;
  background: #fff;
  font-size: 14px;
  color: #606266;
  cursor: pointer;
  transition: all 0.2s;
}

.option-btn.active {
  background: #534AB7;
  color: #fff;
  border-color: #534AB7;
}

.form-slider {
  width: 100%;
  height: 6px;
  -webkit-appearance: none;
  appearance: none;
  background: #EBEEF5;
  border-radius: 3px;
  outline: none;
}

.form-slider::-webkit-slider-thumb {
  -webkit-appearance: none;
  width: 24px;
  height: 24px;
  background: #534AB7;
  border-radius: 50%;
  cursor: pointer;
}

.slider-labels {
  display: flex;
  justify-content: space-between;
  font-size: 12px;
  color: #C0C4CC;
}

.create-btn {
  width: 100%;
  height: 48px;
  margin-top: 12px;
  border: none;
  border-radius: 24px;
  background: linear-gradient(135deg, #534AB7, #6366F1);
  color: #fff;
  font-size: 16px;
  font-weight: 600;
  cursor: pointer;
  transition: opacity 0.2s;
}

.create-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
</style>
