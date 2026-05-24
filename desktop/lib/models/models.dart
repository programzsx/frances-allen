     1|class KbBank {
     2|  final String id;
     3|  final String createTime;
     4|  final String updateTime;
     5|  final String name;
     6|  final String? parentId;
     7|  List<KbBank> children;
     8|
     9|  KbBank({
    10|    required this.id,
    11|    required this.createTime,
    12|    required this.updateTime,
    13|    required this.name,
    14|    this.parentId,
    15|    this.children = const [],
    16|  });
    17|
    18|  factory KbBank.fromJson(Map<String, dynamic> json) {
    19|    return KbBank(
    20|      id: json['id'] ?? '',
    21|      createTime: json['create_time'] ?? '',
    22|      updateTime: json['update_time'] ?? '',
    23|      name: json['name'] ?? '',
    24|      parentId: json['parent_id'],
    25|      children: (json['children'] as List<dynamic>?)
    26|              ?.map((e) => KbBank.fromJson(e))
    27|              .toList() ??
    28|          [],
    29|    );
    30|  }
    31|}
    32|
    33|class KbTag {
    34|  final String id;
    35|  final String createTime;
    36|  final String updateTime;
    37|  final String name;
    38|
    39|  KbTag({
    40|    required this.id,
    41|    required this.createTime,
    42|    required this.updateTime,
    43|    required this.name,
    44|  });
    45|
    46|  factory KbTag.fromJson(Map<String, dynamic> json) {
    47|    return KbTag(
    48|      id: json['id'] ?? '',
    49|      createTime: json['create_time'] ?? '',
    50|      updateTime: json['update_time'] ?? '',
    51|      name: json['name'] ?? '',
    52|    );
    53|  }
    54|}
    55|
    56|class KbQa {
    57|  final String id;
    58|  final String createTime;
    59|  final String updateTime;
    60|  final String question;
    61|  final List<String> answer;
    62|  final String? imageUrl;
    63|  final int total;
    64|  final int right;
    65|  final int wrong;
    66|  final int randomInt;
    67|  final String? categoryId;
    68|  final List<String>? tagId;
    69|
    70|  KbQa({
    71|    required this.id,
    72|    required this.createTime,
    73|    required this.updateTime,
    74|    required this.question,
    75|    required this.answer,
    76|    this.imageUrl,
    77|    this.total = 0,
    78|    this.right = 0,
    79|    this.wrong = 0,
    80|    this.randomInt = 0,
    81|    this.categoryId,
    82|    this.tagId,
    83|  });
    84|
    85|  factory KbQa.fromJson(Map<String, dynamic> json) {
    86|    return KbQa(
    87|      id: json['id'] ?? '',
    88|      createTime: json['create_time'] ?? '',
    89|      updateTime: json['update_time'] ?? '',
    90|      question: json['question'] ?? '',
    91|      answer: (json['answer'] as List<dynamic>?)
    92|              ?.map((e) => e.toString())
    93|              .toList() ??
    94|          [],
    95|      imageUrl: json['image_url'],
    96|      total: json['total'] ?? 0,
    97|      right: json['right'] ?? 0,
    98|      wrong: json['wrong'] ?? 0,
    99|      randomInt: json['random_int'] ?? 0,
   100|      categoryId: json['category_id'],
   101|      tagId: (json['tag_id'] as List<dynamic>?)
   102|          ?.map((e) => e.toString())
   103|          .toList(),
   104|    );
   105|  }
   106|
   107|  double get accuracy => total == 0 ? 0 : right / total;
   108|}
   109|
   110|class PageResult<T> {
   111|  final List<T> items;
   112|  final int total;
   113|  final int currentPage;
   114|  final int pageSize;
   115|
   116|  PageResult({
   117|    required this.items,
   118|    required this.total,
   119|    required this.currentPage,
   120|    required this.pageSize,
   121|  });
   122|}
   123|