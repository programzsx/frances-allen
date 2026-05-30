import 'package:flutter/material.dart';
import 'qa_page.dart';
import 'tag_page.dart';
import 'bank_page.dart';
import 'practice_page.dart';
import 'image_manage_page.dart';
import '../theme/desktop_theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  static const List<String> _tabLabels = ['考试', '图片'];
  static const List<IconData> _tabIcons = [Icons.quiz_outlined, Icons.image_outlined];
  static const List<IconData> _tabSelectedIcons = [Icons.quiz, Icons.image];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) => setState(() => _currentIndex = index),
            extended: MediaQuery.of(context).size.width > 800,
            destinations: List.generate(
              _tabLabels.length,
              (i) => NavigationRailDestination(
                icon: Icon(_tabIcons[i]),
                selectedIcon: Icon(_tabSelectedIcons[i]),
                label: Text(_tabLabels[i]),
              ),
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: const [ExamHomePage(), ImageManagePage()],
            ),
          ),
        ],
      ),
    );
  }
}

/// 考试主页：顶部切换 题目/练习/题库/标签
class ExamHomePage extends StatefulWidget {
  const ExamHomePage({super.key});

  @override
  State<ExamHomePage> createState() => _ExamHomePageState();
}

class _ExamHomePageState extends State<ExamHomePage> with SingleTickerProviderStateMixin {
  int _switchIndex = 0;
  bool _practiceStarted = false;

  static const List<String> _tabs = ['题目', '练习', '题库', '标签'];
  static const List<IconData> _tabIcons = [
    Icons.edit_note_outlined,
    Icons.school_outlined,
    Icons.folder_outlined,
    Icons.label_outlined,
  ];

  final _qaPage = const QaPage();
  final _bankPage = const BankPage();
  final _tagPage = const TagPage();
  late final _practicePage = PracticePage(onStartedChanged: (v) => setState(() => _practiceStarted = v));

  Widget _buildContent() {
    switch (_switchIndex) {
      case 0: return _qaPage;
      case 1: return _practicePage;
      case 2: return _bankPage;
      case 3: return _tagPage;
      default: return Container();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isQuizPage = _switchIndex == 1 && _practiceStarted;
    return Scaffold(
      body: Column(
        children: [
          Offstage(
            offstage: isQuizPage,
            child: Container(
              padding: const EdgeInsets.only(left: 24, right: 24, top: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: DesktopTheme.border)),
              ),
              child: Row(
                children: List.generate(_tabs.length, (i) {
                  final selected = _switchIndex == i;
                  return GestureDetector(
                    onTap: () => setState(() => _switchIndex = i),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: selected ? DesktopTheme.indigo50 : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _tabIcons[i],
                            size: 16,
                            color: selected ? DesktopTheme.primary : DesktopTheme.textTertiary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _tabs[i],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                              color: selected ? DesktopTheme.primary : DesktopTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }
}
