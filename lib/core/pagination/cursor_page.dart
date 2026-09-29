class CursorPage<T> {
  const CursorPage({required this.items, this.nextCursor});

  final List<T> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;

  factory CursorPage.fromJson(
    dynamic data,
    T Function(Map<String, dynamic> json) parseItem,
  ) {
    if (data is List) {
      return CursorPage(
        items: data.whereType<Map<String, dynamic>>().map(parseItem).toList(),
      );
    }
    final map = data is Map<String, dynamic> ? data : <String, dynamic>{};
    final rawItems = map['items'] as List<dynamic>? ?? const [];
    return CursorPage(
      items: rawItems.whereType<Map<String, dynamic>>().map(parseItem).toList(),
      nextCursor: map['nextCursor'] as String?,
    );
  }
}
