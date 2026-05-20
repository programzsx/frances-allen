import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/global_filter.dart';
import '../theme/app_theme.dart';

class BankPage extends StatefulWidget {
  const BankPage({super.key});

  @override
  State<BankPage> createState() => _BankPageState();
}

class _BankPageState extends State<BankPage> {
  List<_FlatBank> _flatBanks = [];
  bool _loading = true;
  String? _keyword;
  final _searchCtrl = TextEditingController();
  Map<String, int> _bankCounts = {};

  @override
  void initState() {
    super.initState();
    _loadBanks();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBanks() async {
    setState(() => _loading = true);
    try {
      final allBanks = await ApiService.getBanks();
      final tree = await ApiService.getBankTree();
      _sortTree(tree);
      final bankMap = {for (final b in allBanks) b.id: b};

      // Fetch question counts for all banks
      final counts = <String, int>{};
      for (final bank in allBanks) {
        try {
          final data = await ApiService.pageQas(bankId: bank.id, pageSize: 1);
          counts[bank.id] = data['total'] as int? ?? 0;
        } catch (_) {
          counts[bank.id] = 0;
        }
      }

      _bankCounts = counts;
      setState(() {
        _flatBanks = _flattenTree(tree, allBanks, bankMap, counts);
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

  void _sortTree(List<dynamic> tree) {
    tree.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    for (final node in tree) {
      final children = node['children'] as List?;
      if (children != null && children.isNotEmpty) {
        _sortTree(children);
      }
    }
  }

  List<_FlatBank> _flattenTree(
    List<dynamic> tree,
    List<KbBank> allBanks,
    Map<String, KbBank> bankMap,
    Map<String, int> counts,
  ) {
    final result = <_FlatBank>[];
    final childIds = <String>{};
    for (final node in tree) _collectChildIds(node, childIds);
    _traverse(tree, 0, result, childIds, bankMap, counts);
    return result;
  }

  void _collectChildIds(dynamic node, Set<String> ids) {
    if (node is List) {
      for (final child in node) _collectChildIds(child, ids);
    } else if (node is Map) {
      ids.add(node['id'] as String);
      if (node['children'] != null) {
        for (final child in node['children']) _collectChildIds(child, ids);
      }
    }
  }

  void _traverse(
    List<dynamic> nodes,
    int depth,
    List<_FlatBank> result,
    Set<String> childIds,
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
        _traverse(children, depth + 1, result, childIds, bankMap, counts);
      }
    }
  }

  void _doSearch(String v) {
    setState(() {
      _keyword = v.isEmpty ? null : v;
    });
    _loadBanks();
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

  Future<Set<String>> _getSelfAndDescendants(String bankId) async {
    final tree = await ApiService.getBankTree();
    final node = _findNode(tree, bankId);
    if (node == null) return {};
    return _getDescendantIds(node);
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
      excludeIds = await _getSelfAndDescendants(bank.id);
    }
    final tree = await ApiService.getBankTree();
    final dropdownItems = _flattenForDropdown(tree, 0, excludeIds);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _BankDialog(
        title: bank == null ? '新增题库' : '编辑题库',
        initialName: bank?.name ?? '',
        initialParentId: bank?.parentId,
        options: dropdownItems,
      ),
    );

    if (result != null && result['name'] != null && result['name'].isNotEmpty) {
      final data = {'name': result['name'], 'parent_id': result['parent_id']};
      if (bank == null) {
        await ApiService.createBank(data);
      } else {
        await ApiService.updateBank(bank.id, data);
      }
      _loadBanks();
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
        _loadBanks();
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
      body: Column(
          children: [
            // Search bar
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
            // List
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
                              onTap: () {
                                GlobalQuestionFilter.setBank(bank.id);
                              },
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
          // Tree guide line
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
          // Icon — tap to edit
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
          // Name — tap to view questions
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
          // Delete button
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

    // Vertical line (only if not the last child at this depth)
    if (hasVerticalAbove) {
      canvas.drawLine(Offset(cx, 0), Offset(cx, cy), paint);
      canvas.drawLine(Offset(cx, cy), Offset(cx, size.height), paint);
    } else if (!isLast) {
      // Has more siblings below but not above — shouldn't happen in tree traversal
      canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), paint);
    } else {
      // Last child — only vertical to center
      canvas.drawLine(Offset(cx, 0), Offset(cx, cy), paint);
    }

    // Horizontal branch
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
  final List<_BankOption> options;

  const _BankDialog({
    required this.title,
    required this.initialName,
    required this.initialParentId,
    required this.options,
  });

  @override
  State<_BankDialog> createState() => _BankDialogState();
}

class _BankDialogState extends State<_BankDialog> {
  late TextEditingController _nameCtrl;
  String? _parentId;
  bool _nameEmpty = true;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _parentId = widget.initialParentId;
    _nameEmpty = widget.initialName.isEmpty;
    _nameCtrl.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    final empty = _nameCtrl.text.isEmpty;
    if (empty != _nameEmpty) {
      setState(() => _nameEmpty = empty);
    }
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onNameChanged);
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.title,
        style: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
          color: AppTheme.textPrimary,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: '题库名称',
              prefixIcon: const Icon(Icons.folder_outlined),
            ),
            autofocus: true,
          ),
          SizedBox(height: 16.h),
          DropdownButtonFormField<String?>(
            value: _parentId,
            decoration: InputDecoration(
              labelText: '父题库（可选）',
              prefixIcon: const Icon(Icons.subdirectory_arrow_right),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('无（根题库）'),
              ),
              ...widget.options.map((opt) => DropdownMenuItem<String?>(
                    value: opt.id,
                    child: Text(opt.label),
                  )),
            ],
            onChanged: (v) => setState(() => _parentId = v),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        TextButton(
          onPressed: _nameEmpty ? null : () => Navigator.pop(context, {'name': _nameCtrl.text, 'parent_id': _parentId}),
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

  _FlatBank({required this.bank, required this.depth, required this.isLast, required this.hasChildren, this.questionCount = 0});
}

class _BankOption {
  final String id;
  final String label;
  final int depth;

  _BankOption({required this.id, required this.label, required this.depth});
}
