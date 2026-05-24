import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'question_rich_text.dart';
import '../theme/desktop_theme.dart';

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
  String? _categoryId;
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
      _categoryId = widget.qa!.categoryId;
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
        bankName: _categoryName,
      ),
    );
  }

  String get _categoryName {
    if (_categoryId == null) return '未分类';
    final bank = _banks.where((b) => b.id == _categoryId).firstOrNull;
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
        'category_id': _categoryId,
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
      appBar: AppBar(
        title: Text(widget.qa == null ? '新增题目' : '编辑题目', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.visibility_outlined, size: 20),
            onPressed: _showPreview,
            tooltip: '预览',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question section
            _SectionHeader(icon: Icons.edit_note_outlined, label: '题目'),
            const SizedBox(height: 8),

            // Toolbar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: DesktopTheme.bgSection,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _toolbarChip('填空', _insertBlank),
                  _toolbarChip('加粗', _insertBold),
                  _toolbarChip('高亮', _insertHighlight),
                  _toolbarChip('代码', _insertCode),
                  _toolbarChip('分割线', _insertDivider),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Question input
            TextField(
              controller: _questionCtrl,
              focusNode: _questionFocus,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: '输入题目，用 ___ 表示填空',
                filled: true,
                fillColor: DesktopTheme.bgCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: DesktopTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: DesktopTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: DesktopTheme.primary, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            const SizedBox(height: 8),

            // Blank count hint
            if (_blankCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: DesktopTheme.indigo50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '共 $_blankCount 个填空，已自动生成 $_blankCount 个答案输入框',
                  style: const TextStyle(fontSize: 12, color: DesktopTheme.primary),
                ),
              ),
            const SizedBox(height: 24),

            // Answer section
            Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 18, color: DesktopTheme.primary),
                const SizedBox(width: 6),
                const Text('答案', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_circle_outlined, color: DesktopTheme.primary, size: 22),
                  onPressed: _addAnswerField,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_answerCtrls.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: DesktopTheme.bgSection,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.add_circle_outline, size: 32, color: DesktopTheme.textTertiary),
                    SizedBox(height: 8),
                    Text('点击 + 添加答案，或在题目中输入 ___', style: TextStyle(color: DesktopTheme.textTertiary, fontSize: 13)),
                  ],
                ),
              )
            else
              ...List.generate(_answerCtrls.length, (i) => Padding(
                padding: EdgeInsets.only(bottom: i < _answerCtrls.length - 1 ? 10 : 0),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: DesktopTheme.indigo50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text('${i + 1}', style: const TextStyle(color: DesktopTheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _answerCtrls[i],
                        decoration: InputDecoration(
                          hintText: '空${i + 1} 的答案',
                          filled: true,
                          fillColor: DesktopTheme.bgCard,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: DesktopTheme.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: DesktopTheme.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: DesktopTheme.primary, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: DesktopTheme.red, size: 18),
                      onPressed: () => _removeAnswerField(i),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              )),
            const SizedBox(height: 24),

            // Image URL
            _SectionHeader(icon: Icons.image_outlined, label: '图片'),
            const SizedBox(height: 8),
            TextField(
              onChanged: (v) => _imageUrl = v.isEmpty ? null : v,
              decoration: InputDecoration(
                hintText: '输入图片URL（可选）',
                filled: true,
                fillColor: DesktopTheme.bgCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: DesktopTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: DesktopTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: DesktopTheme.primary, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 24),

            // Bank
            _SectionHeader(icon: Icons.folder_outlined, label: '题库'),
            const SizedBox(height: 8),
            _banks.isEmpty
                ? const Center(child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ))
                : DropdownButtonFormField<String>(
                    value: _categoryId,
                    decoration: InputDecoration(
                      hintText: '选择题库',
                      filled: true,
                      fillColor: DesktopTheme.bgCard,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: DesktopTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: DesktopTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: DesktopTheme.primary, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('未分类')),
                      ..._banks.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
                    ],
                    onChanged: (v) => setState(() => _categoryId = v),
                  ),
            const SizedBox(height: 24),

            // Tags
            _SectionHeader(icon: Icons.label_outlined, label: '标签'),
            const SizedBox(height: 8),
            _tags.isEmpty
                ? const Text('暂无标签', style: TextStyle(color: DesktopTheme.textTertiary, fontSize: 13))
                : Wrap(
                    spacing: 8,
                    runSpacing: 6,
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
            const SizedBox(height: 40),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('保存', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _toolbarChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: DesktopTheme.bgCard,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: DesktopTheme.border),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12, color: DesktopTheme.textSecondary)),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? DesktopTheme.indigo50 : DesktopTheme.bgSection,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? DesktopTheme.indigo100 : DesktopTheme.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? DesktopTheme.primary : DesktopTheme.textSecondary,
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
        Icon(icon, size: 18, color: DesktopTheme.primary),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: DesktopTheme.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.visibility_outlined, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text('题目预览', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (bankName != null) ...[
                      _TagChip(label: bankName!, selected: false, onTap: () {}),
                      const SizedBox(height: 12),
                    ],
                    const Text('题目详情', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: DesktopTheme.bgSection,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: QuestionRichText(text: question, fontSize: 15),
                    ),
                    const SizedBox(height: 16),
                    const Text('答案', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: answers.isEmpty
                            ? [const Text('无答案', style: TextStyle(color: DesktopTheme.textTertiary))]
                            : answers.asMap().entries.map((e) => Padding(
                                padding: EdgeInsets.only(bottom: e.key < answers.length - 1 ? 4 : 0),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF86EFAC),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Center(
                                        child: Text('${e.key + 1}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(e.value, style: const TextStyle(fontSize: 14)),
                                  ],
                                ),
                              )).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (imageUrl != null && imageUrl!.isNotEmpty) ...[
                      const Text('图片', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => QuestionRichText.showFullScreenImage(context, imageUrl!),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            imageUrl!,
                            fit: BoxFit.contain,
                            height: 200,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) => Container(
                              height: 80,
                              width: double.infinity,
                              color: DesktopTheme.bgSection,
                              child: const Center(
                                child: Text('图片加载失败', style: TextStyle(color: DesktopTheme.textTertiary, fontSize: 13)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
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
