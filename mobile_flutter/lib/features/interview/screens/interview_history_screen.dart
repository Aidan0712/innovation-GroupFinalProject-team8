import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/utils/formatters.dart';
import '../models/interview_models.dart';
import '../providers/interview_provider.dart';

class InterviewHistoryScreen extends StatefulWidget {
  const InterviewHistoryScreen({super.key});

  @override
  State<InterviewHistoryScreen> createState() => _InterviewHistoryScreenState();
}

class _InterviewHistoryScreenState extends State<InterviewHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InterviewProvider>().loadHistory();
    });
  }

  Future<void> _loadMore() {
    return context.read<InterviewProvider>().loadHistory(append: true);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InterviewProvider>();
    final sessions = provider.historySessions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('面试历史'),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<InterviewProvider>().loadHistory(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[
                    Color(0xFF6366F1),
                    Color(0xFF8B5CF6),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _HistoryStat(
                      title: '总记录',
                      value: '${provider.historyTotal}',
                    ),
                  ),
                  Expanded(
                    child: _HistoryStat(
                      title: '已完成',
                      value: '${provider.completedInterviewCount}',
                    ),
                  ),
                  Expanded(
                    child: _HistoryStat(
                      title: '平均分',
                      value: provider.averageScore == 0
                          ? '0'
                          : provider.averageScore.toStringAsFixed(0),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (provider.isLoading && sessions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (sessions.isEmpty)
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  children: <Widget>[
                    Text('还没有面试记录', style: TextStyle(fontWeight: FontWeight.w700)),
                    SizedBox(height: 8),
                    Text(
                      '完成第一场面试后，这里会展示历史记录和报告入口。',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              )
            else
              ...sessions.map((session) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _HistoryCard(session: session),
                );
              }),
            if (sessions.isNotEmpty && provider.hasMoreHistory)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: OutlinedButton(
                  onPressed: provider.isLoading ? null : _loadMore,
                  child: provider.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('加载更多'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HistoryStat extends StatelessWidget {
  const _HistoryStat({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(color: Colors.white70),
        ),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.session});

  final InterviewSession session;

  bool get _isFinished => session.totalScore != null || session.status == 'finished';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.of(context).pushNamed(
            _isFinished ? AppRouter.interviewReport : AppRouter.interviewRoom,
            arguments: _isFinished
                ? InterviewReportArgs(sessionId: session.id)
                : InterviewRoomArgs(sessionId: session.id),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      session.targetPosition,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                  _StatusBadge(session: session),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _MetaChip(text: AppFormatters.formatInterviewType(session.interviewType)),
                  _MetaChip(text: AppFormatters.formatDifficulty(session.difficulty)),
                  _MetaChip(text: '${session.questionCount} 题'),
                  _MetaChip(text: AppFormatters.formatAnswerMode(session.answerMode)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '创建于 ${AppFormatters.formatDateTime(session.createdAt)}',
                      style: const TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.session});

  final InterviewSession session;

  @override
  Widget build(BuildContext context) {
    final isFinished = session.totalScore != null || session.status == 'finished';
    if (isFinished) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '${(session.totalScore ?? 0).toStringAsFixed(0)} 分',
          style: const TextStyle(
            color: Color(0xFF2563EB),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        session.status == 'in_progress' ? '进行中' : '未开始',
        style: const TextStyle(
          color: Color(0xFFD97706),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF4B5563),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
