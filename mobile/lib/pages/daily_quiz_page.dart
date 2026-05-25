import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'question_rich_text.dart';
import '../theme/app_theme.dart';

class DailyQuizPage extends StatefulWidget {
  const DailyQuizPage({super.key});

  @override
  State<DailyQuizPage> createState() => _DailyQuizPageState();
}

class _DailyQuizPageState extends State<DailyQuizPage> {
  // ── 题库选择阶段 ──
  List<Map<String, dynamic>> _rootBanks = [];
  Map<String, int> _descendantCounts = {};
  bool _loadingBanks = true;
  String? _selectedBankId;

  // ── 答题阶段 ──
  List<KbQa> _questions = [];
  int _currentIndex = 0;
  List<bool> _revealed = [];
  List<List<TextEditingController>> _userAnswerCtrls = [];
  bool _loadingQuiz = false;
  int _correctCount = 0;
  bool _allDone = false;

  @override
  void initState() {
    super.initState();
    _fetchBanks();
  }

  @override
  void dispose() {
    for (final ctrlList in _userAnswerCtrls) {
      for (final c in ctrlList) c.dispose();
    }
    super.dispose();
  }

  // ═══════════════════════════════════════════
  // 题库加载
  // ═══════════════════════════════════════════

  Future<void> _fetchBanks() async {
    try {
      final results = await Future.wait([
        ApiService.getBankTree(),
        ApiService.getDescendantCounts(),
      ]);
      final tree = results[0] as List<dynamic>;
      final counts = results[1] as Map<String, int>;

      if (mounted) {
        setState(() {
          _rootBanks = tree.cast<Map<String, dynamic>>();
          _descendantCounts = counts;
          _loadingBanks = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingBanks = false);
    }
  }

  /// 从树节点收集自身及所有后代的ID
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

  /// 在树中查找指定ID的节点
  Map<String, dynamic>? _findNode(List<Map<String, dynamic>> nodes, String id) {
    for (final node in nodes) {
      if (node['id'] == id) return node;
      final children = node['children'] as List<dynamic>?;
      if (children != null) {
        final found = _findNode(children.cast<Map<String, dynamic>>(), id);
        if (found != null) return found;
      }
    }
    return null;
  }

  void _selectBank(String bankId) {
    final node = _findNode(_rootBanks, bankId);
    List<String>? categoryIds;
    if (node != null) {
      categoryIds = _collectDescendantIds(node);
    }
    setState(() {
      _selectedBankId = bankId;
      _loadingQuiz = true;
    });
    _fetchQuestions(categoryIds: categoryIds);
  }

  // ═══════════════════════════════════════════
  // 题目加载 & 答题逻辑
  // ═══════════════════════════════════════════

  Future<void> _fetchQuestions({List<String>? categoryIds}) async {
    try {
      final data = await ApiService.randomQas(limit: 1, categoryIds: categoryIds);
      if (mounted) {
        setState(() {
          _questions = data.map((e) => KbQa.fromJson(e)).toList();
          _revealed = List.filled(_questions.length, false);
          _userAnswerCtrls = List.generate(
            _questions.length,
            (i) => List.generate(_questions[i].answer.length, (_) => TextEditingController()),
          );
          _loadingQuiz = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingQuiz = false);
    }
  }

  bool _checkAnswer(KbQa qa) {
    final userAnswers = _userAnswerCtrls[_currentIndex].map((c) => c.text.trim()).toList();
    if (userAnswers.length != qa.answer.length) return false;
    for (int i = 0; i < qa.answer.length; i++) {
      if (userAnswers[i] != qa.answer[i]) return false;
    }
    return true;
  }

  void _submitAnswer() {
    final qa = _questions[_currentIndex];
    final isCorrect = _checkAnswer(qa);

    ApiService.updateQa(qa.id, {
      'total': qa.total + 1,
      'right': qa.right + (isCorrect ? 1 : 0),
      'wrong': qa.wrong + (isCorrect ? 0 : 1),
    }).catchError((_) {});

    setState(() {
      _revealed[_currentIndex] = true;
      if (isCorrect) _correctCount++;
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() => _currentIndex++);
    }
  }

  void _finish() {
    setState(() => _allDone = true);
  }

  void _goHome() {
    Navigator.of(context).pushReplacementNamed('/home');
  }

  // ═══════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    // 加载题库中
    if (_loadingBanks) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 题库选择阶段
    if (_selectedBankId == null) return _buildBankSelection();

    // 加载题目中
    if (_loadingQuiz) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 全部完成
    if (_allDone) return _buildCompletionPage();

    // 没有题目
    if (_questions.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 64, color: AppTheme.textTertiary.withAlpha(128)),
              const SizedBox(height: 16),
              const Text('该题库暂无题目', style: TextStyle(color: AppTheme.textTertiary, fontSize: 15)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _goHome, child: const Text('进入APP')),
            ],
          ),
        ),
      );
    }

    // 答题阶段
    final qa = _questions[_currentIndex];
    final revealed = _revealed[_currentIndex];
    final isLast = _currentIndex == _questions.length - 1;
    final userAnswerCtrls = _userAnswerCtrls[_currentIndex];
    final progress = (_currentIndex + (revealed ? 1 : 0)) / _questions.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请先完成今日练习'), duration: Duration(seconds: 1)),
          );
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // 顶部进度条
              Container(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '每日练习',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                            fontFamily: 'Inter',
                          ),
                        ),
                        Text(
                          '${_currentIndex + 1} / ${_questions.length}',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: AppTheme.textSecondary,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4.r),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4.h,
                        backgroundColor: AppTheme.bgSection,
                        valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                      ),
                    ),
                  ],
                ),
              ),

              Divider(height: 1, color: AppTheme.border),

              // 题目区
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 题目卡片
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
                                Container(
                                  width: 28.w,
                                  height: 28.w,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary,
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${_currentIndex + 1}',
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 10.w),
                                Expanded(
                                  child: Text(
                                    '填空题',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: AppTheme.textTertiary,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16.h),
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

                      if (!revealed)
                        _buildAnswerArea(qa, userAnswerCtrls)
                      else
                        _buildResultArea(qa, userAnswerCtrls, isLast),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // 题库选择页面
  // ═══════════════════════════════════════════

  Widget _buildBankSelection() {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请选择题库开始练习'), duration: Duration(seconds: 1)),
          );
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: _rootBanks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder_outlined, size: 64.sp, color: AppTheme.textTertiary),
                      SizedBox(height: 16.h),
                      Text('暂无题库', style: TextStyle(color: AppTheme.textTertiary, fontSize: 16.sp)),
                      SizedBox(height: 16.h),
                      ElevatedButton(onPressed: _goHome, child: const Text('进入APP')),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 8.h),
                      child: Text(
                        '今日练习 · 选择题库',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 16.h),
                      child: Text(
                        '选择一个题库开始每日练习',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: AppTheme.textSecondary,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                    Divider(height: 1, color: AppTheme.border),
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.symmetric(vertical: 8.h),
                        itemCount: _rootBanks.length,
                        itemBuilder: (ctx, i) => _buildBankCard(_rootBanks[i]),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildBankCard(Map<String, dynamic> bank) {
    final id = bank['id'] as String;
    final name = bank['name'] as String;
    final count = _descendantCounts[id] ?? 0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      child: InkWell(
        onTap: () => _selectBank(id),
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(Icons.menu_book_rounded, color: AppTheme.primary, size: 22.sp),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        fontFamily: 'Inter',
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      count > 0 ? '$count 道题目' : '暂无题目',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: count > 0 ? AppTheme.primary : AppTheme.textTertiary,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppTheme.textTertiary, size: 20.sp),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // 答题区 / 结果区（保持原有UI不变）
  // ═══════════════════════════════════════════

  Widget _buildAnswerArea(KbQa qa, List<TextEditingController> ctrls) {
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
          Text('请填空作答',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp, fontFamily: 'Inter', color: AppTheme.textPrimary)),
          SizedBox(height: 12.h),
          ...List.generate(qa.answer.length, (i) {
            return Padding(
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
                      child: Text('${i + 1}',
                          style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: AppTheme.primary, fontFamily: 'Inter')),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: TextField(
                      controller: ctrls[i],
                      autofocus: i == 0,
                      decoration: InputDecoration(
                        hintText: '空${i + 1} 的答案',
                        filled: true,
                        fillColor: AppTheme.bgSection,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.r), borderSide: const BorderSide(color: AppTheme.border)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.r), borderSide: const BorderSide(color: AppTheme.border)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.r), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
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
    );
  }

  Widget _buildResultArea(KbQa qa, List<TextEditingController> ctrls, bool isLast) {
    return Column(
      children: [
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
              Text('答题结果',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp, fontFamily: 'Inter', color: AppTheme.textPrimary)),
              SizedBox(height: 12.h),
              ...List.generate(qa.answer.length, (i) {
                final isCorrect = ctrls[i].text.trim() == qa.answer[i];
                final borderColor = isCorrect ? AppTheme.green : AppTheme.red;
                return Padding(
                  padding: EdgeInsets.only(bottom: 16.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                              child: Icon(isCorrect ? Icons.check : Icons.close, size: 14, color: borderColor),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                              decoration: BoxDecoration(
                                color: AppTheme.bgSection,
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(color: borderColor, width: 1.5),
                              ),
                              child: Text(
                                ctrls[i].text,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'Inter',
                                  color: isCorrect ? AppTheme.green : AppTheme.red,
                                  fontWeight: FontWeight.w600,
                                ),
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
                            Text('正确答案：',
                                style: TextStyle(fontSize: 12.sp, color: AppTheme.textTertiary, fontFamily: 'Inter')),
                            Flexible(
                              child: Text(qa.answer[i],
                                  style: TextStyle(
                                      fontSize: 13.sp, color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                            ),
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

        SizedBox(height: 20.h),

        // 下一题 / 完成按钮
        SizedBox(
          width: double.infinity,
          height: 48.h,
          child: ElevatedButton.icon(
            onPressed: isLast ? _finish : _nextQuestion,
            icon: Icon(isLast ? Icons.emoji_events : Icons.arrow_forward, color: Colors.white),
            label: Text(
              isLast ? '完成练习' : '下一题',
              style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter'),
            ),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionPage() {
    final accuracy = _questions.isNotEmpty ? _correctCount / _questions.length : 0;
    final emoji = accuracy >= 1.0 ? '🎉' : accuracy >= 0.6 ? '👍' : '💪';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: TextStyle(fontSize: 64.sp)),
                SizedBox(height: 16.h),
                Text(
                  '今日练习完成',
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    fontFamily: 'Inter',
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  '正确 $_correctCount / ${_questions.length}',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: AppTheme.textSecondary,
                    fontFamily: 'Inter',
                  ),
                ),
                SizedBox(height: 32.h),
                SizedBox(
                  width: 220.w,
                  height: 48.h,
                  child: ElevatedButton.icon(
                    onPressed: _goHome,
                    icon: const Icon(Icons.home_rounded, color: Colors.white),
                    label: const Text('进入APP', style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
