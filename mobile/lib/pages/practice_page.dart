     1|import 'dart:async';
     2|import 'dart:math';
     3|import 'package:flutter/material.dart';
     4|import 'package:flutter_screenutil/flutter_screenutil.dart';
     5|import '../models/models.dart';
     6|import '../services/api_service.dart';
     7|import 'question_rich_text.dart';
     8|import '../theme/app_theme.dart';
     9|
    10|enum PracticeMode { random, sequential, wrong }
    11|
    12|class PracticePage extends StatefulWidget {
    13|  const PracticePage({super.key});
    14|
    15|  @override
    16|  State<PracticePage> createState() => _PracticePageState();
    17|}
    18|
    19|class _PracticePageState extends State<PracticePage> {
    20|  // Setup state
    21|  KbBank? _selectedBank;
    22|  PracticeMode _mode = PracticeMode.random;
    23|  int _minWrong = 1;
    24|  bool _loading = false;
    25|  int _bankTotal = 0;
    26|
    27|  // Search state
    28|  final _searchCtrl = TextEditingController();
    29|  final _searchKey = GlobalKey();
    30|  List<KbBank> _searchResults = [];
    31|  bool _searching = false;
    32|  Timer? _debounce;
    33|  OverlayEntry? _searchOverlay;
    34|
    35|  @override
    36|  void initState() {
    37|    super.initState();
    38|    _searchCtrl.addListener(_onSearchChanged);
    39|  }
    40|
    41|  @override
    42|  void dispose() {
    43|    _searchCtrl.dispose();
    44|    _debounce?.cancel();
    45|    super.dispose();
    46|  }
    47|
    48|  void _onSearchChanged() {
    49|    _debounce?.cancel();
    50|    final query = _searchCtrl.text.trim();
    51|    if (query.isEmpty) {
    52|      setState(() {
    53|        _searchResults = [];
    54|        _searching = false;
    55|      });
    56|      _removeOverlay();
    57|      return;
    58|    }
    59|    _debounce = Timer(const Duration(milliseconds: 300), () async {
    60|      try {
    61|        final data = await ApiService.pageBanks(keyword: query, pageSize: 20);
    62|        final banks = (data['items'] as List).map((e) => KbBank.fromJson(e)).toList();
    63|        if (mounted) {
    64|          setState(() {
    65|            _searchResults = banks;
    66|            _searching = false;
    67|          });
    68|          if (banks.isNotEmpty || _searching) _showSearchOverlay();
    69|        }
    70|      } catch (_) {
    71|        if (mounted) setState(() => _searching = false);
    72|      }
    73|    });
    74|  }
    75|
    76|  void _selectBank(KbBank bank) {
    77|    _searchCtrl.clear();
    78|    _removeOverlay();
    79|    setState(() {
    80|      _selectedBank = bank;
    81|      _searchResults = [];
    82|      _bankTotal = 0;
    83|    });
    84|    _loadBankTotal(bank);
    85|  }
    86|
    87|  Future<void> _loadBankTotal(KbBank bank) async {
    88|    try {
    89|      final data = await ApiService.pageQas(categoryId: bank.id, pageSize: 1);
    90|      if (mounted) setState(() => _bankTotal = data['total']);
    91|    } catch (_) {}
    92|  }
    93|
    94|  void _showSearchOverlay() {
    95|    _removeOverlay();
    96|    final context = _searchKey.currentContext;
    97|    if (context == null) return;
    98|    final box = context.findRenderObject() as RenderBox?;
    99|    if (box == null) return;
   100|    final offset = box.localToGlobal(Offset.zero);
   101|    final size = box.size;
   102|
   103|    _searchOverlay = OverlayEntry(
   104|      builder: (ctx) => Positioned(
   105|        left: offset.dx,
   106|        top: offset.dy + size.height + 8.h,
   107|        width: size.width,
   108|        child: Material(
   109|          elevation: 4,
   110|          borderRadius: BorderRadius.circular(10.r),
   111|          child: Container(
   112|            constraints: BoxConstraints(maxHeight: 200.h),
   113|            decoration: BoxDecoration(
   114|              color: AppTheme.bgCard,
   115|              borderRadius: BorderRadius.circular(10.r),
   116|              border: Border.all(color: AppTheme.border),
   117|            ),
   118|            child: _searching
   119|                ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
   120|                : ListView.builder(
   121|                    shrinkWrap: true,
   122|                    itemCount: _searchResults.length,
   123|                    itemBuilder: (ctx, i) {
   124|                      final bank = _searchResults[i];
   125|                      return ListTile(
   126|                        dense: true,
   127|                        title: Text(bank.name, style: TextStyle(fontSize: 14.sp, fontFamily: 'Inter')),
   128|                        onTap: () { _selectBank(bank); _removeOverlay(); },
   129|                      );
   130|                    },
   131|                  ),
   132|          ),
   133|        ),
   134|      ),
   135|    );
   136|    Overlay.of(context, rootOverlay: true).insert(_searchOverlay!);
   137|  }
   138|
   139|  void _removeOverlay() {
   140|    _searchOverlay?.remove();
   141|    _searchOverlay = null;
   142|  }
   143|
   144|  Future<void> _startPractice() async {
   145|    if (_selectedBank == null) {
   146|      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先选择题库')));
   147|      return;
   148|    }
   149|    setState(() => _loading = true);
   150|    try {
   151|      List<dynamic> data;
   152|      switch (_mode) {
   153|        case PracticeMode.random:
   154|          data = await ApiService.getAllQasForBank(categoryId: _selectedBank!.id);
   155|          data = List.from(data)..shuffle(Random());
   156|        case PracticeMode.sequential:
   157|          data = await ApiService.getAllQasForBank(categoryId: _selectedBank!.id);
   158|        case PracticeMode.wrong:
   159|          data = await ApiService.wrongQas(limit: 9999, categoryId: _selectedBank!.id, minWrong: _minWrong);
   160|      }
   161|
   162|      final qas = data.map((e) => KbQa.fromJson(e)).toList();
   163|
   164|      if (qas.isEmpty) {
   165|        setState(() => _loading = false);
   166|        if (mounted) {
   167|          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('没有找到符合条件的题目')));
   168|        }
   169|        return;
   170|      }
   171|
   172|      setState(() => _loading = false);
   173|
   174|      if (mounted) {
   175|        Navigator.push(
   176|          context,
   177|          MaterialPageRoute(
   178|            builder: (_) => PracticeQuizPage(
   179|              questions: qas,
   180|              bank: _selectedBank!,
   181|            ),
   182|          ),
   183|        );
   184|      }
   185|    } catch (e) {
   186|      setState(() => _loading = false);
   187|      if (mounted) {
   188|        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载失败: $e')));
   189|      }
   190|    }
   191|  }
   192|
   193|  @override
   194|  Widget build(BuildContext context) {
   195|    return Scaffold(
   196|      body: SafeArea(
   197|        child: Listener(
   198|          behavior: HitTestBehavior.translucent,
   199|          onPointerDown: (_) => _removeOverlay(),
   200|          child: SingleChildScrollView(
   201|            padding: EdgeInsets.all(20.w),
   202|            child: Column(
   203|              crossAxisAlignment: CrossAxisAlignment.start,
   204|              children: [
   205|                Center(
   206|                  child: Container(
   207|                    padding: EdgeInsets.all(24.w),
   208|                    decoration: BoxDecoration(
   209|                      color: AppTheme.indigo50,
   210|                      shape: BoxShape.circle,
   211|                    ),
   212|                    child: Icon(Icons.school_outlined, size: 40.sp, color: AppTheme.primary),
   213|                  ),
   214|                ),
   215|                SizedBox(height: 16.h),
   216|                Center(
   217|                  child: Text('开始练习', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w600, fontFamily: 'Inter', color: AppTheme.textPrimary)),
   218|                ),
   219|                SizedBox(height: 8.h),
   220|                Center(
   221|                  child: Text('选择题库并设置练习模式', style: TextStyle(fontSize: 12.sp, color: AppTheme.textTertiary)),
   222|                ),
   223|                SizedBox(height: 28.h),
   224|
   225|                Text('选择题库', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp, fontFamily: 'Inter', color: AppTheme.textPrimary)),
   226|                SizedBox(height: 8.h),
   227|                _buildBankSearch(),
   228|                SizedBox(height: 24.h),
   229|
   230|                Text('练习模式', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp, fontFamily: 'Inter', color: AppTheme.textPrimary)),
   231|                SizedBox(height: 8.h),
   232|                _buildModeSelector(),
   233|                if (_mode == PracticeMode.wrong) ...[
   234|                  SizedBox(height: 16.h),
   235|                  _buildWrongThresholdControl(),
   236|                ],
   237|                SizedBox(height: 32.h),
   238|
   239|                SizedBox(
   240|                  width: double.infinity,
   241|                  height: 52.h,
   242|                  child: ElevatedButton.icon(
   243|                    onPressed: _loading ? null : _startPractice,
   244|                    icon: _loading
   245|                        ? SizedBox(width: 20.w, height: 20.w, child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
   246|                        : const Icon(Icons.play_arrow, color: Colors.white),
   247|                    label: Text(
   248|                      _loading ? '加载中...' : _selectedBank != null ? '开始练习 (${_bankTotal} 题)' : '开始练习',
   249|                      style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter'),
   250|                    ),
   251|                    style: ElevatedButton.styleFrom(
   252|                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
   253|                    ),
   254|                  ),
   255|                ),
   256|              ],
   257|            ),
   258|          ),
   259|        ),
   260|      ),
   261|    );
   262|  }
   263|
   264|  Widget _buildBankSearch() {
   265|    return Column(
   266|      crossAxisAlignment: CrossAxisAlignment.start,
   267|      children: [
   268|        TextField(
   269|          key: _searchKey,
   270|          controller: _searchCtrl,
   271|          onTap: () {
   272|            if (_searchCtrl.text.trim().isNotEmpty) _showSearchOverlay();
   273|          },
   274|          decoration: InputDecoration(
   275|            hintText: '输入题库名称搜索',
   276|            hintStyle: TextStyle(fontSize: 13, color: AppTheme.textTertiary, fontFamily: 'Inter'),
   277|            prefixIcon: const Icon(Icons.search_rounded, size: 18),
   278|            suffixIcon: _selectedBank != null
   279|                ? IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () {
   280|                    setState(() { _selectedBank = null; _bankTotal = 0; });
   281|                  })
   282|                : null,
   283|            filled: true,
   284|            fillColor: AppTheme.bgCard,
   285|            border: OutlineInputBorder(
   286|              borderRadius: BorderRadius.circular(10.r),
   287|              borderSide: const BorderSide(color: AppTheme.border),
   288|            ),
   289|            enabledBorder: OutlineInputBorder(
   290|              borderRadius: BorderRadius.circular(10.r),
   291|              borderSide: const BorderSide(color: AppTheme.border),
   292|            ),
   293|            focusedBorder: OutlineInputBorder(
   294|              borderRadius: BorderRadius.circular(10.r),
   295|              borderSide: const BorderSide(color: AppTheme.primary, width: 2),
   296|            ),
   297|            contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
   298|          ),
   299|          style: TextStyle(fontSize: 14, fontFamily: 'Inter'),
   300|        ),
   301|        if (_selectedBank != null) ...[
   302|          SizedBox(height: 8.h),
   303|          Container(
   304|            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
   305|            decoration: BoxDecoration(
   306|              color: AppTheme.indigo50,
   307|              borderRadius: BorderRadius.circular(8.r),
   308|              border: Border.all(color: AppTheme.indigo100),
   309|            ),
   310|            child: Row(
   311|              children: [
   312|                Icon(Icons.folder, size: 16.sp, color: AppTheme.primary),
   313|                SizedBox(width: 6.w),
   314|                Expanded(
   315|                  child: Text(
   316|                    _selectedBank!.name,
   317|                    style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: AppTheme.textPrimary, fontFamily: 'Inter'),
   318|                  ),
   319|                ),
   320|                if (_bankTotal > 0)
   321|                  Text(
   322|                    '$_bankTotal 题',
   323|                    style: TextStyle(fontSize: 12.sp, color: AppTheme.textTertiary),
   324|                  ),
   325|              ],
   326|            ),
   327|          ),
   328|        ],
   329|      ],
   330|    );
   331|  }
   332|
   333|  Widget _buildModeSelector() {
   334|    return Container(
   335|      padding: EdgeInsets.all(4.w),
   336|      decoration: BoxDecoration(
   337|        color: AppTheme.bgSection,
   338|        borderRadius: BorderRadius.circular(14.r),
   339|      ),
   340|      child: Row(
   341|        children: [
   342|          _modeTab(PracticeMode.random, '随机', Icons.shuffle_outlined),
   343|          _modeTab(PracticeMode.sequential, '顺序', Icons.format_list_numbered_outlined),
   344|          _modeTab(PracticeMode.wrong, '错题', Icons.error_outline),
   345|        ].expand((w) => [Expanded(child: w)]).toList(),
   346|      ),
   347|    );
   348|  }
   349|
   350|  Widget _modeTab(PracticeMode mode, String label, IconData icon) {
   351|    final selected = _mode == mode;
   352|    return GestureDetector(
   353|      onTap: () => setState(() => _mode = mode),
   354|      child: Container(
   355|        padding: EdgeInsets.symmetric(vertical: 14.h),
   356|        decoration: BoxDecoration(
   357|          color: selected ? AppTheme.primary : Colors.transparent,
   358|          borderRadius: BorderRadius.circular(10.r),
   359|        ),
   360|        child: Column(
   361|          mainAxisSize: MainAxisSize.min,
   362|          children: [
   363|            Icon(icon, size: 20.sp, color: selected ? Colors.white : AppTheme.textTertiary),
   364|            SizedBox(height: 4.h),
   365|            Text(
   366|              label,
   367|              style: TextStyle(
   368|                fontSize: 12.sp,
   369|                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
   370|                color: selected ? Colors.white : AppTheme.textSecondary,
   371|                fontFamily: 'Inter',
   372|              ),
   373|            ),
   374|          ],
   375|        ),
   376|      ),
   377|    );
   378|  }
   379|
   380|  Widget _buildWrongThresholdControl() {
   381|    return Container(
   382|      padding: EdgeInsets.all(16.w),
   383|      decoration: BoxDecoration(
   384|        color: AppTheme.bgCard,
   385|        borderRadius: BorderRadius.circular(14.r),
   386|        border: Border.all(color: AppTheme.border),
   387|      ),
   388|      child: Column(
   389|        crossAxisAlignment: CrossAxisAlignment.start,
   390|        children: [
   391|          Row(
   392|            mainAxisAlignment: MainAxisAlignment.spaceBetween,
   393|            children: [
   394|              Text('最小错误次数', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.sp, color: AppTheme.textPrimary)),
   395|              Container(
   396|                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
   397|                decoration: BoxDecoration(
   398|                  color: AppTheme.indigo50,
   399|                  borderRadius: BorderRadius.circular(12.r),
   400|                ),
   401|                child: Text(
   402|                  '>= $_minWrong',
   403|                  style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 13.sp, fontFamily: 'Inter'),
   404|                ),
   405|              ),
   406|            ],
   407|          ),
   408|          SizedBox(height: 8.h),
   409|          Slider(
   410|            value: _minWrong.toDouble(),
   411|            min: 1,
   412|            max: 10,
   413|            divisions: 9,
   414|            label: '>= $_minWrong',
   415|            onChanged: (v) => setState(() => _minWrong = v.toInt()),
   416|          ),
   417|          Text('筛选错误次数大于等于 $_minWrong 次的题目', style: TextStyle(color: AppTheme.textTertiary, fontSize: 12.sp)),
   418|        ],
   419|      ),
   420|    );
   421|  }
   422|}
   423|
   424|class PracticeQuizPage extends StatefulWidget {
   425|  final List<KbQa> questions;
   426|  final KbBank bank;
   427|  const PracticeQuizPage({super.key, required this.questions, required this.bank});
   428|
   429|  @override
   430|  State<PracticeQuizPage> createState() => _PracticeQuizPageState();
   431|}
   432|
   433|class _PracticeQuizPageState extends State<PracticeQuizPage> {
   434|  List<KbQa> _questions = [];
   435|  int _currentIndex = 0;
   436|  List<bool> _revealed = [];
   437|  List<List<TextEditingController>> _userAnswerCtrls = [];
   438|  bool _showExitConfirm = false;
   439|
   440|  Map<String, KbBank> _categoryMap = {};
   441|
   442|  @override
   443|  void initState() {
   444|    super.initState();
   445|    _questions = widget.questions;
   446|    _revealed = List.filled(_questions.length, false);
   447|    _userAnswerCtrls = List.generate(
   448|      _questions.length,
   449|      (i) => List.generate(_questions[i].answer.length, (_) => TextEditingController()),
   450|    );
   451|    _categoryMap = {widget.bank.id: widget.bank};
   452|  }
   453|
   454|  @override
   455|  void dispose() {
   456|    for (final ctrlList in _userAnswerCtrls) {
   457|      for (final c in ctrlList) c.dispose();
   458|    }
   459|    super.dispose();
   460|  }
   461|
   462|  bool _checkAnswer(KbQa qa) {
   463|    final userAnswers = _userAnswerCtrls[_currentIndex].map((c) => c.text.trim()).toList();
   464|    if (userAnswers.length != qa.answer.length) return false;
   465|    for (int i = 0; i < qa.answer.length; i++) {
   466|      if (userAnswers[i] != qa.answer[i]) return false;
   467|    }
   468|    return true;
   469|  }
   470|
   471|  void _submitAnswer() async {
   472|    final qa = _questions[_currentIndex];
   473|    final isCorrect = _checkAnswer(qa);
   474|
   475|    final newTotal = qa.total + 1;
   476|    final newRight = qa.right + (isCorrect ? 1 : 0);
   477|    final newWrong = qa.wrong + (isCorrect ? 0 : 1);
   478|
   479|    try {
   480|      await ApiService.updateQa(qa.id, {'total': newTotal, 'right': newRight, 'wrong': newWrong});
   481|    } catch (e) {
   482|      debugPrint('统计更新失败: $e');
   483|      if (!mounted) return;
   484|      ScaffoldMessenger.of(context).showSnackBar(
   485|        SnackBar(content: Text('统计更新失败: $e'), backgroundColor: Colors.orange),
   486|      );
   487|    }
   488|
   489|    setState(() {
   490|      _revealed[_currentIndex] = true;
   491|      _questions[_currentIndex] = KbQa(
   492|        id: qa.id,
   493|        createTime: qa.createTime,
   494|        updateTime: qa.updateTime,
   495|        question: qa.question,
   496|        answer: qa.answer,
   497|        imageUrl: qa.imageUrl,
   498|        total: newTotal,
   499|        right: newRight,
   500|        wrong: newWrong,
   501|        randomInt: qa.randomInt,
   502|        categoryId: qa.categoryId,
   503|        tagId: qa.tagId,
   504|      );
   505|    });
   506|  }
   507|
   508|  void _nextQuestion() {
   509|    if (_currentIndex < _questions.length - 1) setState(() => _currentIndex++);
   510|  }
   511|
   512|  void _prevQuestion() {
   513|    if (_currentIndex > 0) setState(() => _currentIndex--);
   514|  }
   515|
   516|  void _exitPractice() {
   517|    setState(() => _showExitConfirm = true);
   518|  }
   519|
   520|  void _cancelExit() {
   521|    setState(() => _showExitConfirm = false);
   522|  }
   523|
   524|  void _confirmExit() {
   525|    void attempt(int tries) {
   526|      if (!mounted || !context.mounted) return;
   527|      WidgetsBinding.instance.addPostFrameCallback((_) {
   528|        if (!mounted || !context.mounted) return;
   529|        Navigator.of(context, rootNavigator: true).maybePop().then((didPop) {
   530|          if (!didPop && tries < 20) {
   531|            attempt(tries + 1);
   532|          }
   533|        });
   534|      });
   535|    }
   536|    attempt(0);
   537|  }
   538|
   539|  @override
   540|  Widget build(BuildContext context) {
   541|    final qa = _questions[_currentIndex];
   542|    final revealed = _revealed[_currentIndex];
   543|    final isLast = _currentIndex == _questions.length - 1;
   544|    final userAnswerCtrls = _userAnswerCtrls[_currentIndex];
   545|
   546|    return Scaffold(
   547|        body: Column(
   548|          children: [
   549|            Expanded(
   550|              child: SingleChildScrollView(
   551|                padding: EdgeInsets.all(16.w),
   552|                child: Column(
   553|                  crossAxisAlignment: CrossAxisAlignment.start,
   554|                  children: [
   555|                    Container(
   556|                      padding: EdgeInsets.all(20.w),
   557|                      decoration: BoxDecoration(
   558|                        color: AppTheme.bgCard,
   559|                        borderRadius: BorderRadius.circular(14.r),
   560|                        border: Border.all(color: AppTheme.border),
   561|                      ),
   562|                      child: Column(
   563|                        crossAxisAlignment: CrossAxisAlignment.start,
   564|                        children: [
   565|                          Row(
   566|                            children: [
   567|                              Expanded(
   568|                                child: Text('第 ${_currentIndex + 1} 题', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16.sp, fontFamily: 'Inter', color: AppTheme.textPrimary)),
   569|                              ),
   570|                              Chip(
   571|                                label: Text(widget.bank.name, style: TextStyle(fontSize: 11.sp, fontFamily: 'Inter')),
   572|                                backgroundColor: AppTheme.bgSection,
   573|                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
   574|                              ),
   575|                              SizedBox(width: 8.w),
   576|                              IconButton(
   577|                                icon: const Icon(Icons.close_rounded, size: 20),
   578|                                color: AppTheme.textTertiary,
   579|                                onPressed: _exitPractice,
   580|                                tooltip: '退出练习',
   581|                              ),
   582|                            ],
   583|                          ),
   584|                          SizedBox(height: 20.h),
   585|                          Container(
   586|                            width: double.infinity,
   587|                            padding: EdgeInsets.all(16.w),
   588|                            decoration: BoxDecoration(
   589|                              color: AppTheme.bgSection,
   590|                              borderRadius: BorderRadius.circular(12.r),
   591|                            ),
   592|                            child: QuestionRichText(
   593|                              text: qa.question,
   594|                              revealed: revealed,
   595|                              answers: qa.answer,
   596|                              fontSize: 18,
   597|                            ),
   598|                          ),
   599|                        ],
   600|                      ),
   601|                    ),
   602|                    SizedBox(height: 20.h),
   603|                    if (!revealed) ...[
   604|                      Container(
   605|                        padding: EdgeInsets.all(16.w),
   606|                        decoration: BoxDecoration(
   607|                          color: AppTheme.bgCard,
   608|                          borderRadius: BorderRadius.circular(14.r),
   609|                          border: Border.all(color: AppTheme.border),
   610|                        ),
   611|                        child: Column(
   612|                          crossAxisAlignment: CrossAxisAlignment.start,
   613|                          children: [
   614|                            Text('请填空作答', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp, fontFamily: 'Inter', color: AppTheme.textPrimary)),
   615|                            SizedBox(height: 12.h),
   616|                            ...List.generate(qa.answer.length, (i) => Padding(
   617|                              padding: EdgeInsets.only(bottom: 12.h),
   618|                              child: Row(
   619|                                children: [
   620|                                  Container(
   621|                                    width: 24.w,
   622|                                    height: 24.w,
   623|                                    decoration: BoxDecoration(
   624|                                      color: AppTheme.indigo50,
   625|                                      borderRadius: BorderRadius.circular(6.r),
   626|                                    ),
   627|                                    child: Center(
   628|                                      child: Text('${i + 1}', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: AppTheme.primary, fontFamily: 'Inter')),
   629|                                    ),
   630|                                  ),
   631|                                  SizedBox(width: 8.w),
   632|                                  Expanded(
   633|                                    child: TextField(
   634|                                      controller: userAnswerCtrls[i],
   635|                                      decoration: InputDecoration(
   636|                                        hintText: '空${i + 1} 的答案',
   637|                                        filled: true,
   638|                                        fillColor: AppTheme.bgSection,
   639|                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r), borderSide: const BorderSide(color: AppTheme.border)),
   640|                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r), borderSide: const BorderSide(color: AppTheme.border)),
   641|                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
   642|                                        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
   643|                                      ),
   644|                                    ),
   645|                                  ),
   646|                                ],
   647|                              ),
   648|                            )),
   649|                            SizedBox(height: 8.h),
   650|                            SizedBox(
   651|                              width: double.infinity,
   652|                              height: 48.h,
   653|                              child: ElevatedButton.icon(
   654|                                onPressed: _submitAnswer,
   655|                                icon: const Icon(Icons.check, color: Colors.white),
   656|                                label: const Text('提交答案', style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter')),
   657|                                style: ElevatedButton.styleFrom(
   658|                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
   659|                                ),
   660|                              ),
   661|                            ),
   662|                          ],
   663|                        ),
   664|                      ),
   665|                    ] else ...[
   666|                      Container(
   667|                        padding: EdgeInsets.all(16.w),
   668|                        decoration: BoxDecoration(
   669|                          color: AppTheme.bgCard,
   670|                          borderRadius: BorderRadius.circular(14.r),
   671|                          border: Border.all(color: AppTheme.border),
   672|                        ),
   673|                        child: Column(
   674|                          crossAxisAlignment: CrossAxisAlignment.start,
   675|                          children: [
   676|                            Text('答题结果', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp, fontFamily: 'Inter', color: AppTheme.textPrimary)),
   677|                            SizedBox(height: 12.h),
   678|                            ...List.generate(qa.answer.length, (i) {
   679|                              final isCorrect = userAnswerCtrls[i].text.trim() == qa.answer[i];
   680|                              final borderColor = isCorrect ? AppTheme.green : AppTheme.red;
   681|                              return Padding(
   682|                                padding: EdgeInsets.only(bottom: 16.h),
   683|                                child: Column(
   684|                                  crossAxisAlignment: CrossAxisAlignment.start,
   685|                                  children: [
   686|                                    Row(
   687|                                      crossAxisAlignment: CrossAxisAlignment.center,
   688|                                      children: [
   689|                                        Container(
   690|                                          width: 24.w,
   691|                                          height: 24.w,
   692|                                          decoration: BoxDecoration(
   693|                                            color: isCorrect ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
   694|                                            borderRadius: BorderRadius.circular(6.r),
   695|                                            border: Border.all(color: borderColor, width: 1.5),
   696|                                          ),
   697|                                          child: Center(
   698|                                            child: Icon(
   699|                                              isCorrect ? Icons.check : Icons.close,
   700|                                              size: 14,
   701|                                              color: borderColor,
   702|                                            ),
   703|                                          ),
   704|                                        ),
   705|                                        SizedBox(width: 8.w),
   706|                                        Expanded(
   707|                                          child: TextField(
   708|                                            controller: userAnswerCtrls[i],
   709|                                            readOnly: true,
   710|                                            decoration: InputDecoration(
   711|                                              filled: true,
   712|                                              fillColor: AppTheme.bgSection,
   713|                                              border: OutlineInputBorder(
   714|                                                borderRadius: BorderRadius.circular(10.r),
   715|                                                borderSide: BorderSide(color: borderColor, width: 1.5),
   716|                                              ),
   717|                                              enabledBorder: OutlineInputBorder(
   718|                                                borderRadius: BorderRadius.circular(10.r),
   719|                                                borderSide: BorderSide(color: borderColor, width: 1.5),
   720|                                              ),
   721|                                              contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
   722|                                            ),
   723|                                            style: TextStyle(
   724|                                              fontSize: 14,
   725|                                              fontFamily: 'Inter',
   726|                                              color: isCorrect ? AppTheme.green : AppTheme.red,
   727|                                              fontWeight: FontWeight.w600,
   728|                                            ),
   729|                                          ),
   730|                                        ),
   731|                                      ],
   732|                                    ),
   733|                                    SizedBox(height: 6.h),
   734|                                    Padding(
   735|                                      padding: EdgeInsets.only(left: 32.w),
   736|                                      child: Row(
   737|                                        children: [
   738|                                          Text('正确答案：', style: TextStyle(fontSize: 12.sp, color: AppTheme.textTertiary, fontFamily: 'Inter')),
   739|                                          Text(qa.answer[i], style: TextStyle(fontSize: 13.sp, color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
   740|                                        ],
   741|                                      ),
   742|                                    ),
   743|                                  ],
   744|                                ),
   745|                              );
   746|                            }),
   747|                          ],
   748|                        ),
   749|                      ),
   750|                    ],
   751|                  ],
   752|                ),
   753|              ),
   754|            ),
   755|            if (_showExitConfirm)
   756|              Container(
   757|                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
   758|                decoration: BoxDecoration(
   759|                  color: AppTheme.bgCard,
   760|                  border: Border(top: BorderSide(color: AppTheme.border)),
   761|                ),
   762|                child: Row(
   763|                  children: [
   764|                    Expanded(
   765|                      child: OutlinedButton(
   766|                        onPressed: _cancelExit,
   767|                        child: const Text('继续练习'),
   768|                      ),
   769|                    ),
   770|                    SizedBox(width: 12.w),
   771|                    Expanded(
   772|                      child: ElevatedButton(
   773|                        onPressed: _confirmExit,
   774|                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
   775|                        child: const Text('退出', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
   776|                      ),
   777|                    ),
   778|                  ],
   779|                ),
   780|              )
   781|            else
   782|              Container(
   783|                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
   784|                decoration: BoxDecoration(
   785|                  color: AppTheme.bgCard,
   786|                  border: Border(top: BorderSide(color: AppTheme.border)),
   787|                ),
   788|                child: Row(
   789|                  children: [
   790|                    Expanded(
   791|                      child: OutlinedButton.icon(
   792|                        onPressed: _currentIndex > 0 ? _prevQuestion : null,
   793|                        icon: const Icon(Icons.chevron_left),
   794|                        label: const Text('上一题'),
   795|                      ),
   796|                    ),
   797|                    SizedBox(width: 12.w),
   798|                    Container(
   799|                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
   800|                      decoration: BoxDecoration(
   801|                        color: AppTheme.indigo50,
   802|                        borderRadius: BorderRadius.circular(20.r),
   803|                      ),
   804|                      child: Text(
   805|                        '${_currentIndex + 1} / ${_questions.length}',
   806|                        style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 13.sp, fontFamily: 'Inter'),
   807|                      ),
   808|                    ),
   809|                    SizedBox(width: 12.w),
   810|                    Expanded(
   811|                      child: ElevatedButton.icon(
   812|                        onPressed: _revealed[_currentIndex] ? (!isLast ? _nextQuestion : () => Navigator.pop(context)) : null,
   813|                        iconAlignment: IconAlignment.end,
   814|                        icon: isLast ? const SizedBox.shrink() : const Icon(Icons.chevron_right, color: Colors.white),
   815|                        label: Text(isLast ? '返回' : '下一题', style: TextStyle(fontWeight: FontWeight.w600)),
   816|                      ),
   817|                    ),
   818|                  ],
   819|                ),
   820|              ),
   821|          ],
   822|        ),
   823|    );
   824|  }
   825|}
   826|