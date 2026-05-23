import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../theme/desktop_theme.dart';

class ImageManagePage extends StatefulWidget {
  const ImageManagePage({super.key});

  @override
  State<ImageManagePage> createState() => _ImageManagePageState();
}

class _ImageManagePageState extends State<ImageManagePage> {
  String _currentPrefix = "";
  List<Map<String, dynamic>> _dirs = [];
  List<Map<String, dynamic>> _files = [];
  bool _loading = true;
  bool _isGridView = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadImages() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.listImages(prefix: _currentPrefix);
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
    _loadImages();
  }

  String _getDisplayName(String key) {
    if (_currentPrefix.isEmpty) {
      return key.replaceAll("/", "");
    }
    final relative = key.substring(_currentPrefix.length);
    return relative.replaceAll("/", "");
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
        currentPrefix: _currentPrefix.isEmpty ? "images" : _currentPrefix,
      ),
    );
    if (result == true) _loadImages();
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
                  child: const Text('删除', style: TextStyle(color: DesktopTheme.red)),
                ),
              ],
            ),
          );
          if (result == true) {
            await ApiService.deleteImage(key);
            if (mounted) Navigator.pop(ctx);
            _loadImages();
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

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    return "${(bytes / 1024 / 1024).toStringAsFixed(1)} MB";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('图片管理', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list_outlined : Icons.grid_view_outlined, size: 20),
            onPressed: () => setState(() => _isGridView = !_isGridView),
            tooltip: _isGridView ? '列表视图' : '网格视图',
          ),
        ],
      ),
      body: Column(
        children: [
          // Breadcrumb
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: BoxDecoration(
              color: DesktopTheme.bgCard,
              border: Border(bottom: BorderSide(color: DesktopTheme.border)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _navigateToDir(""),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: DesktopTheme.indigo50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: DesktopTheme.indigo100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.home_outlined, size: 14, color: DesktopTheme.primary),
                        const SizedBox(width: 4),
                        const Text('根目录', style: TextStyle(color: DesktopTheme.primary, fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
                if (_currentPrefix.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, size: 16, color: DesktopTheme.textTertiary),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _currentPrefix.split("/").where((s) => s.isNotEmpty).map((s) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  final idx = _currentPrefix.split("/").indexOf(s);
                                  final parts = _currentPrefix.split("/").where((p) => p.isNotEmpty).toList();
                                  parts.removeRange(idx + 1, parts.length);
                                  final newPrefix = parts.isEmpty ? "" : "${parts.join("/")}/";
                                  _navigateToDir(newPrefix);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  child: Text(s, style: const TextStyle(color: DesktopTheme.primary, fontSize: 13)),
                                ),
                              ),
                              const Icon(Icons.chevron_right, size: 14, color: DesktopTheme.textTertiary),
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

          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _dirs.isEmpty && _files.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.folder_open_outlined, size: 56, color: DesktopTheme.textTertiary),
                            const SizedBox(height: 16),
                            const Text('目录为空', style: TextStyle(color: DesktopTheme.textSecondary, fontSize: 15)),
                            const SizedBox(height: 8),
                            const Text('点击右下角按钮上传图片', style: TextStyle(color: DesktopTheme.textTertiary, fontSize: 13)),
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
        heroTag: 'image_fab',
        onPressed: _showUploadDialog,
        child: const Icon(Icons.add_photo_alternate_outlined, color: Colors.white),
      ),
    );
  }

  Widget _buildListView() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 72),
      children: [
        ..._dirs.map((dir) => ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: DesktopTheme.indigo50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: DesktopTheme.indigo100),
                ),
                child: const Icon(Icons.folder_outlined, color: DesktopTheme.primary),
              ),
              title: Text(_getDisplayName(dir['key'])),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => _navigateToDir(dir['key']),
            )),
        ..._files.asMap().entries.map((entry) {
          final index = entry.key;
          final file = entry.value;
          return ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: DesktopTheme.orange.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.image_outlined, color: DesktopTheme.orange),
            ),
            title: Text(_getDisplayName(file['key'])),
            subtitle: Text(_formatFileSize(file['size'])),
            onTap: () => _previewImage(index),
          );
        }),
      ],
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: _dirs.length + _files.length,
      itemBuilder: (ctx, i) {
        if (i < _dirs.length) {
          final dir = _dirs[i];
          return GestureDetector(
            onTap: () => _navigateToDir(dir['key']),
            child: Container(
              decoration: BoxDecoration(
                color: DesktopTheme.indigo50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: DesktopTheme.indigo100),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.folder_outlined, color: DesktopTheme.primary, size: 40),
                  const SizedBox(height: 4),
                  Text(
                    _getDisplayName(dir['key']),
                    style: const TextStyle(fontSize: 12, color: DesktopTheme.primary),
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
              color: DesktopTheme.bgSection,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: DesktopTheme.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.broken_image, color: DesktopTheme.textTertiary, size: 32),
                    const SizedBox(height: 4),
                    Text(
                      _getDisplayName(file['key']),
                      style: const TextStyle(fontSize: 11, color: DesktopTheme.textSecondary),
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
      backgroundColor: DesktopTheme.bgCard,
      appBar: AppBar(
        title: const Text('上传图片', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _uploading ? null : () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Preview / pick area
            GestureDetector(
              onTap: _uploading ? null : _pickFile,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: DesktopTheme.bgSection,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: DesktopTheme.border),
                ),
                child: _uploading
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(strokeWidth: 2),
                            SizedBox(height: 16),
                            Text('上传中...', style: TextStyle(fontSize: 14, color: DesktopTheme.textSecondary)),
                          ],
                        ),
                      )
                    : hasFile
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: kIsWeb
                                    ? Image.network(_selectedFile!.path, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48))
                                    : Image.file(File(_selectedFile!.path), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48)),
                              ),
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: _pickFile,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.refresh_rounded, color: Colors.white, size: 14),
                                        SizedBox(width: 4),
                                        Text('重新选择', style: TextStyle(color: Colors.white, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.cloud_upload_outlined, size: 48, color: DesktopTheme.textTertiary),
                                SizedBox(height: 12),
                                Text('点击此处选择图片', style: TextStyle(color: DesktopTheme.textSecondary, fontSize: 14)),
                                SizedBox(height: 4),
                                Text('支持 JPG、PNG 等常见格式', style: TextStyle(color: DesktopTheme.textTertiary, fontSize: 12)),
                              ],
                            ),
                          ),
              ),
            ),
            const SizedBox(height: 20),
            // Filename
            if (hasFile) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      enabled: !_uploading,
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: '文件名（不含扩展名）',
                        prefixIcon: Icon(Icons.edit_note_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(6))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _uploading
                        ? null
                        : () => setState(() {
                            _selectedFile = null;
                            _nameCtrl.clear();
                          }),
                    icon: const Icon(Icons.delete_outline, color: DesktopTheme.red),
                    tooltip: '取消选择',
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            // Storage directory
            TextField(
              enabled: !_uploading,
              controller: TextEditingController(text: _prefix),
              decoration: const InputDecoration(
                labelText: '存储目录',
                hintText: '如: images/qa',
                prefixIcon: Icon(Icons.folder_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(6))),
              ),
              onChanged: (v) => _prefix = v,
            ),
            const SizedBox(height: 20),
            // Upload button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: (_selectedFile == null || _nameCtrl.text.isEmpty || _uploading)
                    ? null
                    : _doUpload,
                icon: _uploading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(_uploading ? '上传中...' : '上传'),
              ),
            ),
            const SizedBox(height: 16),
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
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.content_copy_outlined, color: Colors.white, size: 20),
                    onPressed: () => widget.onCopy(_getUrl(widget.files[_currentIndex]['key'])),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: DesktopTheme.red, size: 20),
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
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16),
              color: Colors.black54,
              child: Text(
                widget.files[_currentIndex]['key'].split("/").last,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
