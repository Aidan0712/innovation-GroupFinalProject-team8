import 'package:flutter/foundation.dart';

import '../../../core/services/interview_service.dart';
import '../../../core/services/recording_service.dart';
import '../models/interview_models.dart';

class InterviewProvider extends ChangeNotifier {
  final InterviewService _interviewService = InterviewService();
  final RecordingService _recordingService = RecordingService();

  bool _isLoading = false;
  bool _isSubmitting = false;
  List<InterviewSession> _recentSessions = const <InterviewSession>[];
  List<InterviewSession> _historySessions = const <InterviewSession>[];
  int _historyTotal = 0;
  int _historyPage = 1;
  final int _historyPageSize = 20;
  InterviewSessionDetail? _currentSession;
  InterviewReport? _currentReport;

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  List<InterviewSession> get recentSessions => _recentSessions;
  List<InterviewSession> get historySessions => _historySessions;
  int get historyTotal => _historyTotal;
  int get historyPage => _historyPage;
  int get historyPageSize => _historyPageSize;
  bool get hasMoreHistory => _historySessions.length < _historyTotal;
  InterviewSessionDetail? get currentSession => _currentSession;
  InterviewReport? get currentReport => _currentReport;

  int get completedInterviewCount =>
      _historySessions.where((session) => session.totalScore != null).length;

  double get averageScore {
    final completed = _historySessions
        .where((session) => session.totalScore != null)
        .map((session) => session.totalScore!)
        .toList();
    if (completed.isEmpty) {
      return 0;
    }
    final total = completed.fold<double>(0, (sum, value) => sum + value);
    return total / completed.length;
  }

  double get bestScore {
    final completed = _historySessions
        .where((session) => session.totalScore != null)
        .map((session) => session.totalScore!)
        .toList();
    if (completed.isEmpty) {
      return 0;
    }
    completed.sort();
    return completed.last;
  }

  Future<void> loadRecentSessions() async {
    _setLoading(true);
    try {
      final page = await _interviewService.fetchSessions(page: 1, pageSize: 5);
      _recentSessions = page.items;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadHistory({bool append = false}) async {
    _setLoading(true);
    try {
      final nextPage = append ? _historyPage + 1 : 1;
      final page = await _interviewService.fetchSessions(
        page: nextPage,
        pageSize: _historyPageSize,
      );
      _historyPage = nextPage;
      _historyTotal = page.total;
      if (append) {
        _historySessions = <InterviewSession>[
          ..._historySessions,
          ...page.items,
        ];
      } else {
        _historySessions = page.items;
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<InterviewSessionDetail> createAndStartSession({
    required String targetPosition,
    required String interviewType,
    required String difficulty,
    required int questionCount,
    required String answerMode,
    bool useProfile = false,
  }) async {
    _setSubmitting(true);
    try {
      final created = await _interviewService.createSession(
        targetPosition: targetPosition,
        interviewType: interviewType,
        difficulty: difficulty,
        questionCount: questionCount,
        answerMode: answerMode,
        useProfile: useProfile,
      );
      final detail = await _interviewService.startSession(created.id);
      _currentSession = detail;
      notifyListeners();
      return detail;
    } finally {
      _setSubmitting(false);
    }
  }

  Future<InterviewSessionDetail> ensureSessionLoaded(int sessionId) async {
    _setLoading(true);
    try {
      final session = await _interviewService.fetchSession(sessionId);
      if (session.status == 'pending') {
        _currentSession = await _interviewService.startSession(sessionId);
      } else {
        _currentSession = session;
      }
      notifyListeners();
      return _currentSession!;
    } finally {
      _setLoading(false);
    }
  }

  Future<InterviewSessionDetail> submitTextAnswer({
    required int sessionId,
    required String answerText,
    required int durationSeconds,
  }) async {
    _setSubmitting(true);
    try {
      _currentSession = await _interviewService.submitAnswer(
        sessionId: sessionId,
        answerText: answerText,
        answerDurationSeconds: durationSeconds,
      );
      notifyListeners();
      return _currentSession!;
    } finally {
      _setSubmitting(false);
    }
  }

  Future<InterviewSessionDetail> submitVoiceAnswer({
    required int sessionId,
    required String filePath,
    required int durationSeconds,
  }) async {
    _setSubmitting(true);
    try {
      final uploaded = await _recordingService.uploadAndWait(
        filePath: filePath,
        durationSeconds: durationSeconds,
      );
      _currentSession = await _interviewService.submitAnswer(
        sessionId: sessionId,
        answerText: uploaded.transcript.isNotEmpty ? uploaded.transcript : null,
        answerAudioUrl: uploaded.remoteAudioUrl,
        answerDurationSeconds: durationSeconds,
        recordingId: uploaded.recordingId,
      );
      notifyListeners();
      return _currentSession!;
    } finally {
      _setSubmitting(false);
    }
  }

  Future<InterviewReport> finishSession(int sessionId) async {
    _setSubmitting(true);
    try {
      _currentReport = await _interviewService.finishSession(sessionId);
      if (_currentSession != null && _currentSession!.id == sessionId) {
        _currentSession = await _interviewService.fetchSession(sessionId);
      }
      notifyListeners();
      return _currentReport!;
    } finally {
      _setSubmitting(false);
    }
  }

  Future<InterviewReport> loadReport(int sessionId) async {
    _setLoading(true);
    try {
      _currentReport = await _interviewService.fetchReport(sessionId);
      notifyListeners();
      return _currentReport!;
    } finally {
      _setLoading(false);
    }
  }

  void clearCurrent() {
    _currentSession = null;
    _currentReport = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setSubmitting(bool value) {
    _isSubmitting = value;
    notifyListeners();
  }
}
