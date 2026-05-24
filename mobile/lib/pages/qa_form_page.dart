     1|import 'package:flutter/material.dart';
     2|import 'package:flutter_screenutil/flutter_screenutil.dart';
     3|import '../models/models.dart';
     4|import '../services/api_service.dart';
     5|import 'question_rich_text.dart';
     6|import '../theme/app_theme.dart';
     7|
     8|class QaFormPage extends StatefulWidget {
     9|  final KbQa? qa;
    10|  const QaFormPage({super.key, this.qa});
    11|
    12|  @override
    13|  State<QaFormPage> createState() => _QaFormPageState();
    14|}
    15|
    16|class _QaFormPageState extends State<QaFormPage> {
    17|  final _questionCtrl = TextEditingController();
    18|  final List<TextEditingController> _answerCtrls = [];
    19|  final _questionFocus = FocusNode();
    20|  String? _imageUrl;
    21|  String? _categoryId;
    22|  List<String> _tagIds = [];
    23|  List<KbBank> _banks = [];
    24|  List<KbTag> _tags = [];
    25|  bool _saving = false;
    26|  int _blankCount = 0;
    27|
    28|  @override
    29|  void initState() {
    30|    super.initState();
    31|    if (widget.qa != null) {
    32|      _questionCtrl.text = widget.qa!.question;
    33|      for (final a in widget.qa!.answer) {
    34|        _answerCtrls.add(TextEditingController(text: a));
    35|      }
    36|      _imageUrl = widget.qa!.imageUrl;
    37|      _categoryId = widget.qa!.categoryId;
    38|      _tagIds = widget.qa!.tagId ?? [];
    39|      _blankCount = '___'.allMatches(widget.qa!.question).length;
    40|    }
    41|    _questionCtrl.addListener(_onQuestionChanged);
    42|    _loadMeta();
    43|  }
    44|
    45|  void _onQuestionChanged() {
    46|    final text = _questionCtrl.text;
    47|    final blankCount = '___'.allMatches(text).length;
    48|    if (blankCount != _blankCount) {
    49|      _blankCount = blankCount;
    50|      _syncAnswerFields();
    51|    }
    52|  }
    53|
    54|  void _syncAnswerFields() {
    55|    if (_blankCount > _answerCtrls.length) {
    56|      while (_answerCtrls.length < _blankCount) {
    57|        _answerCtrls.add(TextEditingController());
    58|      }
    59|    } else if (_blankCount < _answerCtrls.length) {
    60|      while (_answerCtrls.length > _blankCount) {
    61|        _answerCtrls.removeLast().dispose();
    62|      }
    63|    }
    64|    setState(() {});
    65|  }
    66|
    67|  void _insertAtCursor(String before, [String? after]) {
    68|    final text = _questionCtrl.text;
    69|    final selection = _questionCtrl.selection;
    70|    final selectedText = selection.textInside(text);
    71|    String newText;
    72|    int newOffset;
    73|
    74|    if (selectedText.isNotEmpty) {
    75|      newText = text.replaceRange(selection.start, selection.end, '$before$selectedText${after ?? before}');
    76|      newOffset = selection.start + before.length + selectedText.length + (after ?? before).length;
    77|    } else if (after != null) {
    78|      newText = text.replaceRange(selection.start, selection.end, '$before$after');
    79|      newOffset = selection.start + before.length;
    80|    } else {
    81|      newText = text.replaceRange(selection.start, selection.end, before);
    82|      newOffset = selection.start + before.length;
    83|    }
    84|
    85|    _questionCtrl.text = newText;
    86|    _questionCtrl.selection = TextSelection.collapsed(offset: newOffset);
    87|  }
    88|
    89|  void _insertBlank() => _insertAtCursor('___');
    90|  void _insertBold() => _insertAtCursor('**');
    91|  void _insertHighlight() => _insertAtCursor('==');
    92|  void _insertCode() => _insertAtCursor('`');
    93|  void _insertDivider() {
    94|    final text = _questionCtrl.text;
    95|    final selection = _questionCtrl.selection;
    96|    String newText;
    97|    int newOffset;
    98|
    99|    if (selection.start > 0 && text[selection.start - 1] != '\n') {
   100|      newText = text.replaceRange(selection.start, selection.end, '\n----\n');
   101|      newOffset = selection.start + 7;
   102|    } else {
   103|      newText = text.replaceRange(selection.start, selection.end, '----\n');
   104|      newOffset = selection.start + 5;
   105|    }
   106|
   107|    _questionCtrl.text = newText;
   108|    _questionCtrl.selection = TextSelection.collapsed(offset: newOffset);
   109|  }
   110|
   111|  void _showPreview() {
   112|    showDialog(
   113|      context: context,
   114|      builder: (_) => _PreviewDialog(
   115|        question: _questionCtrl.text,
   116|        answers: _answerCtrls.map((c) => c.text).toList(),
   117|        imageUrl: _imageUrl,
   118|        categoryName: _categoryName,
   119|      ),
   120|    );
   121|  }
   122|
   123|  String get _categoryName {
   124|    if (_categoryId == null) return '未分类';
   125|    final bank = _banks.where((b) => b.id == _categoryId).firstOrNull;
   126|    return bank?.name ?? '未知';
   127|  }
   128|
   129|  Future<void> _loadMeta() async {
   130|    try {
   131|      final bankData = await ApiService.pageBanks(pageSize: 100);
   132|      final tagData = await ApiService.pageTags(pageSize: 100);
   133|      setState(() {
   134|        _banks = (bankData['items'] as List).map((e) => KbBank.fromJson(e)).toList();
   135|        _tags = (tagData['items'] as List).map((e) => KbTag.fromJson(e)).toList();
   136|      });
   137|    } catch (_) {}
   138|  }
   139|
   140|  void _addAnswerField() {
   141|    setState(() => _answerCtrls.add(TextEditingController()));
   142|  }
   143|
   144|  void _removeAnswerField(int index) {
   145|    setState(() {
   146|      _answerCtrls[index].dispose();
   147|      _answerCtrls.removeAt(index);
   148|    });
   149|  }
   150|
   151|  Future<void> _save() async {
   152|    if (_questionCtrl.text.isEmpty) {
   153|      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入题目')));
   154|      return;
   155|    }
   156|    final answers = _answerCtrls.map((c) => c.text).where((t) => t.isNotEmpty).toList();
   157|    if (answers.isEmpty) {
   158|      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请至少填写一个答案')));
   159|      return;
   160|    }
   161|
   162|    setState(() => _saving = true);
   163|    try {
   164|      final data = {
   165|        'question': _questionCtrl.text,
   166|        'answer': answers,
   167|        'image_url': _imageUrl,
   168|        'category_id': _categoryId,
   169|        'tag_id': _tagIds.isNotEmpty ? _tagIds : null,
   170|      };
   171|
   172|      if (widget.qa == null) {
   173|        await ApiService.createQa(data);
   174|      } else {
   175|        await ApiService.updateQa(widget.qa!.id, data);
   176|      }
   177|
   178|      if (mounted) Navigator.pop(context);
   179|    } catch (e) {
   180|      if (mounted) {
   181|        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败: $e')));
   182|      }
   183|    } finally {
   184|      setState(() => _saving = false);
   185|    }
   186|  }
   187|
   188|  @override
   189|  void dispose() {
   190|    _questionCtrl.removeListener(_onQuestionChanged);
   191|    _questionCtrl.dispose();
   192|    _questionFocus.dispose();
   193|    for (final c in _answerCtrls) {
   194|      c.dispose();
   195|    }
   196|    super.dispose();
   197|  }
   198|
   199|  @override
   200|  Widget build(BuildContext context) {
   201|    return Scaffold(
   202|      body: CustomScrollView(
   203|        slivers: [
   204|          // Header
   205|          SliverAppBar(
   206|            expandedHeight: 0,
   207|            pinned: true,
   208|            backgroundColor: AppTheme.bgPrimary,
   209|            elevation: 0,
   210|            leading: IconButton(
   211|              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
   212|              onPressed: () => Navigator.pop(context),
   213|            ),
   214|            title: Text(widget.qa == null ? '新增题目' : '编辑题目', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17, fontFamily: 'Inter')),
   215|            centerTitle: true,
   216|            actions: [
   217|              IconButton(
   218|                icon: const Icon(Icons.visibility_outlined, size: 20),
   219|                onPressed: _showPreview,
   220|                tooltip: '预览',
   221|              ),
   222|              SizedBox(width: 8.w),
   223|            ],
   224|          ),
   225|          SliverToBoxAdapter(
   226|            child: Padding(
   227|              padding: EdgeInsets.all(16.w),
   228|              child: Column(
   229|                crossAxisAlignment: CrossAxisAlignment.start,
   230|                children: [
   231|                  // Question section
   232|                  _SectionHeader(icon: Icons.edit_note_outlined, label: '题目'),
   233|                  SizedBox(height: 8.h),
   234|
   235|                  // Toolbar
   236|                  Container(
   237|                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
   238|                    decoration: BoxDecoration(
   239|                      color: AppTheme.bgSection,
   240|                      borderRadius: BorderRadius.circular(10.r),
   241|                    ),
   242|                    child: Wrap(
   243|                      spacing: 6.w,
   244|                      runSpacing: 4.h,
   245|                      children: [
   246|                        _toolbarChip('填空', _insertBlank),
   247|                        _toolbarChip('加粗', _insertBold),
   248|                        _toolbarChip('高亮', _insertHighlight),
   249|                        _toolbarChip('代码', _insertCode),
   250|                        _toolbarChip('分割线', _insertDivider),
   251|                      ],
   252|                    ),
   253|                  ),
   254|                  SizedBox(height: 8.h),
   255|
   256|                  // Question input
   257|                  TextField(
   258|                    controller: _questionCtrl,
   259|                    focusNode: _questionFocus,
   260|                    maxLines: 4,
   261|                    decoration: InputDecoration(
   262|                      hintText: '输入题目，用 ___ 表示填空',
   263|                      filled: true,
   264|                      fillColor: AppTheme.bgCard,
   265|                      border: OutlineInputBorder(
   266|                        borderRadius: BorderRadius.circular(10.r),
   267|                        borderSide: const BorderSide(color: AppTheme.border),
   268|                      ),
   269|                      enabledBorder: OutlineInputBorder(
   270|                        borderRadius: BorderRadius.circular(10.r),
   271|                        borderSide: const BorderSide(color: AppTheme.border),
   272|                      ),
   273|                      focusedBorder: OutlineInputBorder(
   274|                        borderRadius: BorderRadius.circular(10.r),
   275|                        borderSide: const BorderSide(color: AppTheme.primary, width: 2),
   276|                      ),
   277|                      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
   278|                    ),
   279|                    onChanged: (text) {
   280|                      if (text.contains('   ')) {
   281|                        final newText = text.replaceAll('   ', '___');
   282|                        if (newText != text) {
   283|                          _questionCtrl.text = newText;
   284|                          _questionCtrl.selection = TextSelection.collapsed(offset: _questionCtrl.text.length);
   285|                        }
   286|                      }
   287|                    },
   288|                  ),
   289|                  SizedBox(height: 8.h),
   290|
   291|                  // Blank count hint
   292|                  if (_blankCount > 0)
   293|                    Container(
   294|                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
   295|                      decoration: BoxDecoration(
   296|                        color: AppTheme.indigo50,
   297|                        borderRadius: BorderRadius.circular(10.r),
   298|                      ),
   299|                      child: Text(
   300|                        '共 $_blankCount 个填空，已自动生成 $_blankCount 个答案输入框',
   301|                        style: TextStyle(fontSize: 12.sp, color: AppTheme.primary, fontFamily: 'Inter'),
   302|                      ),
   303|                    ),
   304|                  SizedBox(height: 24.h),
   305|
   306|                  // Answer section
   307|                  Row(
   308|                    children: [
   309|                      Icon(Icons.check_circle_outline, size: 18.sp, color: AppTheme.primary),
   310|                      SizedBox(width: 6.w),
   311|                      Text('答案', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, fontFamily: 'Inter')),
   312|                      const Spacer(),
   313|                      IconButton(
   314|                        icon: Icon(Icons.add_circle_outlined, color: AppTheme.primary, size: 22),
   315|                        onPressed: _addAnswerField,
   316|                        padding: EdgeInsets.zero,
   317|                        constraints: const BoxConstraints(),
   318|                      ),
   319|                    ],
   320|                  ),
   321|                  SizedBox(height: 8.h),
   322|                  if (_answerCtrls.isEmpty)
   323|                    Container(
   324|                      width: double.infinity,
   325|                      padding: EdgeInsets.all(24.w),
   326|                      decoration: BoxDecoration(
   327|                        color: AppTheme.bgSection,
   328|                        borderRadius: BorderRadius.circular(14.r),
   329|                      ),
   330|                      child: Column(
   331|                        children: [
   332|                          Icon(Icons.add_circle_outline, size: 32.sp, color: AppTheme.textTertiary),
   333|                          SizedBox(height: 8.h),
   334|                          Text('点击 + 添加答案，或在题目中输入 ___', style: TextStyle(color: AppTheme.textTertiary, fontSize: 13.sp)),
   335|                        ],
   336|                      ),
   337|                    )
   338|                  else
   339|                    ...List.generate(_answerCtrls.length, (i) => Padding(
   340|                      padding: EdgeInsets.only(bottom: 10.h),
   341|                      child: Row(
   342|                        children: [
   343|                          Container(
   344|                            width: 28.w,
   345|                            height: 28.w,
   346|                            decoration: BoxDecoration(
   347|                              color: AppTheme.indigo50,
   348|                              borderRadius: BorderRadius.circular(8.r),
   349|                            ),
   350|                            child: Center(
   351|                              child: Text('${i + 1}', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12.sp, fontFamily: 'Inter')),
   352|                            ),
   353|                          ),
   354|                          SizedBox(width: 10.w),
   355|                          Expanded(
   356|                            child: TextField(
   357|                              controller: _answerCtrls[i],
   358|                              decoration: InputDecoration(
   359|                                hintText: '空${i + 1} 的答案',
   360|                                filled: true,
   361|                                fillColor: AppTheme.bgCard,
   362|                                border: OutlineInputBorder(
   363|                                  borderRadius: BorderRadius.circular(10.r),
   364|                                  borderSide: const BorderSide(color: AppTheme.border),
   365|                                ),
   366|                                enabledBorder: OutlineInputBorder(
   367|                                  borderRadius: BorderRadius.circular(10.r),
   368|                                  borderSide: const BorderSide(color: AppTheme.border),
   369|                                ),
   370|                                focusedBorder: OutlineInputBorder(
   371|                                  borderRadius: BorderRadius.circular(10.r),
   372|                                  borderSide: const BorderSide(color: AppTheme.primary, width: 2),
   373|                                ),
   374|                                contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
   375|                              ),
   376|                            ),
   377|                          ),
   378|                          SizedBox(width: 4.w),
   379|                          IconButton(
   380|                            icon: const Icon(Icons.remove_circle_outline, color: AppTheme.red, size: 18),
   381|                            onPressed: () => _removeAnswerField(i),
   382|                            padding: EdgeInsets.zero,
   383|                            constraints: const BoxConstraints(),
   384|                          ),
   385|                        ],
   386|                      ),
   387|                    )),
   388|                  SizedBox(height: 24.h),
   389|
   390|                  // Image URL
   391|                  _SectionHeader(icon: Icons.image_outlined, label: '图片'),
   392|                  SizedBox(height: 8.h),
   393|                  TextField(
   394|                    onChanged: (v) => _imageUrl = v.isEmpty ? null : v,
   395|                    decoration: InputDecoration(
   396|                      hintText: '输入图片URL（可选）',
   397|                      filled: true,
   398|                      fillColor: AppTheme.bgCard,
   399|                      border: OutlineInputBorder(
   400|                        borderRadius: BorderRadius.circular(10.r),
   401|                        borderSide: const BorderSide(color: AppTheme.border),
   402|                      ),
   403|                      enabledBorder: OutlineInputBorder(
   404|                        borderRadius: BorderRadius.circular(10.r),
   405|                        borderSide: const BorderSide(color: AppTheme.border),
   406|                      ),
   407|                      focusedBorder: OutlineInputBorder(
   408|                        borderRadius: BorderRadius.circular(10.r),
   409|                        borderSide: const BorderSide(color: AppTheme.primary, width: 2),
   410|                      ),
   411|                      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
   412|                    ),
   413|                  ),
   414|                  SizedBox(height: 24.h),
   415|
   416|                  // Bank
   417|                  _SectionHeader(icon: Icons.folder_outlined, label: '题库'),
   418|                  SizedBox(height: 8.h),
   419|                  _banks.isEmpty
   420|                      ? const Center(child: Padding(
   421|                          padding: EdgeInsets.symmetric(vertical: 12),
   422|                          child: CircularProgressIndicator(strokeWidth: 2),
   423|                        ))
   424|                      : DropdownButtonFormField<String>(
   425|                          value: _categoryId,
   426|                          decoration: InputDecoration(
   427|                            hintText: '选择题库',
   428|                            filled: true,
   429|                            fillColor: AppTheme.bgCard,
   430|                            border: OutlineInputBorder(
   431|                              borderRadius: BorderRadius.circular(10.r),
   432|                              borderSide: const BorderSide(color: AppTheme.border),
   433|                            ),
   434|                            enabledBorder: OutlineInputBorder(
   435|                              borderRadius: BorderRadius.circular(10.r),
   436|                              borderSide: const BorderSide(color: AppTheme.border),
   437|                            ),
   438|                            focusedBorder: OutlineInputBorder(
   439|                              borderRadius: BorderRadius.circular(10.r),
   440|                              borderSide: const BorderSide(color: AppTheme.primary, width: 2),
   441|                            ),
   442|                            contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
   443|                          ),
   444|                          items: [
   445|                            const DropdownMenuItem(value: null, child: Text('未分类')),
   446|                            ..._banks.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
   447|                          ],
   448|                          onChanged: (v) => setState(() => _categoryId = v),
   449|                        ),
   450|                  SizedBox(height: 24.h),
   451|
   452|                  // Tags
   453|                  _SectionHeader(icon: Icons.label_outlined, label: '标签'),
   454|                  SizedBox(height: 8.h),
   455|                  _banks.isEmpty
   456|                      ? const Center(child: Padding(
   457|                          padding: EdgeInsets.symmetric(vertical: 12),
   458|                          child: CircularProgressIndicator(strokeWidth: 2),
   459|                        ))
   460|                      : _tags.isEmpty
   461|                          ? Text('暂无标签', style: TextStyle(color: AppTheme.textTertiary, fontSize: 13.sp))
   462|                          : Wrap(
   463|                              spacing: 8.w,
   464|                              runSpacing: 6.h,
   465|                              children: _tags.map((tag) {
   466|                                final selected = _tagIds.contains(tag.id);
   467|                                return _TagChip(
   468|                                  label: tag.name,
   469|                                  selected: selected,
   470|                                  onTap: () {
   471|                                    setState(() {
   472|                                      if (selected) {
   473|                                        _tagIds.remove(tag.id);
   474|                                      } else {
   475|                                        _tagIds.add(tag.id);
   476|                                      }
   477|                                    });
   478|                                  },
   479|                                );
   480|                              }).toList(),
   481|                            ),
   482|                  SizedBox(height: 40.h),
   483|
   484|                  // Save button
   485|                  SizedBox(
   486|                    width: double.infinity,
   487|                    height: 52.h,
   488|                    child: ElevatedButton(
   489|                      onPressed: _saving ? null : _save,
   490|                      style: ElevatedButton.styleFrom(
   491|                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
   492|                      ),
   493|                      child: _saving
   494|                          ? SizedBox(width: 20.w, height: 20.w, child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
   495|                          : const Text('保存', style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter')),
   496|                    ),
   497|                  ),
   498|                  SizedBox(height: 24.h),
   499|                ],
   500|              ),
   501|            ),
   502|          ),
   503|        ],
   504|      ),
   505|    );
   506|  }
   507|
   508|  Widget _toolbarChip(String label, VoidCallback onTap) {
   509|    return GestureDetector(
   510|      onTap: onTap,
   511|      child: Container(
   512|        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
   513|        decoration: BoxDecoration(
   514|          color: AppTheme.bgCard,
   515|          borderRadius: BorderRadius.circular(8.r),
   516|          border: Border.all(color: AppTheme.border),
   517|        ),
   518|        child: Text(label, style: TextStyle(fontSize: 12.sp, color: AppTheme.textSecondary, fontFamily: 'Inter')),
   519|      ),
   520|    );
   521|  }
   522|}
   523|
   524|class _TagChip extends StatelessWidget {
   525|  final String label;
   526|  final bool selected;
   527|  final VoidCallback onTap;
   528|
   529|  const _TagChip({required this.label, required this.selected, required this.onTap});
   530|
   531|  @override
   532|  Widget build(BuildContext context) {
   533|    return GestureDetector(
   534|      onTap: onTap,
   535|      child: Container(
   536|        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
   537|        decoration: BoxDecoration(
   538|          color: selected ? AppTheme.indigo50 : AppTheme.bgSection,
   539|          borderRadius: BorderRadius.circular(20.r),
   540|          border: Border.all(
   541|            color: selected ? AppTheme.indigo100 : AppTheme.border,
   542|            width: 1,
   543|          ),
   544|        ),
   545|        child: Text(
   546|          label,
   547|          style: TextStyle(
   548|            fontSize: 12.sp,
   549|            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
   550|            color: selected ? AppTheme.primary : AppTheme.textSecondary,
   551|            fontFamily: 'Inter',
   552|          ),
   553|        ),
   554|      ),
   555|    );
   556|  }
   557|}
   558|
   559|class _SectionHeader extends StatelessWidget {
   560|  final IconData icon;
   561|  final String label;
   562|
   563|  const _SectionHeader({required this.icon, required this.label});
   564|
   565|  @override
   566|  Widget build(BuildContext context) {
   567|    return Row(
   568|      children: [
   569|        Icon(icon, size: 18.sp, color: AppTheme.primary),
   570|        SizedBox(width: 6.w),
   571|        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, fontFamily: 'Inter')),
   572|      ],
   573|    );
   574|  }
   575|}
   576|
   577|class _PreviewDialog extends StatelessWidget {
   578|  final String question;
   579|  final List<String> answers;
   580|  final String? imageUrl;
   581|  final String? categoryName;
   582|
   583|  const _PreviewDialog({
   584|    required this.question,
   585|    required this.answers,
   586|    this.imageUrl,
   587|    this.categoryName,
   588|  });
   589|
   590|  @override
   591|  Widget build(BuildContext context) {
   592|    return Dialog(
   593|      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
   594|      child: Container(
   595|        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
   596|        child: Column(
   597|          mainAxisSize: MainAxisSize.min,
   598|          crossAxisAlignment: CrossAxisAlignment.start,
   599|          children: [
   600|            // Header
   601|            Container(
   602|              padding: EdgeInsets.all(16.w),
   603|              decoration: BoxDecoration(
   604|                color: AppTheme.primary,
   605|                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
   606|              ),
   607|              child: Row(
   608|                children: [
   609|                  const Icon(Icons.visibility_outlined, color: Colors.white),
   610|                  SizedBox(width: 8.w),
   611|                  Text('题目预览', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16.sp, fontFamily: 'Inter')),
   612|                  const Spacer(),
   613|                  IconButton(
   614|                    icon: const Icon(Icons.close, color: Colors.white),
   615|                    onPressed: () => Navigator.pop(context),
   616|                  ),
   617|                ],
   618|              ),
   619|            ),
   620|            // Content
   621|            Flexible(
   622|              child: SingleChildScrollView(
   623|                padding: EdgeInsets.all(16.w),
   624|                child: Column(
   625|                  crossAxisAlignment: CrossAxisAlignment.start,
   626|                  children: [
   627|                    if (categoryName != null) ...[
   628|                      _TagChip(label: categoryName!, selected: false, onTap: () {}),
   629|                      SizedBox(height: 12.h),
   630|                    ],
   631|                    Text('题目详情', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Inter')),
   632|                    SizedBox(height: 8.h),
   633|                    Container(
   634|                      width: double.infinity,
   635|                      padding: EdgeInsets.all(14.w),
   636|                      decoration: BoxDecoration(
   637|                        color: AppTheme.bgSection,
   638|                        borderRadius: BorderRadius.circular(12.r),
   639|                      ),
   640|                      child: QuestionRichText(text: question, fontSize: 16),
   641|                    ),
   642|                    SizedBox(height: 16.h),
   643|                    Text('答案', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Inter')),
   644|                    SizedBox(height: 8.h),
   645|                    Container(
   646|                      width: double.infinity,
   647|                      padding: EdgeInsets.all(14.w),
   648|                      decoration: BoxDecoration(
   649|                        color: const Color(0xFFF0FDF4),
   650|                        borderRadius: BorderRadius.circular(12.r),
   651|                        border: Border.all(color: const Color(0xFFBBF7D0)),
   652|                      ),
   653|                      child: Column(
   654|                        crossAxisAlignment: CrossAxisAlignment.start,
   655|                        children: answers.isEmpty
   656|                            ? [Text('无答案', style: TextStyle(color: AppTheme.textTertiary))]
   657|                            : answers.asMap().entries.map((e) => Padding(
   658|                                padding: EdgeInsets.only(bottom: 4.h),
   659|                                child: Row(
   660|                                  children: [
   661|                                    Container(
   662|                                      width: 20.w,
   663|                                      height: 20.w,
   664|                                      decoration: BoxDecoration(
   665|                                        color: const Color(0xFF86EFAC),
   666|                                        borderRadius: BorderRadius.circular(5.r),
   667|                                      ),
   668|                                      child: Center(
   669|                                        child: Text('${e.key + 1}', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold, color: const Color(0xFF166534), fontFamily: 'Inter')),
   670|                                      ),
   671|                                    ),
   672|                                    SizedBox(width: 8.w),
   673|                                    Text(e.value, style: TextStyle(fontSize: 14.sp, fontFamily: 'Inter')),
   674|                                  ],
   675|                                ),
   676|                              )).toList(),
   677|                      ),
   678|                    ),
   679|                    SizedBox(height: 16.h),
   680|                    if (imageUrl != null && imageUrl!.isNotEmpty) ...[
   681|                      Text('图片', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Inter')),
   682|                      SizedBox(height: 8.h),
   683|                      GestureDetector(
   684|                        onTap: () => QuestionRichText.showFullScreenImage(context, imageUrl!),
   685|                        child: ClipRRect(
   686|                          borderRadius: BorderRadius.circular(12.r),
   687|                          child: Image.network(
   688|                            imageUrl!,
   689|                            fit: BoxFit.contain,
   690|                            height: 200.h,
   691|                            width: double.infinity,
   692|                            errorBuilder: (_, __, ___) => Container(
   693|                              height: 80.h,
   694|                              width: double.infinity,
   695|                              color: AppTheme.bgSection,
   696|                              child: Center(
   697|                                child: Text('图片加载失败', style: TextStyle(color: AppTheme.textTertiary, fontSize: 13.sp)),
   698|                              ),
   699|                            ),
   700|                          ),
   701|                        ),
   702|                      ),
   703|                      SizedBox(height: 20.h),
   704|                    ],
   705|                  ],
   706|                ),
   707|              ),
   708|            ),
   709|          ],
   710|        ),
   711|      ),
   712|    );
   713|  }
   714|}
   715|