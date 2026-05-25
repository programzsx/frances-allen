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
  // ── 答题状态 ──
  KbQa? _question;
  bool _loading = true;
  bool _revealed = false;
  List<TextEditingController> _answerCtrls = [];
  bool _allDone = false;

  @override
  void initState() {
    super.initState();
    _fetchQuestion();
  }

  @override
  void dispose() {
    for (final c in _answerCtrls) c.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════
  // 题目加载
  // ═══════════════════════════════════════════

  Future<void> _fetchQuestion() async {
    try {
      final data = await ApiService.randomQas(limit: 1);
      if (data.isNotEmpty && mounted) {
        setState(() {
          _question = KbQa.fromJson(data[0]);
          _answerCtrls = List.generate(
            _question!.answer.length,
            (_) => TextEditingController(),
          );
          _loading = false;
        });
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ═══════════════════════════════════════════
  // 答题逻辑
  // ═══════════════════════════════════════════

  bool _checkAnswer() {
    final qa = _question!;
    final userAnswers = _answerCtrls.map((c) => c.text.trim()).toList();
    if (userAnswers.length != qa.answer.length) return false;
    for (int i = 0; i < qa.answer.length; i++) {
      if (userAnswers[i] != qa.answer[i]) return false;
    }
    return true;
  }

  void _submitAnswer() {
    final qa = _question!;
    final isCorrect = _checkAnswer();

    ApiService.updateQa(qa.id, {
      'score': isCorrect ? 1 : -1,
    }).catchError((_) {});

    setState(() => _revealed = true);
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
    // 加载中
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 完成
    if (_allDone) return _buildCompletionPage();

    // 没有题目
    if (_question == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 64, color: AppTheme.textTertiary.withAlpha(128)),
              const SizedBox(height: 16),
              const Text('暂无题目', style: TextStyle(color: AppTheme.textTertiary, fontSize: 15)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _goHome, child: const Text('进入APP')),
            ],
          ),
        ),
      );
    }

    // 答题
    final qa = _question!;
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
              Container(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('每日练习',
                            style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600, color: AppTheme.textPrimary, fontFamily: 'Inter')),
                        Text('1 / 1',
                            style: TextStyle(fontSize: 13.sp, color: AppTheme.textSecondary, fontFamily: 'Inter')),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4.r),
                      child: LinearProgressIndicator(
                        value: _revealed ? 1.0 : 0.0, minHeight: 4.h,
                        backgroundColor: AppTheme.bgSection,
                        valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppTheme.border),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16.w),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _buildQuizCard(qa),
                    SizedBox(height: 20.h),
                    if (!_revealed) _buildAnswerArea(qa) else _buildResultArea(qa),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuizCard(KbQa qa) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(14.r), border: Border.all(color: AppTheme.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 28.w, height: 28.w,
            decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(8.r)),
            child: Center(child: Text('1', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.white))),
          ),
          SizedBox(width: 10.w),
          Expanded(child: Text('填空题', style: TextStyle(fontSize: 12.sp, color: AppTheme.textTertiary, fontFamily: 'Inter'))),
        ]),
        SizedBox(height: 16.h),
        Container(
          width: double.infinity, padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(color: AppTheme.bgSection, borderRadius: BorderRadius.circular(12.r)),
          child: QuestionRichText(text: qa.question, revealed: _revealed, answers: qa.answer, fontSize: 18),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════
  // 答题区
  // ═══════════════════════════════════════════

  Widget _buildAnswerArea(KbQa qa) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(14.r), border: Border.all(color: AppTheme.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('请填空作答', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp, fontFamily: 'Inter', color: AppTheme.textPrimary)),
        SizedBox(height: 12.h),
        ...List.generate(qa.answer.length, (i) {
          return Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: Row(children: [
              Container(
                width: 24.w, height: 24.w,
                decoration: BoxDecoration(color: AppTheme.indigo50, borderRadius: BorderRadius.circular(6.r)),
                child: Center(
                    child: Text('${i + 1}',
                        style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: AppTheme.primary, fontFamily: 'Inter'))),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: TextField(
                  controller: _answerCtrls[i],
                  autofocus: i == 0,
                  decoration: InputDecoration(
                    hintText: '空${i + 1} 的答案',
                    filled: true, fillColor: AppTheme.bgSection,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r), borderSide: const BorderSide(color: AppTheme.border)),
                    enabledBorder:
                        OutlineInputBorder(borderRadius: BorderRadius.circular(10.r), borderSide: const BorderSide(color: AppTheme.border)),
                    focusedBorder:
                        OutlineInputBorder(borderRadius: BorderRadius.circular(10.r), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                  ),
                ),
              ),
            ]),
          );
        }),
        SizedBox(height: 8.h),
        SizedBox(
          width: double.infinity, height: 48.h,
          child: ElevatedButton.icon(
            onPressed: _submitAnswer,
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text('提交答案', style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter')),
            style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r))),
          ),
        ),
      ]),
    );
  }

  Widget _buildResultArea(KbQa qa) {
    return Column(children: [
      Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(14.r), border: Border.all(color: AppTheme.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('答题结果', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp, fontFamily: 'Inter', color: AppTheme.textPrimary)),
          SizedBox(height: 12.h),
          ...List.generate(qa.answer.length, (i) {
            final isCorrect = _answerCtrls[i].text.trim() == qa.answer[i];
            final borderColor = isCorrect ? AppTheme.green : AppTheme.red;
            return Padding(
              padding: EdgeInsets.only(bottom: 16.h),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 24.w, height: 24.w,
                    decoration: BoxDecoration(
                        color: isCorrect ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(6.r),
                        border: Border.all(color: borderColor, width: 1.5)),
                    child: Center(child: Icon(isCorrect ? Icons.check : Icons.close, size: 14, color: borderColor)),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                      decoration: BoxDecoration(color: AppTheme.bgSection, borderRadius: BorderRadius.circular(10.r), border: Border.all(color: borderColor, width: 1.5)),
                      child: Text(_answerCtrls[i].text,
                          style: TextStyle(fontSize: 14, fontFamily: 'Inter', color: isCorrect ? AppTheme.green : AppTheme.red, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
                SizedBox(height: 6.h),
                Padding(
                  padding: EdgeInsets.only(left: 32.w),
                  child: Row(children: [
                    Text('正确答案：', style: TextStyle(fontSize: 12.sp, color: AppTheme.textTertiary, fontFamily: 'Inter')),
                    Flexible(
                        child: Text(qa.answer[i],
                            style: TextStyle(fontSize: 13.sp, color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontFamily: 'Inter'))),
                  ]),
                ),
              ]),
            );
          }),
        ]),
      ),
      SizedBox(height: 20.h),
      SizedBox(
        width: double.infinity, height: 48.h,
        child: ElevatedButton.icon(
          onPressed: _finish,
          icon: const Icon(Icons.emoji_events, color: Colors.white),
          label: const Text('完成练习', style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter')),
          style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r))),
        ),
      ),
    ]);
  }

  Widget _buildCompletionPage() {
    final isCorrect = _question != null && _checkAnswer();
    final emoji = isCorrect ? '🎉' : '💪';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32.w),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(emoji, style: TextStyle(fontSize: 64.sp)),
              SizedBox(height: 16.h),
              Text('今日练习完成',
                  style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontFamily: 'Inter')),
              SizedBox(height: 8.h),
              Text(isCorrect ? '回答正确！' : '继续加油！',
                  style: TextStyle(fontSize: 16.sp, color: AppTheme.textSecondary, fontFamily: 'Inter')),
              SizedBox(height: 32.h),
              SizedBox(
                width: 220.w, height: 48.h,
                child: ElevatedButton.icon(
                  onPressed: _goHome,
                  icon: const Icon(Icons.home_rounded, color: Colors.white),
                  label: const Text('进入APP', style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                  style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r))),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
