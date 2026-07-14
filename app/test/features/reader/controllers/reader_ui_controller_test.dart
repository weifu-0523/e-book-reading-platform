// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/reader/controllers/fullscreen_controller.dart';
import 'package:zhiyue/features/reader/controllers/reader_ui_controller.dart';

void main() {
  group('ReaderUiState.defaults', () {
    test('chromeVisible default true on Windows', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final s = ReaderUiState.defaults();
      expect(s.chromeVisible, true,
          reason: 'desktop readers should show chrome AppBar by default');
    });

    test('chromeVisible default true on macOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final s = ReaderUiState.defaults();
      expect(s.chromeVisible, true);
    });

    test('chromeVisible default true on Linux', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final s = ReaderUiState.defaults();
      expect(s.chromeVisible, true);
    });

    test('chromeVisible default false on Android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final s = ReaderUiState.defaults();
      expect(s.chromeVisible, false,
          reason:
              'mobile uses fullscreen mode (T9) instead of persistent chrome');
    });

    test('chromeVisible default false on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final s = ReaderUiState.defaults();
      expect(s.chromeVisible, false);
    });

    test('other fields retain default values', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final s = ReaderUiState.defaults();
      expect(s.tocDrawerOpen, false);
      expect(s.typographyPanelOpen, false);
    });
  });

  group('ReaderUiController.hideChrome', () {
    // 用 Android 作为 mobile 锚点：chromeVisible 默认 false，符合 UX-B
    // mobile 默认隐藏的契约。NoopFullscreenController 避免插件原生通道。
    ReaderUiController buildMobileController() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      return ReaderUiController(
          fullscreenController: const NoopFullscreenController());
    }

    test('hideChrome sets chromeVisible to false', () {
      final controller = buildMobileController();
      controller.toggleChrome();
      expect(controller.state.chromeVisible, isTrue,
          reason: 'sanity: toggle from default false should reveal chrome');

      controller.hideChrome();
      expect(controller.state.chromeVisible, isFalse);
    });

    test('hideChrome is no-op when already hidden', () {
      final controller = buildMobileController();
      expect(controller.state.chromeVisible, isFalse,
          reason: 'mobile default should start hidden');

      controller.hideChrome();
      expect(controller.state.chromeVisible, isFalse,
          reason: 'idempotent: already-hidden state must not throw or flip');
    });

    test('toggleChrome flips chromeVisible state', () {
      final controller = buildMobileController();
      final initial = controller.state.chromeVisible;

      controller.toggleChrome();
      expect(controller.state.chromeVisible, equals(!initial));

      controller.toggleChrome();
      expect(controller.state.chromeVisible, equals(initial));
    });

    test('showChrome idempotently sets chromeVisible=true', () {
      // Desktop default: chromeVisible=true. toggleChrome would flip to false.
      // showChrome must keep it true regardless of starting state.
      final desktop = ReaderUiController(
        fullscreenController: const NoopFullscreenController(),
        initialState: ReaderUiState.defaultsForPlatform(),
      );
      expect(desktop.state.chromeVisible, isTrue,
          reason: 'desktop default should be visible');

      desktop.showChrome();
      expect(desktop.state.chromeVisible, isTrue,
          reason: 'showChrome on visible state must remain visible');

      // After hideChrome, showChrome must restore to true.
      desktop.hideChrome();
      expect(desktop.state.chromeVisible, isFalse);

      desktop.showChrome();
      expect(desktop.state.chromeVisible, isTrue,
          reason: 'showChrome on hidden state must restore to visible');

      // Idempotent: calling twice doesn't flip.
      desktop.showChrome();
      expect(desktop.state.chromeVisible, isTrue);
    });
  });

  group('ReaderUiState equality + hashCode contract (I1)', () {
    test('two states with same field values are equal', () {
      final a = ReaderUiState(
        chromeVisible: true,
        tocDrawerOpen: false,
        typographyPanelOpen: false,
        activeDrawerTab: DrawerTab.toc,
        tocSidebarCollapsed: false,
        isFullscreen: false,
      );
      final b = ReaderUiState(
        chromeVisible: true,
        tocDrawerOpen: false,
        typographyPanelOpen: false,
        activeDrawerTab: DrawerTab.toc,
        tocSidebarCollapsed: false,
        isFullscreen: false,
      );
      expect(a, equals(b),
          reason: 'same field values must be equal');
      expect(a.hashCode, equals(b.hashCode),
          reason: 'equal objects must have equal hashCode');
    });

    test('chromeVisible difference breaks equality', () {
      final a = ReaderUiState(chromeVisible: true);
      final b = ReaderUiState(chromeVisible: false);
      expect(a, isNot(equals(b)));
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });

    test('activeDrawerTab difference breaks equality', () {
      final a = ReaderUiState(activeDrawerTab: DrawerTab.toc);
      final b = ReaderUiState(activeDrawerTab: DrawerTab.notes);
      expect(a, isNot(equals(b)));
    });

    test('tocSidebarCollapsed difference breaks equality', () {
      final a = ReaderUiState(tocSidebarCollapsed: false);
      final b = ReaderUiState(tocSidebarCollapsed: true);
      expect(a, isNot(equals(b)));
    });

    test('isFullscreen difference breaks equality', () {
      final a = ReaderUiState(isFullscreen: false);
      final b = ReaderUiState(isFullscreen: true);
      expect(a, isNot(equals(b)));
    });

    test('copyWith no-op returns equal state (no spurious rebuild)', () {
      final a = ReaderUiState(
        chromeVisible: true,
        activeDrawerTab: DrawerTab.bookmarks,
        isFullscreen: true,
      );
      final b = a.copyWith(); // no args → all fields default to current
      expect(a, equals(b),
          reason:
              'copyWith() with no args must yield equal state so Riverpod '
              'StateNotifier can skip emitting');
    });
  });
}
