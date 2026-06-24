import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/auth/screens/login_screen.dart';
import '../../../features/interview/providers/interview_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.embedded = false,
  });

  final bool embedded;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<InterviewProvider>();
      if (provider.historySessions.isEmpty) {
        provider.loadHistory();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final interview = context.watch<InterviewProvider>();

    final content = SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[
                  Color(0xFF6366F1),
                  Color(0xFF8B5CF6),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              children: <Widget>[
                const CircleAvatar(
                  radius: 42,
                  backgroundColor: Colors.white,
                  child: Text('👤', style: TextStyle(fontSize: 32)),
                ),
                const SizedBox(height: 12),
                Text(
                  auth.user?.username ?? '用户',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  auth.user?.email ?? '',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Row(
                children: <Widget>[
                  _StatBlock(
                    title: '面试次数',
                    value: '${interview.historySessions.length}',
                  ),
                  _buildDivider(),
                  _StatBlock(
                    title: '平均分',
                    value: interview.averageScore == 0
                        ? '0'
                        : interview.averageScore.round().toString(),
                  ),
                  _buildDivider(),
                  _StatBlock(
                    title: '最高分',
                    value: interview.bestScore == 0
                        ? '0'
                        : interview.bestScore.round().toString(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _MenuTile(
            icon: '🗂️',
            title: '面试历史',
            onTap: () {
              Navigator.of(context).pushNamed(AppRouter.interviewHistory);
            },
          ),
          _MenuTile(
            icon: '⚙️',
            title: '设置',
            onTap: () {
              _showSnack('功能开发中');
            },
          ),
          _MenuTile(
            icon: '❓',
            title: '帮助与反馈',
            onTap: () {
              _showSnack('功能开发中');
            },
          ),
          _MenuTile(
            icon: 'ℹ️',
            title: '关于我们',
            onTap: _showAbout,
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: _handleLogout,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
              side: const BorderSide(color: Color(0xFFEF4444)),
              minimumSize: const Size.fromHeight(54),
            ),
            child: const Text('退出登录'),
          ),
        ],
      ),
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('个人中心')),
      body: content,
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 50,
      color: const Color(0xFFE5E7EB),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _handleLogout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _showAbout() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('关于 AI 面试助手'),
          content: const Text(
            '版本 1.0.0\n\nAI 面试助手是一款面向求职练习场景的智能模拟面试工具，帮助用户练习答题、获取反馈并沉淀个人复盘报告。',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        );
      },
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF6366F1),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final String icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        leading: Text(icon, style: const TextStyle(fontSize: 24)),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
