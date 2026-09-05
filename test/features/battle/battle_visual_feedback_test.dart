import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysticartes/features/battle/battle_screen.dart';

void main() {
  Future<void> pumpBattle(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: BattleScreen.local(),
      ),
    );
    await tester.pump();
  }

  testWidgets('le changement de tour utilise une bannière animée temporaire',
      (tester) async {
    await pumpBattle(tester);

    expect(find.byKey(const Key('battle-moment-banner')), findsOneWidget);
    expect(find.text('TON TOUR'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('TON TOUR'), findsNothing);
  });

  testWidgets('un changement de phase montre son identité visuelle',
      (tester) async {
    await pumpBattle(tester);
    await tester.pump(const Duration(milliseconds: 1300));

    await tester.tap(find.byTooltip('Phase suivante'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('PHASE DE PRÉPARATION'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets(
      'une carte jouée au mauvais moment tremble et affiche une erreur locale',
      (tester) async {
    await pumpBattle(tester);
    final card = find.text('Gardien du Carrefour').first;
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byKey(const Key('battle-card-feedback')), findsOneWidget);
    expect(find.text('Attends une Phase Principale'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.byKey(const Key('battle-card-feedback')), findsNothing);
  });
}
