     1|import 'package:flutter/material.dart';
     2|import '../models/models.dart';
     3|import '../services/api_service.dart';
     4|import 'question_rich_text.dart';
     5|import '../theme/desktop_theme.dart';
     6|
     7|class QaFormPage extends StatefulWidget {
     8|  final KbQa? qa;
     9|  const QaFormPage({super.key, this.qa});
    10|
    11|  @override
    12|  State<QaFormPage> createState() => _QaFormPageState();
    13|}
    14|
    15|class _QaFormPageState extends State<QaFormPage> {
    16|  final _questionCtrl = TextEditingController();
    17|  final List<TextEditingController> _answerCtrls = [];
    18|  final _questionFocus = FocusNode();
    19|  String? _imageUrl;
    20|  String? _categoryId;
    21|  List<String> _tagIds = [];
    22|  List<KbBank> _banks = [];
    23|  List<KbTag> _tags = [];
    24|  bool _saving = false;
    25|  int _blankCount = 0;
    26|
    27|  @override
    28|  void initState() {
    29|    super.initState();
    30|    if (widget.qa != null) {
    31|      _questionCtrl.text = widget.qa!.question;
    32|      for (final a in widget.qa!.answer) {
    33|        _answerCtrls.add(TextEditingController(text: a));
    34|      }
    35|      _imageUrl = widget.qa!.imageUrl;
    36|      _categoryId = widget.qa!.categoryId;
    37|      _tagIds = widget.qa!.tagId ?? [];
    38|      _blankCount = '___'.allMatches(widget.qa!.question).length;
    39|    }
    40|    _questionCtrl.addListener(_onQuestionChanged);
    41|    _loadMeta();
    42|  }
    43|
    44|  void _onQuestionChanged() {
    45|    final text = _questionCtrl.text;
    46|    final blankCount = '___'.allMatches(text).length;
    47|    if (blankCount != _blankCount) {
    48|      _blankCount = blankCount;
    49|      _syncAnswerFields();
    50|    }
    51|  }
    52|
    53|  void _syncAnswerFields() {
    54|    if (_blankCount > _answerCtrls.length) {
    55|      while (_answerCtrls.length < _blankCount) {
    56|        _answerCtrls.add(TextEditingController());
    57|      }
    58|    } else if (_blankCount < _answerCtrls.length) {
    59|      while (_answerCtrls.length > _blankCount) {
    60|        _answerCtrls.removeLast().dispose();
    61|      }
    62|    }
    63|    setState(() {});
    64|  }
    65|
    66|  void _insertAtCursor(String before, [String? after]) {
    67|    final text = _questionCtrl.text;
    68|    final selection = _questionCtrl.selection;
    69|    final selectedText = selection.textInside(text);
    70|    String newText;
    71|    int newOffset;
    72|
    73|    if (selectedText.isNotEmpty) {
    74|      newText = text.replaceRange(selection.start, selection.end, '$before$selectedText${after ?? before}');
    75|      newOffset = selection.start + before.length + selectedText.length + (after ?? before).length;
    76|    } else if (after != null) {
    77|      newText = text.replaceRange(selection.start, selection.end, '$before$after');
    78|      newOffset = selection.start + before.length;
    79|    } else {
    80|      newText = text.replaceRange(selection.start, selection.end, before);
    81|      newOffset = selection.start + before.length;
    82|    }
    83|
    84|    _questionCtrl.text = newText;
    85|    _questionCtrl.selection = TextSelection.collapsed(offset: newOffset);
    86|  }
    87|
    88|  void _insertBlank() => _insertAtCursor('___');
    89|  void _insertBold() => _insertAtCursor('**');
    90|  void _insertHighlight() => _insertAtCursor('==');
    91|  void _insertCode() => _insertAtCursor('`');
    92|  void _insertDivider() {
    93|    final text = _questionCtrl.text;
    94|    final selection = _questionCtrl.selection;
    95|    String newText;
    96|    int newOffset;
    97|
    98|    if (selection.start > 0 && text[selection.start - 1] != '\n') {
    99|      newText = text.replaceRange(selection.start, selection.end, '\n----\n');
   100|      newOffset = selection.start + 7;
   101|    } else {
   102|      newText = text.replaceRange(selection.start, selection.end, '----\n');
   103|      newOffset = selection.start + 5;
   104|    }
   105|
   106|    _questionCtrl.text = newText;
   107|    _questionCtrl.selection = TextSelection.collapsed(offset: newOffset);
   108|  }
   109|
   110|  void _showPreview() {
   111|    showDialog(
   112|      context: context,
   113|      builder: (_) => _PreviewDialog(
   114|        question: _questionCtrl.text,
   115|        answers: _answerCtrls.map((c) => c.text).toList(),
   116|        imageUrl: _imageUrl,
   117|        categoryName: _categoryName,
   118|      ),
   119|    );
   120|  }
   121|
   122|  String get _categoryName {
   123|    if (_categoryId == null) return '未分类';
   124|    final bank = _banks.where((b) => b.id == _categoryId).firstOrNull;
   125|    return bank?.name ?? '未知';
   126|  }
   127|
   128|  Future<void> _loadMeta() async {
   129|    try {
   130|      final bankData = await ApiService.pageBanks(pageSize: 100);
   131|      final tagData = await ApiService.pageTags(pageSize: 100);
   132|      setState(() {
   133|        _banks = (bankData['items'] as List).map((e) => KbBank.fromJson(e)).toList();
   134|        _tags = (tagData['items'] as List).map((e) => KbTag.fromJson(e)).toList();
   135|      });
   136|    } catch (_) {}
   137|  }
   138|
   139|  void _addAnswerField() {
   140|    setState(() => _answerCtrls.add(TextEditingController()));
   141|  }
   142|
   143|  void _removeAnswerField(int index) {
   144|    setState(() {
   145|      _answerCtrls[index].dispose();
   146|      _answerCtrls.removeAt(index);
   147|    });
   148|  }
   149|
   150|  Future<void> _save() async {
   151|    if (_questionCtrl.text.isEmpty) {
   152|      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入题目')));
   153|      return;
   154|    }
   155|    final answers = _answerCtrls.map((c) => c.text).where((t) => t.isNotEmpty).toList();
   156|    if (answers.isEmpty) {
   157|      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请至少填写一个答案')));
   158|      return;
   159|    }
   160|
   161|    setState(() => _saving = true);
   162|    try {
   163|      final data = {
   164|        'question': _questionCtrl.text,
   165|        'answer': answers,
   166|        'image_url': _imageUrl,
   167|        'category_id': _categoryId,
   168|        'tag_id': _tagIds.isNotEmpty ? _tagIds : null,
   169|      };
   170|
   171|      if (widget.qa == null) {
   172|        await ApiService.createQa(data);
   173|      } else {
   174|        await ApiService.updateQa(widget.qa!.id, data);
   175|      }
   176|
   177|      if (mounted) Navigator.pop(context);
   178|    } catch (e) {
   179|      if (mounted) {
   180|        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败: $e')));
   181|      }
   182|    } finally {
   183|      setState(() => _saving = false);
   184|    }
   185|  }
   186|
   187|  @override
   188|  void dispose() {
   189|    _questionCtrl.removeListener(_onQuestionChanged);
   190|    _questionCtrl.dispose();
   191|    _questionFocus.dispose();
   192|    for (final c in _answerCtrls) {
   193|      c.dispose();
   194|    }
   195|    super.dispose();
   196|  }
   197|
   198|  @override
   199|  Widget build(BuildContext context) {
   200|    return Scaffold(
   201|      appBar: AppBar(
   202|        title: Text(widget.qa == null ? '新增题目' : '编辑题目', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
   203|        centerTitle: true,
   204|        leading: IconButton(
   205|          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
   206|          onPressed: () => Navigator.pop(context),
   207|        ),
   208|        actions: [
   209|          IconButton(
   210|            icon: const Icon(Icons.visibility_outlined, size: 20),
   211|            onPressed: _showPreview,
   212|            tooltip: '预览',
   213|          ),
   214|        ],
   215|      ),
   216|      body: SingleChildScrollView(
   217|        padding: const EdgeInsets.all(24),
   218|        child: Column(
   219|          crossAxisAlignment: CrossAxisAlignment.start,
   220|          children: [
   221|            // Question section
   222|            _SectionHeader(icon: Icons.edit_note_outlined, label: '题目'),
   223|            const SizedBox(height: 8),
   224|
   225|            // Toolbar
   226|            Container(
   227|              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
   228|              decoration: BoxDecoration(
   229|                color: DesktopTheme.bgSection,
   230|                borderRadius: BorderRadius.circular(6),
   231|              ),
   232|              child: Wrap(
   233|                spacing: 6,
   234|                runSpacing: 4,
   235|                children: [
   236|                  _toolbarChip('填空', _insertBlank),
   237|                  _toolbarChip('加粗', _insertBold),
   238|                  _toolbarChip('高亮', _insertHighlight),
   239|                  _toolbarChip('代码', _insertCode),
   240|                  _toolbarChip('分割线', _insertDivider),
   241|                ],
   242|              ),
   243|            ),
   244|            const SizedBox(height: 8),
   245|
   246|            // Question input
   247|            TextField(
   248|              controller: _questionCtrl,
   249|              focusNode: _questionFocus,
   250|              maxLines: 4,
   251|              decoration: InputDecoration(
   252|                hintText: '输入题目，用 ___ 表示填空',
   253|                filled: true,
   254|                fillColor: DesktopTheme.bgCard,
   255|                border: OutlineInputBorder(
   256|                  borderRadius: BorderRadius.circular(6),
   257|                  borderSide: const BorderSide(color: DesktopTheme.border),
   258|                ),
   259|                enabledBorder: OutlineInputBorder(
   260|                  borderRadius: BorderRadius.circular(6),
   261|                  borderSide: const BorderSide(color: DesktopTheme.border),
   262|                ),
   263|                focusedBorder: OutlineInputBorder(
   264|                  borderRadius: BorderRadius.circular(6),
   265|                  borderSide: const BorderSide(color: DesktopTheme.primary, width: 2),
   266|                ),
   267|                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
   268|              ),
   269|              onChanged: (text) {
   270|                if (text.contains('   ')) {
   271|                  final newText = text.replaceAll('   ', '___');
   272|                  if (newText != text) {
   273|                    _questionCtrl.text = newText;
   274|                    _questionCtrl.selection = TextSelection.collapsed(offset: _questionCtrl.text.length);
   275|                  }
   276|                }
   277|              },
   278|            ),
   279|            const SizedBox(height: 8),
   280|
   281|            // Blank count hint
   282|            if (_blankCount > 0)
   283|              Container(
   284|                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
   285|                decoration: BoxDecoration(
   286|                  color: DesktopTheme.indigo50,
   287|                  borderRadius: BorderRadius.circular(12),
   288|                ),
   289|                child: Text(
   290|                  '共 $_blankCount 个填空，已自动生成 $_blankCount 个答案输入框',
   291|                  style: const TextStyle(fontSize: 12, color: DesktopTheme.primary),
   292|                ),
   293|              ),
   294|            const SizedBox(height: 24),
   295|
   296|            // Answer section
   297|            Row(
   298|              children: [
   299|                const Icon(Icons.check_circle_outline, size: 18, color: DesktopTheme.primary),
   300|                const SizedBox(width: 6),
   301|                const Text('答案', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
   302|                const Spacer(),
   303|                IconButton(
   304|                  icon: const Icon(Icons.add_circle_outlined, color: DesktopTheme.primary, size: 22),
   305|                  onPressed: _addAnswerField,
   306|                  padding: EdgeInsets.zero,
   307|                  constraints: const BoxConstraints(),
   308|                ),
   309|              ],
   310|            ),
   311|            const SizedBox(height: 8),
   312|            if (_answerCtrls.isEmpty)
   313|              Container(
   314|                width: double.infinity,
   315|                padding: const EdgeInsets.all(24),
   316|                decoration: BoxDecoration(
   317|                  color: DesktopTheme.bgSection,
   318|                  borderRadius: BorderRadius.circular(8),
   319|                ),
   320|                child: const Column(
   321|                  children: [
   322|                    Icon(Icons.add_circle_outline, size: 32, color: DesktopTheme.textTertiary),
   323|                    SizedBox(height: 8),
   324|                    Text('点击 + 添加答案，或在题目中输入 ___', style: TextStyle(color: DesktopTheme.textTertiary, fontSize: 13)),
   325|                  ],
   326|                ),
   327|              )
   328|            else
   329|              ...List.generate(_answerCtrls.length, (i) => Padding(
   330|                padding: EdgeInsets.only(bottom: i < _answerCtrls.length - 1 ? 10 : 0),
   331|                child: Row(
   332|                  children: [
   333|                    Container(
   334|                      width: 28,
   335|                      height: 28,
   336|                      decoration: BoxDecoration(
   337|                        color: DesktopTheme.indigo50,
   338|                        borderRadius: BorderRadius.circular(8),
   339|                      ),
   340|                      child: Center(
   341|                        child: Text('${i + 1}', style: const TextStyle(color: DesktopTheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
   342|                      ),
   343|                    ),
   344|                    const SizedBox(width: 10),
   345|                    Expanded(
   346|                      child: TextField(
   347|                        controller: _answerCtrls[i],
   348|                        decoration: InputDecoration(
   349|                          hintText: '空${i + 1} 的答案',
   350|                          filled: true,
   351|                          fillColor: DesktopTheme.bgCard,
   352|                          border: OutlineInputBorder(
   353|                            borderRadius: BorderRadius.circular(6),
   354|                            borderSide: const BorderSide(color: DesktopTheme.border),
   355|                          ),
   356|                          enabledBorder: OutlineInputBorder(
   357|                            borderRadius: BorderRadius.circular(6),
   358|                            borderSide: const BorderSide(color: DesktopTheme.border),
   359|                          ),
   360|                          focusedBorder: OutlineInputBorder(
   361|                            borderRadius: BorderRadius.circular(6),
   362|                            borderSide: const BorderSide(color: DesktopTheme.primary, width: 2),
   363|                          ),
   364|                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
   365|                        ),
   366|                      ),
   367|                    ),
   368|                    const SizedBox(width: 4),
   369|                    IconButton(
   370|                      icon: const Icon(Icons.remove_circle_outline, color: DesktopTheme.red, size: 18),
   371|                      onPressed: () => _removeAnswerField(i),
   372|                      padding: EdgeInsets.zero,
   373|                      constraints: const BoxConstraints(),
   374|                    ),
   375|                  ],
   376|                ),
   377|              )),
   378|            const SizedBox(height: 24),
   379|
   380|            // Image URL
   381|            _SectionHeader(icon: Icons.image_outlined, label: '图片'),
   382|            const SizedBox(height: 8),
   383|            TextField(
   384|              onChanged: (v) => _imageUrl = v.isEmpty ? null : v,
   385|              decoration: InputDecoration(
   386|                hintText: '输入图片URL（可选）',
   387|                filled: true,
   388|                fillColor: DesktopTheme.bgCard,
   389|                border: OutlineInputBorder(
   390|                  borderRadius: BorderRadius.circular(6),
   391|                  borderSide: const BorderSide(color: DesktopTheme.border),
   392|                ),
   393|                enabledBorder: OutlineInputBorder(
   394|                  borderRadius: BorderRadius.circular(6),
   395|                  borderSide: const BorderSide(color: DesktopTheme.border),
   396|                ),
   397|                focusedBorder: OutlineInputBorder(
   398|                  borderRadius: BorderRadius.circular(6),
   399|                  borderSide: const BorderSide(color: DesktopTheme.primary, width: 2),
   400|                ),
   401|                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
   402|              ),
   403|            ),
   404|            const SizedBox(height: 24),
   405|
   406|            // Bank
   407|            _SectionHeader(icon: Icons.folder_outlined, label: '题库'),
   408|            const SizedBox(height: 8),
   409|            _banks.isEmpty
   410|                ? const Center(child: Padding(
   411|                    padding: EdgeInsets.symmetric(vertical: 12),
   412|                    child: CircularProgressIndicator(strokeWidth: 2),
   413|                  ))
   414|                : DropdownButtonFormField<String>(
   415|                    value: _categoryId,
   416|                    decoration: InputDecoration(
   417|                      hintText: '选择题库',
   418|                      filled: true,
   419|                      fillColor: DesktopTheme.bgCard,
   420|                      border: OutlineInputBorder(
   421|                        borderRadius: BorderRadius.circular(6),
   422|                        borderSide: const BorderSide(color: DesktopTheme.border),
   423|                      ),
   424|                      enabledBorder: OutlineInputBorder(
   425|                        borderRadius: BorderRadius.circular(6),
   426|                        borderSide: const BorderSide(color: DesktopTheme.border),
   427|                      ),
   428|                      focusedBorder: OutlineInputBorder(
   429|                        borderRadius: BorderRadius.circular(6),
   430|                        borderSide: const BorderSide(color: DesktopTheme.primary, width: 2),
   431|                      ),
   432|                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
   433|                    ),
   434|                    items: [
   435|                      const DropdownMenuItem(value: null, child: Text('未分类')),
   436|                      ..._banks.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
   437|                    ],
   438|                    onChanged: (v) => setState(() => _categoryId = v),
   439|                  ),
   440|            const SizedBox(height: 24),
   441|
   442|            // Tags
   443|            _SectionHeader(icon: Icons.label_outlined, label: '标签'),
   444|            const SizedBox(height: 8),
   445|            _tags.isEmpty
   446|                ? const Text('暂无标签', style: TextStyle(color: DesktopTheme.textTertiary, fontSize: 13))
   447|                : Wrap(
   448|                    spacing: 8,
   449|                    runSpacing: 6,
   450|                    children: _tags.map((tag) {
   451|                      final selected = _tagIds.contains(tag.id);
   452|                      return _TagChip(
   453|                        label: tag.name,
   454|                        selected: selected,
   455|                        onTap: () {
   456|                          setState(() {
   457|                            if (selected) {
   458|                              _tagIds.remove(tag.id);
   459|                            } else {
   460|                              _tagIds.add(tag.id);
   461|                            }
   462|                          });
   463|                        },
   464|                      );
   465|                    }).toList(),
   466|                  ),
   467|            const SizedBox(height: 40),
   468|
   469|            // Save button
   470|            SizedBox(
   471|              width: double.infinity,
   472|              height: 48,
   473|              child: ElevatedButton(
   474|                onPressed: _saving ? null : _save,
   475|                child: _saving
   476|                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
   477|                    : const Text('保存', style: TextStyle(fontWeight: FontWeight.w600)),
   478|              ),
   479|            ),
   480|            const SizedBox(height: 24),
   481|          ],
   482|        ),
   483|      ),
   484|    );
   485|  }
   486|
   487|  Widget _toolbarChip(String label, VoidCallback onTap) {
   488|    return GestureDetector(
   489|      onTap: onTap,
   490|      child: Container(
   491|        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
   492|        decoration: BoxDecoration(
   493|          color: DesktopTheme.bgCard,
   494|          borderRadius: BorderRadius.circular(6),
   495|          border: Border.all(color: DesktopTheme.border),
   496|        ),
   497|        child: Text(label, style: const TextStyle(fontSize: 12, color: DesktopTheme.textSecondary)),
   498|      ),
   499|    );
   500|  }
   501|}
   502|
   503|class _TagChip extends StatelessWidget {
   504|  final String label;
   505|  final bool selected;
   506|  final VoidCallback onTap;
   507|
   508|  const _TagChip({required this.label, required this.selected, required this.onTap});
   509|
   510|  @override
   511|  Widget build(BuildContext context) {
   512|    return GestureDetector(
   513|      onTap: onTap,
   514|      child: Container(
   515|        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
   516|        decoration: BoxDecoration(
   517|          color: selected ? DesktopTheme.indigo50 : DesktopTheme.bgSection,
   518|          borderRadius: BorderRadius.circular(16),
   519|          border: Border.all(
   520|            color: selected ? DesktopTheme.indigo100 : DesktopTheme.border,
   521|            width: 1,
   522|          ),
   523|        ),
   524|        child: Text(
   525|          label,
   526|          style: TextStyle(
   527|            fontSize: 12,
   528|            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
   529|            color: selected ? DesktopTheme.primary : DesktopTheme.textSecondary,
   530|          ),
   531|        ),
   532|      ),
   533|    );
   534|  }
   535|}
   536|
   537|class _SectionHeader extends StatelessWidget {
   538|  final IconData icon;
   539|  final String label;
   540|
   541|  const _SectionHeader({required this.icon, required this.label});
   542|
   543|  @override
   544|  Widget build(BuildContext context) {
   545|    return Row(
   546|      children: [
   547|        Icon(icon, size: 18, color: DesktopTheme.primary),
   548|        const SizedBox(width: 6),
   549|        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
   550|      ],
   551|    );
   552|  }
   553|}
   554|
   555|class _PreviewDialog extends StatelessWidget {
   556|  final String question;
   557|  final List<String> answers;
   558|  final String? imageUrl;
   559|  final String? categoryName;
   560|
   561|  const _PreviewDialog({
   562|    required this.question,
   563|    required this.answers,
   564|    this.imageUrl,
   565|    this.categoryName,
   566|  });
   567|
   568|  @override
   569|  Widget build(BuildContext context) {
   570|    return Dialog(
   571|      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
   572|      child: Container(
   573|        constraints: const BoxConstraints(maxHeight: 600),
   574|        child: Column(
   575|          mainAxisSize: MainAxisSize.min,
   576|          crossAxisAlignment: CrossAxisAlignment.start,
   577|          children: [
   578|            // Header
   579|            Container(
   580|              padding: const EdgeInsets.all(16),
   581|              decoration: const BoxDecoration(
   582|                color: DesktopTheme.primary,
   583|                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
   584|              ),
   585|              child: Row(
   586|                children: [
   587|                  const Icon(Icons.visibility_outlined, color: Colors.white),
   588|                  const SizedBox(width: 8),
   589|                  const Text('题目预览', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
   590|                  const Spacer(),
   591|                  IconButton(
   592|                    icon: const Icon(Icons.close, color: Colors.white),
   593|                    onPressed: () => Navigator.pop(context),
   594|                  ),
   595|                ],
   596|              ),
   597|            ),
   598|            // Content
   599|            Flexible(
   600|              child: SingleChildScrollView(
   601|                padding: const EdgeInsets.all(16),
   602|                child: Column(
   603|                  crossAxisAlignment: CrossAxisAlignment.start,
   604|                  children: [
   605|                    if (categoryName != null) ...[
   606|                      _TagChip(label: categoryName!, selected: false, onTap: () {}),
   607|                      const SizedBox(height: 12),
   608|                    ],
   609|                    const Text('题目详情', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
   610|                    const SizedBox(height: 8),
   611|                    Container(
   612|                      width: double.infinity,
   613|                      padding: const EdgeInsets.all(14),
   614|                      decoration: BoxDecoration(
   615|                        color: DesktopTheme.bgSection,
   616|                        borderRadius: BorderRadius.circular(8),
   617|                      ),
   618|                      child: QuestionRichText(text: question, fontSize: 15),
   619|                    ),
   620|                    const SizedBox(height: 16),
   621|                    const Text('答案', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
   622|                    const SizedBox(height: 8),
   623|                    Container(
   624|                      width: double.infinity,
   625|                      padding: const EdgeInsets.all(14),
   626|                      decoration: BoxDecoration(
   627|                        color: const Color(0xFFF0FDF4),
   628|                        borderRadius: BorderRadius.circular(8),
   629|                        border: Border.all(color: const Color(0xFFBBF7D0)),
   630|                      ),
   631|                      child: Column(
   632|                        crossAxisAlignment: CrossAxisAlignment.start,
   633|                        children: answers.isEmpty
   634|                            ? [const Text('无答案', style: TextStyle(color: DesktopTheme.textTertiary))]
   635|                            : answers.asMap().entries.map((e) => Padding(
   636|                                padding: EdgeInsets.only(bottom: e.key < answers.length - 1 ? 4 : 0),
   637|                                child: Row(
   638|                                  children: [
   639|                                    Container(
   640|                                      width: 20,
   641|                                      height: 20,
   642|                                      decoration: BoxDecoration(
   643|                                        color: const Color(0xFF86EFAC),
   644|                                        borderRadius: BorderRadius.circular(5),
   645|                                      ),
   646|                                      child: Center(
   647|                                        child: Text('${e.key + 1}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
   648|                                      ),
   649|                                    ),
   650|                                    const SizedBox(width: 8),
   651|                                    Text(e.value, style: const TextStyle(fontSize: 14)),
   652|                                  ],
   653|                                ),
   654|                              )).toList(),
   655|                      ),
   656|                    ),
   657|                    const SizedBox(height: 16),
   658|                    if (imageUrl != null && imageUrl!.isNotEmpty) ...[
   659|                      const Text('图片', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
   660|                      const SizedBox(height: 8),
   661|                      GestureDetector(
   662|                        onTap: () => QuestionRichText.showFullScreenImage(context, imageUrl!),
   663|                        child: ClipRRect(
   664|                          borderRadius: BorderRadius.circular(8),
   665|                          child: Image.network(
   666|                            imageUrl!,
   667|                            fit: BoxFit.contain,
   668|                            height: 200,
   669|                            width: double.infinity,
   670|                            errorBuilder: (_, __, ___) => Container(
   671|                              height: 80,
   672|                              width: double.infinity,
   673|                              color: DesktopTheme.bgSection,
   674|                              child: const Center(
   675|                                child: Text('图片加载失败', style: TextStyle(color: DesktopTheme.textTertiary, fontSize: 13)),
   676|                              ),
   677|                            ),
   678|                          ),
   679|                        ),
   680|                      ),
   681|                      const SizedBox(height: 20),
   682|                    ],
   683|                  ],
   684|                ),
   685|              ),
   686|            ),
   687|          ],
   688|        ),
   689|      ),
   690|    );
   691|  }
   692|}
   693|