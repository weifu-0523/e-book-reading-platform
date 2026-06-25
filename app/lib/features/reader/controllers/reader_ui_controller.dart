import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 阅读 UI 的瞬时状态（不持久化）：chrome 显隐、抽屉、排版面板。
@immutable
class ReaderUiState {
  final bool chromeVisible;
  final bool tocDrawerOpen;
  final bool typographyPanelOpen;

  const ReaderUiState({
    this.chromeVisible = false,
    this.tocDrawerOpen = false,
    this.typographyPanelOpen = false,
  });

  ReaderUiState copyWith({
    bool? chromeVisible,
    bool? tocDrawerOpen,
    bool? typographyPanelOpen,
  }) {
    return ReaderUiState(
      chromeVisible: chromeVisible ?? this.chromeVisible,
      tocDrawerOpen: tocDrawerOpen ?? this.tocDrawerOpen,
      typographyPanelOpen: typographyPanelOpen ?? this.typographyPanelOpen,
    );
  }
}

class ReaderUiController extends StateNotifier<ReaderUiState> {
  ReaderUiController() : super(const ReaderUiState());

  void toggleChrome() => state = state.copyWith(chromeVisible: !state.chromeVisible);
  void openTocDrawer() => state = state.copyWith(tocDrawerOpen: true);
  void closeTocDrawer() => state = state.copyWith(tocDrawerOpen: false);
  void openTypographyPanel() => state = state.copyWith(typographyPanelOpen: true);
  void closeTypographyPanel() => state = state.copyWith(typographyPanelOpen: false);
}

final readerUiControllerProvider =
    StateNotifierProvider<ReaderUiController, ReaderUiState>((ref) {
  return ReaderUiController();
});
