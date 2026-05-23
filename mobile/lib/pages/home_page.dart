import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'qa_page.dart';
import 'tag_page.dart';
import 'bank_page.dart';
import 'practice_page.dart';
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

  static final List<Widget> _pages = [const ExamHomePage(), const ImageManagePage()];
  static const List<String> _tabLabels = ['考试', '图片'];
  static const List<IconData> _tabIcons = [Icons.quiz_outlined, Icons.image_outlined];
  static const List<IconData> _tabSelectedIcons = [Icons.quiz, Icons.image];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
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

/// 考试主页：顶部切换 题目/练习/题库/标签
class ExamHomePage extends StatefulWidget {
  const ExamHomePage({super.key});

  @override
  State<ExamHomePage> createState() => _ExamHomePageState();
}

class _ExamHomePageState extends State<ExamHomePage> with SingleTickerProviderStateMixin {
  int _switchIndex = 0;

  // Drill-down state
  String? _drillDownBankId;
  String? _drillDownTagId;
  String? _drillDownLabel;

  static const List<String> _tabs = ['题目', '练习', '题库', '标签'];
  static const List<IconData> _tabIcons = [
    Icons.edit_note_outlined,
    Icons.school_outlined,
    Icons.folder_outlined,
    Icons.label_outlined,
  ];

  final _qaPage = QaPage();
  final _practicePage = PracticePage();
  final _bankPage = BankPage();
  final _tagPage = TagPage();

  bool get _isDrillDown => _drillDownBankId != null || _drillDownTagId != null;

  @override
  void initState() {
    super.initState();
    GlobalQuestionFilter.notifier.addListener(_onFilterChanged);
  }

  @override
  void dispose() {
    GlobalQuestionFilter.notifier.removeListener(_onFilterChanged);
    super.dispose();
  }

  void _onFilterChanged() {
    final state = GlobalQuestionFilter.notifier.value;
    setState(() {
      _drillDownBankId = state.bankId;
      _drillDownTagId = state.tagId;
      if (state.bankId != null) {
        _drillDownLabel = null; // Will be resolved by QaPage
      } else if (state.tagId != null) {
        _drillDownLabel = null;
      } else {
        _drillDownLabel = null;
      }
    });
  }

  void _clearDrillDown() {
    GlobalQuestionFilter.clear();
  }

  Widget _buildContent() {
    // IndexedStack must always be in the tree to preserve child state.
    // When in drill-down mode, stack the QaPage on top of it instead
    // of removing the IndexedStack entirely.
    return Stack(
      children: [
        IndexedStack(
          index: _switchIndex,
          children: [_qaPage, _practicePage, _bankPage, _tagPage],
        ),
        if (_isDrillDown)
          Positioned.fill(
            child: QaPage(
              initialBankId: _drillDownBankId,
              initialTagId: _drillDownTagId,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              border: Border(bottom: BorderSide(color: AppTheme.border, width: 1)),
            ),
            child: SafeArea(
              bottom: false,
              child: _isDrillDown ? _buildDrillDownHeader() : _buildTabRow(),
            ),
          ),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildDrillDownHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        children: [
          GestureDetector(
            onTap: _clearDrillDown,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back_ios, size: 16.sp, color: AppTheme.primary),
                  SizedBox(width: 4.w),
                  Text(
                    '返回',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Text(
              _drillDownLabel ?? (_drillDownBankId != null ? '题库题目' : '标签题目'),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                fontFamily: 'Inter',
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(width: 80.w),
        ],
      ),
    );
  }

  Widget _buildTabRow() {
    return Padding(
      padding: EdgeInsets.only(top: 8),
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final selected = _switchIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _switchIndex = i),
              behavior: HitTestBehavior.opaque,
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 6.h),
                padding: EdgeInsets.symmetric(vertical: 10.h),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.indigo50 : Colors.transparent,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _tabIcons[i],
                      size: 18,
                      color: selected ? AppTheme.primary : AppTheme.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _tabs[i],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        color: selected ? AppTheme.primary : AppTheme.textSecondary,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

