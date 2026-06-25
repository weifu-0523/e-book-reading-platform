import 'package:meta/meta.dart';

/// 阅读引擎状态。
@immutable
sealed class ReaderEngineState {
  const ReaderEngineState();
}

class ReaderEngineUnloaded extends ReaderEngineState {
  const ReaderEngineUnloaded();
}

class ReaderEngineLoading extends ReaderEngineState {
  const ReaderEngineLoading();
}

class ReaderEngineReady extends ReaderEngineState {
  const ReaderEngineReady();
}

class ReaderEngineError extends ReaderEngineState {
  final String message;
  final Object? cause;

  const ReaderEngineError({required this.message, this.cause});
}
