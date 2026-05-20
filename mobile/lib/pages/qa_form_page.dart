import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'question_rich_text.dart';
import '../theme/app_theme.dart';

class QaFormPage extends StatefulWidget {
  final KbQa? qa;
  const QaFormPage({super.key, this.qa});

  @override
  State<QaFormPage> createState() => _QaFormPageState();
}

class _QaFormPageState extends State<QaFormPage> {
  final _questionCtrl = TextEditingController();
  final List<TextEditingController> _answerCtrls = [];
  final _questionFocus = FocusNode();
  String? _imageUrl;
  String? _bankId;
  List<String> _tagIds = [];
  List<KbBank> _banks = [];
  List<KbTag> _tags = [];
  bool _saving = false;
  int _blankCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.qa != null) {
      _questionCtrl.text = widget.qa!.question;
      for (final a in widget.qa!.answer) {
        _answerCtrls.add(TextEditingController(text: a));
      }
      _imageUrl = widget.qa!.imageUrl;
      _bankId = widget.qa!.bankId;
      _tagIds = widget.qa!.tagId ?? [];
      _blankCount = '___'.allMatches(widget.qa!.question).length;
    }
    _questionCtrl.addListener(_onQuestionChanged);
    _loadMeta();
  }

  void _onQuestionChanged() {
    final text = _questionCtrl.text;
    final blankCount = '___'.allMatches(text).length;
    if (blankCount != _blankCount) {
      _blankCount = blankCount;
      _syncAnswerFields();
    }
  }

  void _syncAnswerFields() {
    if (_blankCount > _answerCtrls.length) {
      while (_answerCtrls.length < _blankCount) {
        _answerCtrls.add(TextEditingController());
      }
    } else if (_blankCount < _answerCtrls.length) {
      while (_answerCtrls.length > _blankCount) {
        _answerCtrls.removeLast().dispose();
      }
    }
    setState(() {});
  }

  void _insertAtCursor(String before, [String? after]) {
    final text = _questionCtrl.text;
    final selection = _questionCtrl.selection;
    final selectedText = selection.textInside(text);
    String newText;
    int newOffset;

    if (selectedText.isNotEmpty) {
      newText = text.replaceRange(selection.start, selection.end, '$before$selectedText${after ?? before}');
      newOffset = selection.start + before.length + selectedText.length + (after ?? before).length;
    } else if (after != null) {
      newText = text.replaceRange(selection.start, selection.end, '$before$after');
      newOffset = selection.start + before.length;
    } else {
      newText = text.replaceRange(selection.start, selection.end, before);
      newOffset = selection.start + before.length;
    }

    _questionCtrl.text = newText;
    _questionCtrl.selection = TextSelection.collapsed(offset: newOffset);
  }

  void _insertBlank() => _insertAtCursor('___');
  void _insertBold() => _insertAtCursor('**');
  void _insertHighlight() => _insertAtCursor('==');
  void _insertCode() => _insertAtCursor('`');
  void _insertDivider() {
    final text = _questionCtrl.text;
    final selection = _questionCtrl.selection;
    String newText;
    int newOffset;

    if (selection.start > 0 && text[selection.start - 1] != '\n') {
      newText = text.replaceRange(selection.start, selection.end, '\n----\n');
      newOffset = selection.start + 7;
    } else {
      newText = text.replaceRange(selection.start, selection.end, '----\n');
      newOffset = selection.start + 5;
    }

    _questionCtrl.text = newText;
    _questionCtrl.selection = TextSelection.collapsed(offset: newOffset);
  }

  void _showPreview() {
    showDialog(
      context: context,
      builder: (_) => _PreviewDialog(
        question: _questionCtrl.text,
        answers: _answerCtrls.map((c) => c.text).toList(),
        imageUrl: _imageUrl,
        bankName: _bankName,
      ),
    );
  }

  String get _bankName {
    if (_bankId == null) return '未分类';
    final bank = _banks.where((b) => b.id == _bankId).firstOrNull;
    return bank?.name ?? '未知';
  }

  Future<void> _loadMeta() async {
    try {
      final bankData = await ApiService.pageBanks(pageSize: 100);
      final tagData = await ApiService.pageTags(pageSize: 100);
      setState(() {
        _banks = (bankData['items'] as List).map((e) => KbBank.fromJson(e)).toList();
        _tags = (tagData['items'] as List).map((e) => KbTag.fromJson(e)).toList();
      });
    } catch (_) {}
  }

  void _addAnswerField() {
    setState(() => _answerCtrls.add(TextEditingController()));
  }

  void _removeAnswerField(int index) {
    setState(() {
      _answerCtrls[index].dispose();
      _answerCtrls.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (_questionCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入题目')));
      return;
    }
    final answers = _answerCtrls.map((c) => c.text).where((t) => t.isNotEmpty).toList();
    if (answers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请至少填写一个答案')));
      return;
    }

    setState(() => _saving = true);
    try {
      final data = {
        'question': _questionCtrl.text,
        'answer': answers,
        'image_url': _imageUrl,
        'bank_id': _bankId,
        'tag_id': _tagIds.isNotEmpty ? _tagIds : null,
      };

      if (widget.qa == null) {
        await ApiService.createQa(data);
      } else {
        await ApiService.updateQa(widget.qa!.id, data);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _questionCtrl.removeListener(_onQuestionChanged);
    _questionCtrl.dispose();
    _questionFocus.dispose();
    for (final c in _answerCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 0,
            pinned: true,
            backgroundColor: AppTheme.bgPrimary,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(widget.qa == null ? '新增题目' : '编辑题目', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17, fontFamily: 'Inter')),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.visibility_outlined, size: 20),
                onPressed: _showPreview,
                tooltip: '预览',
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
                  // Question section
                  _SectionHeader(icon: Icons.edit_note_outlined, label: '题目'),
                  SizedBox(height: 8.h),

                  // Toolbar
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: AppTheme.bgSection,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Wrap(
                      spacing: 6.w,
                      runSpacing: 4.h,
                      children: [
                        _toolbarChip('填空', _insertBlank),
                        _toolbarChip('加粗', _insertBold),
                        _toolbarChip('高亮', _insertHighlight),
                        _toolbarChip('代码', _insertCode),
                        _toolbarChip('分割线', _insertDivider),
                      ],
                    ),
                  ),
                  SizedBox(height: 8.h),

                  // Question input
                  TextField(
                    controller: _questionCtrl,
                    focusNode: _questionFocus,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: '输入题目，用 ___ 表示填空',
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
                      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                    ),
                    onChanged: (text) {
                      if (text.contains('   ')) {
                        final newText = text.replaceAll('   ', '___');
                        if (newText != text) {
                          _questionCtrl.text = newText;
                          _questionCtrl.selection = TextSelection.collapsed(offset: _questionCtrl.text.length);
                        }
                      }
                    },
                  ),
                  SizedBox(height: 8.h),

                  // Blank count hint
                  if (_blankCount > 0)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: AppTheme.indigo50,
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Text(
                        '共 $_blankCount 个填空，已自动生成 $_blankCount 个答案输入框',
                        style: TextStyle(fontSize: 12.sp, color: AppTheme.primary, fontFamily: 'Inter'),
                      ),
                    ),
                  SizedBox(height: 24.h),

                  // Answer section
                  Row(
                    children: [
                      Icon(Icons.check_circle_outline, size: 18.sp, color: AppTheme.primary),
                      SizedBox(width: 6.w),
                      Text('答案', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, fontFamily: 'Inter')),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.add_circle_outlined, color: AppTheme.primary, size: 22),
                        onPressed: _addAnswerField,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  if (_answerCtrls.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(24.w),
                      decoration: BoxDecoration(
                        color: AppTheme.bgSection,
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.add_circle_outline, size: 32.sp, color: AppTheme.textTertiary),
                          SizedBox(height: 8.h),
                          Text('点击 + 添加答案，或在题目中输入 ___', style: TextStyle(color: AppTheme.textTertiary, fontSize: 13.sp)),
                        ],
                      ),
                    )
                  else
                    ...List.generate(_answerCtrls.length, (i) => Padding(
                      padding: EdgeInsets.only(bottom: 10.h),
                      child: Row(
                        children: [
                          Container(
                            width: 28.w,
                            height: 28.w,
                            decoration: BoxDecoration(
                              color: AppTheme.indigo50,
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Center(
                              child: Text('${i + 1}', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12.sp, fontFamily: 'Inter')),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: TextField(
                              controller: _answerCtrls[i],
                              decoration: InputDecoration(
                                hintText: '空${i + 1} 的答案',
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
                            ),
                          ),
                          SizedBox(width: 4.w),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: AppTheme.red, size: 18),
                            onPressed: () => _removeAnswerField(i),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    )),
                  SizedBox(height: 24.h),

                  // Image URL
                  _SectionHeader(icon: Icons.image_outlined, label: '图片'),
                  SizedBox(height: 8.h),
                  TextField(
                    onChanged: (v) => _imageUrl = v.isEmpty ? null : v,
                    decoration: InputDecoration(
                      hintText: '输入图片URL（可选）',
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
                      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Bank
                  _SectionHeader(icon: Icons.folder_outlined, label: '题库'),
                  SizedBox(height: 8.h),
                  _banks.isEmpty
                      ? const Center(child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ))
                      : DropdownButtonFormField<String>(
                          value: _bankId,
                          decoration: InputDecoration(
                            hintText: '选择题库',
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
                          items: [
                            const DropdownMenuItem(value: null, child: Text('未分类')),
                            ..._banks.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
                          ],
                          onChanged: (v) => setState(() => _bankId = v),
                        ),
                  SizedBox(height: 24.h),

                  // Tags
                  _SectionHeader(icon: Icons.label_outlined, label: '标签'),
                  SizedBox(height: 8.h),
                  _banks.isEmpty
                      ? const Center(child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ))
                      : _tags.isEmpty
                          ? Text('暂无标签', style: TextStyle(color: AppTheme.textTertiary, fontSize: 13.sp))
                          : Wrap(
                              spacing: 8.w,
                              runSpacing: 6.h,
                              children: _tags.map((tag) {
                                final selected = _tagIds.contains(tag.id);
                                return _TagChip(
                                  label: tag.name,
                                  selected: selected,
                                  onTap: () {
                                    setState(() {
                                      if (selected) {
                                        _tagIds.remove(tag.id);
                                      } else {
                                        _tagIds.add(tag.id);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                  SizedBox(height: 40.h),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 52.h,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                      ),
                      child: _saving
                          ? SizedBox(width: 20.w, height: 20.w, child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('保存', style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                    ),
                  ),
                  SizedBox(height: 24.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbarChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(label, style: TextStyle(fontSize: 12.sp, color: AppTheme.textSecondary, fontFamily: 'Inter')),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TagChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: selected ? AppTheme.indigo50 : AppTheme.bgSection,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: selected ? AppTheme.indigo100 : AppTheme.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? AppTheme.primary : AppTheme.textSecondary,
            fontFamily: 'Inter',
          ),
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
        Icon(icon, size: 18.sp, color: AppTheme.primary),
        SizedBox(width: 6.w),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, fontFamily: 'Inter')),
      ],
    );
  }
}

class _PreviewDialog extends StatelessWidget {
  final String question;
  final List<String> answers;
  final String? imageUrl;
  final String? bankName;

  const _PreviewDialog({
    required this.question,
    required this.answers,
    this.imageUrl,
    this.bankName,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.visibility_outlined, color: Colors.white),
                  SizedBox(width: 8.w),
                  Text('题目预览', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16.sp, fontFamily: 'Inter')),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (bankName != null) ...[
                      _TagChip(label: bankName!, selected: false, onTap: () {}),
                      SizedBox(height: 12.h),
                    ],
                    Text('题目详情', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Inter')),
                    SizedBox(height: 8.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(14.w),
                      decoration: BoxDecoration(
                        color: AppTheme.bgSection,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: QuestionRichText(text: question, fontSize: 16),
                    ),
                    SizedBox(height: 16.h),
                    Text('答案', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Inter')),
                    SizedBox(height: 8.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(14.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: answers.isEmpty
                            ? [Text('无答案', style: TextStyle(color: AppTheme.textTertiary))]
                            : answers.asMap().entries.map((e) => Padding(
                                padding: EdgeInsets.only(bottom: 4.h),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 20.w,
                                      height: 20.w,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF86EFAC),
                                        borderRadius: BorderRadius.circular(5.r),
                                      ),
                                      child: Center(
                                        child: Text('${e.key + 1}', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold, color: const Color(0xFF166534), fontFamily: 'Inter')),
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(e.value, style: TextStyle(fontSize: 14.sp, fontFamily: 'Inter')),
                                  ],
                                ),
                              )).toList(),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    if (imageUrl != null && imageUrl!.isNotEmpty) ...[
                      Text('图片', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Inter')),
                      SizedBox(height: 8.h),
                      GestureDetector(
                        onTap: () => QuestionRichText.showFullScreenImage(context, imageUrl!),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12.r),
                          child: Image.network(
                            imageUrl!,
                            fit: BoxFit.contain,
                            height: 200.h,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) => Container(
                              height: 80.h,
                              width: double.infinity,
                              color: AppTheme.bgSection,
                              child: Center(
                                child: Text('图片加载失败', style: TextStyle(color: AppTheme.textTertiary, fontSize: 13.sp)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 20.h),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
