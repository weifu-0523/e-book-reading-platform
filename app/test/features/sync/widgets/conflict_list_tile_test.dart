import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/features/sync/widgets/conflict_list_tile.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

Widget _wrapped(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('zh'),
    home: Scaffold(body: child),
  );
}

SyncConflict _row({
  required String id,
  required String type,
  required String preview,
  String winnerDevice = 'device-A',
  String loserDevice = 'device-B',
}) {
  return SyncConflict(
    id: 1,
    recordId: id,
    recordType: type,
    localMtime: DateTime.utc(2026, 6, 29, 12),
    remoteMtime: DateTime.utc(2026, 6, 29, 10),
    winnerDevice: winnerDevice,
    loserDevice: loserDevice,
    detectedAt: DateTime.utc(2026, 6, 29, 12, 30),
    payloadPreview: preview,
  );
}

void main() {
  testWidgets('renders type label + recordId in collapsed state',
      (tester) async {
    await tester.pumpWidget(_wrapped(
      ConflictListTile(data: _row(id: 'a1', type: 'annotation', preview: '{}')),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('高亮'), findsOneWidget);
    expect(find.textContaining('a1'), findsOneWidget);
    expect(find.text('暂无冲突记录'), findsNothing);
  });

  testWidgets('expands to show preview on tap', (tester) async {
    await tester.pumpWidget(_wrapped(
      ConflictListTile(
        data: _row(id: 'a1', type: 'annotation', preview: '{"quote":"hi"}'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('{"quote":"hi"}'), findsNothing); // collapsed
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();
    expect(find.text('{"quote":"hi"}'), findsOneWidget);
  });

  testWidgets('shows loser device id', (tester) async {
    await tester.pumpWidget(_wrapped(
      ConflictListTile(
        data: _row(
          id: 'a1',
          type: 'bookNote',
          preview: '{}',
          loserDevice: 'device-X',
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('device-X'), findsOneWidget);
  });

  // S3 T7: regression guard for mobile compact width. Long device IDs must
  // not push the subtitle off-screen — verified via maxLines + ellipsis on
  // the subtitle Text widget in ConflictListTile.
  testWidgets('renders without overflow at 360px width with long device id',
      (tester) async {
    tester.view.physicalSize = const Size(360 * 2, 800 * 2); // DPR=2 → 360x800 logical
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrapped(
      ListView(
        children: [
          ConflictListTile(
            data: _row(
              id: 'rec-very-long-id-1234567890',
              type: 'annotation',
              preview: 'preview text',
              loserDevice: 'device-very-long-id-1234567890-abcdef-xyz',
            ),
          ),
        ],
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.textContaining('device-very-long-id'), findsOneWidget);
  });
}
