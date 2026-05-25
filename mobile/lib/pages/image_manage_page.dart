import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../services/data_cache.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';

class ImageManagePage extends StatefulWidget {
  const ImageManagePage({super.key});

  @override
  State<ImageManagePage> createState() => _ImageManagePageState();
}

class _ImageManagePageState extends State<ImageManagePage> {
  String _currentPrefix = "kb/";
  List<Map<String, dynamic>> _dirs = [];
  List<Map<String, dynamic>> _files = [];
  bool _loading = true;
  bool _isGridView = false;
  final _searchCtrl = TextEditingController();
  late DataCache _cache;

  @override
  void initState() {
    super.initState();
    _cache = DataCache();
    _loadImages();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadImages({bool force = false}) async {
    // 先检查缓存
    if (!force) {
      final cached = _cache.getCachedImages(_currentPrefix);
      if (cached != null) {
        setState(() {
          _dirs = (cached['dirs'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
          _files = (cached['files'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
          _loading = false;
        });
        return;
      }
    }
    setState(() => _loading = true);
    try {
      final data = await ApiService.listImages(prefix: _currentPrefix);
      _cache.cacheImages(_currentPrefix, data);
      setState(() {
        _dirs = (data['dirs'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
        _files = (data['files'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  void _navigateToDir(String prefix) {
    setState(() => _currentPrefix = prefix);
    _loadImages(force: true);
  }

  String _getDisplayName(String key) {
    final relative = key.startsWith(_currentPrefix)
        ? key.substring(_currentPrefix.length)
        : key;
    return relative.split('/').where((s) => s.isNotEmpty).last;
  }

  String _getParentPrefix() {
    if (_currentPrefix.isEmpty) return "";
    final parts = _currentPrefix.split("/");
    if (parts.length <= 2) return "";
    parts.removeLast();
    parts.removeLast();
    return parts.isEmpty ? "" : "${parts.join("/")}/";
  }

  Future<void> _showUploadDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => _UploadDialog(
        currentPrefix: _currentPrefix.isEmpty ? "kb" : _currentPrefix,
      ),
    );
    if (result == true) _loadImages(force: true);
  }

  Future<void> _previewImage(int index) async {
    if (_files.isEmpty) return;

    await showDialog(
      context: context,
      builder: (ctx) => _ImageViewerDialog(
        files: _files,
        initialIndex: index,
        onDelete: (key) async {
          final result = await showDialog<bool>(
            context: ctx,
            builder: (ctx) => AlertDialog(
              title: const Text('确认删除'),
              content: Text('确定删除图片「${_getDisplayName(key)}」吗？'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('删除', style: TextStyle(color: AppTheme.red)),
                ),
              ],
            ),
          );
          if (result == true) {
            await ApiService.deleteImage(key);
            if (mounted) Navigator.pop(ctx);
            _loadImages(force: true);
          }
        },
        onCopy: (url) {
          Clipboard.setData(ClipboardData(text: url));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('链接已复制'), behavior: SnackBarBehavior.floating),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 0,
            pinned: true,
            backgroundColor: AppTheme.bgPrimary,
            elevation: 0,
            leading: const SizedBox.shrink(),
            title: Text('图片管理', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17, fontFamily: 'Inter')),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(_isGridView ? Icons.view_list_outlined : Icons.grid_view_outlined, size: 20),
                onPressed: () => setState(() => _isGridView = !_isGridView),
              ),
              SizedBox(width: 8.w),
            ],
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Breadcrumb
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => _navigateToDir(""),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            color: AppTheme.indigo50,
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(color: AppTheme.indigo100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.home_outlined, size: 14.sp, color: AppTheme.primary),
                              SizedBox(width: 4.w),
                              Text('根目录', style: TextStyle(color: AppTheme.primary, fontSize: 13.sp, fontWeight: FontWeight.w500, fontFamily: 'Inter')),
                            ],
                          ),
                        ),
                      ),
                      if (_currentPrefix.isNotEmpty) ...[
                        SizedBox(width: 8.w),
                        Icon(Icons.chevron_right, size: 16.sp, color: AppTheme.textTertiary),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _currentPrefix.split("/").where((s) => s.isNotEmpty).toList().asMap().entries.map((entry) {
                                final idx = entry.key;
                                final s = entry.value;
                                final parts = _currentPrefix.split("/").where((p) => p.isNotEmpty).toList();
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        final subParts = parts.sublist(0, idx + 1);
                                        final newPrefix = subParts.isEmpty ? "" : "${subParts.join("/")}/";
                                        _navigateToDir(newPrefix);
                                      },
                                      child: Container(
                                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                        child: Text(s, style: TextStyle(color: AppTheme.primary, fontSize: 13.sp, fontFamily: 'Inter')),
                                      ),
                                    ),
                                    Icon(Icons.chevron_right, size: 14.sp, color: AppTheme.textTertiary),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          SliverFillRemaining(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _dirs.isEmpty && _files.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.folder_open_outlined, size: 64.sp, color: AppTheme.textTertiary),
                            SizedBox(height: 16.h),
                            Text('目录为空', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16.sp, fontFamily: 'Inter')),
                            SizedBox(height: 8.h),
                            Text('点击右下角按钮上传图片', style: TextStyle(color: AppTheme.textTertiary, fontSize: 13.sp, fontFamily: 'Inter')),
                          ],
                        ),
                      )
                    : _isGridView
                        ? _buildGridView()
                        : _buildListView(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showUploadDialog,
        child: const Icon(Icons.add_photo_alternate_outlined, color: Colors.white),
      ),
    );
  }

  Widget _buildListView() {
    return ListView(
      padding: EdgeInsets.only(bottom: 80.h),
      children: [
        ..._dirs.map((dir) => ListTile(
              leading: Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: AppTheme.indigo50,
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: AppTheme.indigo100),
                ),
                child: Icon(Icons.folder_outlined, color: AppTheme.primary),
              ),
              title: Text(_getDisplayName(dir['key']), style: const TextStyle(fontFamily: 'Inter')),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => _navigateToDir(dir['key']),
            )),
        ..._files.asMap().entries.map((entry) {
          final index = entry.key;
          final file = entry.value;
          return ListTile(
            leading: Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: AppTheme.orange.withAlpha(26),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: const Icon(Icons.image_outlined, color: AppTheme.orange),
            ),
            title: Text(_getDisplayName(file['key']), style: const TextStyle(fontFamily: 'Inter')),
            subtitle: Text(_formatFileSize(file['size']), style: const TextStyle(fontFamily: 'Inter')),
            onTap: () => _previewImage(index),
          );
        }),
      ],
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: EdgeInsets.all(12.w),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8.w,
        mainAxisSpacing: 8.h,
      ),
      itemCount: _dirs.length + _files.length,
      itemBuilder: (ctx, i) {
        if (i < _dirs.length) {
          final dir = _dirs[i];
          return GestureDetector(
            onTap: () => _navigateToDir(dir['key']),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.indigo50,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppTheme.indigo100),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_outlined, color: AppTheme.primary, size: 40.sp),
                  SizedBox(height: 4.h),
                  Text(
                    _getDisplayName(dir['key']),
                    style: TextStyle(fontSize: 11.sp, color: AppTheme.primary, fontFamily: 'Inter'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }
        final file = _files[i - _dirs.length];
        final url = "https://zsx-r7000p.oss-cn-beijing.aliyuncs.com/${file['key']}";
        return GestureDetector(
          onTap: () => _previewImage(i - _dirs.length),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.bgSection,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppTheme.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, color: AppTheme.textTertiary, size: 32.sp),
                    SizedBox(height: 4.h),
                    Text(
                      _getDisplayName(file['key']),
                      style: TextStyle(fontSize: 10.sp, color: AppTheme.textSecondary, fontFamily: 'Inter'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    return "${(bytes / 1024 / 1024).toStringAsFixed(1)} MB";
  }
}

class _UploadDialog extends StatefulWidget {
  final String currentPrefix;
  const _UploadDialog({required this.currentPrefix});

  @override
  State<_UploadDialog> createState() => _UploadDialogState();
}

class _UploadDialogState extends State<_UploadDialog> {
  final _picker = ImagePicker();
  XFile? _selectedFile;
  late String _prefix;
  final _nameCtrl = TextEditingController();
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _prefix = widget.currentPrefix;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() {
        _selectedFile = file;
        _nameCtrl.text = file.name.split('.').first;
      });
    }
  }

  Future<void> _doUpload() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入文件名'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    setState(() => _uploading = true);
    try {
      final timestamp = DateTime.now();
      final dateStr = '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}-${timestamp.hour.toString().padLeft(2, '0')}-${timestamp.minute.toString().padLeft(2, '0')}-${timestamp.second.toString().padLeft(2, '0')}';
      final randomStr = Random().nextInt(99999999).toString().padLeft(8, '0');
      final newFileName = '$name-$dateStr-$randomStr';

      Map<String, dynamic> result;
      if (kIsWeb) {
        final bytes = await _selectedFile!.readAsBytes();
        result = await ApiService.uploadImageBytes(
          _selectedFile!.path,
          bytes,
          fileName: newFileName,
          prefix: _prefix,
        );
      } else {
        result = await ApiService.uploadImage(
          _selectedFile!.path,
          fileName: newFileName,
          prefix: _prefix,
        );
      }
      final url = result['url'] as String;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('上传成功！\n$url'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: '复制',
              onPressed: () => Clipboard.setData(ClipboardData(text: url)),
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFile = _selectedFile != null;
    return Scaffold(
      backgroundColor: AppTheme.bgCard,
      appBar: AppBar(
        title: Text('上传图片', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _uploading ? null : () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Preview / pick area
            GestureDetector(
              onTap: _uploading ? null : _pickFile,
              child: Container(
                height: 200.h,
                decoration: BoxDecoration(
                  color: AppTheme.bgSection,
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: AppTheme.border),
                ),
                child: _uploading
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(strokeWidth: 2),
                            SizedBox(height: 16),
                            Text('上传中...', style: TextStyle(fontSize: 16, color: AppTheme.textSecondary, fontFamily: 'Inter')),
                          ],
                        ),
                      )
                    : hasFile
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14.r),
                                child: kIsWeb
                                    ? Image.network(_selectedFile!.path, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48))
                                    : Image.file(File(_selectedFile!.path), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48)),
                              ),
                              Positioned(
                                bottom: 8.h,
                                right: 8.w,
                                child: GestureDetector(
                                  onTap: _pickFile,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(20.r),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.refresh_rounded, color: Colors.white, size: 14),
                                        SizedBox(width: 4.w),
                                        Text('重新选择', style: TextStyle(color: Colors.white, fontSize: 11.sp, fontFamily: 'Inter')),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.cloud_upload_outlined, size: 64.sp, color: AppTheme.textTertiary),
                                SizedBox(height: 12.h),
                                Text('点击此处选择图片', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14.sp, fontFamily: 'Inter')),
                                SizedBox(height: 4.h),
                                Text('支持 JPG、PNG 等常见格式', style: TextStyle(color: AppTheme.textTertiary, fontSize: 12.sp, fontFamily: 'Inter')),
                              ],
                            ),
                          ),
              ),
            ),
            SizedBox(height: 20.h),
            // Filename
            if (hasFile) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      enabled: !_uploading,
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: '文件名（不含扩展名）',
                        prefixIcon: const Icon(Icons.edit_note_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  IconButton(
                    onPressed: _uploading
                        ? null
                        : () => setState(() {
                            _selectedFile = null;
                            _nameCtrl.clear();
                          }),
                    icon: const Icon(Icons.delete_outline, color: AppTheme.red),
                    tooltip: '取消选择',
                  ),
                ],
              ),
              SizedBox(height: 16.h),
            ],
            // Storage directory
            TextField(
              enabled: !_uploading,
              controller: TextEditingController(text: _prefix),
              decoration: InputDecoration(
                labelText: '存储目录',
                hintText: '如: images/qa',
                prefixIcon: const Icon(Icons.folder_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
              ),
              onChanged: (v) => _prefix = v,
            ),
            SizedBox(height: 20.h),
            // Upload button
            SizedBox(
              width: double.infinity,
              height: 48.h,
              child: ElevatedButton.icon(
                onPressed: (_selectedFile == null || _nameCtrl.text.isEmpty || _uploading)
                    ? null
                    : _doUpload,
                icon: _uploading
                    ? SizedBox(width: 18.w, height: 18.w, child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(_uploading ? '上传中...' : '上传'),
              ),
            ),
            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }
}

