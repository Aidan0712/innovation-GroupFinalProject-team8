class InterviewSession {
  const InterviewSession({
    required this.id,
    required this.userId,
    required this.title,
    required this.targetPosition,
    required this.interviewType,
    required this.difficulty,
    required this.questionCount,
    required this.answerMode,
    required this.status,
    required this.createdAt,
    this.conversationId,
    this.totalScore,
    this.report,
    this.startedAt,
    this.endedAt,
  });

  final int id;
  final int userId;
  final int? conversationId;
  final String title;
  final String targetPosition;
  final String interviewType;
  final String difficulty;
  final int questionCount;
  final String answerMode;
  final String status;
  final double? totalScore;
  final Map<String, dynamic>? report;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime createdAt;

  factory InterviewSession.fromJson(Map<String, dynamic> json) {
    return InterviewSession(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      conversationId: (json['conversation_id'] as num?)?.toInt(),
      title: json['title'] as String? ?? '',
      targetPosition: json['target_position'] as String? ?? '',
      interviewType: json['interview_type'] as String? ?? 'technical',
      difficulty: json['difficulty'] as String? ?? 'medium',
      questionCount: (json['question_count'] as num?)?.toInt() ?? 0,
      answerMode: json['answer_mode'] as String? ?? 'text',
      status: json['status'] as String? ?? 'pending',
      totalScore: (json['total_score'] as num?)?.toDouble(),
      report: json['report'] as Map<String, dynamic>?,
      startedAt: _parseDate(json['started_at']),
      endedAt: _parseDate(json['ended_at']),
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
    );
  }

  InterviewSession copyWith({
    double? totalScore,
    String? status,
  }) {
    return InterviewSession(
      id: id,
      userId: userId,
      conversationId: conversationId,
      title: title,
      targetPosition: targetPosition,
      interviewType: interviewType,
      difficulty: difficulty,
      questionCount: questionCount,
      answerMode: answerMode,
      status: status ?? this.status,
      totalScore: totalScore ?? this.totalScore,
      report: report,
      startedAt: startedAt,
      endedAt: endedAt,
      createdAt: createdAt,
    );
  }
}

class InterviewTurn {
  const InterviewTurn({
    required this.id,
    required this.sessionId,
    required this.questionIndex,
    required this.question,
    required this.createdAt,
    this.answerText,
    this.answerAudioUrl,
    this.answerDurationSeconds,
    this.score,
    this.feedback,
    this.suggestion,
    this.answeredAt,
  });

  final int id;
  final int sessionId;
  final int questionIndex;
  final String question;
  final String? answerText;
  final String? answerAudioUrl;
  final int? answerDurationSeconds;
  final double? score;
  final String? feedback;
  final String? suggestion;
  final DateTime createdAt;
  final DateTime? answeredAt;

  bool get isAnswered => answeredAt != null;

  factory InterviewTurn.fromJson(Map<String, dynamic> json) {
    return InterviewTurn(
      id: (json['id'] as num?)?.toInt() ?? 0,
      sessionId: (json['session_id'] as num?)?.toInt() ?? 0,
      questionIndex: (json['question_index'] as num?)?.toInt() ?? 0,
      question: json['question'] as String? ?? '',
      answerText: json['answer_text'] as String?,
      answerAudioUrl: json['answer_audio_url'] as String?,
      answerDurationSeconds: (json['answer_duration_seconds'] as num?)?.toInt(),
      score: (json['score'] as num?)?.toDouble(),
      feedback: json['feedback'] as String?,
      suggestion: json['suggestion'] as String?,
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      answeredAt: _parseDate(json['answered_at']),
    );
  }
}

class InterviewSessionDetail extends InterviewSession {
  const InterviewSessionDetail({
    required super.id,
    required super.userId,
    required super.title,
    required super.targetPosition,
    required super.interviewType,
    required super.difficulty,
    required super.questionCount,
    required super.answerMode,
    required super.status,
    required super.createdAt,
    required this.turns,
    super.conversationId,
    super.totalScore,
    super.report,
    super.startedAt,
    super.endedAt,
  });

  final List<InterviewTurn> turns;

  List<InterviewTurn> get answeredTurns =>
      turns.where((turn) => turn.isAnswered).toList();

  InterviewTurn? get currentTurn {
    for (final turn in turns) {
      if (!turn.isAnswered) {
        return turn;
      }
    }
    return turns.isNotEmpty ? turns.last : null;
  }

