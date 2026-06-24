import 'package:flutter/material.dart';

import '../../../features/interview/screens/interview_setup_tab.dart';
import '../../../features/profile/screens/profile_screen.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import 'home_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({
    super.key,
    this.initialIndex = 0,
  });

  final int initialIndex;

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(
        onOpenProfileTab: () {
          setState(() {
            _currentIndex = 2;
          });
        },
        onOpenInterviewTab: () {
          setState(() {
            _currentIndex = 1;
          });
        },
      ),
      const InterviewSetupTabScreen(showAppBar: false),
      const ProfileScreen(embedded: true),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
