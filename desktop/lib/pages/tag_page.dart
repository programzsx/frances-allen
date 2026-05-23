import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'qa_page.dart';
import '../theme/desktop_theme.dart';

class TagPage extends StatefulWidget {
  const TagPage({super.key});

  @override
  State<TagPage> createState() => _TagPageState();
}

class _TagPageState extends State<TagPage> {
  List<KbTag> _tags = [];
  Map<String, int> _tagCounts = {};
  bool _loading = true;
  String _searchText = '';
  final Set<String> _selectedTagIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final tagData = await ApiService.pageTags(pageSize: 100);
      final countData = await ApiService.getQaTagCounts();
      if (tagData == null) {
        throw Exception('标签列表为空');
      }
      setState(() {
        _tags = (tagData['items'] as List?)?.map((e) => KbTag.fromJson(e)).toList() ?? [];
        _tagCounts = (countData as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as int)) ?? {};
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载标签失败: $e'),
            backgroundColor: DesktopTheme.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchText = value;
    });
  }

  void _toggleTag(String tagId) {
    setState(() {
      if (_selectedTagIds.contains(tagId)) {
        _selectedTagIds.remove(tagId);
      } else {
        _selectedTagIds.add(tagId);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedTagIds.clear();
    });
  }

  List<KbTag> get _filteredTags {
    var tags = _tags;
    if (_searchText.isNotEmpty) {
      tags = tags.where((t) => t.name.toLowerCase().contains(_searchText.toLowerCase())).toList();
    }
    tags.sort((a, b) {
      final countA = _tagCounts[a.id] ?? 0;
      final countB = _tagCounts[b.id] ?? 0;
      return countB.compareTo(countA);
    });
    return tags;
  }

  Future<void> _showTagDialog({KbTag? tag}) async {
    final nameCtrl = TextEditingController(text: tag?.name);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final nameEmpty = nameCtrl.text.isEmpty;
          return AlertDialog(
            title: Text(
              tag == null ? '新增标签' : '编辑标签',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            content: TextField(
              controller: nameCtrl,
              onChanged: (_) => setDialogState(() {}),
              decoration: const InputDecoration(
                labelText: '标签名称',
                prefixIcon: Icon(Icons.label_outlined),
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
              TextButton(
                onPressed: nameCtrl.text.isEmpty ? null : () => Navigator.pop(ctx, nameCtrl.text),
                child: const Text('确定', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      ),
    );

    if (result != null && result.isNotEmpty) {
      if (tag == null) {
        await ApiService.createTag({'name': result});
      } else {
        await ApiService.updateTag(tag.id, {'name': result});
      }
      _loadData();
    }
  }

  Future<void> _deleteTag(KbTag tag) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定删除标签「${tag.name}」吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除', style: TextStyle(color: DesktopTheme.red))),
        ],
      ),
    );
    if (result == true) {
      await ApiService.deleteTag(tag.id);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 6),
            child: TextField(
              decoration: InputDecoration(
                hintText: '搜索标签',
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
              onChanged: _onSearchChanged,
            ),
          ),

          // Selected filter chips
          if (_selectedTagIds.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '已选 ${_selectedTagIds.length} 个标签',
                        style: const TextStyle(fontSize: 12, color: DesktopTheme.textTertiary),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _clearSelection,
                        child: Text(
                          '清除',
                          style: TextStyle(
                            fontSize: 12,
                            color: DesktopTheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 32,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedTagIds.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final tagId = _selectedTagIds.elementAt(index);
                        final tag = _tags.firstWhere((t) => t.id == tagId);
                        return Chip(
                          label: Text(tag.name, style: const TextStyle(fontSize: 12)),
                          backgroundColor: DesktopTheme.primary.withAlpha(30),
                          side: BorderSide.none,
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => _toggleTag(tagId),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                ],
              ),
            ),

          // Tag list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTags.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.label_outlined, size: 56, color: DesktopTheme.textTertiary),
                            const SizedBox(height: 16),
                            Text(
                              _searchText.isEmpty ? '暂无标签' : '未找到匹配的标签',
                              style: const TextStyle(color: DesktopTheme.textTertiary, fontSize: 15),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchText.isEmpty ? '点击右下角按钮创建' : '尝试其他关键词',
                              style: const TextStyle(color: DesktopTheme.textTertiary, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _filteredTags.length,
                        itemBuilder: (context, index) {
                          final tag = _filteredTags[index];
                          final count = _tagCounts[tag.id] ?? 0;
                          final isSelected = _selectedTagIds.contains(tag.id);

                          return InkWell(
                            onTap: () {
                              final tag = _filteredTags[index];
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => QaPage(initialTagId: tag.id),
                                ),
                              );
                            },
                            onLongPress: () => _showTagDialog(tag: tag),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? DesktopTheme.primary.withAlpha(20) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected ? DesktopTheme.primary.withAlpha(50) : Colors.transparent,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: isSelected ? DesktopTheme.primary : DesktopTheme.primary.withAlpha(50),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        tag.name.substring(0, 1).toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tag.name,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: DesktopTheme.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$count 道题目',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: DesktopTheme.textTertiary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, color: DesktopTheme.textTertiary, size: 20),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'tag_fab',
        onPressed: () => _showTagDialog(),
        child: const Icon(Icons.add_circle_outlined, color: Colors.white),
      ),
    );
  }
}
