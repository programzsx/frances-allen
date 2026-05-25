import 'package:flutter/material.dart';
import 'practice_page.dart';
import 'qa_page.dart';
import '../services/global_filter.dart';
import '../theme/app_theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  bool _canPop = false;

  static final List<Widget> _pages = [
    const PracticePage(),
    const QaPage(),
  ];
  static const List<String> _tabLabels = ['练习', '考试'];
  static const List<IconData> _tabIcons = [
    Icons.school_outlined,
    Icons.quiz_outlined,
  ];
  static const List<IconData> _tabSelectedIcons = [
    Icons.school,
    Icons.quiz,
  ];

  @override
  void initState() {
    super.initState();
    GlobalQuestionFilter.notifier.addListener(_onFilter);
  }

  @override
  void dispose() {
    GlobalQuestionFilter.notifier.removeListener(_onFilter);
    super.dispose();
  }

  void _onFilter() {
    setState(() => _currentIndex = 1);
  }

  Future<bool> _onWillPop() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('确定要退出APP吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认',
                style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    return shouldExit ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _onWillPop();
        if (shouldExit && mounted) {
          setState(() => _canPop = true);
          // 下一帧 PopScope 的 canPop 变为 true，系统 back 会自然退出
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) =>
              setState(() => _currentIndex = index),
          height: 68,
          destinations: List.generate(
            _tabLabels.length,
            (i) => NavigationDestination(
              icon: Icon(_tabIcons[i]),
              selectedIcon: Icon(_tabSelectedIcons[i]),
              label: _tabLabels[i],
            ),
          ),
        ),
      ),
    );
  }
}
