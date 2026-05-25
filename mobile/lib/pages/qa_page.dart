import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/data_cache.dart';
import 'single_qa_practice_page.dart';
import 'qa_form_page.dart';
import 'bank_page.dart';
import 'tag_page.dart';
import 'image_manage_page.dart';
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

  // 题库树（层级下钻）
  List<Map<String, dynamic>> _bankTree = [];
  Map<String, int> _descendantCounts = {};
  final Set<String> _expandedIds = {};
  String? _selectedBankName;

  @override
  void initState() {
    super.initState();
    _bid = widget.initialCategoryId;
    _tid = widget.initialTagId;
    _fetchMeta();
    _fetch();
    _loadBankTree();
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

  Future<void> _loadBankTree() async {
    try {
      final tree = await ApiService.getBankTree();
      final counts = await ApiService.getDescendantCounts();
      if (mounted) {
        setState(() {
          _bankTree = (tree as List<dynamic>).cast<Map<String, dynamic>>();
          _descendantCounts = counts;
        });
      }
    } catch (_) {}
  }

  void _toggleBank(String id, String name) {
    setState(() {
      if (id.isEmpty || _bid == id) {
        // 清空 → 取消筛选
        _bid = null;
        _selectedBankName = null;
      } else {
        _bid = id;
        _selectedBankName = name;
        _tid = null;
      }
      _currentPage = 1;
      _qas = [];
    });
    _fetch();
  }

  /// 展开/折叠树节点
  void _toggleExpand(String id) {
    setState(() {
      if (_expandedIds.contains(id)) {
        _expandedIds.remove(id);
      } else {
        _expandedIds.add(id);
      }
    });
  }

  /// 收集节点自身及所有后代ID
  List<String> _collectDescendantIds(Map<String, dynamic> node) {
    final ids = <String>[node['id'] as String];
    final children = node['children'] as List<dynamic>?;
    if (children != null) {
      for (final child in children) {
        ids.addAll(_collectDescendantIds(child as Map<String, dynamic>));
      }
    }
    return ids;
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('考试'),
        actions: [
          IconButton(
            icon: const Icon(Icons.image_outlined, size: 22),
            tooltip: '图片',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ImageManagePage()),
            ),
          ),
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

          // 题库树（缩进层级视图）
          if (_bankTree.isNotEmpty)
            Container(
              constraints: BoxConstraints(maxHeight: 260.h),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.border.withAlpha(80))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // "全部"清除筛选
                  Material(
                    color: _bid == null ? AppTheme.primary.withAlpha(15) : Colors.transparent,
                    child: InkWell(
                      onTap: () => _toggleBank('', ''),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                        child: Row(children: [
                          Icon(Icons.layers_rounded, size: 16.sp, color: _bid == null ? AppTheme.primary : AppTheme.textTertiary),
                          SizedBox(width: 8.w),
                          Text('全部题库',
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: _bid == null ? FontWeight.w600 : FontWeight.w500,
                              color: _bid == null ? AppTheme.primary : AppTheme.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          if (_bid == null)
                            Icon(Icons.check, size: 16.sp, color: AppTheme.primary),
                        ]),
                      ),
                    ),
                  ),
                  Divider(height: 1, color: AppTheme.border.withAlpha(60)),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: _buildTreeRows(_bankTree, 0),
                    ),
                  ),
                ],
              ),
            ),

          // 已选中题库标签
          if (_selectedBankName != null) ...[
            SizedBox(height: 8.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              child: Row(children: [
                Chip(
                  label: Text(_selectedBankName!, style: TextStyle(fontSize: 12.sp)),
                  backgroundColor: AppTheme.indigo50,
                  labelStyle: TextStyle(color: AppTheme.primary),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () => _toggleBank('', ''),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                if (_tags.isNotEmpty) ...[
                  SizedBox(width: 8.w),
                  Expanded(
                    child: SizedBox(
                      height: 36.h,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _tags
                            .map((t) => Padding(
                              padding: EdgeInsets.only(right: 6.w),
                              child: ChoiceChip(
                                label: Text(t.name, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w500,
                                    color: _tid == t.id ? Colors.white : AppTheme.textSoft)),
                                selected: _tid == t.id,
                                onSelected: (_) => _toggleTag(t.id),
                                selectedColor: AppTheme.primary,
                                backgroundColor: AppTheme.bg,
                                side: BorderSide.none,
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.r)),
                              ),
                            ))
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ]),
            ),
          ],

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

  // ── 树视图构建 ───────────────────────────────────

  List<Widget> _buildTreeRows(List<Map<String, dynamic>> nodes, int depth) {
    final rows = <Widget>[];
    for (final node in nodes) {
      final id = node['id'] as String;
      final name = node['name'] as String;
      final children = (node['children'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      final hasChildren = children.isNotEmpty;
      final count = _descendantCounts[id] ?? 0;
      final isSelected = _bid == id;
      final isExpanded = _expandedIds.contains(id);

      rows.add(
        Material(
          color: isSelected ? AppTheme.primary.withAlpha(12) : Colors.transparent,
          child: InkWell(
            onTap: () {
              if (hasChildren) {
                _toggleExpand(id);
              }
              _toggleBank(id, name);
            },
            child: Padding(
              padding: EdgeInsets.only(
                left: 16.w + depth * 22.w,
                right: 12.w,
                top: 9.h,
                bottom: 9.h,
              ),
              child: Row(children: [
                // 展开/折叠图标
                if (hasChildren)
                  Padding(
                    padding: EdgeInsets.only(right: 4.w),
                    child: Icon(
                      isExpanded ? Icons.expand_more : Icons.chevron_right,
                      size: 18.sp,
                      color: AppTheme.textTertiary,
                    ),
                  )
                else
                  SizedBox(width: 22.w),
                // 名称
                Expanded(
                  child: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                    ),
                  ),
                ),
                // 题目数
                if (count > 0)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Text('$count',
                      style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                  ),
                // 选中标记
                if (isSelected) ...[
                  SizedBox(width: 6.w),
                  Icon(Icons.check, size: 16.sp, color: AppTheme.primary),
                ],
              ]),
            ),
          ),
        ),
      );

      // 展开子节点
      if (hasChildren && isExpanded) {
        rows.addAll(_buildTreeRows(children, depth + 1));
      }
    }
    return rows;
  }

  // ── Question card ───────────────────────────────────
  Widget _card(KbQa qa) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SingleQaPracticePage(
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
