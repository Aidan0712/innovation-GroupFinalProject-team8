import '../../features/interview/models/interview_models.dart';
import 'api_client.dart';

class InterviewService {
  final ApiClient _api = ApiClient.instance;

  Future<InterviewSession> createSession({
    required String targetPosition,
    required String interviewType,
    required String difficulty,
    required int questionCount,
    required String answerMode,
    bool useProfile = false,
  }) async {
    final response = await _api.postJson(
      '/api/v1/interview/sessions',
      body: <String, dynamic>{
        'target_position': targetPosition,
        'interview_type': interviewType,
        'difficulty': difficulty,
        'question_count': questionCount,
        'answer_mode': answerMode,
        'use_profile': useProfile,
      },
    );
    return InterviewSession.fromJson(
      response['data'] as Map<String, dynamic>,
    );
  }

  Future<InterviewSessionDetail> startSession(int sessionId) async {
    final response = await _api.postJson('/api/v1/interview/sessions/$sessionId/start');
    return InterviewSessionDetail.fromJson(
      response['data'] as Map<String, dynamic>,
    );
  }

  Future<InterviewSessionDetail> fetchSession(int sessionId) async {
    final response = await _api.getJson('/api/v1/interview/sessions/$sessionId');
    return InterviewSessionDetail.fromJson(
      response['data'] as Map<String, dynamic>,
    );
  }

  Future<InterviewSessionDetail> submitAnswer({
    required int sessionId,
    String? answerText,
    String? answerAudioUrl,
    int? answerDurationSeconds,
    int? recordingId,
  }) async {
    final body = <String, dynamic>{};
    if (answerText != null && answerText.trim().isNotEmpty) {
      body['answer_text'] = answerText.trim();
    }
    if (answerAudioUrl != null && answerAudioUrl.isNotEmpty) {
      body['answer_audio_url'] = answerAudioUrl;
    }
    if (answerDurationSeconds != null) {
      body['answer_duration_seconds'] = answerDurationSeconds;
    }
    if (recordingId != null) {
      body['recording_id'] = recordingId;
    }

    final response = await _api.postJson(
      '/api/v1/interview/sessions/$sessionId/answer',
      body: body,
    );
    return InterviewSessionDetail.fromJson(
      response['data'] as Map<String, dynamic>,
    );
  }

  Future<InterviewReport> finishSession(int sessionId) async {
    final response = await _api.postJson('/api/v1/interview/sessions/$sessionId/finish');
    return InterviewReport.fromJson(
      response['data'] as Map<String, dynamic>,
    );
  }

  Future<InterviewReport> fetchReport(int sessionId) async {
    final response = await _api.getJson('/api/v1/interview/sessions/$sessionId/report');
    return InterviewReport.fromJson(
      response['data'] as Map<String, dynamic>,
    );
  }

  Future<SessionPage> fetchSessions({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _api.getJson(
      '/api/v1/interview/sessions?page=$page&page_size=$pageSize',
    );
    final payload = response['data'] as Map<String, dynamic>;
    final items = ((payload['data'] as List<dynamic>?) ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(InterviewSession.fromJson)
        .toList();

    return SessionPage(
      items: items,
      total: (payload['total'] as num?)?.toInt() ?? items.length,
      page: (payload['page'] as num?)?.toInt() ?? page,
      pageSize: (payload['page_size'] as num?)?.toInt() ?? pageSize,
    );
  }
}
