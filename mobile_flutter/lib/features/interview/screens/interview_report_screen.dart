import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/services/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/section_card.dart';
import '../models/interview_models.dart';
import '../providers/interview_provider.dart';

class InterviewReportScreen extends StatefulWidget {
  const InterviewReportScreen({
    super.key,
    required this.sessionId,
  });

  final int sessionId;

  @override
  State<InterviewReportScreen> createState() => _InterviewReportScreenState();
}

class _InterviewReportScreenState extends State<InterviewReportScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReport();
    });
  }

  Future<void> _loadReport() async {
    try {
      await context.read<InterviewProvider>().loadReport(widget.sessionId);
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('加载报告失败，请稍后重试');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = context.watch<InterviewProvider>().currentReport;

    return Scaffold(
      appBar: AppBar(
        title: const Text('面试报告'),
      ),
      body: _loading && report == null
          ? const Center(child: CircularProgressIndicator())
          : report == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Text(
                          '暂无可用报告',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _loadReport,
                          child: const Text('重新加载'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: <Widget>[
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadReport,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                          children: <Widget>[
                            _ScoreHero(report: report),
                            const SizedBox(height: 16),
                            if (report.dimensionScores.isNotEmpty) ...<Widget>[
                              SectionCard(
                                title: '维度得分',
                                icon: '📊',
                                child: Column(
                                  children: report.dimensionScores.entries.map((entry) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 14),
                                      child: _DimensionRow(
                                        label: AppFormatters.dimensionLabel(entry.key),
                                        score: entry.value,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            SectionCard(
                              title: '总体评价',
                              icon: '🧾',
                              child: Text(
                                report.summary,
                                style: const TextStyle(
                                  color: Color(0xFF4B5563),
                                  height: 1.6,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _ListSection(
                              title: '优势',
                              icon: '✅',
                              items: report.strengths,
                              emptyText: '暂无优势总结',
                              numbered: false,
                            ),
                            const SizedBox(height: 16),
                            _ListSection(
                              title: '待改进',
                              icon: '🛠️',
                              items: report.weaknesses,
                              emptyText: '暂无待改进项',
                              numbered: false,
                            ),
                            const SizedBox(height: 16),
                            _ListSection(
                              title: '改进建议',
                              icon: '💡',
                              items: report.suggestions,
                              emptyText: '暂无改进建议',
                              numbered: true,
                            ),
                            if (report.actionPlan.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 16),
                              _ListSection(
                                title: '行动计划',
                                icon: '🗓️',
                                items: report.actionPlan,
                                emptyText: '暂无行动计划',
                                numbered: true,
                              ),
                            ],
                            if (report.turnPerformance.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 16),
                              SectionCard(
                                title: '逐题详情',
                                icon: '🧠',
                                child: Column(
                                  children: report.turnPerformance.map((turn) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 16),
                                      child: _TurnPerformanceCard(turn: turn),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  _showMessage('分享功能开发中');
                                },
                                child: const Text('分享报告'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: () {
                                  AppRouter.openShell(context, index: 1);
                                },
                                child: const Text('再次面试'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _ScoreHero extends StatelessWidget {
  const _ScoreHero({required this.report});

  final InterviewReport report;

  @override
  Widget build(BuildContext context) {
    final levelColor = AppFormatters.scoreLevelColor(report.totalScore);

    return Container(
      padding: const EdgeInsets.all(28),
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
        children: <Widget>[
          Text(
            report.totalScore.toStringAsFixed(0),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 72,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Text(
            '总分',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: levelColor.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              AppFormatters.scoreLevelText(report.totalScore),
              style: TextStyle(
                color: levelColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if ((report.scoreBasis ?? '').isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              report.scoreBasis!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DimensionRow extends StatelessWidget {
  const _DimensionRow({
    required this.label,
    required this.score,
  });

  final String label;
  final double score;

  @override
  Widget build(BuildContext context) {
    final clamped = score.clamp(0, 100).toDouble();

    return Row(
      children: <Widget>[
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF4B5563)),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: clamped / 100,
              minHeight: 10,
              backgroundColor: const Color(0xFFE5E7EB),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 40,
          child: Text(
            clamped.toStringAsFixed(0),
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Color(0xFF4F46E5),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ListSection extends StatelessWidget {
  const _ListSection({
    required this.title,
    required this.icon,
    required this.items,
    required this.emptyText,
    required this.numbered,
  });

  final String title;
  final String icon;
  final List<String> items;
  final String emptyText;
  final bool numbered;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      icon: icon,
      child: items.isEmpty
          ? Text(
              emptyText,
              style: const TextStyle(color: Color(0xFF9CA3AF)),
            )
          : Column(
              children: items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return Padding(
                  padding: EdgeInsets.only(bottom: index == items.length - 1 ? 0 : 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF2FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          numbered ? '${index + 1}' : '•',
                          style: const TextStyle(
                            color: Color(0xFF4F46E5),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item,
                          style: const TextStyle(
                            color: Color(0xFF4B5563),
                            height: 1.55,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _TurnPerformanceCard extends StatelessWidget {
  const _TurnPerformanceCard({required this.turn});

  final InterviewTurnPerformance turn;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '第 ${turn.questionIndex} 题',
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF2FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${turn.score.toStringAsFixed(0)} 分',
                  style: const TextStyle(
                    color: Color(0xFF4F46E5),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _LabelText(label: '问题', value: turn.question),
          if ((turn.answer ?? '').isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            _LabelText(label: '回答', value: turn.answer!),
          ],
          const SizedBox(height: 10),
          _LabelText(label: '评价', value: turn.feedback),
          const SizedBox(height: 10),
          _LabelText(label: '建议', value: turn.suggestion),
          if (turn.evidence.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            _LabelText(label: '亮点', value: turn.evidence.join('；')),
          ],
          if (turn.missingPoints.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            _LabelText(label: '缺失点', value: turn.missingPoints.join('；')),
          ],
        ],
      ),
    );
  }
}

class _LabelText extends StatelessWidget {
  const _LabelText({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF4B5563),
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
