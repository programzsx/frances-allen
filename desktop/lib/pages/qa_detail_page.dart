import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'qa_form_page.dart';
import 'question_rich_text.dart';
import '../theme/desktop_theme.dart';

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

  String get _categoryName {
    if (_qa.categoryId == null) return '未分类';
    final bank = widget.banks.where((b) => b.id == _qa.categoryId).firstOrNull;
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
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除', style: TextStyle(color: DesktopTheme.red))),
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

  Future<void> _refreshData() async {
    try {
      final data = await ApiService.getQa(_qa.id);
      if (data != null && mounted) {
        setState(() => _qa = KbQa.fromJson(data));
      }
    } catch (_) {}
  }

  Color _accuracyColor(double accuracy) {
    if (accuracy >= 0.8) return DesktopTheme.green;
    if (accuracy >= 0.5) return DesktopTheme.orange;
    return DesktopTheme.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('题目详情', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: _deleting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
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
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bank & Tags
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _TagChip(label: _categoryName, color: DesktopTheme.indigo50, textColor: DesktopTheme.primary, borderColor: DesktopTheme.indigo100),
                ..._tagNames.map((name) => _TagChip(label: name, color: DesktopTheme.bgSection, textColor: DesktopTheme.textSecondary, borderColor: DesktopTheme.border)),
              ],
            ),
            const SizedBox(height: 24),

            // Question
            _SectionHeader(icon: Icons.edit_note_outlined, label: '题目'),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: DesktopTheme.bgSection,
                borderRadius: BorderRadius.circular(8),
              ),
              child: QuestionRichText(text: _qa.question, fontSize: 15),
            ),
            const SizedBox(height: 24),

            // Answers
            _SectionHeader(icon: Icons.check_circle_outline, label: '答案'),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _qa.answer.asMap().entries.map((e) => Padding(
                  padding: EdgeInsets.only(bottom: e.key < _qa.answer.length - 1 ? 8 : 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: const Color(0xFF86EFAC),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text('${e.key + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(e.value, style: const TextStyle(fontSize: 14, color: DesktopTheme.textPrimary))),
                    ],
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // Image
            if (_qa.imageUrl != null && _qa.imageUrl!.isNotEmpty) ...[
              _SectionHeader(icon: Icons.image_outlined, label: '图片'),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => QuestionRichText.showFullScreenImage(context, _qa.imageUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: _qa.imageUrl!,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    placeholder: (_, __) => Container(
                      height: 200,
                      color: DesktopTheme.bgSection,
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      height: 100,
                      width: double.infinity,
                      color: DesktopTheme.bgSection,
                      child: const Center(child: Text('图片加载失败', style: TextStyle(color: DesktopTheme.textTertiary, fontSize: 13))),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Stats
            _SectionHeader(icon: Icons.bar_chart_outlined, label: '统计'),
            const SizedBox(height: 10),
            Row(
              children: [
                _statCard('总次数', _qa.total.toString(), DesktopTheme.primary),
                const SizedBox(width: 12),
                _statCard('正确', _qa.right.toString(), DesktopTheme.green),
                const SizedBox(width: 12),
                _statCard('错误', _qa.wrong.toString(), DesktopTheme.red),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: DesktopTheme.bgSection,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '正确率 ${(_qa.accuracy * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _accuracyColor(_qa.accuracy),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withAlpha(26),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: DesktopTheme.textSecondary)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
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
        Icon(icon, size: 18, color: DesktopTheme.primary),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: textColor)),
    );
  }
}
