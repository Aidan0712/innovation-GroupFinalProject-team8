# 智能面试助手 - Intelligent Interview Assistant

> 面向大学生就业场景的多Agent协同系统 | 第八届传智杯AI大模型创新应用挑战赛国赛

## 系统简介

基于多Agent协同架构的大学生就业辅助系统，以对话式交互为核心，通过智能调度多个专业Agent，提供简历评估、面试录音分析、面试题生成等求职辅助服务。

## 核心功能

- **面试助手（主Agent）**：统一对话入口，意图识别，智能路由调度
- **简历评估Agent**：简历解析、质量评估、模板查重、违禁词检测
- **面试录音分析Agent**：语音转文字、答案比对、题库自动收录
- **面试题生成Agent**：基于简历和知识库生成个性化面试练习题
- **职业规划Agent**：个性化职业发展路径建议

## 技术架构

```
前端 (Vue 3 + TypeScript + Element Plus)
    ↓ HTTP/WebSocket/SSE
API网关 (FastAPI + Nginx)
    ↓
Agent编排引擎 (LangGraph)
    ├── 面试助手 (Orchestrator)
    ├── 简历评估Agent
    ├── 录音分析Agent
    ├── 面试题生成Agent
    └── 职业规划Agent
    ↓
共享服务层 (LLM | RAG | ASR | 文件解析)
    ↓
数据存储 (MySQL | Redis | ChromaDB)
```

## 技术栈

| 层级 | 技术 |
|------|------|
| 前端 | Vue 3, TypeScript, Vite, Element Plus, Pinia, Vue Router |
| 后端 | Python 3.11, FastAPI, SQLAlchemy, Pydantic |
| Agent | LangGraph, LangChain |
| LLM | 通义千问/智谱GLM (OpenAI兼容API) |
| RAG | ChromaDB, bge-large-zh-v1.5 |
| 数据库 | MySQL 8.0, Redis 7 |
| 部署 | Docker Compose, Nginx |

## 快速开始

### 环境要求

- Node.js >= 18
- Python >= 3.11
- Docker & Docker Compose（可选）

### 方式一：Docker Compose 一键部署

```bash
# 1. 克隆项目
git clone <repo-url>
cd aigc

# 2. 复制环境配置
cp .env.example .env
# 编辑 .env 填入 LLM_API_KEY 等配置

# 3. 启动所有服务
docker-compose up -d

# 4. 访问应用
# 前端：http://localhost
# 后端API：http://localhost:8000/docs
```

### 方式二：本地开发

```bash
# 1. 启动数据库
docker-compose up -d db redis

# 2. 后端启动
cd backend
python -m venv venv
venv\Scripts\activate        # Windows
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000

# 3. 前端启动（新终端）
cd frontend
npm install
npm run dev

# 4. 访问
# 前端：http://localhost:5173
# 后端API文档：http://localhost:8000/docs
```

## 项目结构

```
aigc/
├── frontend/                # Vue 3 前端
│   ├── src/
│   │   ├── api/             # API接口封装
│   │   ├── components/      # 通用组件
│   │   ├── views/           # 页面视图
│   │   ├── stores/          # Pinia状态管理
│   │   ├── router/          # 路由配置
│   │   └── types/           # TypeScript类型
│   └── package.json
├── backend/                 # FastAPI 后端
│   ├── app/
│   │   ├── api/             # API路由
│   │   ├── agents/          # Agent核心模块
│   │   ├── models/          # 数据模型
│   │   ├── schemas/         # 数据校验
│   │   ├── services/        # 业务服务
│   │   └── utils/           # 工具函数
│   └── requirements.txt
├── knowledge_base/          # 知识库数据
├── docker-compose.yml
├── nginx.conf
└── .env.example
```

## API 文档

启动后端后访问 http://localhost:8000/docs 查看 Swagger API 文档。

### 核心 API

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | /api/auth/login | 用户登录 |
| POST | /api/auth/register | 用户注册 |
| GET | /api/chat/stream | SSE流式对话 |
| POST | /api/resume/upload | 上传简历评估 |
| POST | /api/recording/upload | 上传面试录音 |
| POST | /api/questions/generate | 生成面试题 |
| GET | /api/admin/dashboard | 管理后台仪表盘 |

## 知识库

将面试宝典文档放入 `knowledge_base/interview_guide/`，系统启动时会自动向量化导入 ChromaDB。

## License

MIT
