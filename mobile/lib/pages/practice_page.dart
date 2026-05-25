import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'question_rich_text.dart';
import '../theme/app_theme.dart';

enum PracticeMode { random, sequential, wrong }

class PracticePage extends StatefulWidget {
  const PracticePage({super.key});

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  // Setup state
  KbBank? _selectedBank;
  PracticeMode _mode = PracticeMode.random;
  int _minScore = 0;
  bool _loading = false;
  int _bankTotal = 0; // 选中题库的后代总题数（0=未选/全库）

  // Bank drill-down state
  List<Map<String, dynamic>> _bankTreeRaw = []; // tree from API
  Map<String, Map<String, dynamic>> _bankNodeMap = {}; // id → node
  Map<String, int> _descendantCounts = {};
  List<_NavStep> _drillPath = [];
  bool _treeLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBankTree();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadBankTree() async {
    try {
      final results = await Future.wait([
        ApiService.getBankTree(),
        ApiService.getDescendantCounts(),
      ]);
      final tree = results[0] as List<dynamic>;
      final counts = results[1] as Map<String, int>;

      final nodeMap = <String, Map<String, dynamic>>{};
      _buildNodeMap(tree.cast<Map<String, dynamic>>(), nodeMap);

      if (mounted) {
        setState(() {
          _bankTreeRaw = tree.cast<Map<String, dynamic>>();
          _bankNodeMap = nodeMap;
          _descendantCounts = counts;
          _treeLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _treeLoading = false);
    }
  }

  void _buildNodeMap(List<Map<String, dynamic>> nodes, Map<String, Map<String, dynamic>> map) {
    for (final node in nodes) {
      map[node['id'] as String] = node;
      final children = node['children'] as List<dynamic>?;
      if (children != null) _buildNodeMap(children.cast<Map<String, dynamic>>(), map);
    }
  }

  /// 当前展示的题库列表（根或某层的 children）
  List<Map<String, dynamic>> get _currentBanks {
    if (_drillPath.isEmpty) return _bankTreeRaw;
    final node = _bankNodeMap[_drillPath.last.id];
    if (node == null) return [];
    final children = node['children'] as List<dynamic>?;
    return children?.cast<Map<String, dynamic>>() ?? [];
  }

  /// 下钻到子题库
  void _drillInto(String bankId) {
    final node = _bankNodeMap[bankId];
    if (node == null) return;
    setState(() {
      _drillPath.add(_NavStep(id: bankId, name: node['name'] as String));
    });
  }

  /// 面包屑回退到某个位置
  void _drillBackTo(int index) {
    setState(() {
      _drillPath = _drillPath.sublist(0, index + 1);
    });
  }

  /// 回退到根
  void _drillBackToRoot() {
    setState(() {
      _drillPath.clear();
    });
  }

  /// 选中当前层级题库作为练习目标
  void _selectCurrentLevelBank() {
    if (_drillPath.isEmpty) return;
    final node = _bankNodeMap[_drillPath.last.id];
    if (node == null) return;
    _selectBankById(_drillPath.last.id, node['name'] as String);
  }

  void _selectBankById(String bankId, String bankName) {
    setState(() {
      _selectedBank = KbBank(
        id: bankId,
        createTime: '',
        updateTime: '',
        name: bankName,
      );
    });
    _bankTotal = _descendantCounts[bankId] ?? 0;
  }

  void _clearSelection() {
    setState(() {
      _selectedBank = null;
      _bankTotal = 0;
    });
  }

  /// 收集节点自身及所有后代ID
  List<String> _collectDescendantIds(Map<String, dynamic> node) {
    final ids = <String>[node['id'] as String];
    final children = node['children'] as List<dynamic>?;
    if (children != null) {
      for (final child in children) {
        ids.addAll(_collectDescendantIds(child as Map<String, dynamic>));
      }
    }
    return ids;
  }

  Future<void> _startPractice() async {
    setState(() => _loading = true);
    try {
      List<KbQa> qas;

      if (_selectedBank != null) {
        // 选中题库 → 获取该题库及其后代的所有题目
        final node = _bankNodeMap[_selectedBank!.id];
        final categoryIds = node != null ? _collectDescendantIds(node) : <String>[_selectedBank!.id];
        final allData = await ApiService.getAllQasForBank();
        qas = allData
            .map((e) => KbQa.fromJson(e))
            .where((q) => categoryIds.contains(q.categoryId))
            .toList();
      } else {
        // 未选题库 → 全库所有题目
        final allData = await ApiService.getAllQasForBank();
        qas = allData.map((e) => KbQa.fromJson(e)).toList();
      }

      // 根据模式处理
      switch (_mode) {
        case PracticeMode.random:
          qas.shuffle(Random());
          break;
        case PracticeMode.sequential:
          // 保持原顺序
          break;
        case PracticeMode.wrong:
          // 错题模式：从已获取的题目中按 wrong 次数筛选
          qas = qas.where((q) => q.wrong > _minScore).toList();
          break;
      }

      if (qas.isEmpty) {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('没有找到符合条件的题目')));
        }
        return;
      }

      setState(() => _loading = false);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PracticeQuizPage(
              questions: qas,
              bank: _selectedBank,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
            padding: EdgeInsets.all(20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    padding: EdgeInsets.all(24.w),
                    decoration: BoxDecoration(
                      color: AppTheme.indigo50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.school_outlined, size: 40.sp, color: AppTheme.primary),
                  ),
                ),
                SizedBox(height: 16.h),
                Center(
                  child: Text('开始练习', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w600, fontFamily: 'Inter', color: AppTheme.textPrimary)),
                ),
                SizedBox(height: 8.h),
                Center(
                  child: Text('逐层选择题库', style: TextStyle(fontSize: 12.sp, color: AppTheme.textTertiary)),
                ),
                SizedBox(height: 28.h),

