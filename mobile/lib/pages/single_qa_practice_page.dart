import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'qa_form_page.dart';
import 'question_rich_text.dart';
import '../theme/app_theme.dart';

/// 单题练习页：答题 → 结果 → 编辑/删除
class SingleQaPracticePage extends StatefulWidget {
  final KbQa qa;
  final List<KbBank> banks;
  final List<KbTag> tags;
  final VoidCallback onRefresh;

  const SingleQaPracticePage({
    super.key,
    required this.qa,
    required this.banks,
    required this.tags,
    required this.onRefresh,
  });

  @override
  State<SingleQaPracticePage> createState() => _SingleQaPracticePageState();
}

class _SingleQaPracticePageState extends State<SingleQaPracticePage> {
  late KbQa _qa;
  late List<TextEditingController> _ctrls;
  bool _revealed = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _qa = widget.qa;
    _ctrls = List.generate(_qa.answer.length, (_) => TextEditingController());
  }

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════
  // 答题逻辑
  // ═══════════════════════════════════════════

  bool _checkAnswer() {
    final userAnswers = _ctrls.map((c) => c.text.trim()).toList();
    if (userAnswers.length != _qa.answer.length) return false;
    for (int i = 0; i < _qa.answer.length; i++) {
      if (userAnswers[i] != _qa.answer[i]) return false;
    }
    return true;
  }

  void _submitAnswer() {
    final isCorrect = _checkAnswer();
    final newTotal = _qa.total + 1;
    final newRight = _qa.right + (isCorrect ? 1 : 0);
    final newWrong = _qa.wrong + (isCorrect ? 0 : 1);

    ApiService.updateQa(_qa.id, {'total': newTotal, 'right': newRight, 'wrong': newWrong}).catchError((_) {});

    setState(() {
      _revealed = true;
      _qa = KbQa(
        id: _qa.id,
        createTime: _qa.createTime,
        updateTime: _qa.updateTime,
        question: _qa.question,
        answer: _qa.answer,
        imageUrl: _qa.imageUrl,
        total: newTotal,
        right: newRight,
        wrong: newWrong,
        randomInt: _qa.randomInt,
        score: _qa.score,
        sortOrder: _qa.sortOrder,
        categoryId: _qa.categoryId,
        tagId: _qa.tagId,
      );
    });
  }

  // ═══════════════════════════════════════════
  // 编辑 / 删除
  // ═══════════════════════════════════════════

  Future<void> _edit() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => QaFormPage(qa: _qa),
      ),
    );
    if (result == true && mounted) {
      // 编辑后重新加载题目
      try {
        final fresh = await ApiService.getQa(_qa.id);
        if (fresh != null && mounted) {
          setState(() {
            _qa = KbQa.fromJson(fresh);
            _revealed = false;
            _ctrls = List.generate(_qa.answer.length, (_) => TextEditingController());
          });
        }
      } catch (_) {}
      widget.onRefresh();
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定删除该题目吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除', style: TextStyle(color: AppTheme.red))),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _loading = true);
      await ApiService.deleteQa(_qa.id);
      if (mounted) {
        Navigator.pop(context);
        widget.onRefresh();
      }
    }
  }

  // ═══════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('题目练习', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
        centerTitle: true,
        actions: [
          if (_revealed) ...[
            IconButton(icon: const Icon(Icons.edit_outlined), tooltip: '编辑', onPressed: _edit),
            IconButton(icon: const Icon(Icons.delete_outline), tooltip: '删除', onPressed: _delete),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQuestionCard(),
                  SizedBox(height: 20.h),
                  if (!_revealed) _buildAnswerArea() else _buildResultArea(),
                ],
              ),
            ),
    );
  }

  Widget _buildQuestionCard() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 28.w, height: 28.w,
              decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(8.r)),
              child: const Center(child: Text('Q', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white))),
            ),
            SizedBox(width: 10.w),
            Text('填空题', style: TextStyle(fontSize: 12.sp, color: AppTheme.textTertiary, fontFamily: 'Inter')),
          ]),
          SizedBox(height: 16.h),
          Container(
            width: double.infinity, padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(color: AppTheme.bgSection, borderRadius: BorderRadius.circular(12.r)),
            child: QuestionRichText(text: _qa.question, revealed: _revealed, answers: _qa.answer, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerArea() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(14.r), border: Border.all(color: AppTheme.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('请填空作答', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp, fontFamily: 'Inter', color: AppTheme.textPrimary)),
        SizedBox(height: 12.h),
        ...List.generate(_qa.answer.length, (i) => Padding(
          padding: EdgeInsets.only(bottom: 12.h),
          child: Row(children: [
            Container(
              width: 24.w, height: 24.w,
              decoration: BoxDecoration(color: AppTheme.indigo50, borderRadius: BorderRadius.circular(6.r)),
              child: Center(child: Text('${i + 1}', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: AppTheme.primary, fontFamily: 'Inter'))),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: TextField(
                controller: _ctrls[i],
                autofocus: i == 0,
                decoration: InputDecoration(
                  hintText: '空${i + 1} 的答案',
                  filled: true, fillColor: AppTheme.bgSection,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r), borderSide: const BorderSide(color: AppTheme.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r), borderSide: const BorderSide(color: AppTheme.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                ),
              ),
            ),
          ]),
        )),
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

  Widget _buildResultArea() {
    return Column(children: [
      // 答题结果
      Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(14.r), border: Border.all(color: AppTheme.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('答题结果', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp, fontFamily: 'Inter', color: AppTheme.textPrimary)),
          SizedBox(height: 12.h),
          ...List.generate(_qa.answer.length, (i) {
            final isCorrect = _ctrls[i].text.trim() == _qa.answer[i];
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
                      border: Border.all(color: borderColor, width: 1.5),
                    ),
                    child: Center(child: Icon(isCorrect ? Icons.check : Icons.close, size: 14, color: borderColor)),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                      decoration: BoxDecoration(color: AppTheme.bgSection, borderRadius: BorderRadius.circular(10.r), border: Border.all(color: borderColor, width: 1.5)),
                      child: Text(_ctrls[i].text, style: TextStyle(fontSize: 14, fontFamily: 'Inter', color: isCorrect ? AppTheme.green : AppTheme.red, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
                SizedBox(height: 6.h),
                Padding(
                  padding: EdgeInsets.only(left: 32.w),
                  child: Row(children: [
                    Text('正确答案：', style: TextStyle(fontSize: 12.sp, color: AppTheme.textTertiary, fontFamily: 'Inter')),
                    Flexible(child: Text(_qa.answer[i], style: TextStyle(fontSize: 13.sp, color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontFamily: 'Inter'))),
                  ]),
                ),
              ]),
            );
          }),
        ]),
      ),
      SizedBox(height: 16.h),
      // 统计
      _buildStatsCard(),
      SizedBox(height: 16.h),
      // 操作按钮
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _edit,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('编辑题目'),
            style: OutlinedButton.styleFrom(
              minimumSize: Size.fromHeight(44.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline),
            label: const Text('删除题目'),
            style: OutlinedButton.styleFrom(
              minimumSize: Size.fromHeight(44.h),
              foregroundColor: AppTheme.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              side: const BorderSide(color: AppTheme.red),
            ),
          ),
        ),
      ]),
    ]);
  }

  Widget _buildStatsCard() {
    final accuracy = _qa.total > 0 ? (_qa.right / _qa.total * 100).round() : 0;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.bar_chart_rounded, size: 18.sp, color: AppTheme.primary),
          SizedBox(width: 6.w),
          Text('练习统计', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp, fontFamily: 'Inter', color: AppTheme.textPrimary)),
        ]),
        SizedBox(height: 12.h),
        Row(children: [
          _statItem(label: '总次数', value: _qa.total, color: AppTheme.textPrimary),
          _statItem(label: '答对', value: _qa.right, color: AppTheme.green),
          _statItem(label: '答错', value: _qa.wrong, color: AppTheme.red),
        ]),
        SizedBox(height: 10.h),
        Row(children: [
          Text('正确率 ', style: TextStyle(fontSize: 12.sp, color: AppTheme.textTertiary)),
          Text('$accuracy%',
            style: TextStyle(
              fontSize: 14.sp, fontWeight: FontWeight.bold,
              color: accuracy >= 60 ? AppTheme.green : AppTheme.red,
              fontFamily: 'Inter',
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _statItem({required String label, required int value, required Color color}) {
    return Expanded(
      child: Column(children: [
        Text('$value', style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold, color: color, fontFamily: 'Inter')),
        SizedBox(height: 2.h),
        Text(label, style: TextStyle(fontSize: 11.sp, color: AppTheme.textTertiary)),
      ]),
    );
  }
}
