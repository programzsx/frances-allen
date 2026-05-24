class KbBank {
  final String id;
  final String createTime;
  final String updateTime;
  final String name;
  final String? parentId;
  List<KbBank> children;

  KbBank({
    required this.id,
    required this.createTime,
    required this.updateTime,
    required this.name,
    this.parentId,
    this.children = const [],
  });

  factory KbBank.fromJson(Map<String, dynamic> json) {
    return KbBank(
      id: json['id'] ?? '',
      createTime: json['create_time'] ?? '',
      updateTime: json['update_time'] ?? '',
      name: json['name'] ?? '',
      parentId: json['parent_id'],
      children: (json['children'] as List<dynamic>?)
              ?.map((e) => KbBank.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class KbTag {
  final String id;
  final String createTime;
  final String updateTime;
  final String name;

  KbTag({
    required this.id,
    required this.createTime,
    required this.updateTime,
    required this.name,
  });

  factory KbTag.fromJson(Map<String, dynamic> json) {
    return KbTag(
      id: json['id'] ?? '',
      createTime: json['create_time'] ?? '',
      updateTime: json['update_time'] ?? '',
      name: json['name'] ?? '',
    );
  }
}

class KbQa {
  final String id;
  final String createTime;
  final String updateTime;
  final String question;
  final List<String> answer;
  final String? imageUrl;
  final int total;
  final int right;
  final int wrong;
  final int randomInt;
  final String? categoryId;
  final List<String>? tagId;

  KbQa({
    required this.id,
    required this.createTime,
    required this.updateTime,
    required this.question,
    required this.answer,
    this.imageUrl,
    this.total = 0,
    this.right = 0,
    this.wrong = 0,
    this.randomInt = 0,
    this.categoryId,
    this.tagId,
  });

  factory KbQa.fromJson(Map<String, dynamic> json) {
    return KbQa(
      id: json['id'] ?? '',
      createTime: json['create_time'] ?? '',
      updateTime: json['update_time'] ?? '',
      question: json['question'] ?? '',
      answer: (json['answer'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      imageUrl: json['image_url'],
      total: json['total'] ?? 0,
      right: json['right'] ?? 0,
      wrong: json['wrong'] ?? 0,
      randomInt: json['random_int'] ?? 0,
      categoryId: json['category_id'],
      tagId: (json['tag_id'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
    );
  }

  double get accuracy => total == 0 ? 0 : right / total;
}

class PageResult<T> {
  final List<T> items;
  final int total;
  final int currentPage;
  final int pageSize;

  PageResult({
    required this.items,
    required this.total,
    required this.currentPage,
    required this.pageSize,
  });
}
