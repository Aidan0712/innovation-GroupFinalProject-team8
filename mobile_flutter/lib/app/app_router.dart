import 'package:flutter/material.dart';

import '../features/auth/screens/register_screen.dart';
import '../features/home/screens/main_shell_screen.dart';
import '../features/interview/screens/interview_history_screen.dart';
import '../features/interview/screens/interview_report_screen.dart';
import '../features/interview/screens/interview_room_screen.dart';
import '../features/interview/screens/interview_setup_tab.dart';

class AppRouter {
  static const String shell = '/shell';
  static const String register = '/register';
  static const String interviewSetup = '/interview/setup';
  static const String interviewRoom = '/interview/room';
  static const String interviewReport = '/interview/report';
  static const String interviewHistory = '/interview/history';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case register:
        return MaterialPageRoute<void>(
          builder: (_) => const RegisterScreen(),
          settings: settings,
        );
      case shell:
        final args = settings.arguments as ShellRouteArgs?;
        return MaterialPageRoute<void>(
          builder: (_) => MainShellScreen(initialIndex: args?.initialIndex ?? 0),
          settings: settings,
        );
      case interviewSetup:
        final initialType = settings.arguments as String?;
        return MaterialPageRoute<void>(
          builder: (_) => InterviewSetupTabScreen(
            showAppBar: true,
            initialInterviewType: initialType,
          ),
          settings: settings,
        );
      case interviewRoom:
        final args = settings.arguments as InterviewRoomArgs;
        return MaterialPageRoute<void>(
          builder: (_) => InterviewRoomScreen(sessionId: args.sessionId),
          settings: settings,
        );
      case interviewReport:
        final args = settings.arguments as InterviewReportArgs;
        return MaterialPageRoute<void>(
          builder: (_) => InterviewReportScreen(sessionId: args.sessionId),
          settings: settings,
        );
      case interviewHistory:
        return MaterialPageRoute<void>(
          builder: (_) => const InterviewHistoryScreen(),
          settings: settings,
        );
      default:
        return MaterialPageRoute<void>(
          builder: (_) => const MainShellScreen(),
          settings: settings,
        );
    }
  }

  static void openShell(BuildContext context, {int index = 0}) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => MainShellScreen(initialIndex: index),
      ),
      (_) => false,
    );
  }
}

class ShellRouteArgs {
  const ShellRouteArgs({this.initialIndex = 0});

  final int initialIndex;
}

class InterviewRoomArgs {
  const InterviewRoomArgs({required this.sessionId});

  final int sessionId;
}

class InterviewReportArgs {
  const InterviewReportArgs({required this.sessionId});

  final int sessionId;
}
