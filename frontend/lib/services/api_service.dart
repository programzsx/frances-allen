import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/models.dart';

class ApiService {
  static const String baseUrl = 'http://8.160.174.178:8000';

  // 缓存题库数据
  static List<KbBank>? _cachedBanks;
  static List<KbTag>? _cachedTags;

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
      };

  static void clearCache() {
    _cachedBanks = null;
    _cachedTags = null;
  }

  // ============ 题库 ============

  static Future<Map<String, dynamic>> createBank(Map<String, dynamic> data) async {
    try {
      final resp = await http.post(
        Uri.parse('$baseUrl/api/banks'),
        headers: _headers,
        body: jsonEncode(data),
      );
      _checkError(resp);
      clearCache();
      return jsonDecode(resp.body);
    } catch (e) {
      rethrow;
    }
  }

  static Future<bool> deleteBank(String id) async {
    try {
      final resp = await http.delete(Uri.parse('$baseUrl/api/banks/$id'));
      _checkError(resp);
      final body = jsonDecode(resp.body);
      clearCache();
      if (body['success'] != true) {
        throw Exception(body['error'] ?? '删除失败');
      }
      return true;
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> updateBank(String id, Map<String, dynamic> data) async {
    try {
      final resp = await http.put(
        Uri.parse('$baseUrl/api/banks/$id'),
        headers: _headers,
        body: jsonEncode(data),
      );
      _checkError(resp);
      clearCache();
      return jsonDecode(resp.body);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> pageBanks({
    int currentPage = 1,
    int pageSize = 10,
    String? keyword,
  }) async {
    // 如果缓存存在且请求第一页无关键词，返回缓存
    if (_cachedBanks != null && currentPage == 1 && keyword == null) {
      return {
        'items': _cachedBanks!.map((b) => {
          'id': b.id,
          'name': b.name,
          'create_time': b.createTime,
          'update_time': b.updateTime,
          'parent_id': b.parentId,
        }).toList(),
        'total': _cachedBanks!.length,
        'current_page': 1,
        'page_size': pageSize,
      };
    }
    try {
      final params = <String, String>{
        'current_page': currentPage.toString(),
        'page_size': pageSize.toString(),
      };
      if (keyword != null && keyword.isNotEmpty) params['keyword'] = keyword;
      final resp = await http.get(
        Uri.parse('$baseUrl/api/banks').replace(queryParameters: params),
      );
      _checkError(resp);
      final data = jsonDecode(resp.body);
      // 缓存题库数据
      if (currentPage == 1 && keyword == null) {
        _cachedBanks = (data['items'] as List).map((e) => KbBank.fromJson(e)).toList();
      }
      return data;
    } catch (e) {
      rethrow;
    }
  }

  static Future<List<KbBank>> getBanks() async {
    if (_cachedBanks != null) return _cachedBanks!;
    final data = await pageBanks(pageSize: 100);
    _cachedBanks = (data['items'] as List).map((e) => KbBank.fromJson(e)).toList();
    return _cachedBanks!;
  }

  static Future<List<dynamic>> getBankTree() async {
    final resp = await http.get(Uri.parse('$baseUrl/api/banks/tree'));
    _checkError(resp);
    return jsonDecode(resp.body);
  }

  // ============ 标签 ============

  static Future<Map<String, dynamic>> createTag(Map<String, dynamic> data) async {
    try {
      final resp = await http.post(
        Uri.parse('$baseUrl/api/tags'),
        headers: _headers,
        body: jsonEncode(data),
      );
      _checkError(resp);
      clearCache();
      return jsonDecode(resp.body);
    } catch (e) {
      rethrow;
    }
  }

  static Future<bool> deleteTag(String id) async {
    try {
      final resp = await http.delete(Uri.parse('$baseUrl/api/tags/$id'));
      _checkError(resp);
      final body = jsonDecode(resp.body);
      clearCache();
      if (body['success'] != true) {
        throw Exception(body['error'] ?? '删除失败');
      }
      return true;
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> updateTag(String id, Map<String, dynamic> data) async {
    try {
      final resp = await http.put(
        Uri.parse('$baseUrl/api/tags/$id'),
        headers: _headers,
        body: jsonEncode(data),
      );
      _checkError(resp);
      clearCache();
      return jsonDecode(resp.body);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> pageTags({
    int currentPage = 1,
    int pageSize = 10,
    String? keyword,
  }) async {
    try {
      final params = <String, String>{
        'current_page': currentPage.toString(),
        'page_size': pageSize.toString(),
      };
      if (keyword != null && keyword.isNotEmpty) params['keyword'] = keyword;
      final resp = await http.get(
        Uri.parse('$baseUrl/api/tags').replace(queryParameters: params),
      );
      _checkError(resp);
      return jsonDecode(resp.body);
    } catch (e) {
      rethrow;
    }
  }

  static Future<List<KbTag>> getTags() async {
    if (_cachedTags != null) return _cachedTags!;
    final data = await pageTags(pageSize: 100);
    _cachedTags = (data['items'] as List).map((e) => KbTag.fromJson(e)).toList();
    return _cachedTags!;
  }

  static Future<Map<String, dynamic>> getTagsByIds(List<String> ids) async {
    try {
      final resp = await http.post(
        Uri.parse('$baseUrl/api/tags/batch'),
        headers: _headers,
        body: jsonEncode({'ids': ids}),
      );
      _checkError(resp);
      return jsonDecode(resp.body);
    } catch (e) {
      rethrow;
    }
  }

  // ============ 题目 ============

  static Future<Map<String, dynamic>> createQa(Map<String, dynamic> data) async {
    try {
      final resp = await http.post(
        Uri.parse('$baseUrl/api/qas'),
        headers: _headers,
        body: jsonEncode(data),
      );
      _checkError(resp);
      return jsonDecode(resp.body);
    } catch (e) {
      rethrow;
    }
  }

  static Future<bool> deleteQa(String id) async {
    try {
      final resp = await http.delete(Uri.parse('$baseUrl/api/qas/$id'));
      _checkError(resp);
      final body = jsonDecode(resp.body);
      if (body['success'] != true) {
        throw Exception(body['error'] ?? '删除失败');
      }
      return true;
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> updateQa(String id, Map<String, dynamic> data) async {
    try {
      final resp = await http.put(
        Uri.parse('$baseUrl/api/qas/$id'),
        headers: _headers,
        body: jsonEncode(data),
      );
      _checkError(resp);
      return jsonDecode(resp.body);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> getQa(String id) async {
    try {
      final resp = await http.get(Uri.parse('$baseUrl/api/qas/$id'));
      final body = resp.body;
      if (body == 'null') return null;
      _checkError(resp);
      return jsonDecode(body);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> pageQas({
    int currentPage = 1,
    int pageSize = 10,
    String? bankId,
    String? keyword,
    String? tagId,
  }) async {
    try {
      final params = <String, String>{
        'current_page': currentPage.toString(),
        'page_size': pageSize.toString(),
      };
      if (bankId != null) params['bank_id'] = bankId;
      if (keyword != null && keyword.isNotEmpty) params['keyword'] = keyword;
      if (tagId != null) params['tag_id'] = tagId;
      final resp = await http.get(
        Uri.parse('$baseUrl/api/qas').replace(queryParameters: params),
      );
      _checkError(resp);
      return jsonDecode(resp.body);
    } catch (e) {
      rethrow;
    }
  }

  static Future<List<dynamic>> randomQas({
    int limit = 10,
    String? bankId,
  }) async {
    try {
      final params = <String, String>{'limit': limit.toString()};
      if (bankId != null) params['bank_id'] = bankId;
      final resp = await http.get(
        Uri.parse('$baseUrl/api/qas/random/list').replace(queryParameters: params),
      );
      _checkError(resp);
      return jsonDecode(resp.body);
    } catch (e) {
      rethrow;
    }
  }

  static Future<List<dynamic>> sequentialQas({
    int limit = 10,
    String? bankId,
    int? offsetId,
  }) async {
    try {
      final params = <String, String>{'limit': limit.toString()};
      if (bankId != null) params['bank_id'] = bankId;
      if (offsetId != null) params['offset_id'] = offsetId.toString();
      final resp = await http.get(
        Uri.parse('$baseUrl/api/qas/sequential/list').replace(queryParameters: params),
      );
      _checkError(resp);
      return jsonDecode(resp.body);
    } catch (e) {
      rethrow;
    }
  }

  /// 获取指定题库的全部题目（自动翻页）
  static Future<List<dynamic>> getAllQasForBank({
    String? bankId,
  }) async {
    final allItems = <dynamic>[];
    int currentPage = 1;
    int total = 0;
    const pageSize = 100;

    do {
      final data = await pageQas(currentPage: currentPage, pageSize: pageSize, bankId: bankId);
      final items = data['items'] as List;
      allItems.addAll(items);
      total = data['total'];
      currentPage++;
    } while (allItems.length < total);

    return allItems;
  }

  static Future<List<dynamic>> wrongQas({
    int limit = 10,
    String? bankId,
    int minWrong = 1,
  }) async {
    try {
      final params = <String, String>{
        'limit': limit.toString(),
        'min_wrong': minWrong.toString(),
      };
      if (bankId != null) params['bank_id'] = bankId;
      final resp = await http.get(
        Uri.parse('$baseUrl/api/qas/wrong/list').replace(queryParameters: params),
      );
      _checkError(resp);
      return jsonDecode(resp.body);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getQaTagCounts() async {
    try {
      final resp = await http.get(Uri.parse('$baseUrl/api/qas/tag-counts'));
      _checkError(resp);
      final decoded = jsonDecode(resp.body);
      if (decoded == null) return {};
      return decoded as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  // ============ 图片（OSS）===========

  static Future<Map<String, dynamic>> listImages({String prefix = ""}) async {
    try {
      final params = <String, String>{};
      if (prefix.isNotEmpty) params['prefix'] = prefix;
      final resp = await http.get(
        Uri.parse('$baseUrl/api/images/list').replace(queryParameters: params),
      );
      _checkError(resp);
      return jsonDecode(resp.body);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> uploadImageBytes(
    String filePath,
    List<int> bytes, {
    String prefix = "images",
    String? fileName,
    Function(double)? onProgress,
  }) async {
    try {
      final queryParams = <String, String>{'prefix': prefix};
      if (fileName != null) queryParams['filename'] = fileName;
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/images/upload').replace(queryParameters: queryParams),
      );
      final filename = fileName ?? filePath.split('/').last;
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
      final streamResp = await request.send();
      final resp = await http.Response.fromStream(streamResp);
      _checkError(resp);
      return jsonDecode(resp.body);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> uploadImage(
    String filePath, {
    String prefix = "images",
    String? fileName,
  }) async {
    try {
      final queryParams = <String, String>{'prefix': prefix};
      if (fileName != null) queryParams['filename'] = fileName;
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/images/upload').replace(queryParameters: queryParams),
      );
      final filename = fileName ?? filePath.split('/').last;
      request.files.add(await http.MultipartFile.fromPath('file', filePath, filename: filename));
      final streamResp = await request.send();
      final resp = await http.Response.fromStream(streamResp);
      _checkError(resp);
      return jsonDecode(resp.body);
    } catch (e) {
      rethrow;
    }
  }

  static Future<bool> deleteImage(String key) async {
    try {
      final resp = await http.delete(Uri.parse('$baseUrl/api/images/$key'));
      _checkError(resp);
      final body = jsonDecode(resp.body);
      if (body['success'] != true) {
        throw Exception(body['error'] ?? '删除失败');
      }
      return true;
    } catch (e) {
      rethrow;
    }
  }

  static Future<String> getSignedUrl(String key, {int expires = 3600}) async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/api/images/$key/signed-url').replace(queryParameters: {'expires': expires.toString()}),
      );
      _checkError(resp);
      final body = jsonDecode(resp.body);
      return body['url'];
    } catch (e) {
      rethrow;
    }
  }

  static Future<String> getPublicUrl(String key) async {
    try {
      final resp = await http.get(Uri.parse('$baseUrl/api/images/$key/public-url'));
      _checkError(resp);
      final body = jsonDecode(resp.body);
      return body['url'];
    } catch (e) {
      rethrow;
    }
  }

  // ============ 错误处理 ============

  static void _checkError(http.Response resp) {
    if (resp.statusCode >= 400) {
      String message = '请求失败 (${resp.statusCode})';
      try {
        final body = jsonDecode(resp.body);
        if (body['error'] != null) {
          message = body['error'];
        }
      } catch (_) {}
      throw ApiException(message, resp.statusCode);
    }
  }

}

class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}