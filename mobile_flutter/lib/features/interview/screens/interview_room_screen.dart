import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/services/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/voice_message_card.dart';
import '../../../shared/widgets/voice_record_button.dart';
import '../models/interview_models.dart';
import '../providers/interview_provider.dart';

class InterviewRoomScreen extends StatefulWidget {
  const InterviewRoomScreen({
    super.key,
    required this.sessionId,
  });

  final int sessionId;

  @override
  State<InterviewRoomScreen> createState() => _InterviewRoomScreenState();
}

class _InterviewRoomScreenState extends State<InterviewRoomScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Timer? _ticker;
  int _elapsedSeconds = 0;
  int? _activeTurnId;
  bool _initialLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSession();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSession() async {
    final provider = context.read<InterviewProvider>();
    try {
      final session = await provider.ensureSessionLoaded(widget.sessionId);
      if (!mounted) {
        return;
      }
      if (session.status == 'finished') {
        _openReport();
        return;
      }
      _syncActiveTurn(session);
      _scrollToBottom();
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('加载面试失败，请稍后重试');
    } finally {
      if (mounted) {
        setState(() {
          _initialLoading = false;
        });
      }
    }
  }

  void _syncActiveTurn(InterviewSessionDetail session) {
    final currentTurn = session.currentTurn;
    if (currentTurn == null || currentTurn.isAnswered) {
      _stopTimer();
      return;
    }

    if (_activeTurnId != currentTurn.id) {
      _activeTurnId = currentTurn.id;
      _elapsedSeconds = 0;
    }
    _startTimer();
    if (mounted) {
      setState(() {});
    }
  }

  void _startTimer() {
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _elapsedSeconds += 1;
      });
    });
  }

  void _stopTimer() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  bool _isLastQuestion(InterviewSessionDetail session) {
    final currentTurn = session.currentTurn;
    return currentTurn != null &&
        !currentTurn.isAnswered &&
        currentTurn.questionIndex >= session.questionCount;
  }

  bool _hasUnfinishedTurn(InterviewSessionDetail session) {
    return session.turns.any((turn) => !turn.isAnswered);
  }

  Future<void> _submitTextAnswer() async {
    final provider = context.read<InterviewProvider>();
    final session = provider.currentSession;
    final answerText = _textController.text.trim();
    if (session == null || answerText.isEmpty) {
      return;
    }

    final shouldFinish = _isLastQuestion(session);
    final durationSeconds = max(1, _elapsedSeconds);
    _stopTimer();

    try {
      _textController.clear();
      final updated = await provider.submitTextAnswer(
        sessionId: widget.sessionId,
        answerText: answerText,
        durationSeconds: durationSeconds,
      );
      if (!mounted) {
        return;
      }
      if (shouldFinish || !_hasUnfinishedTurn(updated)) {
        await _finishInterview();
        return;
      }
      _syncActiveTurn(updated);
      _scrollToBottom();
    } on ApiException catch (error) {
      _showMessage(error.message);
      _startTimer();
    } catch (_) {
      _showMessage('提交回答失败，请稍后重试');
      _startTimer();
    }
  }

  Future<void> _submitVoiceAnswer(RecordedClip clip) async {
    final provider = context.read<InterviewProvider>();
    final session = provider.currentSession;
    if (session == null) {
      return;
    }

    final shouldFinish = _isLastQuestion(session);
    _stopTimer();

    try {
      final updated = await provider.submitVoiceAnswer(
        sessionId: widget.sessionId,
        filePath: clip.filePath,
        durationSeconds: clip.durationSeconds,
      );
      if (!mounted) {
        return;
      }
      if (shouldFinish || !_hasUnfinishedTurn(updated)) {
        await _finishInterview();
        return;
      }
      _syncActiveTurn(updated);
      _scrollToBottom();
    } on ApiException catch (error) {
      _showMessage(error.message);
      _startTimer();
    } catch (_) {
      _showMessage('语音回答提交失败，请稍后重试');
      _startTimer();
    }
  }

  Future<void> _finishInterview() async {
    final provider = context.read<InterviewProvider>();
    try {
      _stopTimer();
      await provider.finishSession(widget.sessionId);
      if (!mounted) {
        return;
      }
      _openReport(replace: true);
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('结束面试失败，请稍后重试');
    }
  }

  Future<bool> _handleBack() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('确认退出'),
          content: const Text('现在退出会保留当前会话，但本题计时会重置。是否返回？'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('继续作答'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('退出'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  void _openReport({bool replace = false}) {
    final routeName = AppRouter.interviewReport;
    final arguments = InterviewReportArgs(sessionId: widget.sessionId);
    if (replace) {
      Navigator.of(context).pushReplacementNamed(routeName, arguments: arguments);
      return;
    }
    Navigator.of(context).pushNamed(routeName, arguments: arguments);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final interview = context.watch<InterviewProvider>();
    final session = interview.currentSession;
    final currentTurn = session?.currentTurn;
    final messages = session == null ? const <_RoomMessage>[] : _buildMessages(session);
    final canUseText = session != null &&
        (session.answerMode == 'text' || session.answerMode == 'mixed');
    final canUseVoice = session != null &&
        (session.answerMode == 'audio' || session.answerMode == 'mixed');
    final navigator = Navigator.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        final shouldPop = await _handleBack();
        if (shouldPop && mounted) {
          navigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () async {
              final shouldPop = await _handleBack();
              if (shouldPop && mounted) {
                navigator.pop();
              }
            },
            icon: const Icon(Icons.arrow_back_ios_new),
          ),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('AI 面试'),
              if (session != null)
                Text(
                  '${min((currentTurn?.questionIndex ?? session.questionCount), session.questionCount)}/${session.questionCount}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
            ],
          ),
          actions: <Widget>[
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF2FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    AppFormatters.formatDuration(_elapsedSeconds),
                    style: const TextStyle(
                      color: Color(0xFF4F46E5),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: _initialLoading
            ? const Center(child: CircularProgressIndicator())
            : session == null
                ? _ErrorState(
                    onRetry: _loadSession,
                  )
                : Column(
                    children: <Widget>[
                      Expanded(
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            return _MessageItem(message: message);
                          },
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            top: BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                        ),
                        child: SafeArea(
                          top: false,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              if (canUseText) ...<Widget>[
                                TextField(
                                  controller: _textController,
                                  onChanged: (_) => setState(() {}),
                                  minLines: 3,
                                  maxLines: 6,
                                  textInputAction: TextInputAction.newline,
                                  decoration: const InputDecoration(
                                    hintText: '请输入你的回答...',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                FilledButton(
                                  onPressed: interview.isSubmitting || _textController.text.trim().isEmpty
                                      ? null
                                      : _submitTextAnswer,
                                  child: Text(
                                    _isLastQuestion(session) ? '提交并结束面试' : '提交文字回答',
                                  ),
                                ),
                              ],
                              if (canUseText && canUseVoice)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Row(
                                    children: <Widget>[
                                      Expanded(child: Divider()),
                                      Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 12),
                                        child: Text(
                                          '或',
                                          style: TextStyle(color: Color(0xFF9CA3AF)),
                                        ),
                                      ),
                                      Expanded(child: Divider()),
                                    ],
                                  ),
                                ),
                              if (canUseVoice)
                                VoiceRecordButton(
                                  enabled: currentTurn != null && !currentTurn.isAnswered,
                                  busy: interview.isSubmitting,
                                  onRecorded: _submitVoiceAnswer,
                                  onError: _showMessage,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  List<_RoomMessage> _buildMessages(InterviewSessionDetail session) {
    final result = <_RoomMessage>[];
    for (final turn in session.turns) {
      result.add(
        _RoomMessage.ai(
          content: turn.question,
          index: turn.questionIndex,
        ),
      );

      if (!turn.isAnswered) {
        continue;
      }

      if ((turn.answerAudioUrl ?? '').isNotEmpty) {
        result.add(
          _RoomMessage.voice(
            audioUrl: AppFormatters.absoluteUrl(turn.answerAudioUrl ?? ''),
            transcript: turn.answerText ?? '',
            durationSeconds: turn.answerDurationSeconds ?? 0,
          ),
        );
      } else {
        result.add(
          _RoomMessage.user(
            content: turn.answerText ?? '',
            durationSeconds: turn.answerDurationSeconds ?? 0,
          ),
        );
      }

      result.add(
        _RoomMessage.feedback(
          score: turn.score ?? 0,
          feedback: turn.feedback ?? '本题已作答。',
          suggestion: turn.suggestion ?? '继续保持当前节奏，注意回答结构。',
        ),
      );
    }
    return result;
  }
}

class _RoomMessage {
  const _RoomMessage._({
    required this.kind,
    this.content,
    this.index,
    this.durationSeconds,
    this.score,
    this.feedback,
    this.suggestion,
    this.audioUrl,
    this.transcript,
  });

  factory _RoomMessage.ai({
    required String content,
    required int index,
  }) {
    return _RoomMessage._(
      kind: _RoomMessageKind.ai,
      content: content,
      index: index,
    );
  }

  factory _RoomMessage.user({
    required String content,
    required int durationSeconds,
  }) {
    return _RoomMessage._(
      kind: _RoomMessageKind.userText,
      content: content,
      durationSeconds: durationSeconds,
    );
  }

  factory _RoomMessage.voice({
    required String audioUrl,
    required String transcript,
    required int durationSeconds,
  }) {
    return _RoomMessage._(
      kind: _RoomMessageKind.userVoice,
      audioUrl: audioUrl,
      transcript: transcript,
      durationSeconds: durationSeconds,
    );
  }

  factory _RoomMessage.feedback({
    required double score,
    required String feedback,
    required String suggestion,
  }) {
    return _RoomMessage._(
      kind: _RoomMessageKind.feedback,
      score: score,
      feedback: feedback,
      suggestion: suggestion,
    );
  }

  final _RoomMessageKind kind;
  final String? content;
  final int? index;
  final int? durationSeconds;
  final double? score;
  final String? feedback;
  final String? suggestion;
  final String? audioUrl;
  final String? transcript;
}

enum _RoomMessageKind {
  ai,
  userText,
  userVoice,
  feedback,
}

class _MessageItem extends StatelessWidget {
  const _MessageItem({required this.message});

  final _RoomMessage message;

  @override
  Widget build(BuildContext context) {
    switch (message.kind) {
      case _RoomMessageKind.ai:
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: <Color>[
                      Color(0xFF6366F1),
                      Color(0xFF8B5CF6),
                    ],
                  ),
                ),
                child: const Text('AI', style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x11000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (message.index != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '第 ${message.index} 题',
                            style: const TextStyle(
                              color: Color(0xFF6366F1),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      Text(
                        message.content ?? '',
                        style: const TextStyle(
                          color: Color(0xFF1F2937),
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      case _RoomMessageKind.userText:
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: <Color>[
                        Color(0xFF6366F1),
                        Color(0xFF4F46E5),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        message.content ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '用时 ${AppFormatters.formatDuration(message.durationSeconds ?? 0)}',
                        style: const TextStyle(
                          color: Color(0xFFE0E7FF),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      case _RoomMessageKind.userVoice:
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              Flexible(
                child: VoiceMessageCard(
                  audioUrl: message.audioUrl ?? '',
                  durationSeconds: message.durationSeconds ?? 0,
                  transcript: message.transcript ?? '',
                ),
              ),
            ],
          ),
        );
      case _RoomMessageKind.feedback:
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const Text(
                      '本题反馈',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF2FF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${(message.score ?? 0).toStringAsFixed(0)} 分',
                        style: const TextStyle(
                          color: Color(0xFF4F46E5),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  '评价',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message.feedback ?? '',
                  style: const TextStyle(
                    color: Color(0xFF4B5563),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  '建议',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message.suggestion ?? '',
                  style: const TextStyle(
                    color: Color(0xFF4B5563),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              '未能加载面试内容',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '你可以重试一次，或稍后返回面试历史继续。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('重新加载'),
            ),
          ],
        ),
      ),
    );
  }
}
