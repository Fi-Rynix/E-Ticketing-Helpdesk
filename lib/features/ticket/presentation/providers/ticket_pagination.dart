import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Generic pagination state for cursor-based pagination
class PaginationState<T> {
  final List<T> items;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final DateTime? cursor; // created_at of last loaded item

  const PaginationState({
    this.items = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.cursor,
  });

  PaginationState<T> copyWith({
    List<T>? items,
    bool? isLoading,
    bool? hasMore,
    String? error,
    DateTime? cursor,
  }) {
    return PaginationState<T>(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      cursor: cursor ?? this.cursor,
    );
  }
}

class PaginationNotifier<T> extends StateNotifier<PaginationState<T>> {
  final Future<List<T>> Function({DateTime? cursor, int limit}) fetcher;
  final int pageSize;

  PaginationNotifier({
    required this.fetcher,
    this.pageSize = 20,
  }) : super(const PaginationState());

  /// Load first page (replaces existing items)
  Future<void> loadFirstPage() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final items = await fetcher(cursor: null, limit: pageSize);
      state = PaginationState<T>(
        items: items,
        isLoading: false,
        hasMore: items.length >= pageSize,
        cursor: items.isNotEmpty ? _getCursor(items.last) : null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Load next page (appends to existing items)
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final items = await fetcher(cursor: state.cursor, limit: pageSize);
      final allItems = [...state.items, ...items];
      state = PaginationState<T>(
        items: allItems,
        isLoading: false,
        hasMore: items.length >= pageSize,
        cursor: items.isNotEmpty ? _getCursor(items.last) : null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Refresh from start
  Future<void> refresh() => loadFirstPage();

  /// Extract cursor from item (override in subclass if needed)
  DateTime? _getCursor(T item) {
    // Items must implement a 'createdAt' field by convention
    try {
      final dynamic d = item;
      return d.createdAt as DateTime?;
    } catch (_) {
      return null;
    }
  }
}