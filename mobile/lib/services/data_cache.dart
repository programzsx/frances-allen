import 'package:flutter/material.dart';
import '../models/models.dart';
import 'api_service.dart';

class DataCache extends ChangeNotifier {
  static final DataCache _instance = DataCache._();
  factory DataCache() => _instance;
  DataCache._();

  // ── 银行数据 ──
  List<KbBank>? _allBanks;
  List<dynamic>? _bankTree;
  Map<String, int>? _bankCounts;
  bool _banksLoading = false;

  List<KbBank> get allBanks => _allBanks ?? [];
  List<dynamic> get bankTree => _bankTree ?? [];
  Map<String, int> get bankCounts => _bankCounts ?? {};
  bool get hasBanks => _allBanks != null;
  bool get banksLoading => _banksLoading;

  Future<void> ensureBanks() async {
    if (_allBanks != null) return;
    _banksLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        ApiService.getBanks(),
        ApiService.getBankTree(),
        ApiService.getBankQuestionCounts().catchError((_) => <String, int>{}),
      ]);
      _allBanks = results[0] as List<KbBank>;
      _bankTree = results[1] as List<dynamic>;
      _bankCounts = results[2] as Map<String, int>;
    } catch (_) {
    } finally {
      _banksLoading = false;
      notifyListeners();
    }
  }

  // ── 标签数据 ──
  List<KbTag>? _allTags;
  bool _tagsLoading = false;

  List<KbTag> get allTags => _allTags ?? [];
  bool get hasTags => _allTags != null;
  bool get tagsLoading => _tagsLoading;

  Future<void> ensureTags() async {
    if (_allTags != null) return;
    _tagsLoading = true;
    notifyListeners();
    try {
      _allTags = await ApiService.getTags();
    } catch (_) {
    } finally {
      _tagsLoading = false;
      notifyListeners();
    }
  }

  // ── 图片列表缓存 (按 prefix 分桶) ──
  final Map<String, Map<String, dynamic>> _imageCache = {};

  Map<String, dynamic>? getCachedImages(String prefix) {
    return _imageCache[prefix];
  }

  void cacheImages(String prefix, Map<String, dynamic> data) {
    _imageCache[prefix] = data;
  }

  void invalidateImages({String? prefix}) {
    if (prefix != null) {
      _imageCache.remove(prefix);
    } else {
      _imageCache.clear();
    }
    notifyListeners();
  }

  // ── 全局失效 ──
  void invalidate() {
    _allBanks = null;
    _bankTree = null;
    _allTags = null;
    _bankCounts = null;
    _imageCache.clear();
    notifyListeners();
  }
}
