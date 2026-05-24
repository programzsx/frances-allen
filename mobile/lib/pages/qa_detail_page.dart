     1|import 'package:flutter/material.dart';
     2|import 'package:flutter_screenutil/flutter_screenutil.dart';
     3|import 'package:cached_network_image/cached_network_image.dart';
     4|import '../models/models.dart';
     5|import '../services/api_service.dart';
     6|import 'qa_form_page.dart';
     7|import 'question_rich_text.dart';
     8|import '../theme/app_theme.dart';
     9|
    10|class QaDetailPage extends StatefulWidget {
    11|  final KbQa qa;
    12|  final List<KbBank> banks;
    13|  final List<KbTag> tags;
    14|  final VoidCallback onRefresh;
    15|
    16|  const QaDetailPage({
    17|    super.key,
    18|    required this.qa,
    19|    required this.banks,
    20|    required this.tags,
    21|    required this.onRefresh,
    22|  });
    23|
    24|  @override
    25|  State<QaDetailPage> createState() => _QaDetailPageState();
    26|}
    27|
    28|class _QaDetailPageState extends State<QaDetailPage> {
    29|  late KbQa _qa;
    30|  bool _deleting = false;
    31|
    32|  @override
    33|  void initState() {
    34|    super.initState();
    35|    _qa = widget.qa;
    36|  }
    37|
    38|  String get _categoryName {
    39|    if (_qa.categoryId == null) return '未分类';
    40|    final bank = widget.banks.where((b) => b.id == _qa.categoryId).firstOrNull;
    41|    return bank?.name ?? '未知';
    42|  }
    43|
    44|  List<String> get _tagNames {
    45|    if (_qa.tagId == null || _qa.tagId!.isEmpty) return [];
    46|    return _qa.tagId!
    47|        .map((id) => widget.tags.where((t) => t.id == id).firstOrNull?.name)
    48|        .whereType<String>()
    49|        .toList();
    50|  }
    51|
    52|  Future<void> _delete() async {
    53|    final result = await showDialog<bool>(
    54|      context: context,
    55|      builder: (ctx) => AlertDialog(
    56|        title: const Text('确认删除'),
    57|        content: const Text('确定删除该题目吗？'),
    58|        actions: [
    59|          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
    60|          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除', style: TextStyle(color: AppTheme.red))),
    61|        ],
    62|      ),
    63|    );
    64|    if (result == true) {
    65|      setState(() => _deleting = true);
    66|      await ApiService.deleteQa(_qa.id);
    67|      if (mounted) {
    68|        Navigator.pop(context);
    69|        widget.onRefresh();
    70|      }
    71|    }
    72|  }
    73|
    74|  @override
    75|  Widget build(BuildContext context) {
    76|    return Scaffold(
    77|      body: CustomScrollView(
    78|        slivers: [
    79|          // Modern header
    80|          SliverAppBar(
    81|            expandedHeight: 0,
    82|            pinned: true,
    83|            backgroundColor: AppTheme.bgPrimary,
    84|            elevation: 0,
    85|            leading: IconButton(
    86|              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
    87|              onPressed: () => Navigator.pop(context),
    88|            ),
    89|            title: Text('题目详情', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17, fontFamily: 'Inter')),
    90|            centerTitle: true,
    91|            actions: [
    92|              IconButton(
    93|                icon: _deleting
    94|                    ? SizedBox(width: 20.w, height: 20.w, child: const CircularProgressIndicator(strokeWidth: 2))
    95|                    : const Icon(Icons.edit_outlined, size: 20),
    96|                onPressed: _deleting ? null : () async {
    97|                  await Navigator.push(context, MaterialPageRoute(builder: (_) => QaFormPage(qa: _qa)));
    98|                  _refreshData();
    99|                },
   100|                tooltip: '编辑',
   101|              ),
   102|              IconButton(
   103|                icon: _deleting ? const SizedBox.shrink() : const Icon(Icons.delete_outline, size: 20),
   104|                onPressed: _deleting ? null : _delete,
   105|                tooltip: '删除',
   106|              ),
   107|              SizedBox(width: 8.w),
   108|            ],
   109|          ),
   110|          SliverToBoxAdapter(
   111|            child: Padding(
   112|              padding: EdgeInsets.all(16.w),
   113|              child: Column(
   114|                crossAxisAlignment: CrossAxisAlignment.start,
   115|                children: [
   116|                  // Bank & Tags
   117|                  Wrap(
   118|                    spacing: 6.w,
   119|                    runSpacing: 6.h,
   120|                    children: [
   121|                      _TagChip(label: _categoryName, color: AppTheme.indigo50, textColor: AppTheme.primary, borderColor: AppTheme.indigo100),
   122|                      ..._tagNames.map((name) => _TagChip(label: name, color: AppTheme.bgSection, textColor: AppTheme.textSecondary, borderColor: AppTheme.border)),
   123|                    ],
   124|                  ),
   125|                  SizedBox(height: 24.h),
   126|
   127|                  // Question
   128|                  _SectionHeader(icon: Icons.edit_note_outlined, label: '题目'),
   129|                  SizedBox(height: 10.h),
   130|                  Container(
   131|                    width: double.infinity,
   132|                    padding: EdgeInsets.all(16.w),
   133|                    decoration: BoxDecoration(
   134|                      color: AppTheme.bgSection,
   135|                      borderRadius: BorderRadius.circular(14.r),
   136|                    ),
   137|                    child: QuestionRichText(text: _qa.question, fontSize: 16),
   138|                  ),
   139|                  SizedBox(height: 24.h),
   140|
   141|                  // Answers
   142|                  _SectionHeader(icon: Icons.check_circle_outline, label: '答案'),
   143|                  SizedBox(height: 10.h),
   144|                  Container(
   145|                    width: double.infinity,
   146|                    padding: EdgeInsets.all(16.w),
   147|                    decoration: BoxDecoration(
   148|                      color: const Color(0xFFF0FDF4), // green-50
   149|                      borderRadius: BorderRadius.circular(14.r),
   150|                      border: Border.all(color: const Color(0xFFBBF7D0)), // green-200
   151|                    ),
   152|                    child: Column(
   153|                      crossAxisAlignment: CrossAxisAlignment.start,
   154|                      children: _qa.answer.asMap().entries.map((e) => Padding(
   155|                        padding: EdgeInsets.only(bottom: 8.h),
   156|                        child: Row(
   157|                          crossAxisAlignment: CrossAxisAlignment.start,
   158|                          children: [
   159|                            Container(
   160|                              width: 24.w,
   161|                              height: 24.w,
   162|                              decoration: BoxDecoration(
   163|                                color: const Color(0xFF86EFAC), // green-300
   164|                                borderRadius: BorderRadius.circular(6.r),
   165|                              ),
   166|                              child: Center(
   167|                                child: Text('${e.key + 1}', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: const Color(0xFF166534))),
   168|                              ),
   169|                            ),
   170|                            SizedBox(width: 10.w),
   171|                            Expanded(child: Text(e.value, style: TextStyle(fontSize: 15.sp, fontFamily: 'Inter', color: AppTheme.textPrimary))),
   172|                          ],
   173|                        ),
   174|                      )).toList(),
   175|                    ),
   176|                  ),
   177|                  SizedBox(height: 24.h),
   178|
   179|                  // Image
   180|                  if (_qa.imageUrl != null && _qa.imageUrl!.isNotEmpty) ...[
   181|                    _SectionHeader(icon: Icons.image_outlined, label: '图片'),
   182|                    SizedBox(height: 10.h),
   183|                    GestureDetector(
   184|                      onTap: () => QuestionRichText.showFullScreenImage(context, _qa.imageUrl!),
   185|                      child: ClipRRect(
   186|                        borderRadius: BorderRadius.circular(14.r),
   187|                        child: CachedNetworkImage(
   188|                          imageUrl: _qa.imageUrl!,
   189|                          fit: BoxFit.contain,
   190|                          width: double.infinity,
   191|                          placeholder: (_, __) => Container(
   192|                            height: 200.h,
   193|                            color: AppTheme.bgSection,
   194|                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
   195|                          ),
   196|                          errorWidget: (_, __, ___) => Container(
   197|                            height: 100.h,
   198|                            width: double.infinity,
   199|                            color: AppTheme.bgSection,
   200|                            child: Center(
   201|                              child: Text('图片加载失败', style: TextStyle(color: AppTheme.textTertiary, fontSize: 13.sp)),
   202|                            ),
   203|                          ),
   204|                        ),
   205|                      ),
   206|                    ),
   207|                    SizedBox(height: 24.h),
   208|                  ],
   209|
   210|                  // Stats
   211|                  _SectionHeader(icon: Icons.bar_chart_outlined, label: '统计'),
   212|                  SizedBox(height: 10.h),
   213|                  Row(
   214|                    children: [
   215|                      _statCard('总次数', _qa.total.toString(), AppTheme.primary),
   216|                      SizedBox(width: 12.w),
   217|                      _statCard('正确', _qa.right.toString(), AppTheme.green),
   218|                      SizedBox(width: 12.w),
   219|                      _statCard('错误', _qa.wrong.toString(), AppTheme.red),
   220|                    ],
   221|                  ),
   222|                  SizedBox(height: 12.h),
   223|                  Container(
   224|                    width: double.infinity,
   225|                    padding: EdgeInsets.symmetric(vertical: 14.h),
   226|                    decoration: BoxDecoration(
   227|                      color: AppTheme.bgSection,
   228|                      borderRadius: BorderRadius.circular(14.r),
   229|                    ),
   230|                    child: Center(
   231|                      child: Text(
   232|                        '正确率 ${(_qa.accuracy * 100).toStringAsFixed(1)}%',
   233|                        style: TextStyle(
   234|                          fontSize: 20.sp,
   235|                          fontWeight: FontWeight.bold,
   236|                          fontFamily: 'Inter',
   237|                          color: _accuracyColor(_qa.accuracy),
   238|                        ),
   239|                      ),
   240|                    ),
   241|                  ),
   242|                  SizedBox(height: 32.h),
   243|                ],
   244|              ),
   245|            ),
   246|          ),
   247|        ],
   248|      ),
   249|    );
   250|  }
   251|
   252|  Widget _statCard(String label, String value, Color color) {
   253|    return Expanded(
   254|      child: Container(
   255|        padding: EdgeInsets.symmetric(vertical: 16.h),
   256|        decoration: BoxDecoration(
   257|          color: color.withAlpha(26),
   258|          borderRadius: BorderRadius.circular(14.r),
   259|        ),
   260|        child: Column(
   261|          children: [
   262|            Text(label, style: TextStyle(fontSize: 12.sp, color: AppTheme.textSecondary)),
   263|            SizedBox(height: 4.h),
   264|            Text(value, style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold, color: color, fontFamily: 'Inter')),
   265|          ],
   266|        ),
   267|      ),
   268|    );
   269|  }
   270|
   271|  Color _accuracyColor(double accuracy) {
   272|    if (accuracy >= 0.8) return AppTheme.green;
   273|    if (accuracy >= 0.5) return AppTheme.orange;
   274|    return AppTheme.red;
   275|  }
   276|
   277|  Future<void> _refreshData() async {
   278|    try {
   279|      final data = await ApiService.getQa(_qa.id);
   280|      if (data != null && mounted) {
   281|        setState(() => _qa = KbQa.fromJson(data));
   282|      }
   283|    } catch (_) {}
   284|  }
   285|}
   286|
   287|class _SectionHeader extends StatelessWidget {
   288|  final IconData icon;
   289|  final String label;
   290|
   291|  const _SectionHeader({required this.icon, required this.label});
   292|
   293|  @override
   294|  Widget build(BuildContext context) {
   295|    return Row(
   296|      children: [
   297|        Icon(icon, size: 18.sp, color: AppTheme.primary),
   298|        SizedBox(width: 6.w),
   299|        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, fontFamily: 'Inter')),
   300|      ],
   301|    );
   302|  }
   303|}
   304|
   305|class _TagChip extends StatelessWidget {
   306|  final String label;
   307|  final Color color;
   308|  final Color textColor;
   309|  final Color borderColor;
   310|
   311|  const _TagChip({required this.label, required this.color, required this.textColor, required this.borderColor});
   312|
   313|  @override
   314|  Widget build(BuildContext context) {
   315|    return Container(
   316|      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
   317|      decoration: BoxDecoration(
   318|        color: color,
   319|        borderRadius: BorderRadius.circular(20.r),
   320|        border: Border.all(color: borderColor),
   321|      ),
   322|      child: Text(label, style: TextStyle(fontSize: 12.sp, color: textColor, fontFamily: 'Inter')),
   323|    );
   324|  }
   325|}
   326|