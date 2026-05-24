import 'package:flutter/foundation.dart';

/// Global filter state for navigating to question list from bank/tag pages.
class GlobalQuestionFilter {
  static final ValueNotifier<_FilterState> notifier =
      ValueNotifier(const _FilterState(null, null));

  static void setBank(String? id) {
    notifier.value = _FilterState(id, null);
  }

  static void setTag(String? id) {
    notifier.value = _FilterState(null, id);
  }

  static void clear() {
    notifier.value = const _FilterState(null, null);
  }
}

class _FilterState {
  final String? categoryId;
  final String? tagId;

  const _FilterState(this.categoryId, this.tagId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _FilterState &&
          runtimeType == other.runtimeType &&
          categoryId == other.categoryId &&
          tagId == other.tagId;

  @override
  int get hashCode => categoryId.hashCode ^ tagId.hashCode;
}