  factory InterviewSessionDetail.fromJson(Map<String, dynamic> json) {
    return InterviewSessionDetail(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      conversationId: (json['conversation_id'] as num?)?.toInt(),
      title: json['title'] as String? ?? '',
      targetPosition: json['target_position'] as String? ?? '',
      interviewType: json['interview_type'] as String? ?? 'technical',
      difficulty: json['difficulty'] as String? ?? 'medium',
      questionCount: (json['question_count'] as num?)?.toInt() ?? 0,
      answerMode: json['answer_mode'] as String? ?? 'text',
      status: json['status'] as String? ?? 'pending',
      totalScore: (json['total_score'] as num?)?.toDouble(),
      report: json['report'] as Map<String, dynamic>?,
      startedAt: _parseDate(json['started_at']),
      endedAt: _parseDate(json['ended_at']),
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      turns: ((json['turns'] as List<dynamic>?) ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(InterviewTurn.fromJson)
          .toList()
        ..sort((left, right) => left.questionIndex.compareTo(right.questionIndex)),
    );
  }
}

class InterviewTurnPerformance {
  const InterviewTurnPerformance({
    required this.questionIndex,
    required this.question,
    required this.score,
    required this.feedback,
    required this.suggestion,
    this.answer,
    this.answerDurationSeconds,
    this.dimensions = const <String, double>{},
    this.evidence = const <String>[],
    this.missingPoints = const <String>[],
  });

  final int questionIndex;
  final String question;
  final String? answer;
  final int? answerDurationSeconds;
  final double score;
  final Map<String, double> dimensions;
  final List<String> evidence;
  final List<String> missingPoints;
  final String feedback;
  final String suggestion;

  factory InterviewTurnPerformance.fromJson(Map<String, dynamic> json) {
    return InterviewTurnPerformance(
      questionIndex: (json['question_index'] as num?)?.toInt() ?? 0,
      question: json['question'] as String? ?? '',
      answer: json['answer'] as String?,
      answerDurationSeconds: (json['answer_duration_seconds'] as num?)?.toInt(),
      score: (json['score'] as num?)?.toDouble() ?? 0,
      dimensions: _toDoubleMap(json['dimensions']),
      evidence: ((json['evidence'] as List<dynamic>?) ?? <dynamic>[])
          .map((item) => item.toString())
          .toList(),
      missingPoints: ((json['missing_points'] as List<dynamic>?) ?? <dynamic>[])
          .map((item) => item.toString())
          .toList(),
      feedback: json['feedback'] as String? ?? '',
      suggestion: json['suggestion'] as String? ?? '',
    );
  }
}

class InterviewReport {
  const InterviewReport({
    required this.sessionId,
    required this.totalScore,
    required this.status,
    required this.summary,
    required this.generatedAt,
    this.scoreBasis,
    this.dimensionScores = const <String, double>{},
    this.turnPerformance = const <InterviewTurnPerformance>[],
    this.strengths = const <String>[],
    this.weaknesses = const <String>[],
    this.suggestions = const <String>[],
    this.actionPlan = const <String>[],
  });

  final int sessionId;
  final double totalScore;
  final String status;
  final String summary;
  final String? scoreBasis;
  final Map<String, double> dimensionScores;
  final List<InterviewTurnPerformance> turnPerformance;
  final List<String> strengths;
  final List<String> weaknesses;
  final List<String> suggestions;
  final List<String> actionPlan;
  final DateTime generatedAt;

  factory InterviewReport.fromJson(Map<String, dynamic> json) {
    return InterviewReport(
      sessionId: (json['session_id'] as num?)?.toInt() ?? 0,
      totalScore: (json['total_score'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      scoreBasis: json['score_basis'] as String?,
      dimensionScores: _toDoubleMap(json['dimension_scores']),
      turnPerformance:
          ((json['turn_performance'] as List<dynamic>?) ?? <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(InterviewTurnPerformance.fromJson)
              .toList(),
      strengths: ((json['strengths'] as List<dynamic>?) ?? <dynamic>[])
          .map((item) => item.toString())
          .toList(),
      weaknesses: ((json['weaknesses'] as List<dynamic>?) ?? <dynamic>[])
          .map((item) => item.toString())
          .toList(),
      suggestions: ((json['suggestions'] as List<dynamic>?) ?? <dynamic>[])
          .map((item) => item.toString())
          .toList(),
      actionPlan: ((json['action_plan'] as List<dynamic>?) ?? <dynamic>[])
          .map((item) => item.toString())
          .toList(),
      generatedAt: _parseDate(json['generated_at']) ?? DateTime.now(),
    );
  }
}

class SessionPage {
  const SessionPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<InterviewSession> items;
  final int total;
  final int page;
  final int pageSize;
}

class VoiceUploadResult {
  const VoiceUploadResult({
    required this.localFilePath,
    required this.remoteAudioUrl,
    required this.durationSeconds,
    required this.recordingId,
    required this.transcript,
    required this.transcriptReady,
  });

  final String localFilePath;
  final String remoteAudioUrl;
  final int durationSeconds;
  final int recordingId;
  final String transcript;
  final bool transcriptReady;
}

DateTime? _parseDate(Object? value) {
  if (value == null) {
    return null;
  }
  return DateTime.tryParse(value.toString());
}

Map<String, double> _toDoubleMap(Object? value) {
  if (value is! Map) {
    return const <String, double>{};
  }

  final result = <String, double>{};
  value.forEach((key, entry) {
    if (entry is num) {
      result[key.toString()] = entry.toDouble();
    }
  });
  return result;
}
