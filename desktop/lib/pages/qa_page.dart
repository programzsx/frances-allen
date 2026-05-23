import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'qa_detail_page.dart';
import 'qa_form_page.dart';
import 'question_rich_text.dart';
import '../theme/desktop_theme.dart';

class QaPage extends StatefulWidget {
  final String? initialBankId;
  final String? initialBankName;
  final String? initialTagId;
  final String? initialTagName;

  const QaPage({
    super.key,
    this.initialBankId,
    this.initialBankName,
    this.initialTagId,
    this.initialTagName,
  });

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
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除', style: TextStyle(color: DesktopTheme.red))),
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
    if (accuracy >= 0.8) return DesktopTheme.green;
    if (accuracy >= 0.5) return DesktopTheme.orange;
    return DesktopTheme.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
            decoration: BoxDecoration(
              color: DesktopTheme.bgCard,
              border: Border(bottom: BorderSide(color: DesktopTheme.border, width: 0.5)),
            ),
            child: Row(
              children: [
                if (widget.initialBankName != null || widget.initialTagName != null) ...[
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back_ios, size: 16, color: DesktopTheme.textSecondary),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    widget.initialTagName ?? widget.initialBankName ?? '全部题目',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: DesktopTheme.textPrimary,
                    ),
                  ),
                ),
                if (_total > 0)
                  Text(
                    '$_total 题',
                    style: const TextStyle(
                      fontSize: 13,
                      color: DesktopTheme.textTertiary,
                    ),
                  ),
              ],
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 6),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: '搜索题目',
                hintStyle: const TextStyle(fontSize: 13, color: DesktopTheme.textTertiary),
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              style: const TextStyle(fontSize: 14),
              onSubmitted: _doSearch,
            ),
          ),

          // Bank filter chips
          if (_banks.isNotEmpty && widget.initialBankId == null)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _FilterChip(label: '全部', selected: _bankId == null, onTap: () {
                      setState(() { _bankId = null; _currentPage = 1; });
                      _loadQas();
                    }),
                  ),
                  ..._banks.map((b) => Padding(
                    padding: const EdgeInsets.only(right: 6),
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
                            Icon(Icons.quiz_outlined, size: 56, color: DesktopTheme.textTertiary),
                            const SizedBox(height: 16),
                            Text('暂无题目', style: TextStyle(color: DesktopTheme.textTertiary, fontSize: 15)),
                            const SizedBox(height: 8),
                            Text('点击右下角按钮创建', style: TextStyle(color: DesktopTheme.textTertiary, fontSize: 13)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.only(top: 4, bottom: 72),
                        itemCount: _qas.length + (_loadingMore ? 1 : 0),
                        itemBuilder: (ctx, i) {
                          if (i >= _qas.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
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
        heroTag: 'qa_fab',
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const QaFormPage()));
          _loadQas();
        },
        child: const Icon(Icons.add_circle_outlined, color: Colors.white),
      ),
    );
  }
}

/// QA card
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
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 5),
      decoration: BoxDecoration(
        color: DesktopTheme.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DesktopTheme.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        QuestionRichText(text: qa.question, fontSize: 14),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(bankName, style: const TextStyle(fontSize: 11, color: DesktopTheme.textTertiary)),
                            const Spacer(),
                            Text(
                              '${(qa.accuracy * 100).toStringAsFixed(0)}%',
                              style: TextStyle(color: accColor, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline, color: DesktopTheme.red, size: 18),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
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
