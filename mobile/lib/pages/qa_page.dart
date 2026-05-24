     1|import 'package:flutter/material.dart';
     2|import 'package:flutter_screenutil/flutter_screenutil.dart';
     3|import '../models/models.dart';
     4|import '../services/api_service.dart';
     5|import '../services/data_cache.dart';
     6|import 'qa_detail_page.dart';
     7|import 'qa_form_page.dart';
     8|import 'bank_page.dart';
     9|import 'tag_page.dart';
    10|import 'practice_page.dart';
    11|import 'question_rich_text.dart';
    12|import '../theme/app_theme.dart';
    13|
    14|class QaPage extends StatefulWidget {
    15|  final String? initialCategoryId;
    16|  final String? initialTagId;
    17|
    18|  const QaPage({super.key, this.initialCategoryId, this.initialTagId});
    19|
    20|  @override
    21|  State<QaPage> createState() => _QaPageState();
    22|}
    23|
    24|class _QaPageState extends State<QaPage> {
    25|  List<KbQa> _qas = [];
    26|  int _total = 0;
    27|  int _currentPage = 1;
    28|  bool _busy = true;
    29|  bool _loadingMore = false;
    30|
    31|  String? _bid; // selected bank id
    32|  String? _tid; // selected tag id
    33|  final _q = TextEditingController();
    34|  final _sc = ScrollController();
    35|
    36|  List<KbBank> _banks = [];
    37|  List<KbTag> _tags = [];
    38|
    39|  @override
    40|  void initState() {
    41|    super.initState();
    42|    _bid = widget.initialCategoryId;
    43|    _tid = widget.initialTagId;
    44|    _fetchMeta();
    45|    _fetch();
    46|    _sc.addListener(_more);
    47|  }
    48|
    49|  void _more() {
    50|    if (_sc.position.pixels > _sc.position.maxScrollExtent - 150 &&
    51|        !_busy &&
    52|        !_loadingMore &&
    53|        _qas.length < _total) {
    54|      _currentPage++;
    55|      _fetch();
    56|    }
    57|  }
    58|
    59|  Future<void> _fetchMeta() async {
    60|    final cache = DataCache();
    61|    await cache.ensureBanks();
    62|    await cache.ensureTags();
    63|    if (mounted) {
    64|      setState(() {
    65|        _banks = cache.allBanks;
    66|        _tags = cache.allTags;
    67|      });
    68|    }
    69|  }
    70|
    71|  Future<void> _fetch() async {
    72|    setState(() => _busy = true);
    73|    try {
    74|      final data = await ApiService.pageQas(
    75|        currentPage: _currentPage,
    76|        categoryId: _bid,
    77|        keyword: _q.text.isNotEmpty ? _q.text : null,
    78|        tagId: _tid,
    79|      );
    80|      if (mounted) {
    81|        setState(() {
    82|          _total = data['total'] as int;
    83|          if (_currentPage == 1) {
    84|            _qas = (data['items'] as List)
    85|                .map((e) => KbQa.fromJson(e))
    86|                .toList();
    87|          } else {
    88|            _qas.addAll((data['items'] as List)
    89|                .map((e) => KbQa.fromJson(e)));
    90|          }
    91|          _busy = false;
    92|        });
    93|      }
    94|    } catch (_) {
    95|      if (mounted) setState(() => _busy = false);
    96|    }
    97|  }
    98|
    99|  void _toggleBank(String? id) {
   100|    setState(() {
   101|      _bid = _bid == id ? null : id;
   102|      _tid = null;
   103|      _currentPage = 1;
   104|      _qas = [];
   105|    });
   106|    _fetch();
   107|  }
   108|
   109|  void _toggleTag(String? id) {
   110|    setState(() {
   111|      _tid = _tid == id ? null : id;
   112|      _currentPage = 1;
   113|      _qas = [];
   114|    });
   115|    _fetch();
   116|  }
   117|
   118|  String _categoryName(String? id) {
   119|    if (id == null) return '未分类';
   120|    return _banks.where((b) => b.id == id).firstOrNull?.name ?? '未知';
   121|  }
   122|
   123|  Color _accColor(double a) {
   124|    if (a >= 0.8) return AppTheme.success;
   125|    if (a >= 0.5) return AppTheme.accent;
   126|    return AppTheme.danger;
   127|  }
   128|
   129|  Future<void> _deleteQa(KbQa qa) async {
   130|    final ok = await showDialog<bool>(
   131|      context: context,
   132|      builder: (ctx) => AlertDialog(
   133|        title: const Text('确认删除'),
   134|        content: const Text('确定删除该题目吗？'),
   135|        actions: [
   136|          TextButton(
   137|            onPressed: () => Navigator.pop(ctx, false),
   138|            child: const Text('取消'),
   139|          ),
   140|          TextButton(
   141|            onPressed: () => Navigator.pop(ctx, true),
   142|            child: const Text('删除',
   143|                style: TextStyle(color: AppTheme.danger)),
   144|          ),
   145|        ],
   146|      ),
   147|    );
   148|    if (ok == true) {
   149|      await ApiService.deleteQa(qa.id);
   150|      _currentPage = 1;
   151|      _fetch();
   152|    }
   153|  }
   154|
   155|  @override
   156|  Widget build(BuildContext context) {
   157|    final selBank = _banks.where((b) => b.id == _bid).firstOrNull;
   158|
   159|    return Scaffold(
   160|      appBar: AppBar(
   161|        title: const Text('题目'),
   162|        actions: [
   163|          IconButton(
   164|            icon: const Icon(Icons.sell_outlined, size: 22),
   165|            tooltip: '标签',
   166|            onPressed: () => Navigator.push(
   167|              context,
   168|              MaterialPageRoute(builder: (_) => const TagPage()),
   169|            ).then((_) {
   170|              DataCache().invalidate();
   171|              _fetchMeta();
   172|              _currentPage = 1;
   173|              _fetch();
   174|            }),
   175|          ),
   176|          IconButton(
   177|            icon: const Icon(Icons.folder_outlined, size: 22),
   178|            tooltip: '题库',
   179|            onPressed: () => Navigator.push(
   180|              context,
   181|              MaterialPageRoute(builder: (_) => const BankPage()),
   182|            ).then((_) {
   183|              DataCache().invalidate();
   184|              _fetchMeta();
   185|              _currentPage = 1;
   186|              _fetch();
   187|            }),
   188|          ),
   189|          IconButton(
   190|            icon: const Icon(Icons.school_outlined, size: 22),
   191|            tooltip: '练习',
   192|            onPressed: () => Navigator.push(
   193|              context,
   194|              MaterialPageRoute(builder: (_) => const PracticePage()),
   195|            ),
   196|          ),
   197|        ],
   198|      ),
   199|      body: Column(
   200|        children: [
   201|          // Search
   202|          Padding(
   203|            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
   204|            child: TextField(
   205|              controller: _q,
   206|              style: const TextStyle(fontSize: 15),
   207|              decoration: InputDecoration(
   208|                hintText: '搜索题目…',
   209|                prefixIcon: const Icon(Icons.search,
   210|                    color: AppTheme.textHint, size: 20),
   211|                suffixIcon: _q.text.isNotEmpty
   212|                    ? IconButton(
   213|                        icon: const Icon(Icons.clear, size: 18),
   214|                        onPressed: () {
   215|                          _q.clear();
   216|                          _currentPage = 1;
   217|                          _fetch();
   218|                        },
   219|                      )
   220|                    : null,
   221|              ),
   222|              onSubmitted: (_) {
   223|                _currentPage = 1;
   224|                _fetch();
   225|              },
   226|            ),
   227|          ),
   228|
   229|          // Bank chip row (always visible)
   230|          SizedBox(
   231|            height: 44,
   232|            child: ListView(
   233|              scrollDirection: Axis.horizontal,
   234|              padding:
   235|                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
   236|              children: _banks
   237|                  .map((b) =>
   238|                      _chip(b.name, _bid == b.id, () => _toggleBank(b.id)))
   239|                  .toList(),
   240|            ),
   241|          ),
   242|
   243|          // Tag chip row (only when bank selected)
   244|          if (selBank != null && _tags.isNotEmpty)
   245|            SizedBox(
   246|              height: 38,
   247|              child: ListView(
   248|                scrollDirection: Axis.horizontal,
   249|                padding: const EdgeInsets.symmetric(horizontal: 12),
   250|                children: _tags
   251|                    .map((t) => _chip(t.name, _tid == t.id,
   252|                        () => _toggleTag(t.id),
   253|                        small: true))
   254|                    .toList(),
   255|              ),
   256|            ),
   257|
   258|          const Divider(height: 1),
   259|
   260|          // Question list
   261|          Expanded(
   262|            child: _busy && _qas.isEmpty
   263|                ? const Center(child: CircularProgressIndicator())
   264|                : _qas.isEmpty
   265|                    ? Center(
   266|                        child: Column(
   267|                          mainAxisSize: MainAxisSize.min,
   268|                          children: [
   269|                            Icon(Icons.quiz_outlined,
   270|                                size: 56,
   271|                                color: AppTheme.textHint
   272|                                    .withValues(alpha: 0.5)),
   273|                            const SizedBox(height: 12),
   274|                            const Text('暂无题目',
   275|                                style: TextStyle(
   276|                                    color: AppTheme.textSoft,
   277|                                    fontSize: 15)),
   278|                          ],
   279|                        ),
   280|                      )
   281|                    : ListView.builder(
   282|                        controller: _sc,
   283|                        padding:
   284|                            const EdgeInsets.only(top: 2, bottom: 80),
   285|                        itemCount:
   286|                            _qas.length + (_loadingMore ? 1 : 0),
   287|                        itemBuilder: (_, i) {
   288|                          if (i >= _qas.length) {
   289|                            return const Padding(
   290|                              padding: EdgeInsets.all(20),
   291|                              child: Center(
   292|                                child: SizedBox(
   293|                                  width: 24,
   294|                                  height: 24,
   295|                                  child: CircularProgressIndicator(
   296|                                      strokeWidth: 2),
   297|                                ),
   298|                              ),
   299|                            );
   300|                          }
   301|                          return _card(_qas[i]);
   302|                        },
   303|                      ),
   304|          ),
   305|        ],
   306|      ),
   307|      floatingActionButton: FloatingActionButton(
   308|        onPressed: () async {
   309|          await Navigator.push(
   310|            context,
   311|            MaterialPageRoute(
   312|                builder: (_) => const QaFormPage()),
   313|          );
   314|          _currentPage = 1;
   315|          _fetch();
   316|        },
   317|        child: const Icon(Icons.add),
   318|      ),
   319|    );
   320|  }
   321|
   322|  // ── Alan Perlis style chip ──────────────────────────
   323|  Widget _chip(String label, bool sel, VoidCallback fn,
   324|          {bool small = false}) =>
   325|      Padding(
   326|        padding: const EdgeInsets.only(right: 6),
   327|        child: ChoiceChip(
   328|          label: Text(label,
   329|              style: TextStyle(
   330|                  fontSize: small ? 11 : 12,
   331|                  fontWeight: FontWeight.w500,
   332|                  color: sel ? Colors.white : AppTheme.textSoft)),
   333|          selected: sel,
   334|          onSelected: (_) => fn(),
   335|          selectedColor: AppTheme.primary,
   336|          backgroundColor: AppTheme.bg,
   337|          side: BorderSide.none,
   338|          visualDensity: VisualDensity.compact,
   339|          shape: RoundedRectangleBorder(
   340|              borderRadius: BorderRadius.circular(sel ? 8 : 6)),
   341|        ),
   342|      );
   343|
   344|  // ── Question card ───────────────────────────────────
   345|  Widget _card(KbQa qa) {
   346|    return Card(
   347|      child: InkWell(
   348|        borderRadius: BorderRadius.circular(12),
   349|        onTap: () async {
   350|          await Navigator.push(
   351|            context,
   352|            MaterialPageRoute(
   353|              builder: (_) => QaDetailPage(
   354|                qa: qa,
   355|                banks: _banks,
   356|                tags: _tags,
   357|                onRefresh: () {
   358|                  _currentPage = 1;
   359|                  _fetch();
   360|                },
   361|              ),
   362|            ),
   363|          );
   364|          _currentPage = 1;
   365|          _fetch();
   366|        },
   367|        child: Padding(
   368|          padding: const EdgeInsets.all(14),
   369|          child: Row(
   370|            children: [
   371|              Expanded(
   372|                child: Column(
   373|                  crossAxisAlignment: CrossAxisAlignment.start,
   374|                  children: [
   375|                    QuestionRichText(
   376|                        text: qa.question, fontSize: 14),
   377|                    const SizedBox(height: 8),
   378|                    Row(
   379|                      children: [
   380|                        Text(_categoryName(qa.categoryId),
   381|                            style: const TextStyle(
   382|                                fontSize: 11,
   383|                                color: AppTheme.textSoft)),
   384|                        const Spacer(),
   385|                        Text(
   386|                          '${(qa.accuracy * 100).toStringAsFixed(0)}%',
   387|                          style: TextStyle(
   388|                            color: _accColor(qa.accuracy),
   389|                            fontWeight: FontWeight.bold,
   390|                            fontSize: 13,
   391|                          ),
   392|                        ),
   393|                      ],
   394|                    ),
   395|                  ],
   396|                ),
   397|              ),
   398|              const SizedBox(width: 4),
   399|              IconButton(
   400|                icon: const Icon(Icons.delete_outline,
   401|                    color: AppTheme.danger, size: 18),
   402|                onPressed: () => _deleteQa(qa),
   403|                padding: EdgeInsets.zero,
   404|                constraints: const BoxConstraints(),
   405|              ),
   406|            ],
   407|          ),
   408|        ),
   409|      ),
   410|    );
   411|  }
   412|
   413|  @override
   414|  void dispose() {
   415|    _q.dispose();
   416|    _sc.dispose();
   417|    super.dispose();
   418|  }
   419|}
   420|