                Text('选择题库', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp, fontFamily: 'Inter', color: AppTheme.textPrimary)),
                SizedBox(height: 8.h),
                _buildBankDrilldown(),
                SizedBox(height: 24.h),

                Text('练习模式', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp, fontFamily: 'Inter', color: AppTheme.textPrimary)),
                SizedBox(height: 8.h),
                _buildModeSelector(),
                if (_mode == PracticeMode.wrong) ...[
                  SizedBox(height: 16.h),
                  _buildWrongThresholdControl(),
                ],
                SizedBox(height: 32.h),

                SizedBox(
                  width: double.infinity,
                  height: 52.h,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _startPractice,
                    icon: _loading
                        ? SizedBox(width: 20.w, height: 20.w, child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.play_arrow, color: Colors.white),
                    label: Text(
                      _loading
                          ? '加载中...'
                          : _selectedBank != null
                              ? '开始练习 ($_bankTotal 题)'
                              : '开始练习（全部题库）',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter'),
                    ),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }

  Widget _buildBankDrilldown() {
    if (_treeLoading) {
      return Container(
        padding: EdgeInsets.all(24.h),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final currentBanks = _currentBanks;
    final hasSelected = _selectedBank != null;

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: hasSelected ? AppTheme.primary : AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 面包屑导航
          _buildBreadcrumb(),

          // 空状态
          if (currentBanks.isEmpty && _drillPath.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Center(
                child: Text('暂无题库，请先创建', style: TextStyle(color: AppTheme.textTertiary, fontSize: 13.sp)),
              ),
            ),

          // 银行网格
          if (currentBanks.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: currentBanks.map((bank) => _buildBankChip(bank)).toList(),
            ),
          ],

          // 选中当前层级题库的提示
          if (_drillPath.isNotEmpty && (_selectedBank == null || _selectedBank!.id != _drillPath.last.id)) ...[
            SizedBox(height: 12.h),
            GestureDetector(
              onTap: _selectCurrentLevelBank,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: AppTheme.indigo50,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: AppTheme.indigo100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline, size: 16.sp, color: AppTheme.primary),
                    SizedBox(width: 6.w),
                    Text(
                      '选择「${_drillPath.last.name}」',
                      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: AppTheme.primary, fontFamily: 'Inter'),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // 已选中的题库信息
          if (hasSelected) ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: AppTheme.indigo50,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: AppTheme.indigo100),
              ),
              child: Row(
                children: [
                  Icon(Icons.folder, size: 16.sp, color: AppTheme.primary),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      _selectedBank!.name,
                      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: AppTheme.textPrimary, fontFamily: 'Inter'),
                    ),
                  ),
                  if (_bankTotal > 0)
                    Text('$_bankTotal 题', style: TextStyle(fontSize: 12.sp, color: AppTheme.textTertiary)),
                  SizedBox(width: 4.w),
                  GestureDetector(
                    onTap: _clearSelection,
                    child: Icon(Icons.close, size: 16.sp, color: AppTheme.textTertiary),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 面包屑
  Widget _buildBreadcrumb() {
    if (_drillPath.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 4.w,
      runSpacing: 4.h,
      children: [
        _breadcrumbChip('全部', onTap: _drillBackToRoot),
        for (int i = 0; i < _drillPath.length; i++) ...[
          Icon(Icons.chevron_right, size: 16.sp, color: AppTheme.textTertiary),
          _breadcrumbChip(
            _drillPath[i].name,
            isLast: i == _drillPath.length - 1,
            onTap: () => _drillBackTo(i),
          ),
        ],
      ],
    );
  }

  Widget _breadcrumbChip(String label, {bool isLast = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: isLast ? AppTheme.primary : AppTheme.bgSection,
          borderRadius: BorderRadius.circular(6.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: isLast ? Colors.white : AppTheme.textSecondary,
            fontWeight: isLast ? FontWeight.w600 : FontWeight.normal,
            fontFamily: 'Inter',
          ),
        ),
      ),
    );
  }

  /// 单个题库卡片
  Widget _buildBankChip(Map<String, dynamic> bank) {
    final id = bank['id'] as String;
    final name = bank['name'] as String;
    final hasChildren = (bank['children'] as List<dynamic>?)?.isNotEmpty ?? false;
    final isSelected = _selectedBank?.id == id;

    return GestureDetector(
      onTap: () {
        if (hasChildren) {
          _drillInto(id);
        } else {
          _selectBankById(id, name);
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: isSelected ? AppTheme.primary : (hasChildren ? AppTheme.indigo100 : AppTheme.border),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasChildren ? Icons.folder_outlined : Icons.description_outlined,
              size: 16.sp,
              color: isSelected ? Colors.white : (hasChildren ? AppTheme.primary : AppTheme.textTertiary),
            ),
            SizedBox(width: 6.w),
            Text(
              name,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : AppTheme.textPrimary,
                fontFamily: 'Inter',
              ),
            ),
            if (hasChildren) ...[
              SizedBox(width: 4.w),
              Icon(
                Icons.chevron_right,
                size: 16.sp,
                color: isSelected ? Colors.white70 : AppTheme.textTertiary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppTheme.bgSection,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: [
          _modeTab(PracticeMode.random, '随机', Icons.shuffle_outlined),
          _modeTab(PracticeMode.sequential, '顺序', Icons.format_list_numbered_outlined),
          _modeTab(PracticeMode.wrong, '错题', Icons.error_outline),
        ].expand((w) => [Expanded(child: w)]).toList(),
      ),
    );
  }

  Widget _modeTab(PracticeMode mode, String label, IconData icon) {
    final selected = _mode == mode;
    return GestureDetector(
      onTap: () => setState(() => _mode = mode),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14.h),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20.sp, color: selected ? Colors.white : AppTheme.textTertiary),
            SizedBox(height: 4.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? Colors.white : AppTheme.textSecondary,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWrongThresholdControl() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('最小错误次数', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.sp, color: AppTheme.textPrimary)),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppTheme.indigo50,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  '>= $_minScore',
                  style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 13.sp, fontFamily: 'Inter'),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Slider(
            value: _minScore.toDouble(),
            min: -1,
            max: 1,
            divisions: 2,
            label: '>= $_minScore',
            onChanged: (v) => setState(() => _minScore = v.toInt()),
          ),
          Text('筛选掌握程度 <= $_minScore 的题目 (-1=不会, 0=模糊, 1=掌握)', style: TextStyle(color: AppTheme.textTertiary, fontSize: 12.sp)),
        ],
      ),
    );
  }
}

