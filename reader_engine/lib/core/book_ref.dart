import 'package:meta/meta.dart';

/// 书籍格式枚举。
///
/// 与 M1 `app/lib/data/models/book.dart` 中的 `BookFormat` 同构；
/// 这里在 reader_engine 重新定义以避免 reader_engine 反向依赖 app 包。
enum BookFormat {
  epub,
  pdf,
}

/// 渲染层对书籍的轻量引用。
///
/// 不持有完整 `Book` 聚合根（后者还含阅读进度、笔记聚合等不属于渲染职责的数据）。
/// reader_engine 只关心：哪个文件、什么格式、什么标题。
@immutable
class BookRef {
  final String id;
  final String title;
  final BookFormat format;
  final String filePath;

  const BookRef({
    required this.id,
    required this.title,
    required this.format,
    required this.filePath,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is BookRef && id == other.id);

  @override
  int get hashCode => id.hashCode;
}
