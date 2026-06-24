import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/interview/providers/interview_provider.dart';
import '../features/home/screens/main_shell_screen.dart';
import 'app_router.dart';

class AiInterviewApp extends StatelessWidget {
  const AiInterviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider()..restoreSession(),
        ),
        ChangeNotifierProvider<InterviewProvider>(
          create: (_) => InterviewProvider(),
        ),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'AI面试助手',
            theme: AppTheme.light(),
            onGenerateRoute: AppRouter.onGenerateRoute,
            home: !auth.isReady
                ? const _AppSplashScreen()
                : auth.isAuthenticated
                    ? const MainShellScreen()
                    : const LoginScreen(),
          );
        },
      ),
    );
  }
}

class _AppSplashScreen extends StatelessWidget {
  const _AppSplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
