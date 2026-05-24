     1|import 'package:flutter/material.dart';
     2|import 'package:cached_network_image/cached_network_image.dart';
     3|import '../models/models.dart';
     4|import '../services/api_service.dart';
     5|import 'qa_form_page.dart';
     6|import 'question_rich_text.dart';
     7|import '../theme/desktop_theme.dart';
     8|
     9|class QaDetailPage extends StatefulWidget {
    10|  final KbQa qa;
    11|  final List<KbBank> banks;
    12|  final List<KbTag> tags;
    13|  final VoidCallback onRefresh;
    14|
    15|  const QaDetailPage({
    16|    super.key,
    17|    required this.qa,
    18|    required this.banks,
    19|    required this.tags,
    20|    required this.onRefresh,
    21|  });
    22|
    23|  @override
    24|  State<QaDetailPage> createState() => _QaDetailPageState();
    25|}
    26|
    27|class _QaDetailPageState extends State<QaDetailPage> {
    28|  late KbQa _qa;
    29|  bool _deleting = false;
    30|
    31|  @override
    32|  void initState() {
    33|    super.initState();
    34|    _qa = widget.qa;
    35|  }
    36|
    37|  String get _categoryName {
    38|    if (_qa.categoryId == null) return '未分类';
    39|    final bank = widget.banks.where((b) => b.id == _qa.categoryId).firstOrNull;
    40|    return bank?.name ?? '未知';
    41|  }
    42|
    43|  List<String> get _tagNames {
    44|    if (_qa.tagId == null || _qa.tagId!.isEmpty) return [];
    45|    return _qa.tagId!
    46|        .map((id) => widget.tags.where((t) => t.id == id).firstOrNull?.name)
    47|        .whereType<String>()
    48|        .toList();
    49|  }
    50|
    51|  Future<void> _delete() async {
    52|    final result = await showDialog<bool>(
    53|      context: context,
    54|      builder: (ctx) => AlertDialog(
    55|        title: const Text('确认删除'),
    56|        content: const Text('确定删除该题目吗？'),
    57|        actions: [
    58|          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
    59|          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除', style: TextStyle(color: DesktopTheme.red))),
    60|        ],
    61|      ),
    62|    );
    63|    if (result == true) {
    64|      setState(() => _deleting = true);
    65|      await ApiService.deleteQa(_qa.id);
    66|      if (mounted) {
    67|        Navigator.pop(context);
    68|        widget.onRefresh();
    69|      }
    70|    }
    71|  }
    72|
    73|  Future<void> _refreshData() async {
    74|    try {
    75|      final data = await ApiService.getQa(_qa.id);
    76|      if (data != null && mounted) {
    77|        setState(() => _qa = KbQa.fromJson(data));
    78|      }
    79|    } catch (_) {}
    80|  }
    81|
    82|  Color _accuracyColor(double accuracy) {
    83|    if (accuracy >= 0.8) return DesktopTheme.green;
    84|    if (accuracy >= 0.5) return DesktopTheme.orange;
    85|    return DesktopTheme.red;
    86|  }
    87|
    88|  @override
    89|  Widget build(BuildContext context) {
    90|    return Scaffold(
    91|      appBar: AppBar(
    92|        title: const Text('题目详情', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
    93|        centerTitle: true,
    94|        leading: IconButton(
    95|          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
    96|          onPressed: () => Navigator.pop(context),
    97|        ),
    98|        actions: [
    99|          IconButton(
   100|            icon: _deleting
   101|                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
   102|                : const Icon(Icons.edit_outlined, size: 20),
   103|            onPressed: _deleting ? null : () async {
   104|              await Navigator.push(context, MaterialPageRoute(builder: (_) => QaFormPage(qa: _qa)));
   105|              _refreshData();
   106|            },
   107|            tooltip: '编辑',
   108|          ),
   109|          IconButton(
   110|            icon: _deleting ? const SizedBox.shrink() : const Icon(Icons.delete_outline, size: 20),
   111|            onPressed: _deleting ? null : _delete,
   112|            tooltip: '删除',
   113|          ),
   114|        ],
   115|      ),
   116|      body: SingleChildScrollView(
   117|        padding: const EdgeInsets.all(24),
   118|        child: Column(
   119|          crossAxisAlignment: CrossAxisAlignment.start,
   120|          children: [
   121|            // Bank & Tags
   122|            Wrap(
   123|              spacing: 8,
   124|              runSpacing: 8,
   125|              children: [
   126|                _TagChip(label: _categoryName, color: DesktopTheme.indigo50, textColor: DesktopTheme.primary, borderColor: DesktopTheme.indigo100),
   127|                ..._tagNames.map((name) => _TagChip(label: name, color: DesktopTheme.bgSection, textColor: DesktopTheme.textSecondary, borderColor: DesktopTheme.border)),
   128|              ],
   129|            ),
   130|            const SizedBox(height: 24),
   131|
   132|            // Question
   133|            _SectionHeader(icon: Icons.edit_note_outlined, label: '题目'),
   134|            const SizedBox(height: 10),
   135|            Container(
   136|              width: double.infinity,
   137|              padding: const EdgeInsets.all(20),
   138|              decoration: BoxDecoration(
   139|                color: DesktopTheme.bgSection,
   140|                borderRadius: BorderRadius.circular(8),
   141|              ),
   142|              child: QuestionRichText(text: _qa.question, fontSize: 15),
   143|            ),
   144|            const SizedBox(height: 24),
   145|
   146|            // Answers
   147|            _SectionHeader(icon: Icons.check_circle_outline, label: '答案'),
   148|            const SizedBox(height: 10),
   149|            Container(
   150|              width: double.infinity,
   151|              padding: const EdgeInsets.all(20),
   152|              decoration: BoxDecoration(
   153|                color: const Color(0xFFF0FDF4),
   154|                borderRadius: BorderRadius.circular(8),
   155|                border: Border.all(color: const Color(0xFFBBF7D0)),
   156|              ),
   157|              child: Column(
   158|                crossAxisAlignment: CrossAxisAlignment.start,
   159|                children: _qa.answer.asMap().entries.map((e) => Padding(
   160|                  padding: EdgeInsets.only(bottom: e.key < _qa.answer.length - 1 ? 8 : 0),
   161|                  child: Row(
   162|                    crossAxisAlignment: CrossAxisAlignment.start,
   163|                    children: [
   164|                      Container(
   165|                        width: 24,
   166|                        height: 24,
   167|                        decoration: BoxDecoration(
   168|                          color: const Color(0xFF86EFAC),
   169|                          borderRadius: BorderRadius.circular(6),
   170|                        ),
   171|                        child: Center(
   172|                          child: Text('${e.key + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
   173|                        ),
   174|                      ),
   175|                      const SizedBox(width: 10),
   176|                      Expanded(child: Text(e.value, style: const TextStyle(fontSize: 14, color: DesktopTheme.textPrimary))),
   177|                    ],
   178|                  ),
   179|                )).toList(),
   180|              ),
   181|            ),
   182|            const SizedBox(height: 24),
   183|
   184|            // Image
   185|            if (_qa.imageUrl != null && _qa.imageUrl!.isNotEmpty) ...[
   186|              _SectionHeader(icon: Icons.image_outlined, label: '图片'),
   187|              const SizedBox(height: 10),
   188|              GestureDetector(
   189|                onTap: () => QuestionRichText.showFullScreenImage(context, _qa.imageUrl!),
   190|                child: ClipRRect(
   191|                  borderRadius: BorderRadius.circular(8),
   192|                  child: CachedNetworkImage(
   193|                    imageUrl: _qa.imageUrl!,
   194|                    fit: BoxFit.contain,
   195|                    width: double.infinity,
   196|                    placeholder: (_, __) => Container(
   197|                      height: 200,
   198|                      color: DesktopTheme.bgSection,
   199|                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
   200|                    ),
   201|                    errorWidget: (_, __, ___) => Container(
   202|                      height: 100,
   203|                      width: double.infinity,
   204|                      color: DesktopTheme.bgSection,
   205|                      child: const Center(child: Text('图片加载失败', style: TextStyle(color: DesktopTheme.textTertiary, fontSize: 13))),
   206|                    ),
   207|                  ),
   208|                ),
   209|              ),
   210|              const SizedBox(height: 24),
   211|            ],
   212|
   213|            // Stats
   214|            _SectionHeader(icon: Icons.bar_chart_outlined, label: '统计'),
   215|            const SizedBox(height: 10),
   216|            Row(
   217|              children: [
   218|                _statCard('总次数', _qa.total.toString(), DesktopTheme.primary),
   219|                const SizedBox(width: 12),
   220|                _statCard('正确', _qa.right.toString(), DesktopTheme.green),
   221|                const SizedBox(width: 12),
   222|                _statCard('错误', _qa.wrong.toString(), DesktopTheme.red),
   223|              ],
   224|            ),
   225|            const SizedBox(height: 12),
   226|            Container(
   227|              width: double.infinity,
   228|              padding: const EdgeInsets.symmetric(vertical: 16),
   229|              decoration: BoxDecoration(
   230|                color: DesktopTheme.bgSection,
   231|                borderRadius: BorderRadius.circular(8),
   232|              ),
   233|              child: Center(
   234|                child: Text(
   235|                  '正确率 ${(_qa.accuracy * 100).toStringAsFixed(1)}%',
   236|                  style: TextStyle(
   237|                    fontSize: 18,
   238|                    fontWeight: FontWeight.bold,
   239|                    color: _accuracyColor(_qa.accuracy),
   240|                  ),
   241|                ),
   242|              ),
   243|            ),
   244|            const SizedBox(height: 32),
   245|          ],
   246|        ),
   247|      ),
   248|    );
   249|  }
   250|
   251|  Widget _statCard(String label, String value, Color color) {
   252|    return Expanded(
   253|      child: Container(
   254|        padding: const EdgeInsets.symmetric(vertical: 16),
   255|        decoration: BoxDecoration(
   256|          color: color.withAlpha(26),
   257|          borderRadius: BorderRadius.circular(8),
   258|        ),
   259|        child: Column(
   260|          children: [
   261|            Text(label, style: const TextStyle(fontSize: 12, color: DesktopTheme.textSecondary)),
   262|            const SizedBox(height: 4),
   263|            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
   264|          ],
   265|        ),
   266|      ),
   267|    );
   268|  }
   269|}
   270|
   271|class _SectionHeader extends StatelessWidget {
   272|  final IconData icon;
   273|  final String label;
   274|
   275|  const _SectionHeader({required this.icon, required this.label});
   276|
   277|  @override
   278|  Widget build(BuildContext context) {
   279|    return Row(
   280|      children: [
   281|        Icon(icon, size: 18, color: DesktopTheme.primary),
   282|        const SizedBox(width: 6),
   283|        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
   284|      ],
   285|    );
   286|  }
   287|}
   288|
   289|class _TagChip extends StatelessWidget {
   290|  final String label;
   291|  final Color color;
   292|  final Color textColor;
   293|  final Color borderColor;
   294|
   295|  const _TagChip({required this.label, required this.color, required this.textColor, required this.borderColor});
   296|
   297|  @override
   298|  Widget build(BuildContext context) {
   299|    return Container(
   300|      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
   301|      decoration: BoxDecoration(
   302|        color: color,
   303|        borderRadius: BorderRadius.circular(16),
   304|        border: Border.all(color: borderColor),
   305|      ),
   306|      child: Text(label, style: TextStyle(fontSize: 12, color: textColor)),
   307|    );
   308|  }
   309|}
   310|