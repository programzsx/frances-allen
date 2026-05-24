     1|import 'package:flutter/foundation.dart';
     2|
     3|/// Global filter state for navigating to question list from bank/tag pages.
     4|class GlobalQuestionFilter {
     5|  static final ValueNotifier<_FilterState> notifier =
     6|      ValueNotifier(const _FilterState(null, null));
     7|
     8|  static void setBank(String? id) {
     9|    notifier.value = _FilterState(id, null);
    10|  }
    11|
    12|  static void setTag(String? id) {
    13|    notifier.value = _FilterState(null, id);
    14|  }
    15|
    16|  static void clear() {
    17|    notifier.value = const _FilterState(null, null);
    18|  }
    19|}
    20|
    21|class _FilterState {
    22|  final String? categoryId;
    23|  final String? tagId;
    24|
    25|  const _FilterState(this.categoryId, this.tagId);
    26|
    27|  @override
    28|  bool operator ==(Object other) =>
    29|      identical(this, other) ||
    30|      other is _FilterState &&
    31|          runtimeType == other.runtimeType &&
    32|          categoryId == other.categoryId &&
    33|          tagId == other.tagId;
    34|
    35|  @override
    36|  int get hashCode => categoryId.hashCode ^ tagId.hashCode;
    37|}
    38|