import 'package:flutter/material.dart';
import '../models/models.dart';
import 'api_service.dart';

class DataCache extends ChangeNotifier {
  static final DataCache _instance = DataCache._();
  factory DataCache() => _instance;
  DataCache._();

  List<KbBank>? _allBanks;
  List<dynamic>? _bankTree;
  List<KbTag>? _allTags;

  List<KbBank> get allBanks => _allBanks ?? [];
  List<dynamic> get bankTree => _bankTree ?? [];
  List<KbTag> get allTags => _allTags ?? [];
  bool get hasBanks => _allBanks != null;
  bool get hasTags => _allTags != null;

  Future<void> ensureBanks() async {
    if (_allBanks != null) return;
    try {
      _allBanks = await ApiService.getBanks();
      _bankTree = await ApiService.getBankTree();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> ensureTags() async {
    if (_allTags != null) return;
    try {
      _allTags = await ApiService.getTags();
      notifyListeners();
    } catch (_) {}
  }

  void invalidate() {
    _allBanks = null;
    _bankTree = null;
    _allTags = null;
    notifyListeners();
  }
}
