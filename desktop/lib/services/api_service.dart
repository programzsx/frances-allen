     1|import 'package:http/http.dart' as http;
     2|import 'dart:convert';
     3|import '../models/models.dart';
     4|
     5|class ApiService {
     6|  static const String baseUrl = 'http://8.160.174.178:8000';
     7|
     8|  // 缓存题库数据
     9|  static List<KbBank>? _cachedBanks;
    10|  static List<KbTag>? _cachedTags;
    11|
    12|  static Map<String, String> get _headers => {
    13|        'Content-Type': 'application/json',
    14|      };
    15|
    16|  static void clearCache() {
    17|    _cachedBanks = null;
    18|    _cachedTags = null;
    19|  }
    20|
    21|  // ============ 题库 ============
    22|
    23|  static Future<Map<String, dynamic>> createBank(Map<String, dynamic> data) async {
    24|    try {
    25|      final resp = await http.post(
    26|        Uri.parse('$baseUrl/api/banks'),
    27|        headers: _headers,
    28|        body: jsonEncode(data),
    29|      );
    30|      _checkError(resp);
    31|      clearCache();
    32|      return jsonDecode(resp.body);
    33|    } catch (e) {
    34|      rethrow;
    35|    }
    36|  }
    37|
    38|  static Future<bool> deleteBank(String id) async {
    39|    try {
    40|      final resp = await http.delete(Uri.parse('$baseUrl/api/banks/$id'));
    41|      _checkError(resp);
    42|      final body = jsonDecode(resp.body);
    43|      clearCache();
    44|      if (body['success'] != true) {
    45|        throw Exception(body['error'] ?? '删除失败');
    46|      }
    47|      return true;
    48|    } catch (e) {
    49|      rethrow;
    50|    }
    51|  }
    52|
    53|  static Future<Map<String, dynamic>> updateBank(String id, Map<String, dynamic> data) async {
    54|    try {
    55|      final resp = await http.put(
    56|        Uri.parse('$baseUrl/api/banks/$id'),
    57|        headers: _headers,
    58|        body: jsonEncode(data),
    59|      );
    60|      _checkError(resp);
    61|      clearCache();
    62|      return jsonDecode(resp.body);
    63|    } catch (e) {
    64|      rethrow;
    65|    }
    66|  }
    67|
    68|  static Future<Map<String, dynamic>> pageBanks({
    69|    int currentPage = 1,
    70|    int pageSize = 10,
    71|    String? keyword,
    72|  }) async {
    73|    // 如果缓存存在且请求第一页无关键词，返回缓存
    74|    if (_cachedBanks != null && currentPage == 1 && keyword == null) {
    75|      return {
    76|        'items': _cachedBanks!.map((b) => {
    77|          'id': b.id,
    78|          'name': b.name,
    79|          'create_time': b.createTime,
    80|          'update_time': b.updateTime,
    81|          'parent_id': b.parentId,
    82|        }).toList(),
    83|        'total': _cachedBanks!.length,
    84|        'current_page': 1,
    85|        'page_size': pageSize,
    86|      };
    87|    }
    88|    try {
    89|      final params = <String, String>{
    90|        'current_page': currentPage.toString(),
    91|        'page_size': pageSize.toString(),
    92|      };
    93|      if (keyword != null && keyword.isNotEmpty) params['keyword'] = keyword;
    94|      final resp = await http.get(
    95|        Uri.parse('$baseUrl/api/banks').replace(queryParameters: params),
    96|      );
    97|      _checkError(resp);
    98|      final data = jsonDecode(resp.body);
    99|      // 缓存题库数据
   100|      if (currentPage == 1 && keyword == null) {
   101|        _cachedBanks = (data['items'] as List).map((e) => KbBank.fromJson(e)).toList();
   102|      }
   103|      return data;
   104|    } catch (e) {
   105|      rethrow;
   106|    }
   107|  }
   108|
   109|  static Future<List<KbBank>> getBanks() async {
   110|    if (_cachedBanks != null) return _cachedBanks!;
   111|    final data = await pageBanks(pageSize: 100);
   112|    _cachedBanks = (data['items'] as List).map((e) => KbBank.fromJson(e)).toList();
   113|    return _cachedBanks!;
   114|  }
   115|
   116|  static Future<List<dynamic>> getBankTree() async {
   117|    final resp = await http.get(Uri.parse('$baseUrl/api/banks/tree'));
   118|    _checkError(resp);
   119|    return jsonDecode(resp.body);
   120|  }
   121|
   122|  // ============ 标签 ============
   123|
   124|  static Future<Map<String, dynamic>> createTag(Map<String, dynamic> data) async {
   125|    try {
   126|      final resp = await http.post(
   127|        Uri.parse('$baseUrl/api/tags'),
   128|        headers: _headers,
   129|        body: jsonEncode(data),
   130|      );
   131|      _checkError(resp);
   132|      clearCache();
   133|      return jsonDecode(resp.body);
   134|    } catch (e) {
   135|      rethrow;
   136|    }
   137|  }
   138|
   139|  static Future<bool> deleteTag(String id) async {
   140|    try {
   141|      final resp = await http.delete(Uri.parse('$baseUrl/api/tags/$id'));
   142|      _checkError(resp);
   143|      final body = jsonDecode(resp.body);
   144|      clearCache();
   145|      if (body['success'] != true) {
   146|        throw Exception(body['error'] ?? '删除失败');
   147|      }
   148|      return true;
   149|    } catch (e) {
   150|      rethrow;
   151|    }
   152|  }
   153|
   154|  static Future<Map<String, dynamic>> updateTag(String id, Map<String, dynamic> data) async {
   155|    try {
   156|      final resp = await http.put(
   157|        Uri.parse('$baseUrl/api/tags/$id'),
   158|        headers: _headers,
   159|        body: jsonEncode(data),
   160|      );
   161|      _checkError(resp);
   162|      clearCache();
   163|      return jsonDecode(resp.body);
   164|    } catch (e) {
   165|      rethrow;
   166|    }
   167|  }
   168|
   169|  static Future<Map<String, dynamic>> pageTags({
   170|    int currentPage = 1,
   171|    int pageSize = 10,
   172|    String? keyword,
   173|  }) async {
   174|    try {
   175|      final params = <String, String>{
   176|        'current_page': currentPage.toString(),
   177|        'page_size': pageSize.toString(),
   178|      };
   179|      if (keyword != null && keyword.isNotEmpty) params['keyword'] = keyword;
   180|      final resp = await http.get(
   181|        Uri.parse('$baseUrl/api/tags').replace(queryParameters: params),
   182|      );
   183|      _checkError(resp);
   184|      return jsonDecode(resp.body);
   185|    } catch (e) {
   186|      rethrow;
   187|    }
   188|  }
   189|
   190|  static Future<List<KbTag>> getTags() async {
   191|    if (_cachedTags != null) return _cachedTags!;
   192|    final data = await pageTags(pageSize: 100);
   193|    _cachedTags = (data['items'] as List).map((e) => KbTag.fromJson(e)).toList();
   194|    return _cachedTags!;
   195|  }
   196|
   197|  static Future<Map<String, dynamic>> getTagsByIds(List<String> ids) async {
   198|    try {
   199|      final resp = await http.post(
   200|        Uri.parse('$baseUrl/api/tags/batch'),
   201|        headers: _headers,
   202|        body: jsonEncode({'ids': ids}),
   203|      );
   204|      _checkError(resp);
   205|      return jsonDecode(resp.body);
   206|    } catch (e) {
   207|      rethrow;
   208|    }
   209|  }
   210|
   211|  // ============ 题目 ============
   212|
   213|  static Future<Map<String, dynamic>> createQa(Map<String, dynamic> data) async {
   214|    try {
   215|      final resp = await http.post(
   216|        Uri.parse('$baseUrl/api/qas'),
   217|        headers: _headers,
   218|        body: jsonEncode(data),
   219|      );
   220|      _checkError(resp);
   221|      return jsonDecode(resp.body);
   222|    } catch (e) {
   223|      rethrow;
   224|    }
   225|  }
   226|
   227|  static Future<bool> deleteQa(String id) async {
   228|    try {
   229|      final resp = await http.delete(Uri.parse('$baseUrl/api/qas/$id'));
   230|      _checkError(resp);
   231|      final body = jsonDecode(resp.body);
   232|      if (body['success'] != true) {
   233|        throw Exception(body['error'] ?? '删除失败');
   234|      }
   235|      return true;
   236|    } catch (e) {
   237|      rethrow;
   238|    }
   239|  }
   240|
   241|  static Future<Map<String, dynamic>> updateQa(String id, Map<String, dynamic> data) async {
   242|    try {
   243|      final resp = await http.put(
   244|        Uri.parse('$baseUrl/api/qas/$id'),
   245|        headers: _headers,
   246|        body: jsonEncode(data),
   247|      );
   248|      _checkError(resp);
   249|      return jsonDecode(resp.body);
   250|    } catch (e) {
   251|      rethrow;
   252|    }
   253|  }
   254|
   255|  static Future<Map<String, dynamic>?> getQa(String id) async {
   256|    try {
   257|      final resp = await http.get(Uri.parse('$baseUrl/api/qas/$id'));
   258|      final body = resp.body;
   259|      if (body == 'null') return null;
   260|      _checkError(resp);
   261|      return jsonDecode(body);
   262|    } catch (e) {
   263|      rethrow;
   264|    }
   265|  }
   266|
   267|  static Future<Map<String, dynamic>> pageQas({
   268|    int currentPage = 1,
   269|    int pageSize = 10,
   270|    String? categoryId,
   271|    String? keyword,
   272|    String? tagId,
   273|  }) async {
   274|    try {
   275|      final params = <String, String>{
   276|        'current_page': currentPage.toString(),
   277|        'page_size': pageSize.toString(),
   278|      };
   279|      if (categoryId != null) params['category_id'] = categoryId;
   280|      if (keyword != null && keyword.isNotEmpty) params['keyword'] = keyword;
   281|      if (tagId != null) params['tag_id'] = tagId;
   282|      final resp = await http.get(
   283|        Uri.parse('$baseUrl/api/qas').replace(queryParameters: params),
   284|      );
   285|      _checkError(resp);
   286|      return jsonDecode(resp.body);
   287|    } catch (e) {
   288|      rethrow;
   289|    }
   290|  }
   291|
   292|  static Future<List<dynamic>> randomQas({
   293|    int limit = 10,
   294|    String? categoryId,
   295|  }) async {
   296|    try {
   297|      final params = <String, String>{'limit': limit.toString()};
   298|      if (categoryId != null) params['category_id'] = categoryId;
   299|      final resp = await http.get(
   300|        Uri.parse('$baseUrl/api/qas/random/list').replace(queryParameters: params),
   301|      );
   302|      _checkError(resp);
   303|      return jsonDecode(resp.body);
   304|    } catch (e) {
   305|      rethrow;
   306|    }
   307|  }
   308|
   309|  static Future<List<dynamic>> sequentialQas({
   310|    int limit = 10,
   311|    String? categoryId,
   312|    int? offsetId,
   313|  }) async {
   314|    try {
   315|      final params = <String, String>{'limit': limit.toString()};
   316|      if (categoryId != null) params['category_id'] = categoryId;
   317|      if (offsetId != null) params['offset_id'] = offsetId.toString();
   318|      final resp = await http.get(
   319|        Uri.parse('$baseUrl/api/qas/sequential/list').replace(queryParameters: params),
   320|      );
   321|      _checkError(resp);
   322|      return jsonDecode(resp.body);
   323|    } catch (e) {
   324|      rethrow;
   325|    }
   326|  }
   327|
   328|  static Future<List<dynamic>> wrongQas({
   329|    int limit = 10,
   330|    String? categoryId,
   331|    int minWrong = 1,
   332|  }) async {
   333|    try {
   334|      final params = <String, String>{
   335|        'limit': limit.toString(),
   336|        'min_wrong': minWrong.toString(),
   337|      };
   338|      if (categoryId != null) params['category_id'] = categoryId;
   339|      final resp = await http.get(
   340|        Uri.parse('$baseUrl/api/qas/wrong/list').replace(queryParameters: params),
   341|      );
   342|      _checkError(resp);
   343|      return jsonDecode(resp.body);
   344|    } catch (e) {
   345|      rethrow;
   346|    }
   347|  }
   348|
   349|  static Future<Map<String, dynamic>> getQaTagCounts() async {
   350|    try {
   351|      final resp = await http.get(Uri.parse('$baseUrl/api/qas/tag-counts'));
   352|      _checkError(resp);
   353|      final decoded = jsonDecode(resp.body);
   354|      if (decoded == null) return {};
   355|      return decoded as Map<String, dynamic>;
   356|    } catch (e) {
   357|      rethrow;
   358|    }
   359|  }
   360|
   361|  // ============ 图片（OSS）===========
   362|
   363|  static Future<Map<String, dynamic>> listImages({String prefix = "kb"}) async {
   364|    try {
   365|      final params = <String, String>{};
   366|      if (prefix.isNotEmpty) params['prefix'] = prefix;
   367|      final resp = await http.get(
   368|        Uri.parse('$baseUrl/api/images/list').replace(queryParameters: params),
   369|      );
   370|      _checkError(resp);
   371|      return jsonDecode(resp.body);
   372|    } catch (e) {
   373|      rethrow;
   374|    }
   375|  }
   376|
   377|  static Future<Map<String, dynamic>> uploadImageBytes(
   378|    String filePath,
   379|    List<int> bytes, {
   380|    String prefix = "kb",
   381|    String? fileName,
   382|    Function(double)? onProgress,
   383|  }) async {
   384|    try {
   385|      final queryParams = <String, String>{'prefix': prefix};
   386|      if (fileName != null) queryParams['filename'] = fileName;
   387|      final request = http.MultipartRequest(
   388|        'POST',
   389|        Uri.parse('$baseUrl/api/images/upload').replace(queryParameters: queryParams),
   390|      );
   391|      final filename = fileName ?? filePath.split('/').last;
   392|      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
   393|      final streamResp = await request.send();
   394|      final resp = await http.Response.fromStream(streamResp);
   395|      _checkError(resp);
   396|      return jsonDecode(resp.body);
   397|    } catch (e) {
   398|      rethrow;
   399|    }
   400|  }
   401|
   402|  static Future<Map<String, dynamic>> uploadImage(
   403|    String filePath, {
   404|    String prefix = "kb",
   405|    String? fileName,
   406|  }) async {
   407|    try {
   408|      final queryParams = <String, String>{'prefix': prefix};
   409|      if (fileName != null) queryParams['filename'] = fileName;
   410|      final request = http.MultipartRequest(
   411|        'POST',
   412|        Uri.parse('$baseUrl/api/images/upload').replace(queryParameters: queryParams),
   413|      );
   414|      final filename = fileName ?? filePath.split('/').last;
   415|      request.files.add(await http.MultipartFile.fromPath('file', filePath, filename: filename));
   416|      final streamResp = await request.send();
   417|      final resp = await http.Response.fromStream(streamResp);
   418|      _checkError(resp);
   419|      return jsonDecode(resp.body);
   420|    } catch (e) {
   421|      rethrow;
   422|    }
   423|  }
   424|
   425|  static Future<bool> deleteImage(String key) async {
   426|    try {
   427|      final resp = await http.delete(Uri.parse('$baseUrl/api/images/$key'));
   428|      _checkError(resp);
   429|      final body = jsonDecode(resp.body);
   430|      if (body['success'] != true) {
   431|        throw Exception(body['error'] ?? '删除失败');
   432|      }
   433|      return true;
   434|    } catch (e) {
   435|      rethrow;
   436|    }
   437|  }
   438|
   439|  static Future<String> getSignedUrl(String key, {int expires = 3600}) async {
   440|    try {
   441|      final resp = await http.get(
   442|        Uri.parse('$baseUrl/api/images/$key/signed-url').replace(queryParameters: {'expires': expires.toString()}),
   443|      );
   444|      _checkError(resp);
   445|      final body = jsonDecode(resp.body);
   446|      return body['url'];
   447|    } catch (e) {
   448|      rethrow;
   449|    }
   450|  }
   451|
   452|  static Future<String> getPublicUrl(String key) async {
   453|    try {
   454|      final resp = await http.get(Uri.parse('$baseUrl/api/images/$key/public-url'));
   455|      _checkError(resp);
   456|      final body = jsonDecode(resp.body);
   457|      return body['url'];
   458|    } catch (e) {
   459|      rethrow;
   460|    }
   461|  }
   462|
   463|  // ============ 错误处理 ============
   464|
   465|  static void _checkError(http.Response resp) {
   466|    if (resp.statusCode >= 400) {
   467|      String message = '请求失败 (${resp.statusCode})';
   468|      try {
   469|        final body = jsonDecode(resp.body);
   470|        if (body['error'] != null) {
   471|          message = body['error'];
   472|        }
   473|      } catch (_) {}
   474|      throw ApiException(message, resp.statusCode);
   475|    }
   476|  }
   477|
   478|}
   479|
   480|class ApiException implements Exception {
   481|  final String message;
   482|  final int statusCode;
   483|
   484|  ApiException(this.message, this.statusCode);
   485|
   486|  @override
   487|  String toString() => message;
   488|}