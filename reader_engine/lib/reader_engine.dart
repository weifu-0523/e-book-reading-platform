/// reader_engine — 阅读引擎抽象层。
///
/// 永远不依赖 Flutter，所有抽象和模型在此。
library reader_engine;

export 'core/locator.dart';
export 'core/typography_settings.dart';
export 'core/book_ref.dart';
export 'rendering/pagination_model.dart';
export 'engine/reader_engine_state.dart';
export 'navigation/toc.dart';

const String readerEngineLibraryVersion = '0.1.0';
