import 'package:meta/meta.dart';

import '../../core/locator.dart';

@immutable
class ReadingProgress {
  final String bookId;
  final Locator locator;
  final double _percent;
  final DateTime updatedAt;

  ReadingProgress({
    required this.bookId,
    required this.locator,
    required double percent,
    required this.updatedAt,
  }) : _percent = percent.clamp(0.0, 1.0);

  double get percent => _percent;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadingProgress &&
          runtimeType == other.runtimeType &&
          bookId == other.bookId &&
          locator == other.locator &&
          _percent == other._percent &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(bookId, locator, _percent, updatedAt);
}