class PracticeQuizPage extends StatefulWidget {
  final List<KbQa> questions;
  final KbBank? bank;
  const PracticeQuizPage({super.key, required this.questions, this.bank});

  @override
  State<PracticeQuizPage> createState() => _PracticeQuizPageState();
}

class _PracticeQuizPageState extends State<PracticeQuizPage> {
  List<KbQa> _questions = [];
  int _currentIndex = 0;
  List<bool> _revealed = [];
  List<List<TextEditingController>> _userAnswerCtrls = [];
  bool _showExitConfirm = false;

  Map<String, KbBank> _categoryMap = {};

  @override
  void initState() {
    super.initState();
    _questions = widget.questions;
    _revealed = List.filled(_questions.length, false);
    _userAnswerCtrls = List.generate(
      _questions.length,
      (i) => List.generate(_questions[i].answer.length, (_) => TextEditingController()),
    );
    if (widget.bank != null) {
      _categoryMap = {widget.bank!.id: widget.bank!};
    }
  }

  @override
  void dispose() {
    for (final ctrlList in _userAnswerCtrls) {
      for (final c in ctrlList) c.dispose();
    }
    super.dispose();
  }

  bool _checkAnswer(KbQa qa) {
    final userAnswers = _userAnswerCtrls[_currentIndex].map((c) => c.text.trim()).toList();
    if (userAnswers.length != qa.answer.length) return false;
    for (int i = 0; i < qa.answer.length; i++) {
      if (userAnswers[i] != qa.answer[i]) return false;
    }
    return true;
  }

