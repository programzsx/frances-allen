     1|import 'package:flutter/material.dart';
     2|import '../models/models.dart';
     3|import '../services/api_service.dart';
     4|import 'qa_detail_page.dart';
     5|import 'qa_form_page.dart';
     6|import 'question_rich_text.dart';
     7|import '../theme/desktop_theme.dart';
     8|
     9|class QaPage extends StatefulWidget {
    10|  final String? initialCategoryId;
    11|  final String? initialBankName;
    12|  final String? initialTagId;
    13|  final String? initialTagName;
    14|
    15|  const QaPage({
    16|    super.key,
    17|    this.initialCategoryId,
    18|    this.initialBankName,
    19|    this.initialTagId,
    20|    this.initialTagName,
    21|  });
    22|
    23|  @override
    24|  State<QaPage> createState() => _QaPageState();
    25|}
    26|
    27|class _QaPageState extends State<QaPage> {
    28|  List<KbQa> _qas = [];
    29|  int _total = 0;
    30|  int _currentPage = 1;
    31|  bool _loading = true;
    32|  bool _loadingMore = false;
    33|  String? _keyword;
    34|  String? _categoryId;
    35|  String? _tagId;
    36|  List<KbBank> _banks = [];
    37|  List<KbTag> _tags = [];
    38|  final _searchCtrl = TextEditingController();
    39|  final _scrollCtrl = ScrollController();
    40|
    41|  @override
    42|  void initState() {
    43|    super.initState();
    44|    _categoryId = widget.initialCategoryId;
    45|    _tagId = widget.initialTagId;
    46|    _loadBanks();
    47|    _loadTags();
    48|    _loadQas();
    49|    _scrollCtrl.addListener(_onScroll);
    50|  }
    51|
    52|  @override
    53|  void dispose() {
    54|    _searchCtrl.dispose();
    55|    _scrollCtrl.dispose();
    56|    super.dispose();
    57|  }
    58|
    59|  void _onScroll() {
    60|    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
    61|      if (!_loadingMore && _qas.length < _total) {
    62|        _loadMore();
    63|      }
    64|    }
    65|  }
    66|
    67|  Future<void> _loadMore() async {
    68|    if (_loadingMore || _qas.length >= _total) return;
    69|    setState(() => _loadingMore = true);
    70|    try {
    71|      final data = await ApiService.pageQas(
    72|        currentPage: _currentPage + 1,
    73|        categoryId: _categoryId,
    74|        keyword: _keyword,
    75|        tagId: _tagId,
    76|      );
    77|      final newQas = (data['items'] as List).map((e) => KbQa.fromJson(e)).toList();
    78|      setState(() {
    79|        _qas.addAll(newQas);
    80|        _currentPage++;
    81|        _loadingMore = false;
    82|      });
    83|    } catch (e) {
    84|      setState(() => _loadingMore = false);
    85|    }
    86|  }
    87|
    88|  Future<void> _loadBanks() async {
    89|    try {
    90|      final data = await ApiService.pageBanks(pageSize: 100);
    91|      setState(() {
    92|        _banks = (data['items'] as List).map((e) => KbBank.fromJson(e)).toList();
    93|      });
    94|    } catch (_) {}
    95|  }
    96|
    97|  Future<void> _loadTags() async {
    98|    try {
    99|      final data = await ApiService.pageTags(pageSize: 100);
   100|      setState(() {
   101|        _tags = (data['items'] as List).map((e) => KbTag.fromJson(e)).toList();
   102|      });
   103|    } catch (_) {}
   104|  }
   105|
   106|  Future<void> _loadQas() async {
   107|    setState(() => _loading = true);
   108|    try {
   109|      final data = await ApiService.pageQas(
   110|        currentPage: _currentPage,
   111|        categoryId: _categoryId,
   112|        keyword: _keyword,
   113|        tagId: _tagId,
   114|      );
   115|      setState(() {
   116|        _qas = (data['items'] as List).map((e) => KbQa.fromJson(e)).toList();
   117|        _total = data['total'];
   118|        _loading = false;
   119|      });
   120|    } catch (e) {
   121|      setState(() => _loading = false);
   122|      if (mounted) {
   123|        ScaffoldMessenger.of(context).showSnackBar(
   124|          SnackBar(content: Text('加载失败: $e')),
   125|        );
   126|      }
   127|    }
   128|  }
   129|
   130|  void _doSearch(String v) {
   131|    setState(() {
   132|      _keyword = v.isEmpty ? null : v;
   133|      _currentPage = 1;
   134|    });
   135|    _loadQas();
   136|  }
   137|
   138|  Future<void> _deleteQa(KbQa qa) async {
   139|    final result = await showDialog<bool>(
   140|      context: context,
   141|      builder: (ctx) => AlertDialog(
   142|        title: const Text('确认删除'),
   143|        content: const Text('确定删除该题目吗？'),
   144|        actions: [
   145|          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
   146|          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除', style: TextStyle(color: DesktopTheme.red))),
   147|        ],
   148|      ),
   149|    );
   150|    if (result == true) {
   151|      await ApiService.deleteQa(qa.id);
   152|      _loadQas();
   153|    }
   154|  }
   155|
   156|  String _getCategoryName(String? categoryId) {
   157|    if (categoryId == null) return '未分类';
   158|    final bank = _banks.where((b) => b.id == categoryId).firstOrNull;
   159|    return bank?.name ?? '未知';
   160|  }
   161|
   162|  Color _accuracyColor(double accuracy) {
   163|    if (accuracy >= 0.8) return DesktopTheme.green;
   164|    if (accuracy >= 0.5) return DesktopTheme.orange;
   165|    return DesktopTheme.red;
   166|  }
   167|
   168|  @override
   169|  Widget build(BuildContext context) {
   170|    return Scaffold(
   171|      body: Column(
   172|        children: [
   173|          // Header
   174|          Container(
   175|            padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
   176|            decoration: BoxDecoration(
   177|              color: DesktopTheme.bgCard,
   178|              border: Border(bottom: BorderSide(color: DesktopTheme.border, width: 0.5)),
   179|            ),
   180|            child: Row(
   181|              children: [
   182|                if (widget.initialBankName != null || widget.initialTagName != null) ...[
   183|                  GestureDetector(
   184|                    onTap: () => Navigator.pop(context),
   185|                    child: Icon(Icons.arrow_back_ios, size: 16, color: DesktopTheme.textSecondary),
   186|                  ),
   187|                  const SizedBox(width: 8),
   188|                ],
   189|                Expanded(
   190|                  child: Text(
   191|                    widget.initialTagName ?? widget.initialBankName ?? '全部题目',
   192|                    style: const TextStyle(
   193|                      fontSize: 16,
   194|                      fontWeight: FontWeight.w600,
   195|                      color: DesktopTheme.textPrimary,
   196|                    ),
   197|                  ),
   198|                ),
   199|                if (_total > 0)
   200|                  Text(
   201|                    '$_total 题',
   202|                    style: const TextStyle(
   203|                      fontSize: 13,
   204|                      color: DesktopTheme.textTertiary,
   205|                    ),
   206|                  ),
   207|              ],
   208|            ),
   209|          ),
   210|
   211|          // Search
   212|          Padding(
   213|            padding: const EdgeInsets.fromLTRB(24, 10, 24, 6),
   214|            child: TextField(
   215|              controller: _searchCtrl,
   216|              decoration: InputDecoration(
   217|                hintText: '搜索题目',
   218|                hintStyle: const TextStyle(fontSize: 13, color: DesktopTheme.textTertiary),
   219|                prefixIcon: const Icon(Icons.search_rounded, size: 18),
   220|                filled: true,
   221|                fillColor: DesktopTheme.bgCard,
   222|                border: OutlineInputBorder(
   223|                  borderRadius: BorderRadius.circular(6),
   224|                  borderSide: const BorderSide(color: DesktopTheme.border),
   225|                ),
   226|                enabledBorder: OutlineInputBorder(
   227|                  borderRadius: BorderRadius.circular(6),
   228|                  borderSide: const BorderSide(color: DesktopTheme.border),
   229|                ),
   230|                focusedBorder: OutlineInputBorder(
   231|                  borderRadius: BorderRadius.circular(6),
   232|                  borderSide: const BorderSide(color: DesktopTheme.primary, width: 2),
   233|                ),
   234|                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
   235|              ),
   236|              style: const TextStyle(fontSize: 14),
   237|              onSubmitted: _doSearch,
   238|            ),
   239|          ),
   240|
   241|          // Bank filter chips
   242|          if (_banks.isNotEmpty && widget.initialCategoryId == null)
   243|            SizedBox(
   244|              height: 40,
   245|              child: ListView(
   246|                scrollDirection: Axis.horizontal,
   247|                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
   248|                children: [
   249|                  Padding(
   250|                    padding: const EdgeInsets.only(right: 6),
   251|                    child: _FilterChip(label: '全部', selected: _categoryId == null, onTap: () {
   252|                      setState(() { _categoryId = null; _currentPage = 1; });
   253|                      _loadQas();
   254|                    }),
   255|                  ),
   256|                  ..._banks.map((b) => Padding(
   257|                    padding: const EdgeInsets.only(right: 6),
   258|                    child: _FilterChip(label: b.name, selected: _categoryId == b.id, onTap: () {
   259|                      setState(() { _categoryId = b.id; _currentPage = 1; });
   260|                      _loadQas();
   261|                    }),
   262|                  )),
   263|                ],
   264|              ),
   265|            ),
   266|
   267|          // List
   268|          Expanded(
   269|            child: _loading
   270|                ? const Center(child: CircularProgressIndicator())
   271|                : _qas.isEmpty
   272|                    ? Center(
   273|                        child: Column(
   274|                          mainAxisSize: MainAxisSize.min,
   275|                          children: [
   276|                            Icon(Icons.quiz_outlined, size: 56, color: DesktopTheme.textTertiary),
   277|                            const SizedBox(height: 16),
   278|                            Text('暂无题目', style: TextStyle(color: DesktopTheme.textTertiary, fontSize: 15)),
   279|                            const SizedBox(height: 8),
   280|                            Text('点击右下角按钮创建', style: TextStyle(color: DesktopTheme.textTertiary, fontSize: 13)),
   281|                          ],
   282|                        ),
   283|                      )
   284|                    : ListView.builder(
   285|                        controller: _scrollCtrl,
   286|                        padding: const EdgeInsets.only(top: 4, bottom: 72),
   287|                        itemCount: _qas.length + (_loadingMore ? 1 : 0),
   288|                        itemBuilder: (ctx, i) {
   289|                          if (i >= _qas.length) {
   290|                            return const Padding(
   291|                              padding: EdgeInsets.all(16),
   292|                              child: Center(child: CircularProgressIndicator()),
   293|                            );
   294|                          }
   295|                          final qa = _qas[i];
   296|                          final accColor = _accuracyColor(qa.accuracy);
   297|                          return _QaCard(
   298|                            qa: qa,
   299|                            categoryName: _getCategoryName(qa.categoryId),
   300|                            accColor: accColor,
   301|                            onTap: () async {
   302|                              await Navigator.push(context, MaterialPageRoute(
   303|                                builder: (_) => QaDetailPage(
   304|                                  qa: qa,
   305|                                  banks: _banks,
   306|                                  tags: _tags,
   307|                                  onRefresh: _loadQas,
   308|                                ),
   309|                              ));
   310|                              _loadQas();
   311|                            },
   312|                            onDelete: () => _deleteQa(qa),
   313|                          );
   314|                        },
   315|                      ),
   316|          ),
   317|        ],
   318|      ),
   319|      floatingActionButton: FloatingActionButton(
   320|        heroTag: 'qa_fab',
   321|        onPressed: () async {
   322|          await Navigator.push(context, MaterialPageRoute(builder: (_) => const QaFormPage()));
   323|          _loadQas();
   324|        },
   325|        child: const Icon(Icons.add_circle_outlined, color: Colors.white),
   326|      ),
   327|    );
   328|  }
   329|}
   330|
   331|/// QA card
   332|class _QaCard extends StatelessWidget {
   333|  final KbQa qa;
   334|  final String categoryName;
   335|  final Color accColor;
   336|  final VoidCallback onTap;
   337|  final VoidCallback onDelete;
   338|
   339|  const _QaCard({
   340|    required this.qa,
   341|    required this.categoryName,
   342|    required this.accColor,
   343|    required this.onTap,
   344|    required this.onDelete,
   345|  });
   346|
   347|  @override
   348|  Widget build(BuildContext context) {
   349|    return Container(
   350|      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 5),
   351|      decoration: BoxDecoration(
   352|        color: DesktopTheme.bgCard,
   353|        borderRadius: BorderRadius.circular(8),
   354|        border: Border.all(color: DesktopTheme.border),
   355|      ),
   356|      child: ClipRRect(
   357|        borderRadius: BorderRadius.circular(8),
   358|        child: Material(
   359|          color: Colors.transparent,
   360|          child: InkWell(
   361|            onTap: onTap,
   362|            child: Padding(
   363|              padding: const EdgeInsets.all(14),
   364|              child: Row(
   365|                crossAxisAlignment: CrossAxisAlignment.start,
   366|                children: [
   367|                  Expanded(
   368|                    child: Column(
   369|                      crossAxisAlignment: CrossAxisAlignment.start,
   370|                      children: [
   371|                        QuestionRichText(text: qa.question, fontSize: 14),
   372|                        const SizedBox(height: 8),
   373|                        Row(
   374|                          children: [
   375|                            Text(categoryName, style: const TextStyle(fontSize: 11, color: DesktopTheme.textTertiary)),
   376|                            const Spacer(),
   377|                            Text(
   378|                              '${(qa.accuracy * 100).toStringAsFixed(0)}%',
   379|                              style: TextStyle(color: accColor, fontWeight: FontWeight.bold, fontSize: 13),
   380|                            ),
   381|                          ],
   382|                        ),
   383|                      ],
   384|                    ),
   385|                  ),
   386|                  SizedBox(
   387|                    width: 32,
   388|                    height: 32,
   389|                    child: IconButton(
   390|                      icon: const Icon(Icons.delete_outline, color: DesktopTheme.red, size: 18),
   391|                      onPressed: onDelete,
   392|                      padding: EdgeInsets.zero,
   393|                      constraints: const BoxConstraints(),
   394|                    ),
   395|                  ),
   396|                ],
   397|              ),
   398|            ),
   399|          ),
   400|        ),
   401|      ),
   402|    );
   403|  }
   404|}
   405|
   406|class _FilterChip extends StatelessWidget {
   407|  final String label;
   408|  final bool selected;
   409|  final VoidCallback onTap;
   410|
   411|  const _FilterChip({required this.label, required this.selected, required this.onTap});
   412|
   413|  @override
   414|  Widget build(BuildContext context) {
   415|    return GestureDetector(
   416|      onTap: onTap,
   417|      child: Container(
   418|        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
   419|        decoration: BoxDecoration(
   420|          color: selected ? DesktopTheme.indigo50 : DesktopTheme.bgSection,
   421|          borderRadius: BorderRadius.circular(16),
   422|          border: Border.all(
   423|            color: selected ? DesktopTheme.indigo100 : DesktopTheme.border,
   424|            width: 1,
   425|          ),
   426|        ),
   427|        child: Text(
   428|          label,
   429|          style: TextStyle(
   430|            fontSize: 12,
   431|            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
   432|            color: selected ? DesktopTheme.primary : DesktopTheme.textSecondary,
   433|          ),
   434|        ),
   435|      ),
   436|    );
   437|  }
   438|}
   439|