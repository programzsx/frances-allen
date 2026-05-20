import 'dart:async';
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
  int _minWrong = 1;
  bool _loading = false;
  int _bankTotal = 0;

  // Search state
  final _searchCtrl = TextEditingController();
  final _searchKey = GlobalKey();
  List<KbBank> _searchResults = [];
  bool _searching = false;
  Timer? _debounce;
  OverlayEntry? _searchOverlay;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      _removeOverlay();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final data = await ApiService.pageBanks(keyword: query, pageSize: 20);
        final banks = (data['items'] as List).map((e) => KbBank.fromJson(e)).toList();
        if (mounted) {
          setState(() {
            _searchResults = banks;
            _searching = false;
          });
          if (banks.isNotEmpty || _searching) _showSearchOverlay();
        }
      } catch (_) {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  void _selectBank(KbBank bank) {
    _searchCtrl.clear();
    _removeOverlay();
    setState(() {
      _selectedBank = bank;
      _searchResults = [];
      _bankTotal = 0;
    });
    _loadBankTotal(bank);
  }

  Future<void> _loadBankTotal(KbBank bank) async {
    try {
      final data = await ApiService.pageQas(bankId: bank.id, pageSize: 1);
      if (mounted) setState(() => _bankTotal = data['total']);
    } catch (_) {}
  }

  void _showSearchOverlay() {
    _removeOverlay();
    final context = _searchKey.currentContext;
    if (context == null) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;

    _searchOverlay = OverlayEntry(
      builder: (ctx) => Positioned(
        left: offset.dx,
        top: offset.dy + size.height + 8.h,
        width: size.width,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(10.r),
          child: Container(
            constraints: BoxConstraints(maxHeight: 200.h),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: AppTheme.border),
            ),
            child: _searching
                ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    itemBuilder: (ctx, i) {
                      final bank = _searchResults[i];
                      return ListTile(
                        dense: true,
                        title: Text(bank.name, style: TextStyle(fontSize: 14.sp, fontFamily: 'Inter')),
                        onTap: () { _selectBank(bank); _removeOverlay(); },
                      );
                    },
                  ),
          ),
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_searchOverlay!);
  }

  void _removeOverlay() {
    _searchOverlay?.remove();
    _searchOverlay = null;
  }

  Future<void> _startPractice() async {
    if (_selectedBank == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先选择题库')));
      return;
    }
    setState(() => _loading = true);
    try {
      List<dynamic> data;
      switch (_mode) {
        case PracticeMode.random:
          data = await ApiService.getAllQasForBank(bankId: _selectedBank!.id);
          data = List.from(data)..shuffle(Random());
        case PracticeMode.sequential:
          data = await ApiService.getAllQasForBank(bankId: _selectedBank!.id);
        case PracticeMode.wrong:
          data = await ApiService.wrongQas(limit: 9999, bankId: _selectedBank!.id, minWrong: _minWrong);
      }

      final qas = data.map((e) => KbQa.fromJson(e)).toList();

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
              bank: _selectedBank!,
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
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _removeOverlay(),
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
                  child: Text('选择题库并设置练习模式', style: TextStyle(fontSize: 12.sp, color: AppTheme.textTertiary)),
                ),
                SizedBox(height: 28.h),

                Text('选择题库', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp, fontFamily: 'Inter', color: AppTheme.textPrimary)),
                SizedBox(height: 8.h),
                _buildBankSearch(),
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
                      _loading ? '加载中...' : _selectedBank != null ? '开始练习 (${_bankTotal} 题)' : '开始练习',
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
      ),
    );
  }

  Widget _buildBankSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: _searchKey,
          controller: _searchCtrl,
          onTap: () {
            if (_searchCtrl.text.trim().isNotEmpty) _showSearchOverlay();
          },
          decoration: InputDecoration(
            hintText: '输入题库名称搜索',
            hintStyle: TextStyle(fontSize: 13, color: AppTheme.textTertiary, fontFamily: 'Inter'),
            prefixIcon: const Icon(Icons.search_rounded, size: 18),
            suffixIcon: _selectedBank != null
                ? IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () {
                    setState(() { _selectedBank = null; _bankTotal = 0; });
                  })
                : null,
            filled: true,
            fillColor: AppTheme.bgCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.r),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.r),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.r),
              borderSide: const BorderSide(color: AppTheme.primary, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          ),
          style: TextStyle(fontSize: 14, fontFamily: 'Inter'),
        ),
        if (_selectedBank != null) ...[
          SizedBox(height: 8.h),
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
                  Text(
                    '$_bankTotal 题',
                    style: TextStyle(fontSize: 12.sp, color: AppTheme.textTertiary),
                  ),
              ],
            ),
          ),
        ],
      ],
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
                  '>= $_minWrong',
                  style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 13.sp, fontFamily: 'Inter'),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Slider(
            value: _minWrong.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            label: '>= $_minWrong',
            onChanged: (v) => setState(() => _minWrong = v.toInt()),
          ),
          Text('筛选错误次数大于等于 $_minWrong 次的题目', style: TextStyle(color: AppTheme.textTertiary, fontSize: 12.sp)),
        ],
      ),
    );
  }
}

class PracticeQuizPage extends StatefulWidget {
  final List<KbQa> questions;
  final KbBank bank;
  const PracticeQuizPage({super.key, required this.questions, required this.bank});

  @override
  State<PracticeQuizPage> createState() => _PracticeQuizPageState();
}

class _PracticeQuizPageState extends State<PracticeQuizPage> {
  List<KbQa> _questions = [];
  int _currentIndex = 0;
  List<bool> _revealed = [];
  List<List<TextEditingController>> _userAnswerCtrls = [];
  bool _showExitConfirm = false;

  Map<String, KbBank> _bankMap = {};

  @override
  void initState() {
    super.initState();
    _questions = widget.questions;
    _revealed = List.filled(_questions.length, false);
    _userAnswerCtrls = List.generate(
      _questions.length,
      (i) => List.generate(_questions[i].answer.length, (_) => TextEditingController()),
    );
    _bankMap = {widget.bank.id: widget.bank};
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
        bankId: qa.bankId,
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
                              Chip(
                                label: Text(widget.bank.name, style: TextStyle(fontSize: 11.sp, fontFamily: 'Inter')),
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
