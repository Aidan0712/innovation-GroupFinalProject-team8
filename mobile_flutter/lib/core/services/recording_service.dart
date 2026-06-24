import 'dart:async';
import 'dart:io';

import 'package:http_parser/http_parser.dart';

import '../../core/utils/formatters.dart';
import '../../features/interview/models/interview_models.dart';
import 'api_client.dart';

class RecordingService {
  final ApiClient _api = ApiClient.instance;

  Future<VoiceUploadResult> uploadAndWait({
    required String filePath,
    required int durationSeconds,
  }) async {
    if (!File(filePath).existsSync()) {
      throw ApiException('录音文件不存在');
    }

    final uploadResponse = await _api.postMultipartJson(
      '/api/v1/recording/upload',
      filePath: filePath,
      fieldName: 'file',
      contentType: _contentTypeForPath(filePath),
    );

    final uploadData = uploadResponse['data'] as Map<String, dynamic>;
    final recordingId = (uploadData['id'] as num?)?.toInt() ?? 0;
    if (recordingId <= 0) {
      throw ApiException('录音上传失败');
    }

    await _waitUntilCompleted(recordingId);

    final detailResponse = await _api.getJson('/api/v1/recording/$recordingId');
    final detail = detailResponse['data'] as Map<String, dynamic>;
    final audioUrl = AppFormatters.absoluteUrl(
      detail['file_url'] as String? ?? '',
    );

    String transcript = detail['transcript'] as String? ?? '';
    bool transcriptReady = transcript.isNotEmpty;

    try {
      final analysisResponse =
          await _api.getJson('/api/v1/recording/$recordingId/analysis');
      final analysis = analysisResponse['data'] as Map<String, dynamic>;
      transcript = analysis['transcript'] as String? ?? transcript;
      transcriptReady = transcript.isNotEmpty;
    } on ApiException {
      transcriptReady = transcript.isNotEmpty;
    }

    return VoiceUploadResult(
      localFilePath: filePath,
      remoteAudioUrl: audioUrl,
      durationSeconds: durationSeconds,
      recordingId: recordingId,
      transcript: transcript,
      transcriptReady: transcriptReady,
    );
  }

  Future<void> _waitUntilCompleted(int recordingId) async {
    final startedAt = DateTime.now();
    while (DateTime.now().difference(startedAt).inSeconds < 180) {
      final response =
          await _api.getJson('/api/v1/recording/$recordingId/status');
      final status = (response['data'] as Map<String, dynamic>)['status']
              as String? ??
          '';

      if (status == 'completed') {
        return;
      }
      if (status == 'failed') {
        throw ApiException('录音转写失败，请重试');
      }

      await Future<void>.delayed(const Duration(seconds: 2));
    }
    throw ApiException('录音转写超时，请尝试使用文字回答');
  }

  MediaType _contentTypeForPath(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    switch (extension) {
      case 'wav':
        return MediaType('audio', 'wav');
      case 'mp3':
        return MediaType('audio', 'mp3');
      case 'webm':
        return MediaType('audio', 'webm');
      case 'm4a':
      default:
        return MediaType('audio', 'm4a');
    }
  }
}
