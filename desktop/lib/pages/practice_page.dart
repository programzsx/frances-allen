     1|import 'package:flutter/material.dart';
     2|import '../models/models.dart';
     3|import '../services/api_service.dart';
     4|import 'question_rich_text.dart';
     5|import '../theme/desktop_theme.dart';
     6|
     7|enum PracticeModeType { random, bank, wrong }
     8|
     9|enum SubMode { sequential, random, wrong }
    10|
    11|class PracticePage extends StatefulWidget {
    12|  final ValueChanged<bool>? onStartedChanged;
    13|  const PracticePage({super.key, this.onStartedChanged});
    14|
    15|  @override
    16|  State<PracticePage> createState() => _PracticePageState();
    17|}
    18|
    19|class _PracticePageState extends State<PracticePage> {
    20|  PracticeModeType _modeType = PracticeModeType.random;
    21|  String? _categoryId;
    22|  SubMode _subMode = SubMode.random;
    23|  int _minWrong = 1;
    24|  List<KbBank> _banks = [];
    25|  Map<String, KbBank> _categoryMap = {};
    26|  bool _loading = false;
    27|
    28|  List<KbQa> _questions = [];
    29|  int _currentIndex = 0;
    30|  List<bool> _revealed = [];
    31|  List<List<TextEditingController>> _userAnswerCtrls = [];
    32|  bool _started = false;
    33|  int _rightCount = 0;
    34|  int _wrongCount = 0;
    35|
    36|  @override
    37|  void initState() {
    38|    super.initState();
    39|    _loadBanks();
    40|  }
    41|
    42|  Future<void> _loadBanks() async {
    43|    try {
    44|      final data = await ApiService.pageBanks(pageSize: 100);
    45|      final banks = (data['items'] as List).map((e) => KbBank.fromJson(e)).toList();
    46|      setState(() {
    47|        _banks = banks;
    48|        _categoryMap = {for (var b in banks) b.id: b};
    49|      });
    50|    } catch (_) {}
    51|  }
    52|
    53|  Future<void> _startPractice() async {
    54|    setState(() => _loading = true);
    55|    try {
    56|      List<dynamic> data;
    57|      switch (_modeType) {
    58|        case PracticeModeType.random:
    59|          data = await ApiService.randomQas(limit: 10);
    60|        case PracticeModeType.bank:
    61|          switch (_subMode) {
    62|            case SubMode.sequential:
    63|              data = await ApiService.sequentialQas(limit: 10, categoryId: _categoryId);
    64|            case SubMode.random:
    65|              data = await ApiService.randomQas(limit: 10, categoryId: _categoryId);
    66|            case SubMode.wrong:
    67|              data = await ApiService.wrongQas(limit: 10, categoryId: _categoryId, minWrong: _minWrong);
    68|          }
    69|        case PracticeModeType.wrong:
    70|          data = await ApiService.wrongQas(limit: 10, minWrong: _minWrong);
    71|      }
    72|
    73|      final qas = data.map((e) => KbQa.fromJson(e)).toList();
    74|
    75|      if (qas.isEmpty) {
    76|        setState(() => _loading = false);
    77|        if (mounted) {
    78|          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('没有找到符合条件的题目')));
    79|        }
    80|        return;
    81|      }
    82|
    83|      setState(() {
    84|        _questions = qas;
    85|        _revealed = List.filled(qas.length, false);
    86|        _userAnswerCtrls = List.generate(
    87|          qas.length,
    88|          (i) => List.generate(qas[i].answer.length, (_) => TextEditingController()),
    89|        );
    90|        _currentIndex = 0;
    91|        _started = true;
    92|        _loading = false;
    93|        _rightCount = 0;
    94|        _wrongCount = 0;
    95|      });
    96|      WidgetsBinding.instance.addPostFrameCallback((_) {
    97|        if (mounted) widget.onStartedChanged?.call(true);
    98|      });
    99|    } catch (e) {
   100|      setState(() => _loading = false);
   101|      if (mounted) {
   102|        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载失败: $e')));
   103|      }
   104|    }
   105|  }
   106|
   107|  void _reset() {
   108|    for (final ctrlList in _userAnswerCtrls) {
   109|      for (final c in ctrlList) c.dispose();
   110|    }
   111|    widget.onStartedChanged?.call(false);
   112|    setState(() {
   113|      _started = false;
   114|      _questions = [];
   115|      _revealed = [];
   116|      _userAnswerCtrls = [];
   117|      _rightCount = 0;
   118|      _wrongCount = 0;
   119|    });
   120|  }
   121|
   122|  bool _checkAnswer(KbQa qa) {
   123|    final userAnswers = _userAnswerCtrls[_currentIndex].map((c) => c.text.trim()).toList();
   124|    if (userAnswers.length != qa.answer.length) return false;
   125|    for (int i = 0; i < qa.answer.length; i++) {
   126|      if (userAnswers[i] != qa.answer[i]) return false;
   127|    }
   128|    return true;
   129|  }
   130|
   131|  void _submitAnswer() async {
   132|    final qa = _questions[_currentIndex];
   133|    final isCorrect = _checkAnswer(qa);
   134|
   135|    final newTotal = qa.total + 1;
   136|    final newRight = qa.right + (isCorrect ? 1 : 0);
   137|    final newWrong = qa.wrong + (isCorrect ? 0 : 1);
   138|
   139|    try {
   140|      await ApiService.updateQa(qa.id, {'total': newTotal, 'right': newRight, 'wrong': newWrong});
   141|    } catch (e) {
   142|      debugPrint('统计更新失败: $e');
   143|      if (!mounted) return;
   144|      ScaffoldMessenger.of(context).showSnackBar(
   145|        SnackBar(content: Text('统计更新失败: $e'), backgroundColor: Colors.orange),
   146|      );
   147|    }
   148|
   149|    setState(() {
   150|      if (isCorrect) {
   151|        _rightCount++;
   152|      } else {
   153|        _wrongCount++;
   154|      }
   155|      _revealed[_currentIndex] = true;
   156|      _questions[_currentIndex] = KbQa(
   157|        id: qa.id,
   158|        createTime: qa.createTime,
   159|        updateTime: qa.updateTime,
   160|        question: qa.question,
   161|        answer: qa.answer,
   162|        imageUrl: qa.imageUrl,
   163|        total: newTotal,
   164|        right: newRight,
   165|        wrong: newWrong,
   166|        randomInt: qa.randomInt,
   167|        categoryId: qa.categoryId,
   168|        tagId: qa.tagId,
   169|      );
   170|    });
   171|
   172|    if (mounted) {
   173|      ScaffoldMessenger.of(context).showSnackBar(
   174|        SnackBar(
   175|          content: Text(isCorrect ? '回答正确！' : '回答错误，正确答案：${qa.answer.join("、")}'),
   176|          backgroundColor: isCorrect ? DesktopTheme.green : DesktopTheme.red,
   177|          duration: const Duration(milliseconds: 500),
   178|        ),
   179|      );
   180|    }
   181|  }
   182|
   183|  void _nextQuestion() {
   184|    if (_currentIndex < _questions.length - 1) setState(() => _currentIndex++);
   185|  }
   186|
   187|  void _prevQuestion() {
   188|    if (_currentIndex > 0) setState(() => _currentIndex--);
   189|  }
   190|
   191|  @override
   192|  void dispose() {
   193|    if (_started) {
   194|      for (final ctrlList in _userAnswerCtrls) {
   195|        for (final c in ctrlList) c.dispose();
   196|      }
   197|    }
   198|    super.dispose();
   199|  }
   200|
   201|  @override
   202|  Widget build(BuildContext context) {
   203|    if (!_started) return _buildSetupPage();
   204|    if (_questions.isEmpty) return _buildEmptyPracticePage();
   205|    return _buildPracticePage();
   206|  }
   207|
   208|  Widget _buildEmptyPracticePage() {
   209|    return Scaffold(
   210|      body: Center(
   211|        child: Column(
   212|          mainAxisSize: MainAxisSize.min,
   213|          children: [
   214|            const Icon(Icons.inbox_outlined, size: 64, color: DesktopTheme.textTertiary),
   215|            const SizedBox(height: 16),
   216|            const Text('暂无题目', style: TextStyle(color: DesktopTheme.textTertiary, fontSize: 15)),
   217|            const SizedBox(height: 16),
   218|            ElevatedButton(onPressed: _reset, child: const Text('返回')),
   219|          ],
   220|        ),
   221|      ),
   222|    );
   223|  }
   224|
   225|  Widget _buildSetupPage() {
   226|    return Scaffold(
   227|      body: Center(
   228|        child: Container(
   229|          constraints: const BoxConstraints(maxWidth: 600),
   230|          child: SingleChildScrollView(
   231|            padding: const EdgeInsets.all(24),
   232|            child: Column(
   233|              crossAxisAlignment: CrossAxisAlignment.start,
   234|              children: [
   235|                // Header
   236|                const Center(
   237|                  child: Icon(Icons.school_outlined, size: 48, color: DesktopTheme.primary),
   238|                ),
   239|                const SizedBox(height: 16),
   240|                const Center(
   241|                  child: Text('选择练习模式', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
   242|                ),
   243|                const SizedBox(height: 8),
   244|                const Center(
   245|                  child: Text('选择你喜欢的练习方式', style: TextStyle(fontSize: 13, color: DesktopTheme.textTertiary)),
   246|                ),
   247|                const SizedBox(height: 28),
   248|
   249|                // Mode selector
   250|                _buildModeSelector(),
   251|                const SizedBox(height: 20),
   252|
   253|                // Mode-specific controls
   254|                _buildModeControls(),
   255|                const SizedBox(height: 32),
   256|
   257|                // Start button
   258|                SizedBox(
   259|                  width: double.infinity,
   260|                  height: 48,
   261|                  child: ElevatedButton.icon(
   262|                    onPressed: _loading ? null : _startPractice,
   263|                    icon: _loading
   264|                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
   265|                        : const Icon(Icons.play_arrow, color: Colors.white),
   266|                    label: Text(_loading ? '加载中...' : '开始练习', style: const TextStyle(fontWeight: FontWeight.w600)),
   267|                  ),
   268|                ),
   269|              ],
   270|            ),
   271|          ),
   272|        ),
   273|      ),
   274|    );
   275|  }
   276|
   277|  Widget _buildModeSelector() {
   278|    return Container(
   279|      padding: const EdgeInsets.all(4),
   280|      decoration: BoxDecoration(
   281|        color: DesktopTheme.bgSection,
   282|        borderRadius: BorderRadius.circular(8),
   283|      ),
   284|      child: Row(
   285|        children: [
   286|          _modeTab(PracticeModeType.random, '随机', Icons.shuffle_outlined),
   287|          _modeTab(PracticeModeType.bank, '题库', Icons.folder_outlined),
   288|          _modeTab(PracticeModeType.wrong, '错题', Icons.error_outline),
   289|        ].expand((w) => [Expanded(child: w)]).toList(),
   290|      ),
   291|    );
   292|  }
   293|
   294|  Widget _modeTab(PracticeModeType type, String label, IconData icon) {
   295|    final selected = _modeType == type;
   296|    return GestureDetector(
   297|      onTap: () => setState(() => _modeType = type),
   298|      child: Container(
   299|        padding: const EdgeInsets.symmetric(vertical: 14),
   300|        decoration: BoxDecoration(
   301|          color: selected ? DesktopTheme.primary : Colors.transparent,
   302|          borderRadius: BorderRadius.circular(6),
   303|        ),
   304|        child: Column(
   305|          mainAxisSize: MainAxisSize.min,
   306|          children: [
   307|            Icon(icon, size: 20, color: selected ? Colors.white : DesktopTheme.textTertiary),
   308|            const SizedBox(height: 4),
   309|            Text(
   310|              label,
   311|              style: TextStyle(
   312|                fontSize: 12,
   313|                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
   314|                color: selected ? Colors.white : DesktopTheme.textSecondary,
   315|              ),
   316|            ),
   317|          ],
   318|        ),
   319|      ),
   320|    );
   321|  }
   322|
   323|  Widget _buildModeControls() {
   324|    switch (_modeType) {
   325|      case PracticeModeType.random:
   326|        return _buildRandomControls();
   327|      case PracticeModeType.bank:
   328|        return _buildBankControls();
   329|      case PracticeModeType.wrong:
   330|        return _buildWrongControls();
   331|    }
   332|  }
   333|
   334|  Widget _buildRandomControls() {
   335|    return Container(
   336|      padding: const EdgeInsets.all(16),
   337|      decoration: BoxDecoration(
   338|        color: DesktopTheme.bgCard,
   339|        borderRadius: BorderRadius.circular(8),
   340|        border: Border.all(color: DesktopTheme.border),
   341|      ),
   342|      child: const Column(
   343|        crossAxisAlignment: CrossAxisAlignment.start,
   344|        children: [
   345|          Row(
   346|            children: [
   347|              Icon(Icons.shuffle_outlined, size: 18, color: DesktopTheme.primary),
   348|              SizedBox(width: 6),
   349|              Text('随机模式', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
   350|            ],
   351|          ),
   352|          SizedBox(height: 8),
   353|          Text('从全部题库中随机抽取10道题目', style: TextStyle(color: DesktopTheme.textTertiary, fontSize: 12)),
   354|        ],
   355|      ),
   356|    );
   357|  }
   358|
   359|  Widget _buildBankControls() {
   360|    return Container(
   361|      padding: const EdgeInsets.all(16),
   362|      decoration: BoxDecoration(
   363|        color: DesktopTheme.bgCard,
   364|        borderRadius: BorderRadius.circular(8),
   365|        border: Border.all(color: DesktopTheme.border),
   366|      ),
   367|      child: Column(
   368|        crossAxisAlignment: CrossAxisAlignment.start,
   369|        children: [
   370|          const Row(
   371|            children: [
   372|              Icon(Icons.folder_outlined, size: 18, color: DesktopTheme.primary),
   373|              SizedBox(width: 6),
   374|              Text('题库模式', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
   375|            ],
   376|          ),
   377|          const SizedBox(height: 12),
   378|          DropdownButtonFormField<String>(
   379|            value: _categoryId,
   380|            decoration: InputDecoration(
   381|              labelText: '选择题库',
   382|              hintText: '全部题库',
   383|              filled: true,
   384|              fillColor: DesktopTheme.bgSection,
   385|              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: DesktopTheme.border)),
   386|              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: DesktopTheme.border)),
   387|              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: DesktopTheme.primary, width: 2)),
   388|              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
   389|            ),
   390|            items: [
   391|              const DropdownMenuItem(value: null, child: Text('全部题库')),
   392|              ..._banks.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
   393|            ],
   394|            dropdownColor: DesktopTheme.bgCard,
   395|            style: const TextStyle(fontSize: 13),
   396|            onChanged: (v) => setState(() => _categoryId = v),
   397|          ),
   398|          const SizedBox(height: 12),
   399|          const Text('练习方式', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
   400|          const SizedBox(height: 8),
   401|          Wrap(
   402|            spacing: 8,
   403|            children: SubMode.values.map((mode) {
   404|              final selected = _subMode == mode;
   405|              return _SubModeChip(label: _subModeLabel(mode), selected: selected, onTap: () => setState(() => _subMode = mode));
   406|            }).toList(),
   407|          ),
   408|          if (_subMode == SubMode.wrong) ...[
   409|            const SizedBox(height: 12),
   410|            _buildWrongThresholdControl(),
   411|          ],
   412|        ],
   413|      ),
   414|    );
   415|  }
   416|
   417|  Widget _buildWrongControls() {
   418|    return Container(
   419|      padding: const EdgeInsets.all(16),
   420|      decoration: BoxDecoration(
   421|        color: DesktopTheme.bgCard,
   422|        borderRadius: BorderRadius.circular(8),
   423|        border: Border.all(color: DesktopTheme.border),
   424|      ),
   425|      child: Column(
   426|        crossAxisAlignment: CrossAxisAlignment.start,
   427|        children: [
   428|          const Row(
   429|            children: [
   430|              Icon(Icons.error_outline, size: 18, color: DesktopTheme.primary),
   431|              SizedBox(width: 6),
   432|              Text('错题模式', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
   433|            ],
   434|          ),
   435|          const SizedBox(height: 12),
   436|          _buildWrongThresholdControl(),
   437|        ],
   438|      ),
   439|    );
   440|  }
   441|
   442|  Widget _buildWrongThresholdControl() {
   443|    return Column(
   444|      crossAxisAlignment: CrossAxisAlignment.start,
   445|      children: [
   446|        Row(
   447|          mainAxisAlignment: MainAxisAlignment.spaceBetween,
   448|          children: [
   449|            const Text('最小错误次数', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
   450|            Container(
   451|              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
   452|              decoration: BoxDecoration(
   453|                color: DesktopTheme.indigo50,
   454|                borderRadius: BorderRadius.circular(12),
   455|              ),
   456|              child: Text(
   457|                '>= $_minWrong',
   458|                style: const TextStyle(color: DesktopTheme.primary, fontWeight: FontWeight.bold, fontSize: 13),
   459|              ),
   460|            ),
   461|          ],
   462|        ),
   463|        Slider(
   464|          value: _minWrong.toDouble(),
   465|          min: 1,
   466|          max: 10,
   467|          divisions: 9,
   468|          label: '>= $_minWrong',
   469|          onChanged: (v) => setState(() => _minWrong = v.toInt()),
   470|        ),
   471|        Text('筛选错误次数大于等于 $_minWrong 次的题目', style: const TextStyle(color: DesktopTheme.textTertiary, fontSize: 12)),
   472|      ],
   473|    );
   474|  }
   475|
   476|  String _subModeLabel(SubMode mode) {
   477|    switch (mode) {
   478|      case SubMode.sequential: return '顺序练习';
   479|      case SubMode.random: return '随机练习';
   480|      case SubMode.wrong: return '错题练习';
   481|    }
   482|  }
   483|
   484|  Widget _buildPracticePage() {
   485|    final qa = _questions[_currentIndex];
   486|    final revealed = _revealed[_currentIndex];
   487|    final isLast = _currentIndex == _questions.length - 1;
   488|    final userAnswerCtrls = _userAnswerCtrls[_currentIndex];
   489|
   490|    return Scaffold(
   491|      body: Column(
   492|        children: [
   493|          Expanded(
   494|            child: Center(
   495|              child: Container(
   496|                constraints: const BoxConstraints(maxWidth: 800),
   497|                child: SingleChildScrollView(
   498|                  padding: const EdgeInsets.all(24),
   499|                  child: Column(
   500|                    crossAxisAlignment: CrossAxisAlignment.start,
   501|                    children: [
   502|                      Container(
   503|                        padding: const EdgeInsets.all(20),
   504|                        decoration: BoxDecoration(
   505|                          color: DesktopTheme.bgCard,
   506|                          borderRadius: BorderRadius.circular(8),
   507|                          border: Border.all(color: DesktopTheme.border),
   508|                        ),
   509|                        child: Column(
   510|                          crossAxisAlignment: CrossAxisAlignment.start,
   511|                          children: [
   512|                            Row(
   513|                              children: [
   514|                                Expanded(
   515|                                  child: Text('第 ${_currentIndex + 1} 题', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
   516|                                ),
   517|                                if (qa.categoryId != null)
   518|                                  Chip(
   519|                                    label: Text(_categoryMap[qa.categoryId]?.name ?? '', style: const TextStyle(fontSize: 11)),
   520|                                    backgroundColor: DesktopTheme.bgSection,
   521|                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
   522|                                  ),
   523|                                const SizedBox(width: 8),
   524|                                IconButton(
   525|                                  icon: const Icon(Icons.close_rounded, size: 20),
   526|                                  color: DesktopTheme.textTertiary,
   527|                                  onPressed: () => showDialog(
   528|                                    context: context,
   529|                                    builder: (ctx) => AlertDialog(
   530|                                      title: const Text('退出练习'),
   531|                                      content: const Text('确定要退出当前练习吗？'),
   532|                                      actions: [
   533|                                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
   534|                                        TextButton(
   535|                                          onPressed: () { Navigator.pop(ctx); _reset(); },
   536|                                          child: const Text('确定', style: TextStyle(color: DesktopTheme.red)),
   537|                                        ),
   538|                                      ],
   539|                                    ),
   540|                                  ),
   541|                                  tooltip: '退出练习',
   542|                                ),
   543|                              ],
   544|                            ),
   545|                            const SizedBox(height: 20),
   546|                            Container(
   547|                              width: double.infinity,
   548|                              padding: const EdgeInsets.all(16),
   549|                              decoration: BoxDecoration(
   550|                                color: DesktopTheme.bgSection,
   551|                                borderRadius: BorderRadius.circular(8),
   552|                              ),
   553|                              child: QuestionRichText(
   554|                                text: qa.question,
   555|                                revealed: revealed,
   556|                                answers: qa.answer,
   557|                                fontSize: 16,
   558|                              ),
   559|                            ),
   560|                          ],
   561|                        ),
   562|                      ),
   563|                      const SizedBox(height: 20),
   564|                      if (!revealed) ...[
   565|                        Container(
   566|                          padding: const EdgeInsets.all(16),
   567|                          decoration: BoxDecoration(
   568|                            color: DesktopTheme.bgCard,
   569|                            borderRadius: BorderRadius.circular(8),
   570|                            border: Border.all(color: DesktopTheme.border),
   571|                          ),
   572|                          child: Column(
   573|                            crossAxisAlignment: CrossAxisAlignment.start,
   574|                            children: [
   575|                              const Text('请填空作答', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
   576|                              const SizedBox(height: 12),
   577|                              ...List.generate(qa.answer.length, (i) => Padding(
   578|                                padding: EdgeInsets.only(bottom: i < qa.answer.length - 1 ? 12 : 0),
   579|                                child: Row(
   580|                                  children: [
   581|                                    Container(
   582|                                      width: 24,
   583|                                      height: 24,
   584|                                      decoration: BoxDecoration(
   585|                                        color: DesktopTheme.indigo50,
   586|                                        borderRadius: BorderRadius.circular(6),
   587|                                      ),
   588|                                      child: Center(
   589|                                        child: Text('${i + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: DesktopTheme.primary)),
   590|                                      ),
   591|                                    ),
   592|                                    const SizedBox(width: 8),
   593|                                    Expanded(
   594|                                      child: TextField(
   595|                                        controller: userAnswerCtrls[i],
   596|                                        decoration: InputDecoration(
   597|                                          hintText: '空${i + 1} 的答案',
   598|                                          filled: true,
   599|                                          fillColor: DesktopTheme.bgSection,
   600|                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: DesktopTheme.border)),
   601|                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: DesktopTheme.border)),
   602|                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: DesktopTheme.primary, width: 2)),
   603|                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
   604|                                        ),
   605|                                      ),
   606|                                    ),
   607|                                  ],
   608|                                ),
   609|                              )),
   610|                              const SizedBox(height: 8),
   611|                              SizedBox(
   612|                                width: double.infinity,
   613|                                height: 44,
   614|                                child: ElevatedButton.icon(
   615|                                  onPressed: _submitAnswer,
   616|                                  icon: const Icon(Icons.check, color: Colors.white),
   617|                                  label: const Text('提交答案', style: TextStyle(fontWeight: FontWeight.w600)),
   618|                                ),
   619|                              ),
   620|                            ],
   621|                          ),
   622|                        ),
   623|                      ] else ...[
   624|                        Container(
   625|                          width: double.infinity,
   626|                          padding: const EdgeInsets.all(16),
   627|                          decoration: BoxDecoration(
   628|                            color: const Color(0xFFF0FDF4),
   629|                            borderRadius: BorderRadius.circular(8),
   630|                            border: Border.all(color: const Color(0xFFBBF7D0)),
   631|                          ),
   632|                          child: Column(
   633|                            crossAxisAlignment: CrossAxisAlignment.start,
   634|                            children: [
   635|                              Row(
   636|                                children: [
   637|                                  Icon(Icons.check_circle, color: DesktopTheme.green, size: 18),
   638|                                  const SizedBox(width: 6),
   639|                                  const Text('正确答案', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF166534), fontSize: 14)),
   640|                                ],
   641|                              ),
   642|                              const SizedBox(height: 10),
   643|                              ...qa.answer.asMap().entries.map((e) => Padding(
   644|                                padding: EdgeInsets.only(bottom: e.key < qa.answer.length - 1 ? 6 : 0),
   645|                                child: Row(
   646|                                  children: [
   647|                                    Container(
   648|                                      width: 22,
   649|                                      height: 22,
   650|                                      decoration: BoxDecoration(
   651|                                        color: const Color(0xFF86EFAC),
   652|                                        borderRadius: BorderRadius.circular(6),
   653|                                      ),
   654|                                      child: Center(
   655|                                        child: Text('${e.key + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
   656|                                      ),
   657|                                    ),
   658|                                    const SizedBox(width: 8),
   659|                                    Text(e.value, style: const TextStyle(fontSize: 14)),
   660|                                  ],
   661|                                ),
   662|                              )),
   663|                            ],
   664|                          ),
   665|                        ),
   666|                      ],
   667|                    ],
   668|                  ),
   669|                ),
   670|              ),
   671|            ),
   672|          ),
   673|          Container(
   674|            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
   675|            decoration: BoxDecoration(
   676|              color: DesktopTheme.bgCard,
   677|              border: Border(top: BorderSide(color: DesktopTheme.border)),
   678|            ),
   679|            child: Row(
   680|              children: [
   681|                Expanded(
   682|                  child: OutlinedButton.icon(
   683|                    onPressed: _currentIndex > 0 ? _prevQuestion : null,
   684|                    icon: const Icon(Icons.chevron_left),
   685|                    label: const Text('上一题'),
   686|                  ),
   687|                ),
   688|                const SizedBox(width: 12),
   689|                Container(
   690|                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
   691|                  decoration: BoxDecoration(
   692|                    color: DesktopTheme.indigo50,
   693|                    borderRadius: BorderRadius.circular(16),
   694|                  ),
   695|                  child: Text(
   696|                    '${_currentIndex + 1} / ${_questions.length}',
   697|                    style: const TextStyle(color: DesktopTheme.primary, fontWeight: FontWeight.w600, fontSize: 13),
   698|                  ),
   699|                ),
   700|                const SizedBox(width: 12),
   701|                Expanded(
   702|                  child: ElevatedButton.icon(
   703|                    onPressed: _revealed[_currentIndex] ? (!isLast ? _nextQuestion : _reset) : null,
   704|                    icon: isLast ? const SizedBox.shrink() : const Icon(Icons.chevron_right, color: Colors.white),
   705|                    iconAlignment: IconAlignment.end,
   706|                    label: Text(isLast ? '返回' : '下一题', style: const TextStyle(fontWeight: FontWeight.w600)),
   707|                  ),
   708|                ),
   709|              ],
   710|            ),
   711|          ),
   712|        ],
   713|      ),
   714|    );
   715|  }
   716|}
   717|
   718|class _SubModeChip extends StatelessWidget {
   719|  final String label;
   720|  final bool selected;
   721|  final VoidCallback onTap;
   722|
   723|  const _SubModeChip({required this.label, required this.selected, required this.onTap});
   724|
   725|  @override
   726|  Widget build(BuildContext context) {
   727|    return GestureDetector(
   728|      onTap: onTap,
   729|      child: Container(
   730|        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
   731|        decoration: BoxDecoration(
   732|          color: selected ? DesktopTheme.indigo50 : DesktopTheme.bgSection,
   733|          borderRadius: BorderRadius.circular(16),
   734|          border: Border.all(
   735|            color: selected ? DesktopTheme.indigo100 : DesktopTheme.border,
   736|            width: 1,
   737|          ),
   738|        ),
   739|        child: Text(
   740|          label,
   741|          style: TextStyle(
   742|            fontSize: 12,
   743|            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
   744|            color: selected ? DesktopTheme.primary : DesktopTheme.textSecondary,
   745|          ),
   746|        ),
   747|      ),
   748|    );
   749|  }
   750|}
   751|