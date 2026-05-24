import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/data_cache.dart';
import 'qa_detail_page.dart';
import 'qa_form_page.dart';
import 'bank_page.dart';
import 'tag_page.dart';
import 'practice_page.dart';
import 'question_rich_text.dart';
import '../theme/app_theme.dart';

class QaPage extends StatefulWidget {
  final String? initialCategoryId;
  final String? initialTagId;

  const QaPage({super.key, this.initialCategoryId, this.initialTagId});

  @override
  State<QaPage> createState() => _QaPageState();
}

class _QaPageState extends State<QaPage> {
  List<KbQa> _qas = [];
  int _total = 0;
  int _currentPage = 1;
  bool _busy = true;
  bool _loadingMore = false;

  String? _bid; // selected bank id
  String? _tid; // selected tag id
  final _q = TextEditingController();
  final _sc = ScrollController();

  List<KbBank> _banks = [];
  List<KbTag> _tags = [];

  @override
  void initState() {
    super.initState();
    _bid = widget.initialCategoryId;
    _tid = widget.initialTagId;
    _fetchMeta();
    _fetch();
    _sc.addListener(_more);
  }

  void _more() {
    if (_sc.position.pixels > _sc.position.maxScrollExtent - 150 &&
        !_busy &&
        !_loadingMore &&
        _qas.length < _total) {
      _currentPage++;
      _fetch();
    }
  }

  Future<void> _fetchMeta() async {
    final cache = DataCache();
    await cache.ensureBanks();
    await cache.ensureTags();
    if (mounted) {
      setState(() {
        _banks = cache.allBanks;
        _tags = cache.allTags;
      });
    }
  }

  Future<void> _fetch() async {
    setState(() => _busy = true);
    try {
      final data = await ApiService.pageQas(
        currentPage: _currentPage,
        categoryId: _bid,
        keyword: _q.text.isNotEmpty ? _q.text : null,
        tagId: _tid,
      );
      if (mounted) {
        setState(() {
          _total = data['total'] as int;
          if (_currentPage == 1) {
            _qas = (data['items'] as List)
                .map((e) => KbQa.fromJson(e))
                .toList();
          } else {
            _qas.addAll((data['items'] as List)
                .map((e) => KbQa.fromJson(e)));
          }
          _busy = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggleBank(String? id) {
    setState(() {
      _bid = _bid == id ? null : id;
      _tid = null;
      _currentPage = 1;
      _qas = [];
    });
    _fetch();
  }

  void _toggleTag(String? id) {
    setState(() {
      _tid = _tid == id ? null : id;
      _currentPage = 1;
      _qas = [];
    });
    _fetch();
  }

  String _categoryName(String? id) {
    if (id == null) return '未分类';
    return _banks.where((b) => b.id == id).firstOrNull?.name ?? '未知';
  }

  Color _accColor(double a) {
    if (a >= 0.8) return AppTheme.success;
    if (a >= 0.5) return AppTheme.accent;
    return AppTheme.danger;
  }

  Future<void> _deleteQa(KbQa qa) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定删除该题目吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除',
                style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ApiService.deleteQa(qa.id);
      _currentPage = 1;
      _fetch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final selBank = _banks.where((b) => b.id == _bid).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('题目'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sell_outlined, size: 22),
            tooltip: '标签',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TagPage()),
            ).then((_) {
              DataCache().invalidate();
              _fetchMeta();
              _currentPage = 1;
              _fetch();
            }),
          ),
          IconButton(
            icon: const Icon(Icons.folder_outlined, size: 22),
            tooltip: '题库',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BankPage()),
            ).then((_) {
              DataCache().invalidate();
              _fetchMeta();
              _currentPage = 1;
              _fetch();
            }),
          ),
          IconButton(
            icon: const Icon(Icons.school_outlined, size: 22),
            tooltip: '练习',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PracticePage()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: TextField(
              controller: _q,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: '搜索题目…',
                prefixIcon: const Icon(Icons.search,
                    color: AppTheme.textHint, size: 20),
                suffixIcon: _q.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _q.clear();
                          _currentPage = 1;
                          _fetch();
                        },
                      )
                    : null,
              ),
              onSubmitted: (_) {
                _currentPage = 1;
                _fetch();
              },
            ),
          ),

          // Bank chip row (always visible)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: _banks
                  .map((b) =>
                      _chip(b.name, _bid == b.id, () => _toggleBank(b.id)))
                  .toList(),
            ),
          ),

          // Tag chip row (only when bank selected)
          if (selBank != null && _tags.isNotEmpty)
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: _tags
                    .map((t) => _chip(t.name, _tid == t.id,
                        () => _toggleTag(t.id),
                        small: true))
                    .toList(),
              ),
            ),

          const Divider(height: 1),

          // Question list
          Expanded(
            child: _busy && _qas.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _qas.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.quiz_outlined,
                                size: 56,
                                color: AppTheme.textHint
                                    .withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            const Text('暂无题目',
                                style: TextStyle(
                                    color: AppTheme.textSoft,
                                    fontSize: 15)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _sc,
                        padding:
                            const EdgeInsets.only(top: 2, bottom: 80),
                        itemCount:
                            _qas.length + (_loadingMore ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i >= _qas.length) {
                            return const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                              ),
                            );
                          }
                          return _card(_qas[i]);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const QaFormPage()),
          );
          _currentPage = 1;
          _fetch();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  // ── Alan Perlis style chip ──────────────────────────
  Widget _chip(String label, bool sel, VoidCallback fn,
          {bool small = false}) =>
      Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(label,
              style: TextStyle(
                  fontSize: small ? 11 : 12,
                  fontWeight: FontWeight.w500,
                  color: sel ? Colors.white : AppTheme.textSoft)),
          selected: sel,
          onSelected: (_) => fn(),
          selectedColor: AppTheme.primary,
          backgroundColor: AppTheme.bg,
          side: BorderSide.none,
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(sel ? 8 : 6)),
        ),
      );

  // ── Question card ───────────────────────────────────
  Widget _card(KbQa qa) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => QaDetailPage(
                qa: qa,
                banks: _banks,
                tags: _tags,
                onRefresh: () {
                  _currentPage = 1;
                  _fetch();
                },
              ),
            ),
          );
          _currentPage = 1;
          _fetch();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    QuestionRichText(
                        text: qa.question, fontSize: 14),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(_categoryName(qa.categoryId),
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSoft)),
                        const Spacer(),
                        Text(
                          '${(qa.accuracy * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: _accColor(qa.accuracy),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: AppTheme.danger, size: 18),
                onPressed: () => _deleteQa(qa),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _q.dispose();
    _sc.dispose();
    super.dispose();
  }
}
