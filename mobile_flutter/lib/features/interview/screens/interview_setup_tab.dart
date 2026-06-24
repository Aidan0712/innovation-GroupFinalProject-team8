import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/section_card.dart';
import '../providers/interview_provider.dart';

class InterviewSetupTabScreen extends StatefulWidget {
  const InterviewSetupTabScreen({
    super.key,
    required this.showAppBar,
    this.initialInterviewType,
  });

  final bool showAppBar;
  final String? initialInterviewType;

  @override
  State<InterviewSetupTabScreen> createState() => _InterviewSetupTabScreenState();
}

class _InterviewSetupTabScreenState extends State<InterviewSetupTabScreen> {
  final TextEditingController _positionController = TextEditingController();

  String _interviewType = 'technical';
  String _difficulty = 'medium';
  int _questionCount = 5;
  String _answerMode = 'text';
  bool _useProfile = false;

  @override
  void initState() {
    super.initState();
    final initialType = widget.initialInterviewType;
    if (initialType != null &&
        AppConstants.interviewTypeLabels.containsKey(initialType)) {
      _interviewType = initialType;
    }
  }

  @override
  void dispose() {
    _positionController.dispose();
    super.dispose();
  }

  bool get _canSubmit => _positionController.text.trim().isNotEmpty;

  Future<void> _startInterview() async {
    if (!_canSubmit) {
      _showMessage('请输入目标岗位');
      return;
    }

    final provider = context.read<InterviewProvider>();
    try {
      final detail = await provider.createAndStartSession(
        targetPosition: _positionController.text.trim(),
        interviewType: _interviewType,
        difficulty: _difficulty,
        questionCount: _questionCount,
        answerMode: _answerMode,
        useProfile: _useProfile,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushNamed(
        AppRouter.interviewRoom,
        arguments: InterviewRoomArgs(sessionId: detail.id),
      );
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('创建面试失败，请稍后重试');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final interview = context.watch<InterviewProvider>();

    return Scaffold(
      appBar: widget.showAppBar ? AppBar(title: const Text('面试配置')) : null,
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        top: !widget.showAppBar,
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                children: <Widget>[
                  SectionCard(
                    title: '面试信息',
                    icon: '🎯',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        TextField(
                          controller: _positionController,
                          onChanged: (_) => setState(() {}),
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: '目标岗位',
                            hintText: '请输入目标岗位，例如 Flutter 开发工程师',
                          ),
                        ),
                        const SizedBox(height: 20),
                        _FieldLabel(label: '面试类型'),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: <Widget>[
                            _ChoiceChip(
                              selected: _interviewType == 'technical',
                              label: '技术面试',
                              icon: '💻',
                              onSelected: () {
                                setState(() {
                                  _interviewType = 'technical';
                                });
                              },
                            ),
                            _ChoiceChip(
                              selected: _interviewType == 'behavioral',
                              label: '行为面试',
                              icon: '🗣️',
                              onSelected: () {
                                setState(() {
                                  _interviewType = 'behavioral';
                                });
                              },
                            ),
                            _ChoiceChip(
                              selected: _interviewType == 'comprehensive',
                              label: '综合面试',
                              icon: '🧠',
                              onSelected: () {
                                setState(() {
                                  _interviewType = 'comprehensive';
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _FieldLabel(label: '难度'),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: <Widget>[
                            _ChoiceChip(
                              selected: _difficulty == 'easy',
                              label: AppFormatters.formatDifficulty('easy'),
                              icon: '🌱',
                              onSelected: () {
                                setState(() {
                                  _difficulty = 'easy';
                                });
                              },
                            ),
                            _ChoiceChip(
                              selected: _difficulty == 'medium',
                              label: AppFormatters.formatDifficulty('medium'),
                              icon: '🚀',
                              onSelected: () {
                                setState(() {
                                  _difficulty = 'medium';
                                });
                              },
                            ),
                            _ChoiceChip(
                              selected: _difficulty == 'hard',
                              label: AppFormatters.formatDifficulty('hard'),
                              icon: '🔥',
                              onSelected: () {
                                setState(() {
                                  _difficulty = 'hard';
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _FieldLabel(label: '题目数量'),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: <int>[3, 5, 8, 10].map((count) {
                            return _ChoiceChip(
                              selected: _questionCount == count,
                              label: '$count 题',
                              onSelected: () {
                                setState(() {
                                  _questionCount = count;
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                        _FieldLabel(label: '回答方式'),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: <Widget>[
                            _ChoiceChip(
                              selected: _answerMode == 'text',
                              label: AppFormatters.formatAnswerMode('text'),
                              icon: '⌨️',
                              onSelected: () {
                                setState(() {
                                  _answerMode = 'text';
                                });
                              },
                            ),
                            _ChoiceChip(
                              selected: _answerMode == 'audio',
                              label: AppFormatters.formatAnswerMode('audio'),
                              icon: '🎙️',
                              onSelected: () {
                                setState(() {
                                  _answerMode = 'audio';
                                });
                              },
                            ),
                            _ChoiceChip(
                              selected: _answerMode == 'mixed',
                              label: AppFormatters.formatAnswerMode('mixed'),
                              icon: '🔁',
                              onSelected: () {
                                setState(() {
                                  _answerMode = 'mixed';
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          value: _useProfile,
                          onChanged: (value) {
                            setState(() {
                              _useProfile = value;
                            });
                          },
                          contentPadding: EdgeInsets.zero,
                          title: const Text('结合个人资料提问'),
                          subtitle: const Text('开启后，系统会尽量结合你的背景生成问题'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: '面试说明',
                    icon: '📝',
                    child: const Column(
                      children: <Widget>[
                        _TipTile(
                          index: 1,
                          text: '请确保网络稳定，面试过程中需要与后端实时通信。',
                        ),
                        SizedBox(height: 12),
                        _TipTile(
                          index: 2,
                          text: '每题建议回答 1 到 3 分钟，尽量保持结构清晰。',
                        ),
                        SizedBox(height: 12),
                        _TipTile(
                          index: 3,
                          text: '面试结束后会自动生成总评、维度评分和逐题建议。',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: FilledButton(
                onPressed: interview.isSubmitting ? null : _startInterview,
                child: interview.isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('开始面试'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF6B7280),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.selected,
    required this.label,
    required this.onSelected,
    this.icon,
  });

  final bool selected;
  final String label;
  final VoidCallback onSelected;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFEFF2FF)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? const Color(0xFF6366F1)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Text(icon!, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? const Color(0xFF4F46E5)
                    : const Color(0xFF4B5563),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipTile extends StatelessWidget {
  const _TipTile({
    required this.index,
    required this.text,
  });

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        CircleAvatar(
          radius: 14,
          backgroundColor: const Color(0xFFEEF2FF),
          child: Text(
            '$index',
            style: const TextStyle(
              color: Color(0xFF4F46E5),
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
    );
  }
}
