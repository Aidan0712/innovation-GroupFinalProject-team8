class AppConstants {
  static const String appName = 'AI面试助手';
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'user';

  static const List<String> homeTips = <String>[
    '提前了解目标岗位的技术要求。',
    '准备常见问题的结构化回答。',
    '回答尽量简洁，突出重点和结果。',
    '控制每题时长在 1 到 3 分钟更合适。',
  ];

  static const Map<String, String> interviewTypeLabels = <String, String>{
    'technical': '技术面试',
    'behavioral': '行为面试',
    'comprehensive': '综合面试',
  };

  static const Map<String, String> difficultyLabels = <String, String>{
    'easy': '简单',
    'medium': '进阶',
    'hard': '困难',
  };

  static const Map<String, String> answerModeLabels = <String, String>{
    'text': '文字',
    'audio': '语音',
    'mixed': '混合',
  };
}
