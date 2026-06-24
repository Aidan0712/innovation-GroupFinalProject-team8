import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

class AppFormatters {
  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) {
      return '刚刚';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} 分钟前';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} 小时前';
    }
    return '${dateTime.month}/${dateTime.day}';
  }

  static String formatDateTime(DateTime dateTime) {
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }

  static String formatDuration(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  static String formatInterviewType(String value) {
    return AppConstants.interviewTypeLabels[value] ?? value;
  }

  static String formatDifficulty(String value) {
    return AppConstants.difficultyLabels[value] ?? value;
  }

  static String formatAnswerMode(String value) {
    return AppConstants.answerModeLabels[value] ?? value;
  }

  static String scoreLevelText(double score) {
    if (score >= 90) {
      return '优秀';
    }
    if (score >= 80) {
      return '良好';
    }
    if (score >= 60) {
      return '及格';
    }
    return '需努力';
  }

  static Color scoreLevelColor(double score) {
    if (score >= 90) {
      return const Color(0xFF22C55E);
    }
    if (score >= 80) {
      return const Color(0xFF3B82F6);
    }
    if (score >= 60) {
      return const Color(0xFFF59E0B);
    }
    return const Color(0xFFEF4444);
  }

  static String dimensionLabel(String key) {
    const labels = <String, String>{
      '岗位相关性': '岗位相关性',
      '技术深度': '技术深度',
      '逻辑结构': '逻辑结构',
      '案例与结果': '案例与结果',
      '表达沟通': '表达沟通',
      '时间控制': '时间控制',
      'relevance': '岗位相关性',
      'technical_depth': '技术深度',
      'logic': '逻辑结构',
      'cases': '案例与结果',
      'communication': '表达沟通',
      'time_control': '时间控制',
    };
    return labels[key] ?? key;
  }

  static String absoluteUrl(String value) {
    if (value.isEmpty) {
      return value;
    }
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('/')) {
      return '${AppConstants.apiBaseUrl}$value';
    }
    return '${AppConstants.apiBaseUrl}/$value';
  }
}
