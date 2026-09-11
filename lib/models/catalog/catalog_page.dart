import 'package:equatable/equatable.dart';

class CatalogPage<T> extends Equatable {
  const CatalogPage({required this.items, this.nextCursor});

  final List<T> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;

  @override
  List<Object?> get props => [items, nextCursor];
}
