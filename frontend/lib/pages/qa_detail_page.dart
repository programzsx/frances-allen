import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'qa_form_page.dart';
import 'question_rich_text.dart';
import '../theme/app_theme.dart';

class QaDetailPage extends StatefulWidget {
  final KbQa qa;
  final List<KbBank> banks;
  final List<KbTag> tags;
  final VoidCallback onRefresh;

  const QaDetailPage({
    super.key,
    required this.qa,
    required this.banks,
    required this.tags,
    required this.onRefresh,
  });

  @override
  State<QaDetailPage> createState() => _QaDetailPageState();
}

class _QaDetailPageState extends State<QaDetailPage> {
  late KbQa _qa;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _qa = widget.qa;
  }

  String get _bankName {
    if (_qa.bankId == null) return '未分类';
    final bank = widget.banks.where((b) => b.id == _qa.bankId).firstOrNull;
    return bank?.name ?? '未知';
  }

  List<String> get _tagNames {
    if (_qa.tagId == null || _qa.tagId!.isEmpty) return [];
    return _qa.tagId!
        .map((id) => widget.tags.where((t) => t.id == id).firstOrNull?.name)
        .whereType<String>()
        .toList();
  }

  Future<void> _delete() async {
    final result = await showDialog<bool>(
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
    if (result == true) {
      setState(() => _deleting = true);
      await ApiService.deleteQa(_qa.id);
      if (mounted) {
        Navigator.pop(context);
        widget.onRefresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Modern header
          SliverAppBar(
            expandedHeight: 0,
            pinned: true,
            backgroundColor: AppTheme.bgPrimary,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text('题目详情', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17, fontFamily: 'Inter')),
            centerTitle: true,
            actions: [
              IconButton(
                icon: _deleting
                    ? SizedBox(width: 20.w, height: 20.w, child: const CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.edit_outlined, size: 20),
                onPressed: _deleting ? null : () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => QaFormPage(qa: _qa)));
                  _refreshData();
                },
                tooltip: '编辑',
              ),
              IconButton(
                icon: _deleting ? const SizedBox.shrink() : const Icon(Icons.delete_outline, size: 20),
                onPressed: _deleting ? null : _delete,
                tooltip: '删除',
              ),
              SizedBox(width: 8.w),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bank & Tags
                  Wrap(
                    spacing: 6.w,
                    runSpacing: 6.h,
                    children: [
                      _TagChip(label: _bankName, color: AppTheme.indigo50, textColor: AppTheme.primary, borderColor: AppTheme.indigo100),
                      ..._tagNames.map((name) => _TagChip(label: name, color: AppTheme.bgSection, textColor: AppTheme.textSecondary, borderColor: AppTheme.border)),
                    ],
                  ),
                  SizedBox(height: 24.h),

                  // Question
                  _SectionHeader(icon: Icons.edit_note_outlined, label: '题目'),
                  SizedBox(height: 10.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: AppTheme.bgSection,
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: QuestionRichText(text: _qa.question, fontSize: 16),
                  ),
                  SizedBox(height: 24.h),

                  // Answers
                  _SectionHeader(icon: Icons.check_circle_outline, label: '答案'),
                  SizedBox(height: 10.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4), // green-50
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: const Color(0xFFBBF7D0)), // green-200
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _qa.answer.asMap().entries.map((e) => Padding(
                        padding: EdgeInsets.only(bottom: 8.h),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 24.w,
                              height: 24.w,
                              decoration: BoxDecoration(
                                color: const Color(0xFF86EFAC), // green-300
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Center(
                                child: Text('${e.key + 1}', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: const Color(0xFF166534))),
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Expanded(child: Text(e.value, style: TextStyle(fontSize: 15.sp, fontFamily: 'Inter', color: AppTheme.textPrimary))),
                          ],
                        ),
                      )).toList(),
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Image
                  if (_qa.imageUrl != null && _qa.imageUrl!.isNotEmpty) ...[
                    _SectionHeader(icon: Icons.image_outlined, label: '图片'),
                    SizedBox(height: 10.h),
                    GestureDetector(
                      onTap: () => QuestionRichText.showFullScreenImage(context, _qa.imageUrl!),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14.r),
                        child: CachedNetworkImage(
                          imageUrl: _qa.imageUrl!,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          placeholder: (_, __) => Container(
                            height: 200.h,
                            color: AppTheme.bgSection,
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            height: 100.h,
                            width: double.infinity,
                            color: AppTheme.bgSection,
                            child: Center(
                              child: Text('图片加载失败', style: TextStyle(color: AppTheme.textTertiary, fontSize: 13.sp)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 24.h),
                  ],

                  // Stats
                  _SectionHeader(icon: Icons.bar_chart_outlined, label: '统计'),
                  SizedBox(height: 10.h),
                  Row(
                    children: [
                      _statCard('总次数', _qa.total.toString(), AppTheme.primary),
                      SizedBox(width: 12.w),
                      _statCard('正确', _qa.right.toString(), AppTheme.green),
                      SizedBox(width: 12.w),
                      _statCard('错误', _qa.wrong.toString(), AppTheme.red),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    decoration: BoxDecoration(
                      color: AppTheme.bgSection,
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Center(
                      child: Text(
                        '正确率 ${(_qa.accuracy * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                          color: _accuracyColor(_qa.accuracy),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 32.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
          color: color.withAlpha(26),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 12.sp, color: AppTheme.textSecondary)),
            SizedBox(height: 4.h),
            Text(value, style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold, color: color, fontFamily: 'Inter')),
          ],
        ),
      ),
    );
  }

  Color _accuracyColor(double accuracy) {
    if (accuracy >= 0.8) return AppTheme.green;
    if (accuracy >= 0.5) return AppTheme.orange;
    return AppTheme.red;
  }

  Future<void> _refreshData() async {
    try {
      final data = await ApiService.getQa(_qa.id);
      if (data != null && mounted) {
        setState(() => _qa = KbQa.fromJson(data));
      }
    } catch (_) {}
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18.sp, color: AppTheme.primary),
        SizedBox(width: 6.w),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, fontFamily: 'Inter')),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final Color borderColor;

  const _TagChip({required this.label, required this.color, required this.textColor, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: borderColor),
      ),
      child: Text(label, style: TextStyle(fontSize: 12.sp, color: textColor, fontFamily: 'Inter')),
    );
  }
}
