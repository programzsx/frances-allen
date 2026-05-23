import 'package:flutter/material.dart';
import 'qa_page.dart';
import 'image_manage_page.dart';
import '../services/global_filter.dart';
import '../theme/app_theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  static final List<Widget> _pages = [
    const QaPage(),
    const ImageManagePage(),
  ];
  static const List<String> _tabLabels = ['考试', '图片'];
  static const List<IconData> _tabIcons = [
    Icons.quiz_outlined,
    Icons.image_outlined,
  ];
  static const List<IconData> _tabSelectedIcons = [
    Icons.quiz,
    Icons.image,
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
    // When drill-down filter is triggered from BankPage/TagPage,
    // switch to exam tab
    setState(() => _currentIndex = 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
    );
  }
}
