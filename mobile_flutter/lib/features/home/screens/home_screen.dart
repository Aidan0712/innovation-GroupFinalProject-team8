import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/interview/models/interview_models.dart';
import '../../../features/interview/providers/interview_provider.dart';
import '../../../shared/widgets/section_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onOpenInterviewTab,
    required this.onOpenProfileTab,
  });

  final VoidCallback onOpenInterviewTab;
  final VoidCallback onOpenProfileTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InterviewProvider>().loadRecentSessions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final interview = context.watch<InterviewProvider>();
    final sessions = interview.recentSessions;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => context.read<InterviewProvider>().loadRecentSessions(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[
                    Color(0xFF6366F1),
                    Color(0xFF8B5CF6),
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const CircleAvatar(
                        radius: 26,
                        backgroundColor: Color(0x33FFFFFF),
                        child: Text('👤'),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '你好，${auth.user?.username ?? '同学'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              '准备好开始今天的 AI 面试训练了吗？',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: widget.onOpenProfileTab,
                        color: Colors.white,
                        icon: const Icon(Icons.settings_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: widget.onOpenInterviewTab,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: <Widget>[
                          CircleAvatar(
                            backgroundColor: Color(0xFFEEF2FF),
                            child: Text('🚀'),
                          ),
                          SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  '快速开始面试',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '一键进入配置页，开始新的模拟面试。',
                                  style: TextStyle(color: Color(0xFF6B7280)),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios, size: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SectionCard(
              title: '面试类型',
              icon: '🎯',
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: const <Widget>[
                  _InterviewTypeChip(
                    value: 'technical',
                    icon: '💻',
                    title: '技术面试',
                    description: '深入考察技术能力',
                  ),
                  _InterviewTypeChip(
                    value: 'behavioral',
                    icon: '🧠',
                    title: '行为面试',
                    description: '侧重经历和沟通表达',
                  ),
                  _InterviewTypeChip(
                    value: 'comprehensive',
                    icon: '🎤',
                    title: '综合面试',
                    description: '全方位模拟问答',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SectionCard(
              title: '最近面试',
              icon: '🕒',
              child: sessions.isEmpty
                  ? const _EmptyState(
                      title: '暂无面试记录',
                      subtitle: '从首页快速开始你的第一场 AI 面试吧。',
                    )
                  : Column(
                      children: <Widget>[
                        ...sessions.map((session) {
                          return _HistoryTile(session: session);
                        }),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).pushNamed(
                                AppRouter.interviewHistory,
                              );
                            },
                            child: const Text('查看全部'),
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 20),
            SectionCard(
              title: '面试技巧',
              icon: '📌',
              child: Column(
                children: AppConstants.homeTips.asMap().entries.map((entry) {
                  final index = entry.key + 1;
                  final text = entry.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: const Color(0xFFEEF2FF),
                          child: Text(
                            '$index',
                            style: const TextStyle(
                              color: Color(0xFF6366F1),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            text,
                            style: const TextStyle(
                              color: Color(0xFF4B5563),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InterviewTypeChip extends StatelessWidget {
  const _InterviewTypeChip({
    required this.value,
    required this.icon,
    required this.title,
    required this.description,
  });

  final String value;
  final String icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pushNamed(
          AppRouter.interviewSetup,
          arguments: value,
        );
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.session});

  final InterviewSession session;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(session.targetPosition),
      subtitle: Text(AppFormatters.formatRelativeTime(session.createdAt)),
      trailing: session.totalScore != null
          ? Text(
              '${session.totalScore!.round()} 分',
              style: const TextStyle(
                color: Color(0xFF6366F1),
                fontWeight: FontWeight.w700,
              ),
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFDE68A).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                session.status == 'in_progress' ? '进行中' : '未完成',
                style: const TextStyle(
                  color: Color(0xFFD97706),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
      onTap: () {
        Navigator.of(context).pushNamed(
          session.totalScore != null || session.status == 'finished'
              ? AppRouter.interviewReport
              : AppRouter.interviewRoom,
          arguments: session.totalScore != null || session.status == 'finished'
              ? InterviewReportArgs(sessionId: session.id)
              : InterviewRoomArgs(sessionId: session.id),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: <Widget>[
          const Text('🗂️', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF4B5563),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }
}
