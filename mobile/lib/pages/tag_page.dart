import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/global_filter.dart';
import '../theme/app_theme.dart';

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

  Future<void> _loadData({bool force = false}) async {
    if (!force && _tags.isNotEmpty) return;
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
            backgroundColor: AppTheme.red,
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
    // Sort by count descending
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
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
                color: AppTheme.textPrimary,
              ),
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
      _loadData(force: true);
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
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除', style: TextStyle(color: AppTheme.red))),
        ],
      ),
    );
    if (result == true) {
      await ApiService.deleteTag(tag.id);
      _loadData(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('标签管理')),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
            child: TextField(
              decoration: InputDecoration(
                hintText: '搜索标签',
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
              onChanged: _onSearchChanged,
            ),
          ),

          // Selected filter chips
          if (_selectedTagIds.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '已选 ${_selectedTagIds.length} 个标签',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppTheme.textTertiary,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _clearSelection,
                        child: Text(
                          '清除',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppTheme.primary,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  SizedBox(
                    height: 32.h,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedTagIds.length,
                      separatorBuilder: (_, __) => SizedBox(width: 8.w),
                      itemBuilder: (context, index) {
                        final tagId = _selectedTagIds.elementAt(index);
                        final tag = _tags.firstWhere((t) => t.id == tagId);
                        return Chip(
                          label: Text(tag.name, style: TextStyle(fontSize: 12.sp, fontFamily: 'Inter')),
                          backgroundColor: AppTheme.primary.withAlpha(30),
                          side: BorderSide.none,
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => _toggleTag(tagId),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 8.h),
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
                            Icon(Icons.label_outlined, size: 64.sp, color: AppTheme.textTertiary),
                            SizedBox(height: 16.h),
                            Text(
                              _searchText.isEmpty ? '暂无标签' : '未找到匹配的标签',
                              style: TextStyle(color: AppTheme.textTertiary, fontSize: 16.sp, fontFamily: 'Inter'),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              _searchText.isEmpty ? '点击右下角按钮创建' : '尝试其他关键词',
                              style: TextStyle(color: AppTheme.textTertiary, fontSize: 13.sp),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(vertical: 8.h),
                        itemCount: _filteredTags.length,
                        itemBuilder: (context, index) {
                          final tag = _filteredTags[index];
                          final count = _tagCounts[tag.id] ?? 0;
                          final isSelected = _selectedTagIds.contains(tag.id);

                          return InkWell(
                            onTap: () {
                              final tag = _filteredTags[index];
                              GlobalQuestionFilter.setTag(tag.id);
                            },
                            onLongPress: () => _showTagDialog(tag: tag),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.primary.withAlpha(20) : Colors.transparent,
                                border: Border(
                                  bottom: BorderSide(color: AppTheme.border.withAlpha(100), width: 0.5),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36.w,
                                    height: 36.w,
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppTheme.primary : AppTheme.primary.withAlpha(50),
                                      borderRadius: BorderRadius.circular(8.r),
                                    ),
                                    child: Center(
                                      child: Text(
                                        tag.name.substring(0, 1).toUpperCase(),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14.sp,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tag.name,
                                          style: TextStyle(
                                            fontSize: 15.sp,
                                            fontWeight: FontWeight.w500,
                                            color: AppTheme.textPrimary,
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                        SizedBox(height: 2.h),
                                        Text(
                                          '$count 道题目',
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                            color: AppTheme.textTertiary,
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right, color: AppTheme.textTertiary, size: 22.sp),
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
        onPressed: () => _showTagDialog(),
        child: const Icon(Icons.add_circle_outlined, color: Colors.white),
      ),
    );
  }
}