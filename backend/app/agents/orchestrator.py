"""
主编排 Agent（面试助手）
负责意图识别和路由调度，是整个系统的核心调度器

工作流程：
1. 接收用户消息
2. 通过 LLM 识别用户意图（面试帮助 / 简历评估 / 录音分析 / 题目生成 / 闲聊等）
3. 根据意图路由到对应的子 Agent
4. 汇总结果返回给用户
"""

import json
import re
from typing import Any

from app.agents.base_agent import AgentInput, AgentOutput, BaseAgent


class OrchestratorAgent(BaseAgent):
    """
    主编排 Agent
    作为面试助手的总入口，协调各个子 Agent 完成用户请求
    """

    VALID_INTENTS = {
        "resume_evaluation",
        "recording_analysis",
        "question_generation",
        "career_planning",
        "interview_practice",
        "knowledge_query",
        "interview_help",
    }
    INTENT_TO_AGENT = {
        "resume_evaluation": "resume",
        "recording_analysis": "recording",
        "question_generation": "question",
        "career_planning": "general",
        "interview_practice": "general",
        "knowledge_query": "general",
        "interview_help": "general",
    }

    def __init__(self):
        super().__init__(name="orchestrator")
        # 子 Agent 实例（延迟初始化以避免循环导入）
        self._sub_agents: dict[str, BaseAgent] = {}

    async def _get_sub_agent(self, intent: str) -> BaseAgent | None:
        """
        根据意图获取对应的子 Agent 实例
        使用延迟导入避免循环引用
        """
        agent_map = {
            "resume_evaluation": "resume_agent",
            "recording_analysis": "recording_agent",
            "question_generation": "question_agent",
            "career_planning": "career_agent",
        }

        agent_key = agent_map.get(intent)
        if not agent_key:
            return None

        if agent_key not in self._sub_agents:
            # 延迟导入具体的 Agent
            if agent_key == "resume_agent":
                from app.agents.resume_agent import ResumeAgent
                self._sub_agents[agent_key] = ResumeAgent()
            elif agent_key == "recording_agent":
                from app.agents.recording_agent import RecordingAgent
                self._sub_agents[agent_key] = RecordingAgent()
            elif agent_key == "question_agent":
                from app.agents.question_agent import QuestionAgent
                self._sub_agents[agent_key] = QuestionAgent()
            elif agent_key == "career_agent":
                from app.agents.career_agent import CareerAgent
                self._sub_agents[agent_key] = CareerAgent()

        return self._sub_agents.get(agent_key)

    async def _classify_intent(self, content: str) -> str:
        """
        意图识别
        
        策略：优先由 LLM 做语义判断，避免被文件类型或关键词硬编码覆盖用户真实意图。
        
        Args:
            content: 用户输入内容
            
        Returns:
            str: 识别出的意图类型
        """
        llm_intent = await self._llm_classify_intent(content)
        if llm_intent:
            return llm_intent

        # 默认意图：普通对话/面试帮助
        return "interview_help"

    def _extract_json(self, text: str) -> dict[str, Any] | None:
        raw = text.strip()
        if "```json" in raw:
            raw = raw.split("```json", 1)[1].split("```", 1)[0].strip()
        elif "```" in raw:
            raw = raw.split("```", 1)[1].split("```", 1)[0].strip()

        decoder = json.JSONDecoder()
        for index, char in enumerate(raw):
            if char != "{":
                continue
            try:
                data, _ = decoder.raw_decode(raw[index:])
                return data if isinstance(data, dict) else None
            except json.JSONDecodeError:
                continue
        return None

    async def plan_route(
        self,
        content: str,
        file_url: str | None = None,
        requested_agent: str = "general",
    ) -> dict[str, Any]:
        """
        由主 Agent 生成结构化调度计划。

        输出包含 intent、agent_type、reason，使 API 层只负责执行计划，不再散落硬编码意图规则。
        """
        ext = ""
        if file_url:
            import os

            ext = os.path.splitext(file_url)[1].lower().lstrip(".")

        try:
            from app.services.llm_service import LLMService

            llm = LLMService()
            prompt = f"""你是智能面试助手的主 Agent，负责分析用户真实意图并选择要调用的子 Agent。

请只返回 JSON，不要输出解释文字。

可选子 Agent：
- resume：简历评估、简历优化、简历查重、违禁词检测；通常处理 PDF/Word/图片简历
- recording：录音/视频转写、面试表现分析、回答质量评估；通常处理音视频
- question：生成面试题、根据简历/录音/岗位生成相似题、刷题、追问题库
- general：通用面试咨询、职业规划、知识问答、模拟面试

决策原则：
1. 用户文字表达的任务目标优先级最高，上传文件类型只是上下文，不得直接覆盖用户意图。
2. 如果用户上传录音但要求“生成类似面试题/出题/追问”，应选择 question，而不是 recording。
3. 如果用户上传录音并要求“分析表现/转写/评价回答”，应选择 recording。
4. 如果用户手动选择了模块，它是一个强提示，但若用户文字明显表达了不同任务，要以文字意图为准。
5. reason 要用一句中文说明为什么选择该 Agent。

用户文字：{content or "（空）"}
上传文件扩展名：{ext or "无"}
前端当前模块提示：{requested_agent or "general"}

返回 JSON 格式：
{{"intent":"question_generation","agent_type":"question","reason":"用户要求根据录音生成类似面试题，因此调用面试题生成 Agent。","confidence":0.0}}
"""
            result = await llm.chat(
                messages=[{"role": "user", "content": prompt}],
                temperature=0,
                max_tokens=256,
            )
            data = self._extract_json(result) or {}
            agent_type = str(data.get("agent_type") or "general")
            intent = str(data.get("intent") or "interview_help")
            if agent_type not in {"resume", "recording", "question", "general"}:
                agent_type = self.INTENT_TO_AGENT.get(intent, "general")
            if intent not in self.VALID_INTENTS:
                intent = "interview_help"
            return {
                "intent": intent,
                "agent_type": agent_type,
                "reason": data.get("reason") or f"主 Agent 判断该请求适合交给 {agent_type} 处理。",
                "confidence": data.get("confidence", 0),
                "requested_agent": requested_agent,
                "file_ext": ext,
            }
        except Exception:
            # 仅在主 Agent 规划失败时使用保守降级，不作为常规意图判断路径。
            fallback_agent = requested_agent if requested_agent in {"resume", "recording", "question"} else "general"
            return {
                "intent": "interview_help",
                "agent_type": fallback_agent,
                "reason": "主 Agent 意图规划失败，已按当前模块提示进行保守降级。",
                "confidence": 0,
                "requested_agent": requested_agent,
                "file_ext": ext,
            }

    async def _llm_classify_intent(self, content: str) -> str | None:
        """
        使用 LLM 进行意图分类（预留）
        
        TODO: 实现 LLM 意图分类
        - 构造分类 prompt，包含所有可能的意图类型和描述
        - 调用 llm_service 获取分类结果
        - 解析返回的 JSON 格式结果
        """
        try:
            from app.services.llm_service import LLMService

            llm = LLMService()
            prompt = f"""请判断用户消息最适合交给哪个 Agent 处理，只返回一个意图标识。

可选意图：
- resume_evaluation：简历评估、简历优化、简历查重、违禁词检测
- recording_analysis：面试录音/视频转写、录音分析、回答表现评估
- question_generation：生成面试题、刷题、根据岗位或简历出题
- career_planning：职业规划、就业方向、成长路径
- interview_practice：模拟面试、练习问答
- knowledge_query：面试知识、面经、技术概念解释
- interview_help：普通对话或无法归类

用户消息：{content}
"""
            result = await llm.chat(
                messages=[{"role": "user", "content": prompt}],
                temperature=0,
                max_tokens=32,
            )
            intent = result.strip().strip("`").split()[0]
            return intent if intent in self.VALID_INTENTS else None
        except Exception:
            return None

    async def _handle_direct_chat(self, agent_input: AgentInput) -> AgentOutput:
        """
        处理直接对话（无特定意图时）
        使用 LLM 生成一般性回复
        
        TODO: 集成 RAG 检索，让回复包含面试宝典中的相关知识
        """
        try:
            from app.services.llm_service import LLMService
            from app.services.rag_service import RAGService

            rag = RAGService()
            docs = await rag.search(agent_input.content, top_k=4, threshold=0.35)
            context = "\n\n".join(
                f"[资料{i + 1}] {doc.get('content', '')}"
                for i, doc in enumerate(docs)
            )
            system_prompt = (
                "你是面向大学生就业场景的智能面试助手。请结合知识库资料回答，"
                "输出 Markdown，给出可执行建议；如果资料不足，说明你的判断依据。"
            )
            user_message = agent_input.content
            if context:
                user_message += f"\n\n可参考的知识库资料：\n{context}"

            llm = LLMService()
            response = await llm.chat(
                messages=[{"role": "user", "content": user_message}],
                system_prompt=system_prompt,
            )
            return AgentOutput(
                content=response,
                agent_name=self.name,
                metadata={"intent": "direct_chat", "rag_hits": len(docs)},
            )
        except Exception:
            pass

        return AgentOutput(
            content=(
                f"你好！我是面试助手，可以帮你：\n"
                f"1. 📄 上传简历进行评估和优化建议\n"
                f"2. 🎙️ 上传录音进行面试表现分析\n"
                f"3. 💡 生成各类面试题目\n"
                f"4. 📚 查询面试经验和知识\n"
                f"5. 🎯 进行模拟面试练习\n\n"
                f"请告诉我你需要什么帮助？"
            ),
            agent_name=self.name,
        )

    async def execute(self, agent_input: AgentInput) -> AgentOutput:
        """
        执行编排逻辑
        
        流程：
        1. 意图识别
        2. 路由到子 Agent（或不路由，直接对话）
        3. 返回结果
        """
        # 第一步：意图识别
        intent = await self._classify_intent(agent_input.content)

        # 第二步：根据意图路由
        if intent in ["interview_help", "interview_practice", "knowledge_query"]:
            # 直接对话处理（后续可集成 RAG）
            return await self._handle_direct_chat(agent_input)
        else:
            # 路由到子 Agent
            sub_agent = await self._get_sub_agent(intent)
            if sub_agent:
                return await sub_agent.run(agent_input)
            else:
                # 无匹配的子 Agent，回退到直接对话
                return await self._handle_direct_chat(agent_input)
