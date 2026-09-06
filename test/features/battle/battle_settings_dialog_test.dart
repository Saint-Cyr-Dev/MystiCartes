import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysticartes/features/battle/battle_settings_dialog.dart';

void main() {
  testWidgets('readable pace is returned when resuming on a small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    BattleSettingsResult? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDialog<BattleSettingsResult>(
                context: context,
                builder: (_) => const BattleSettingsDialog(
                  pace: BattleAnimationPace.normal,
                ),
              );
            },
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plus lisible'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('battle-resume')));
    await tester.pumpAndSettle();
    expect(result?.pace, BattleAnimationPace.readable);
    expect(result?.restart, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('restart needs confirmation; cancel keeps the duel paused', (
    tester,
  ) async {
    BattleSettingsResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDialog<BattleSettingsResult>(
                context: context,
                builder: (_) => const BattleSettingsDialog(
                  pace: BattleAnimationPace.readable,
                ),
              );
            },
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('battle-restart-from-settings')));
    await tester.pumpAndSettle();
    expect(result, isNull);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('battle-settings-dialog')), findsOneWidget);
    expect(result, isNull);
    await tester.tap(find.byKey(const Key('battle-restart-from-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('battle-confirm-restart')));
    await tester.pumpAndSettle();
    expect(result?.restart, isTrue);
    expect(result?.pace, BattleAnimationPace.readable);
  });
}
