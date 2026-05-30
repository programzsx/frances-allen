import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/data_cache.dart';
import 'bank_detail_page.dart';
import '../theme/app_theme.dart';

class BankPage extends StatefulWidget {
  const BankPage({super.key});

  @override
  State<BankPage> createState() => _BankPageState();
}

class _BankPageState extends State<BankPage> {
  late DataCache _cache;
  List<_FlatBank> _flatBanks = [];
  bool _loading = true;
  String? _keyword;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cache = DataCache();
    _cache.addListener(_onCacheUpdate);
    _loadBanks();
  }

  @override
  void dispose() {
    _cache.removeListener(_onCacheUpdate);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onCacheUpdate() {
    if (_cache.hasBanks && !_cache.banksLoading) {
      _buildFlatList();
    }
  }

  Future<void> _loadBanks({bool force = false}) async {
    if (!force && _cache.hasBanks) {
      _buildFlatList();
      return;
    }
    setState(() => _loading = true);
    await _cache.ensureBanks();
    if (mounted) _buildFlatList();
  }

  void _buildFlatList() {
    final tree = _cache.bankTree;
    final counts = _cache.bankCounts;
    _sortTree(tree);
    final bankMap = {for (final b in _cache.allBanks) b.id: b};
    setState(() {
      _flatBanks = _flattenTree(tree, bankMap, counts);
      _loading = false;
    });
  }

  void _sortTree(List<dynamic> tree) {
    tree.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    for (final node in tree) {
      final children = node['children'] as List?;
      if (children != null && children.isNotEmpty) _sortTree(children);
    }
  }

  List<_FlatBank> _flattenTree(
    List<dynamic> tree,
    Map<String, KbBank> bankMap,
    Map<String, int> counts,
  ) {
    final result = <_FlatBank>[];
    _traverse(tree, 0, result, bankMap, counts);
    return result;
  }

  void _traverse(
    List<dynamic> nodes,
    int depth,
    List<_FlatBank> result,
    Map<String, KbBank> bankMap,
    Map<String, int> counts,
  ) {
    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i] as Map<String, dynamic>;
      final id = node['id'] as String;
      final isLast = (i == nodes.length - 1);
      final hasChildren = (node['children'] as List?)?.isNotEmpty ?? false;
      final bank = bankMap[id];
      result.add(_FlatBank(
        bank: bank,
        depth: depth,
        isLast: isLast,
        hasChildren: hasChildren,
        questionCount: counts[id] ?? 0,
      ));
      final children = node['children'] as List<dynamic>?;
      if (children != null && children.isNotEmpty) {
        _traverse(children, depth + 1, result, bankMap, counts);
      }
    }
  }

  void _doSearch(String v) {
    setState(() {
      _keyword = v.isEmpty ? null : v;
    });
  }

  Set<String> _getDescendantIds(dynamic node) {
    final ids = <String>{};
    if (node is List) {
      for (final child in node) ids.addAll(_getDescendantIds(child));
    } else if (node is Map) {
      ids.add(node['id'] as String);
      final children = node['children'] as List?;
      if (children != null) {
        for (final child in children) ids.addAll(_getDescendantIds(child));
      }
    }
    return ids;
  }

  dynamic _findNode(List<dynamic> nodes, String id) {
    for (final node in nodes) {
      if (node is Map && node['id'] == id) return node;
      if (node is Map && node['children'] != null) {
        final found = _findNode(node['children'], id);
        if (found != null) return found;
      }
    }
    return null;
  }

  List<_BankOption> _flattenForDropdown(List<dynamic> nodes, int depth, Set<String>? excludeIds) {
    final result = <_BankOption>[];
    for (final node in nodes) {
      final id = node['id'] as String;
      final name = node['name'] as String;
      final prefix = '  ' * depth;
      final isExcluded = excludeIds != null && excludeIds.contains(id);
      if (!isExcluded) {
        result.add(_BankOption(id: id, label: '$prefix $name', depth: depth));
      }
      final children = node['children'] as List?;
      if (children != null) {
        result.addAll(_flattenForDropdown(children, depth + 1, excludeIds));
      }
    }
    return result;
  }

  Future<void> _showBankDialog({KbBank? bank}) async {
    Set<String>? excludeIds;
    if (bank != null) {
      final tree = _cache.bankTree;
      final node = _findNode(tree, bank.id);
      if (node != null) excludeIds = _getDescendantIds(node);
    }
    final tree = _cache.bankTree;
    final dropdownItems = _flattenForDropdown(tree, 0, excludeIds);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _BankDialog(
        title: bank == null ? '新增题库' : '编辑题库',
        initialName: bank?.name ?? '',
        initialParentId: bank?.parentId,
        initialSortOrder: bank?.sortOrder ?? 0,
        options: dropdownItems,
      ),
    );

    if (result != null && result['name'] != null && result['name'].isNotEmpty) {
      final data = {
        'name': result['name'],
        'parent_id': result['parent_id'],
        'sort_order': result['sort_order'],
      };
      if (bank == null) {
        await ApiService.createBank(data);
      } else {
        await ApiService.updateBank(bank.id, data);
      }
      _cache.invalidate();
      _loadBanks(force: true);
    }
  }

  Future<void> _deleteBank(KbBank bank) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定删除题库「${bank.name}」吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除', style: TextStyle(color: AppTheme.red))),
        ],
      ),
    );
    if (result == true) {
      try {
        await ApiService.deleteBank(bank.id);
        _cache.invalidate();
        _loadBanks(force: true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    List<_FlatBank> displayedBanks = _flatBanks;
    if (_keyword != null && _keyword!.isNotEmpty) {
      displayedBanks = _flatBanks.where((fb) {
        return fb.bank != null && fb.bank!.name.toLowerCase().contains(_keyword!.toLowerCase());
      }).toList();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('题库管理')),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: '搜索题库',
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
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : displayedBanks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.folder_outlined, size: 64.sp, color: AppTheme.textTertiary),
                            SizedBox(height: 16.h),
                            Text('暂无题库', style: TextStyle(color: AppTheme.textTertiary, fontSize: 16.sp, fontFamily: 'Inter')),
                            SizedBox(height: 8.h),
                            Text('点击右下角按钮创建', style: TextStyle(color: AppTheme.textTertiary, fontSize: 13.sp)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.only(top: 4.h, bottom: 80.h),
                        itemCount: displayedBanks.length,
                        itemBuilder: (ctx, i) {
                          final fb = displayedBanks[i];
                          final bank = fb.bank;
                          if (bank == null) return const SizedBox.shrink();
                          return _BankTreeItem(
                            bank: bank,
                            depth: fb.depth,
                            isLast: fb.isLast,
                            hasChildren: fb.hasChildren,
                            questionCount: fb.questionCount,
                            onEdit: () => _showBankDialog(bank: bank),
                            onTap: () => Navigator.push(context, MaterialPageRoute(
                              builder: (_) => BankDetailPage(bank: bank),
                            )),
                            onDelete: () => _deleteBank(bank),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showBankDialog(),
        child: const Icon(Icons.add_circle_outlined, color: Colors.white),
      ),
    );
  }
}

/// Bank tree item with visual guide lines
class _BankTreeItem extends StatelessWidget {
  final KbBank bank;
  final int depth;
  final bool isLast;
  final bool hasChildren;
  final int questionCount;
  final VoidCallback onEdit;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _BankTreeItem({
    required this.bank,
    required this.depth,
    required this.isLast,
    required this.hasChildren,
    required this.questionCount,
    required this.onEdit,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(left: 16.w, right: 16.w, top: 4.h, bottom: 4.h),
      padding: EdgeInsets.only(left: depth * 28.w),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (depth > 0) ...[
            SizedBox(width: 16.w),
            CustomPaint(
              size: Size(12.w, 32.h),
              painter: _TreeLinePainter(
                hasVerticalAbove: !isLast,
                hasHorizontal: true,
                isLast: isLast,
              ),
            ),
            SizedBox(width: 4.w),
          ],
          GestureDetector(
            onTap: onEdit,
            child: Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: AppTheme.indigo50,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(Icons.edit_note, color: AppTheme.primary, size: 20.sp),
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bank.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15.sp,
                      fontFamily: 'Inter',
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    questionCount > 0 ? '$questionCount 题' : '暂无题目',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: questionCount > 0 ? AppTheme.primary : AppTheme.textTertiary,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 36.w,
            height: 36.w,
            child: IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.red),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }
}

class _TreeLinePainter extends CustomPainter {
  final bool hasVerticalAbove;
  final bool hasHorizontal;
  final bool isLast;

  _TreeLinePainter({
    required this.hasVerticalAbove,
    required this.hasHorizontal,
    required this.isLast,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.textTertiary
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;

    if (hasVerticalAbove) {
      canvas.drawLine(Offset(cx, 0), Offset(cx, cy), paint);
      canvas.drawLine(Offset(cx, cy), Offset(cx, size.height), paint);
    } else if (!isLast) {
      canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), paint);
    } else {
      canvas.drawLine(Offset(cx, 0), Offset(cx, cy), paint);
    }

    if (hasHorizontal) {
      canvas.drawLine(Offset(cx, cy), Offset(size.width, cy), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BankDialog extends StatefulWidget {
  final String title;
  final String initialName;
  final String? initialParentId;
  final int initialSortOrder;
  final List<_BankOption> options;

  const _BankDialog({
    required this.title,
    required this.initialName,
    required this.initialParentId,
    required this.initialSortOrder,
    required this.options,
  });

  @override
  State<_BankDialog> createState() => _BankDialogState();
}

class _BankDialogState extends State<_BankDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _sortCtrl;
  String? _parentId;
  bool _nameEmpty = true;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _sortCtrl = TextEditingController(text: widget.initialSortOrder.toString());
    _parentId = widget.initialParentId;
    _nameCtrl.addListener(() {
      setState(() => _nameEmpty = _nameCtrl.text.isEmpty);
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sortCtrl.dispose();
    super.dispose();
  }

  int get _sortOrder => int.tryParse(_sortCtrl.text) ?? 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.title,
        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, fontFamily: 'Inter', color: AppTheme.textPrimary),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '题库名称',
                prefixIcon: Icon(Icons.folder_outlined),
              ),
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: _sortCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '排序值',
                prefixIcon: Icon(Icons.sort_outlined),
                hintText: '0',
              ),
            ),
            SizedBox(height: 16.h),
            DropdownButtonFormField<String>(
              value: _parentId,
              decoration: const InputDecoration(
                labelText: '父题库（可选）',
                prefixIcon: Icon(Icons.account_tree_outlined),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('无（根题库）')),
                ...widget.options.map((o) => DropdownMenuItem(
                      value: o.id,
                      child: Text(o.label),
                    )),
              ],
              onChanged: (v) => setState(() => _parentId = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        TextButton(
          onPressed: _nameEmpty
              ? null
              : () => Navigator.pop(context, {
                    'name': _nameCtrl.text,
                    'parent_id': _parentId,
                    'sort_order': _sortOrder,
                  }),
          child: const Text('确定', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _FlatBank {
  final KbBank? bank;
  final int depth;
  final bool isLast;
  final bool hasChildren;
  final int questionCount;

  _FlatBank({
    this.bank,
    required this.depth,
    required this.isLast,
    required this.hasChildren,
    required this.questionCount,
  });
}

class _BankOption {
  final String id;
  final String label;
  final int depth;

  _BankOption({required this.id, required this.label, required this.depth});
}
