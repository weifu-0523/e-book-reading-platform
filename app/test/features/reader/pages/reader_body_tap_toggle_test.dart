// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/reader/controllers/reader_ui_controller.dart';
import 'package:zhiyue/features/reader/controllers/fullscreen_controller.dart';

void main() {
  test('ReaderUiController.toggleChrome flips chromeVisible', () {
    final controller = ReaderUiController(
      fullscreenController: const NoopFullscreenController(),
    );
    // toggleChrome flips; defaults() sets chromeVisible based on platform.
    // Record initial value so the test works on both desktop and mobile.
    final initial = controller.state.chromeVisible;

    controller.toggleChrome();
    expect(controller.state.chromeVisible, isNot(initial));

    controller.toggleChrome();
    expect(controller.state.chromeVisible, initial);
  });
}
