import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/data_cache.dart';
import 'tag_detail_page.dart';
import '../theme/app_theme.dart';

class TagPage extends StatefulWidget {
  const TagPage({super.key});

  @override
  State<TagPage> createState() => _TagPageState();
}

class _TagPageState extends State<TagPage> {
  late DataCache _cache;
  List<KbTag> _tags = [];
  Map<String, int> _tagCounts = {};
  bool _loading = true;
  String _searchText = '';
  final Set<String> _selectedTagIds = {};

  @override
  void initState() {
    super.initState();
    _cache = DataCache();
    _cache.addListener(_onCacheUpdate);
    _loadData();
  }

  @override
  void dispose() {
    _cache.removeListener(_onCacheUpdate);
    super.dispose();
  }

  void _onCacheUpdate() {
    if (_cache.hasTags && !_cache.tagsLoading) {
      _loadCounts();
    }
  }

  Future<void> _loadData({bool force = false}) async {
    if (!force && _cache.hasTags) {
      setState(() {
        _tags = _cache.allTags;
        _loading = false;
      });
      _loadCounts();
      return;
    }
    setState(() => _loading = true);
    await _cache.ensureTags();
    if (mounted) {
      setState(() {
        _tags = _cache.allTags;
        _loading = false;
      });
      _loadCounts();
    }
  }

  Future<void> _loadCounts() async {
    try {
      final countData = await ApiService.getQaTagCounts();
      if (mounted) {
        setState(() {
          _tagCounts = (countData as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as int)) ?? {};
        });
      }
    } catch (_) {}
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchText = value;
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
    final sortCtrl = TextEditingController(text: (tag?.sortOrder ?? 0).toString());

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final nameEmpty = nameCtrl.text.isEmpty;
          return AlertDialog(
            title: Text(
              tag == null ? '新增标签' : '编辑标签',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, fontFamily: 'Inter', color: AppTheme.textPrimary),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(
                      labelText: '标签名称',
                      prefixIcon: Icon(Icons.label_outlined),
                    ),
                    autofocus: true,
                  ),
                  SizedBox(height: 16.h),
                  TextField(
                    controller: sortCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '排序值',
                      prefixIcon: Icon(Icons.sort_outlined),
                      hintText: '0',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
              TextButton(
                onPressed: nameEmpty
                    ? null
                    : () => Navigator.pop(ctx, {
                        'name': nameCtrl.text,
                        'sort_order': int.tryParse(sortCtrl.text) ?? 0,
                      }),
                child: const Text('确定', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      ),
    );

    if (result != null && result['name'] != null && (result['name'] as String).isNotEmpty) {
      final data = {
        'name': result['name'],
        'sort_order': result['sort_order'],
      };
      if (tag == null) {
        await ApiService.createTag(data);
      } else {
        await ApiService.updateTag(tag.id, data);
      }
      _cache.invalidate();
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
      _cache.invalidate();
      _loadData(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('标签管理')),
      body: Column(
        children: [
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

                          return InkWell(
                            onTap: () => Navigator.push(context, MaterialPageRoute(
                              builder: (_) => TagDetailPage(tag: tag),
                            )),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                              decoration: BoxDecoration(
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
                                      color: AppTheme.primary.withAlpha(50),
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
                                  // 编辑按钮
                                  GestureDetector(
                                    onTap: () => _showTagDialog(tag: tag),
                                    child: Container(
                                      padding: EdgeInsets.all(8.w),
                                      decoration: BoxDecoration(
                                        color: AppTheme.indigo50,
                                        borderRadius: BorderRadius.circular(8.r),
                                      ),
                                      child: Icon(Icons.edit_note, color: AppTheme.primary, size: 18.sp),
                                    ),
                                  ),
                                  SizedBox(width: 4.w),
                                  // 删除按钮
                                  SizedBox(
                                    width: 32.w,
                                    height: 32.w,
                                    child: IconButton(
                                      icon: const Icon(Icons.delete_outline, color: AppTheme.red, size: 16),
                                      onPressed: () => _deleteTag(tag),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ),
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