class _ImageViewerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> files;
  final int initialIndex;
  final Function(String key) onDelete;
  final Function(String url) onCopy;

  const _ImageViewerDialog({
    required this.files,
    required this.initialIndex,
    required this.onDelete,
    required this.onCopy,
  });

  @override
  State<_ImageViewerDialog> createState() => _ImageViewerDialogState();
}

class _ImageViewerDialogState extends State<_ImageViewerDialog> {
  late PageController _pageCtrl;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  String _getUrl(String key) => "https://zsx-r7000p.oss-cn-beijing.aliyuncs.com/$key";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageCtrl,
            itemCount: widget.files.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (ctx, i) {
              final file = widget.files[i];
              final url = _getUrl(file['key']);
              return Center(
                child: InteractiveViewer(
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.contain,
                    errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white, size: 64),
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              color: Colors.black54,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      '${_currentIndex + 1} / ${widget.files.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Inter'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.content_copy_outlined, color: Colors.white, size: 20),
                    onPressed: () => widget.onCopy(_getUrl(widget.files[_currentIndex]['key'])),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppTheme.red, size: 20),
                    onPressed: () => widget.onDelete(widget.files[_currentIndex]['key']),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16.h),
              color: Colors.black54,
              child: Text(
                widget.files[_currentIndex]['key'].split("/").last,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Inter'),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