  void _submitAnswer() async {
    final qa = _questions[_currentIndex];
    final isCorrect = _checkAnswer(qa);

    final newTotal = qa.total + 1;
    final newRight = qa.right + (isCorrect ? 1 : 0);
    final newWrong = qa.wrong + (isCorrect ? 0 : 1);

    try {
      await ApiService.updateQa(qa.id, {'total': newTotal, 'right': newRight, 'wrong': newWrong});
    } catch (e) {
      debugPrint('统计更新失败: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('统计更新失败: $e'), backgroundColor: Colors.orange),
      );
    }

    setState(() {
      _revealed[_currentIndex] = true;
      _questions[_currentIndex] = KbQa(
        id: qa.id,
        createTime: qa.createTime,
        updateTime: qa.updateTime,
        question: qa.question,
        answer: qa.answer,
        imageUrl: qa.imageUrl,
        total: newTotal,
        right: newRight,
        wrong: newWrong,
        randomInt: qa.randomInt,
        categoryId: qa.categoryId,
        tagId: qa.tagId,
      );
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) setState(() => _currentIndex++);
  }

  void _prevQuestion() {
    if (_currentIndex > 0) setState(() => _currentIndex--);
  }

  void _exitPractice() {
    setState(() => _showExitConfirm = true);
  }

  void _cancelExit() {
    setState(() => _showExitConfirm = false);
  }

  void _confirmExit() {
    void attempt(int tries) {
      if (!mounted || !context.mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !context.mounted) return;
        Navigator.of(context, rootNavigator: true).maybePop().then((didPop) {
          if (!didPop && tries < 20) {
            attempt(tries + 1);
          }
        });
      });
    }
    attempt(0);
  }

  @override
  Widget build(BuildContext context) {
    final qa = _questions[_currentIndex];
    final revealed = _revealed[_currentIndex];
    final isLast = _currentIndex == _questions.length - 1;
    final userAnswerCtrls = _userAnswerCtrls[_currentIndex];

    return Scaffold(
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(20.w),
                      decoration: BoxDecoration(
                        color: AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text('第 ${_currentIndex + 1} 题', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16.sp, fontFamily: 'Inter', color: AppTheme.textPrimary)),
                              ),
                              if (widget.bank != null)
                                Chip(
                                  label: Text(widget.bank!.name, style: TextStyle(fontSize: 11.sp, fontFamily: 'Inter')),
                                  backgroundColor: AppTheme.bgSection,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                                ),
                              SizedBox(width: 8.w),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 20),
                                color: AppTheme.textTertiary,
                                onPressed: _exitPractice,
                                tooltip: '退出练习',
                              ),
                            ],
                          ),
                          SizedBox(height: 20.h),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(16.w),
                            decoration: BoxDecoration(
                              color: AppTheme.bgSection,
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: QuestionRichText(
                              text: qa.question,
                              revealed: revealed,
                              answers: qa.answer,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20.h),
                    if (!revealed) ...[
                      Container(
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: AppTheme.bgCard,
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('请填空作答', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp, fontFamily: 'Inter', color: AppTheme.textPrimary)),
                            SizedBox(height: 12.h),
                            ...List.generate(qa.answer.length, (i) => Padding(
                              padding: EdgeInsets.only(bottom: 12.h),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24.w,
                                    height: 24.w,
                                    decoration: BoxDecoration(
                                      color: AppTheme.indigo50,
                                      borderRadius: BorderRadius.circular(6.r),
                                    ),
                                    child: Center(
                                      child: Text('${i + 1}', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: AppTheme.primary, fontFamily: 'Inter')),
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Expanded(
                                    child: TextField(
                                      controller: userAnswerCtrls[i],
                                      decoration: InputDecoration(
                                        hintText: '空${i + 1} 的答案',
                                        filled: true,
                                        fillColor: AppTheme.bgSection,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r), borderSide: const BorderSide(color: AppTheme.border)),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r), borderSide: const BorderSide(color: AppTheme.border)),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                            SizedBox(height: 8.h),
                            SizedBox(
                              width: double.infinity,
                              height: 48.h,
                              child: ElevatedButton.icon(
                                onPressed: _submitAnswer,
                                icon: const Icon(Icons.check, color: Colors.white),
                                label: const Text('提交答案', style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: AppTheme.bgCard,
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('答题结果', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp, fontFamily: 'Inter', color: AppTheme.textPrimary)),
                            SizedBox(height: 12.h),
                            ...List.generate(qa.answer.length, (i) {
                              final isCorrect = userAnswerCtrls[i].text.trim() == qa.answer[i];
                              final borderColor = isCorrect ? AppTheme.green : AppTheme.red;
                              return Padding(
                                padding: EdgeInsets.only(bottom: 16.h),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 24.w,
                                          height: 24.w,
                                          decoration: BoxDecoration(
                                            color: isCorrect ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                                            borderRadius: BorderRadius.circular(6.r),
                                            border: Border.all(color: borderColor, width: 1.5),
                                          ),
                                          child: Center(
                                            child: Icon(
                                              isCorrect ? Icons.check : Icons.close,
                                              size: 14,
                                              color: borderColor,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 8.w),
                                        Expanded(
                                          child: TextField(
                                            controller: userAnswerCtrls[i],
                                            readOnly: true,
                                            decoration: InputDecoration(
                                              filled: true,
                                              fillColor: AppTheme.bgSection,
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(10.r),
                                                borderSide: BorderSide(color: borderColor, width: 1.5),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(10.r),
                                                borderSide: BorderSide(color: borderColor, width: 1.5),
                                              ),
                                              contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                                            ),
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontFamily: 'Inter',
                                              color: isCorrect ? AppTheme.green : AppTheme.red,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 6.h),
                                    Padding(
                                      padding: EdgeInsets.only(left: 32.w),
                                      child: Row(
                                        children: [
                                          Text('正确答案：', style: TextStyle(fontSize: 12.sp, color: AppTheme.textTertiary, fontFamily: 'Inter')),
                                          Text(qa.answer[i], style: TextStyle(fontSize: 13.sp, color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_showExitConfirm)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  border: Border(top: BorderSide(color: AppTheme.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _cancelExit,
                        child: const Text('继续练习'),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _confirmExit,
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
                        child: const Text('退出', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  border: Border(top: BorderSide(color: AppTheme.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _currentIndex > 0 ? _prevQuestion : null,
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('上一题'),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: AppTheme.indigo50,
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text(
                        '${_currentIndex + 1} / ${_questions.length}',
                        style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 13.sp, fontFamily: 'Inter'),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _revealed[_currentIndex] ? (!isLast ? _nextQuestion : () => Navigator.pop(context)) : null,
                        iconAlignment: IconAlignment.end,
                        icon: isLast ? const SizedBox.shrink() : const Icon(Icons.chevron_right, color: Colors.white),
                        label: Text(isLast ? '返回' : '下一题', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
    );
  }
}

/// 面包屑导航步骤
class _NavStep {
  final String id;
  final String name;
  const _NavStep({required this.id, required this.name});
}
