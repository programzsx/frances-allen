import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'qa_detail_page.dart';
import 'qa_form_page.dart';
import 'question_rich_text.dart';
import '../theme/app_theme.dart';

class QaPage extends StatefulWidget {
  final String? initialBankId;
  final String? initialTagId;

  const QaPage({super.key, this.initialBankId, this.initialTagId});

  @override
  State<QaPage> createState() => _QaPageState();
}

class _QaPageState extends State<QaPage> {
  List<KbQa> _qas = [];
  int _total = 0;
  int _currentPage = 1;
  bool _loading = true;
  bool _loadingMore = false;
  String? _keyword;
  String? _bankId;
  String? _tagId;
  List<KbBank> _banks = [];
  List<KbTag> _tags = [];
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _bankId = widget.initialBankId;
    _tagId = widget.initialTagId;
    _loadBanks();
    _loadTags();
    _loadQas();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      if (!_loadingMore && _qas.length < _total) {
        _loadMore();
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _qas.length >= _total) return;
    setState(() => _loadingMore = true);
    try {
      final data = await ApiService.pageQas(
        currentPage: _currentPage + 1,
        bankId: _bankId,
        keyword: _keyword,
        tagId: _tagId,
      );
      final newQas = (data['items'] as List).map((e) => KbQa.fromJson(e)).toList();
      setState(() {
        _qas.addAll(newQas);
        _currentPage++;
        _loadingMore = false;
      });
    } catch (e) {
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _loadBanks() async {
    try {
      final data = await ApiService.pageBanks(pageSize: 100);
      setState(() {
        _banks = (data['items'] as List).map((e) => KbBank.fromJson(e)).toList();
      });
    } catch (_) {}
  }

  Future<void> _loadTags() async {
    try {
      final data = await ApiService.pageTags(pageSize: 100);
      setState(() {
        _tags = (data['items'] as List).map((e) => KbTag.fromJson(e)).toList();
      });
    } catch (_) {}
  }

  Future<void> _loadQas() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.pageQas(
        currentPage: _currentPage,
        bankId: _bankId,
        keyword: _keyword,
        tagId: _tagId,
      );
      setState(() {
        _qas = (data['items'] as List).map((e) => KbQa.fromJson(e)).toList();
        _total = data['total'];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  void _doSearch(String v) {
    setState(() {
      _keyword = v.isEmpty ? null : v;
      _currentPage = 1;
    });
    _loadQas();
  }

  Future<void> _deleteQa(KbQa qa) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定删除该题目吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除', style: TextStyle(color: AppTheme.red))),
        ],
      ),
    );
    if (result == true) {
      await ApiService.deleteQa(qa.id);
      _loadQas();
    }
  }

  String _getBankName(String? bankId) {
    if (bankId == null) return '未分类';
    final bank = _banks.where((b) => b.id == bankId).firstOrNull;
    return bank?.name ?? '未知';
  }

  Color _accuracyColor(double accuracy) {
    if (accuracy >= 0.8) return AppTheme.green;
    if (accuracy >= 0.5) return AppTheme.orange;
    return AppTheme.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
          children: [
            // Search
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 4.h),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: '搜索题目',
                  hintStyle: TextStyle(fontSize: 13, color: AppTheme.textTertiary, fontFamily: 'Inter'),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
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
                style: TextStyle(fontSize: 14, fontFamily: 'Inter'),
                onSubmitted: _doSearch,
              ),
            ),

            // Bank filter chips
            if (_banks.isNotEmpty && widget.initialBankId == null)
              SizedBox(
                height: 40.h,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                  children: [
                    Padding(
                      padding: EdgeInsets.only(right: 6.w),
                      child: _FilterChip(label: '全部', selected: _bankId == null, onTap: () {
                        setState(() { _bankId = null; _currentPage = 1; });
                        _loadQas();
                      }),
                    ),
                    ..._banks.map((b) => Padding(
                      padding: EdgeInsets.only(right: 6.w),
                      child: _FilterChip(label: b.name, selected: _bankId == b.id, onTap: () {
                        setState(() { _bankId = b.id; _currentPage = 1; });
                        _loadQas();
                      }),
                    )),
                  ],
                ),
              ),

            // List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _qas.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.quiz_outlined, size: 64.sp, color: AppTheme.textTertiary),
                              SizedBox(height: 16.h),
                              Text('暂无题目', style: TextStyle(color: AppTheme.textTertiary, fontSize: 16.sp, fontFamily: 'Inter')),
                              SizedBox(height: 8.h),
                              Text('点击右下角按钮创建', style: TextStyle(color: AppTheme.textTertiary, fontSize: 13.sp)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollCtrl,
                          padding: EdgeInsets.only(top: 4.h, bottom: 80.h),
                          itemCount: _qas.length + (_loadingMore ? 1 : 0),
                          itemBuilder: (ctx, i) {
                            if (i >= _qas.length) {
                              return Padding(
                                padding: EdgeInsets.all(16.w),
                                child: const Center(child: CircularProgressIndicator()),
                              );
                            }
                            final qa = _qas[i];
                            final accColor = _accuracyColor(qa.accuracy);
                            return _QaCard(
                              qa: qa,
                              bankName: _getBankName(qa.bankId),
                              accColor: accColor,
                              onTap: () async {
                                await Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => QaDetailPage(
                                    qa: qa,
                                    banks: _banks,
                                    tags: _tags,
                                    onRefresh: _loadQas,
                                  ),
                                ));
                                _loadQas();
                              },
                              onDelete: () => _deleteQa(qa),
                            );
                          },
                        ),
            ),

            ],
        ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const QaFormPage()));
          _loadQas();
        },
        child: const Icon(Icons.add_circle_outlined, color: Colors.white),
      ),
    );
  }
}

/// QA card with subtle border and left accent
class _QaCard extends StatelessWidget {
  final KbQa qa;
  final String bankName;
  final Color accColor;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _QaCard({
    required this.qa,
    required this.bankName,
    required this.accColor,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.all(14.w),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        QuestionRichText(text: qa.question, fontSize: 14),
                        SizedBox(height: 8.h),
                        Row(
                          children: [
                            Text(bankName, style: TextStyle(fontSize: 11.sp, color: AppTheme.textTertiary)),
                            const Spacer(),
                            Text(
                              '${(qa.accuracy * 100).toStringAsFixed(0)}%',
                              style: TextStyle(color: accColor, fontWeight: FontWeight.bold, fontSize: 13.sp, fontFamily: 'Inter'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 32.w,
                    height: 32.w,
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppTheme.red, size: 18),
                      onPressed: onDelete,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

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
