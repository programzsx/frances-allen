import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'qa_page.dart';
import '../theme/desktop_theme.dart';

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
      setState(() {
        _flatBanks = _flattenTree(tree, allBanks);
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

  List<_FlatBank> _flattenTree(List<dynamic> tree, List<KbBank> allBanks) {
    final result = <_FlatBank>[];
    final bankMap = {for (final b in allBanks) b.id: b};
    final childIds = <String>{};
    for (final node in tree) _collectChildIds(node, childIds);
    _traverse(tree, 0, result, childIds, bankMap);
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
  ) {
    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i] as Map<String, dynamic>;
      final id = node['id'] as String;
      final isLast = (i == nodes.length - 1);
      final hasChildren = (node['children'] as List?)?.isNotEmpty ?? false;
      final bank = bankMap[id];
      result.add(_FlatBank(bank: bank, depth: depth, isLast: isLast, hasChildren: hasChildren));
      final children = node['children'] as List<dynamic>?;
      if (children != null && children.isNotEmpty) {
        _traverse(children, depth + 1, result, childIds, bankMap);
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
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除', style: TextStyle(color: DesktopTheme.red))),
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
      appBar: AppBar(title: const Text('题库管理')),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 6),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: '搜索题库',
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
          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : displayedBanks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.folder_outlined, size: 56, color: DesktopTheme.textTertiary),
                            const SizedBox(height: 16),
                            const Text('暂无题库', style: TextStyle(color: DesktopTheme.textTertiary, fontSize: 15)),
                            const SizedBox(height: 8),
                            const Text('点击右下角按钮创建', style: TextStyle(color: DesktopTheme.textTertiary, fontSize: 13)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 4, bottom: 72),
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
                            onEdit: () => _showBankDialog(bank: bank),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => QaPage(initialCategoryId: bank.id),
                                ),
                              );
                            },
                            onDelete: () => _deleteBank(bank),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'bank_fab',
        onPressed: () => _showBankDialog(),
        child: const Icon(Icons.add_circle_outlined, color: Colors.white),
      ),
    );
  }
}

class _BankTreeItem extends StatelessWidget {
  final KbBank bank;
  final int depth;
  final bool isLast;
  final bool hasChildren;
  final VoidCallback onEdit;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _BankTreeItem({
    required this.bank,
    required this.depth,
    required this.isLast,
    required this.hasChildren,
    required this.onEdit,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(left: 24, right: 24, top: 4, bottom: 4),
      padding: EdgeInsets.only(left: depth * 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Tree guide line
          if (depth > 0) ...[
            const SizedBox(width: 16),
            CustomPaint(
              size: const Size(12, 32),
              painter: _TreeLinePainter(
                hasVerticalAbove: !isLast,
                hasHorizontal: true,
                isLast: isLast,
              ),
            ),
            const SizedBox(width: 4),
          ],
          // Icon — tap to edit
          GestureDetector(
            onTap: onEdit,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: DesktopTheme.indigo50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit_note, color: DesktopTheme.primary, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          // Name — tap to view questions
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Text(
                bank.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: DesktopTheme.textPrimary,
                ),
              ),
            ),
          ),
          // Delete button
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
      ..color = DesktopTheme.textTertiary
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
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: '题库名称',
              prefixIcon: Icon(Icons.folder_outlined),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            value: _parentId,
            decoration: const InputDecoration(
              labelText: '父题库（可选）',
              prefixIcon: Icon(Icons.subdirectory_arrow_right),
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

  _FlatBank({required this.bank, required this.depth, required this.isLast, required this.hasChildren});
}

class _BankOption {
  final String id;
  final String label;
  final int depth;

  _BankOption({required this.id, required this.label, required this.depth});
}
