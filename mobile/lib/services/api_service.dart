     1|import 'package:http/http.dart' as http;
     2|import 'dart:convert';
     3|import '../models/models.dart';
     4|import 'api_config.dart';
     5|
     6|class ApiService {
     7|  static String get baseUrl => ApiConfig.baseUrl;
     8|
     9|  // 缓存题库数据
    10|  static List<KbBank>? _cachedBanks;
    11|  static List<KbTag>? _cachedTags;
    12|
    13|  static Map<String, String> get _headers => {
    14|        'Content-Type': 'application/json',
    15|      };
    16|
    17|  static void clearCache() {
    18|    _cachedBanks = null;
    19|    _cachedTags = null;
    20|  }
    21|
    22|  // ============ 题库 ============
    23|
    24|  static Future<Map<String, dynamic>> createBank(Map<String, dynamic> data) async {
    25|    try {
    26|      final resp = await http.post(
    27|        Uri.parse('$baseUrl/api/banks'),
    28|        headers: _headers,
    29|        body: jsonEncode(data),
    30|      );
    31|      _checkError(resp);
    32|      clearCache();
    33|      return jsonDecode(resp.body);
    34|    } catch (e) {
    35|      rethrow;
    36|    }
    37|  }
    38|
    39|  static Future<bool> deleteBank(String id) async {
    40|    try {
    41|      final resp = await http.delete(Uri.parse('$baseUrl/api/banks/$id'));
    42|      _checkError(resp);
    43|      final body = jsonDecode(resp.body);
    44|      clearCache();
    45|      if (body['success'] != true) {
    46|        throw Exception(body['error'] ?? '删除失败');
    47|      }
    48|      return true;
    49|    } catch (e) {
    50|      rethrow;
    51|    }
    52|  }
    53|
    54|  static Future<Map<String, dynamic>> updateBank(String id, Map<String, dynamic> data) async {
    55|    try {
    56|      final resp = await http.put(
    57|        Uri.parse('$baseUrl/api/banks/$id'),
    58|        headers: _headers,
    59|        body: jsonEncode(data),
    60|      );
    61|      _checkError(resp);
    62|      clearCache();
    63|      return jsonDecode(resp.body);
    64|    } catch (e) {
    65|      rethrow;
    66|    }
    67|  }
    68|
    69|  static Future<Map<String, dynamic>> pageBanks({
    70|    int currentPage = 1,
    71|    int pageSize = 10,
    72|    String? keyword,
    73|  }) async {
    74|    // 如果缓存存在且请求第一页无关键词，返回缓存
    75|    if (_cachedBanks != null && currentPage == 1 && keyword == null) {
    76|      return {
    77|        'items': _cachedBanks!.map((b) => {
    78|          'id': b.id,
    79|          'name': b.name,
    80|          'create_time': b.createTime,
    81|          'update_time': b.updateTime,
    82|          'parent_id': b.parentId,
    83|        }).toList(),
    84|        'total': _cachedBanks!.length,
    85|        'current_page': 1,
    86|        'page_size': pageSize,
    87|      };
    88|    }
    89|    try {
    90|      final params = <String, String>{
    91|        'current_page': currentPage.toString(),
    92|        'page_size': pageSize.toString(),
    93|      };
    94|      if (keyword != null && keyword.isNotEmpty) params['keyword'] = keyword;
    95|      final resp = await http.get(
    96|        Uri.parse('$baseUrl/api/banks').replace(queryParameters: params),
    97|      );
    98|      _checkError(resp);
    99|      final data = jsonDecode(resp.body);
   100|      // 缓存题库数据
   101|      if (currentPage == 1 && keyword == null) {
   102|        _cachedBanks = (data['items'] as List).map((e) => KbBank.fromJson(e)).toList();
   103|      }
   104|      return data;
   105|    } catch (e) {
   106|      rethrow;
   107|    }
   108|  }
   109|
   110|  static Future<List<KbBank>> getBanks() async {
   111|    if (_cachedBanks != null) return _cachedBanks!;
   112|    final data = await pageBanks(pageSize: 100);
   113|    _cachedBanks = (data['items'] as List).map((e) => KbBank.fromJson(e)).toList();
   114|    return _cachedBanks!;
   115|  }
   116|
   117|  static Future<List<dynamic>> getBankTree() async {
   118|    final resp = await http.get(Uri.parse('$baseUrl/api/banks/tree'));
   119|    _checkError(resp);
   120|    return jsonDecode(resp.body);
   121|  }
   122|
   123|  // ============ 标签 ============
   124|
   125|  static Future<Map<String, dynamic>> createTag(Map<String, dynamic> data) async {
   126|    try {
   127|      final resp = await http.post(
   128|        Uri.parse('$baseUrl/api/tags'),
   129|        headers: _headers,
   130|        body: jsonEncode(data),
   131|      );
   132|      _checkError(resp);
   133|      clearCache();
   134|      return jsonDecode(resp.body);
   135|    } catch (e) {
   136|      rethrow;
   137|    }
   138|  }
   139|
   140|  static Future<bool> deleteTag(String id) async {
   141|    try {
   142|      final resp = await http.delete(Uri.parse('$baseUrl/api/tags/$id'));
   143|      _checkError(resp);
   144|      final body = jsonDecode(resp.body);
   145|      clearCache();
   146|      if (body['success'] != true) {
   147|        throw Exception(body['error'] ?? '删除失败');
   148|      }
   149|      return true;
   150|    } catch (e) {
   151|      rethrow;
   152|    }
   153|  }
   154|
   155|  static Future<Map<String, dynamic>> updateTag(String id, Map<String, dynamic> data) async {
   156|    try {
   157|      final resp = await http.put(
   158|        Uri.parse('$baseUrl/api/tags/$id'),
   159|        headers: _headers,
   160|        body: jsonEncode(data),
   161|      );
   162|      _checkError(resp);
   163|      clearCache();
   164|      return jsonDecode(resp.body);
   165|    } catch (e) {
   166|      rethrow;
   167|    }
   168|  }
   169|
   170|  static Future<Map<String, dynamic>> pageTags({
   171|    int currentPage = 1,
   172|    int pageSize = 10,
   173|    String? keyword,
   174|  }) async {
   175|    try {
   176|      final params = <String, String>{
   177|        'current_page': currentPage.toString(),
   178|        'page_size': pageSize.toString(),
   179|      };
   180|      if (keyword != null && keyword.isNotEmpty) params['keyword'] = keyword;
   181|      final resp = await http.get(
   182|        Uri.parse('$baseUrl/api/tags').replace(queryParameters: params),
   183|      );
   184|      _checkError(resp);
   185|      return jsonDecode(resp.body);
   186|    } catch (e) {
   187|      rethrow;
   188|    }
   189|  }
   190|
   191|  static Future<List<KbTag>> getTags() async {
   192|    if (_cachedTags != null) return _cachedTags!;
   193|    final data = await pageTags(pageSize: 100);
   194|    _cachedTags = (data['items'] as List).map((e) => KbTag.fromJson(e)).toList();
   195|    return _cachedTags!;
   196|  }
   197|
   198|  static Future<Map<String, dynamic>> getTagsByIds(List<String> ids) async {
   199|    try {
   200|      final resp = await http.post(
   201|        Uri.parse('$baseUrl/api/tags/batch'),
   202|        headers: _headers,
   203|        body: jsonEncode({'ids': ids}),
   204|      );
   205|      _checkError(resp);
   206|      return jsonDecode(resp.body);
   207|    } catch (e) {
   208|      rethrow;
   209|    }
   210|  }
   211|
   212|  // ============ 题目 ============
   213|
   214|  static Future<Map<String, dynamic>> createQa(Map<String, dynamic> data) async {
   215|    try {
   216|      final resp = await http.post(
   217|        Uri.parse('$baseUrl/api/qas'),
   218|        headers: _headers,
   219|        body: jsonEncode(data),
   220|      );
   221|      _checkError(resp);
   222|      return jsonDecode(resp.body);
   223|    } catch (e) {
   224|      rethrow;
   225|    }
   226|  }
   227|
   228|  static Future<bool> deleteQa(String id) async {
   229|    try {
   230|      final resp = await http.delete(Uri.parse('$baseUrl/api/qas/$id'));
   231|      _checkError(resp);
   232|      final body = jsonDecode(resp.body);
   233|      if (body['success'] != true) {
   234|        throw Exception(body['error'] ?? '删除失败');
   235|      }
   236|      return true;
   237|    } catch (e) {
   238|      rethrow;
   239|    }
   240|  }
   241|
   242|  static Future<Map<String, dynamic>> updateQa(String id, Map<String, dynamic> data) async {
   243|    try {
   244|      final resp = await http.put(
   245|        Uri.parse('$baseUrl/api/qas/$id'),
   246|        headers: _headers,
   247|        body: jsonEncode(data),
   248|      );
   249|      _checkError(resp);
   250|      return jsonDecode(resp.body);
   251|    } catch (e) {
   252|      rethrow;
   253|    }
   254|  }
   255|
   256|  static Future<Map<String, dynamic>?> getQa(String id) async {
   257|    try {
   258|      final resp = await http.get(Uri.parse('$baseUrl/api/qas/$id'));
   259|      final body = resp.body;
   260|      if (body == 'null') return null;
   261|      _checkError(resp);
   262|      return jsonDecode(body);
   263|    } catch (e) {
   264|      rethrow;
   265|    }
   266|  }
   267|
   268|  static Future<Map<String, dynamic>> pageQas({
   269|    int currentPage = 1,
   270|    int pageSize = 10,
   271|    String? categoryId,
   272|    String? keyword,
   273|    String? tagId,
   274|  }) async {
   275|    try {
   276|      final params = <String, String>{
   277|        'current_page': currentPage.toString(),
   278|        'page_size': pageSize.toString(),
   279|      };
   280|      if (categoryId != null) params['category_id'] = categoryId;
   281|      if (keyword != null && keyword.isNotEmpty) params['keyword'] = keyword;
   282|      if (tagId != null) params['tag_id'] = tagId;
   283|      final resp = await http.get(
   284|        Uri.parse('$baseUrl/api/qas').replace(queryParameters: params),
   285|      );
   286|      _checkError(resp);
   287|      return jsonDecode(resp.body);
   288|    } catch (e) {
   289|      rethrow;
   290|    }
   291|  }
   292|
   293|  static Future<List<dynamic>> randomQas({
   294|    int limit = 10,
   295|    String? categoryId,
   296|  }) async {
   297|    try {
   298|      final params = <String, String>{'limit': limit.toString()};
   299|      if (categoryId != null) params['category_id'] = categoryId;
   300|      final resp = await http.get(
   301|        Uri.parse('$baseUrl/api/qas/random/list').replace(queryParameters: params),
   302|      );
   303|      _checkError(resp);
   304|      return jsonDecode(resp.body);
   305|    } catch (e) {
   306|      rethrow;
   307|    }
   308|  }
   309|
   310|  static Future<List<dynamic>> sequentialQas({
   311|    int limit = 10,
   312|    String? categoryId,
   313|    int? offsetId,
   314|  }) async {
   315|    try {
   316|      final params = <String, String>{'limit': limit.toString()};
   317|      if (categoryId != null) params['category_id'] = categoryId;
   318|      if (offsetId != null) params['offset_id'] = offsetId.toString();
   319|      final resp = await http.get(
   320|        Uri.parse('$baseUrl/api/qas/sequential/list').replace(queryParameters: params),
   321|      );
   322|      _checkError(resp);
   323|      return jsonDecode(resp.body);
   324|    } catch (e) {
   325|      rethrow;
   326|    }
   327|  }
   328|
   329|  /// 获取指定题库的全部题目（自动翻页）
   330|  static Future<List<dynamic>> getAllQasForBank({
   331|    String? categoryId,
   332|  }) async {
   333|    final allItems = <dynamic>[];
   334|    int currentPage = 1;
   335|    int total = 0;
   336|    const pageSize = 100;
   337|
   338|    do {
   339|      final data = await pageQas(currentPage: currentPage, pageSize: pageSize, categoryId: categoryId);
   340|      final items = data['items'] as List;
   341|      allItems.addAll(items);
   342|      total = data['total'];
   343|      currentPage++;
   344|    } while (allItems.length < total);
   345|
   346|    return allItems;
   347|  }
   348|
   349|  static Future<List<dynamic>> wrongQas({
   350|    int limit = 10,
   351|    String? categoryId,
   352|    int minWrong = 1,
   353|  }) async {
   354|    try {
   355|      final params = <String, String>{
   356|        'limit': limit.toString(),
   357|        'min_wrong': minWrong.toString(),
   358|      };
   359|      if (categoryId != null) params['category_id'] = categoryId;
   360|      final resp = await http.get(
   361|        Uri.parse('$baseUrl/api/qas/wrong/list').replace(queryParameters: params),
   362|      );
   363|      _checkError(resp);
   364|      return jsonDecode(resp.body);
   365|    } catch (e) {
   366|      rethrow;
   367|    }
   368|  }
   369|
   370|  static Future<Map<String, dynamic>> getQaTagCounts() async {
   371|    try {
   372|      final resp = await http.get(Uri.parse('$baseUrl/api/qas/tag-counts'));
   373|      _checkError(resp);
   374|      final decoded = jsonDecode(resp.body);
   375|      if (decoded == null) return {};
   376|      return decoded as Map<String, dynamic>;
   377|    } catch (e) {
   378|      rethrow;
   379|    }
   380|  }
   381|
   382|  // ============ 图片（OSS）===========
   383|
   384|  static Future<Map<String, dynamic>> listImages({String prefix = "kb"}) async {
   385|    try {
   386|      final params = <String, String>{};
   387|      if (prefix.isNotEmpty) params['prefix'] = prefix;
   388|      final resp = await http.get(
   389|        Uri.parse('$baseUrl/api/images/list').replace(queryParameters: params),
   390|      );
   391|      _checkError(resp);
   392|      return jsonDecode(resp.body);
   393|    } catch (e) {
   394|      rethrow;
   395|    }
   396|  }
   397|
   398|  static Future<Map<String, dynamic>> uploadImageBytes(
   399|    String filePath,
   400|    List<int> bytes, {
   401|    String prefix = "kb",
   402|    String? fileName,
   403|    Function(double)? onProgress,
   404|  }) async {
   405|    try {
   406|      final queryParams = <String, String>{'prefix': prefix};
   407|      if (fileName != null) queryParams['filename'] = fileName;
   408|      final request = http.MultipartRequest(
   409|        'POST',
   410|        Uri.parse('$baseUrl/api/images/upload').replace(queryParameters: queryParams),
   411|      );
   412|      final filename = fileName ?? filePath.split('/').last;
   413|      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
   414|      final streamResp = await request.send();
   415|      final resp = await http.Response.fromStream(streamResp);
   416|      _checkError(resp);
   417|      return jsonDecode(resp.body);
   418|    } catch (e) {
   419|      rethrow;
   420|    }
   421|  }
   422|
   423|  static Future<Map<String, dynamic>> uploadImage(
   424|    String filePath, {
   425|    String prefix = "kb",
   426|    String? fileName,
   427|  }) async {
   428|    try {
   429|      final queryParams = <String, String>{'prefix': prefix};
   430|      if (fileName != null) queryParams['filename'] = fileName;
   431|      final request = http.MultipartRequest(
   432|        'POST',
   433|        Uri.parse('$baseUrl/api/images/upload').replace(queryParameters: queryParams),
   434|      );
   435|      final filename = fileName ?? filePath.split('/').last;
   436|      request.files.add(await http.MultipartFile.fromPath('file', filePath, filename: filename));
   437|      final streamResp = await request.send();
   438|      final resp = await http.Response.fromStream(streamResp);
   439|      _checkError(resp);
   440|      return jsonDecode(resp.body);
   441|    } catch (e) {
   442|      rethrow;
   443|    }
   444|  }
   445|
   446|  static Future<bool> deleteImage(String key) async {
   447|    try {
   448|      final resp = await http.delete(Uri.parse('$baseUrl/api/images/$key'));
   449|      _checkError(resp);
   450|      final body = jsonDecode(resp.body);
   451|      if (body['success'] != true) {
   452|        throw Exception(body['error'] ?? '删除失败');
   453|      }
   454|      return true;
   455|    } catch (e) {
   456|      rethrow;
   457|    }
   458|  }
   459|
   460|  static Future<String> getSignedUrl(String key, {int expires = 3600}) async {
   461|    try {
   462|      final resp = await http.get(
   463|        Uri.parse('$baseUrl/api/images/$key/signed-url').replace(queryParameters: {'expires': expires.toString()}),
   464|      );
   465|      _checkError(resp);
   466|      final body = jsonDecode(resp.body);
   467|      return body['url'];
   468|    } catch (e) {
   469|      rethrow;
   470|    }
   471|  }
   472|
   473|  static Future<String> getPublicUrl(String key) async {
   474|    try {
   475|      final resp = await http.get(Uri.parse('$baseUrl/api/images/$key/public-url'));
   476|      _checkError(resp);
   477|      final body = jsonDecode(resp.body);
   478|      return body['url'];
   479|    } catch (e) {
   480|      rethrow;
   481|    }
   482|  }
   483|
   484|  // ============ 错误处理 ============
   485|
   486|  static void _checkError(http.Response resp) {
   487|    if (resp.statusCode >= 400) {
   488|      String message = '请求失败 (${resp.statusCode})';
   489|      try {
   490|        final body = jsonDecode(resp.body);
   491|        if (body['error'] != null) {
   492|          message = body['error'];
   493|        }
   494|      } catch (_) {}
   495|      throw ApiException(message, resp.statusCode);
   496|    }
   497|  }
   498|
   499|}
   500|
   501|class ApiException implements Exception {
   502|  final String message;
   503|  final int statusCode;
   504|
   505|  ApiException(this.message, this.statusCode);
   506|
   507|  @override
   508|  String toString() => message;
   509|}