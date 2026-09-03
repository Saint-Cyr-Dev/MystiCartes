// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:mysticartes/app/app_routes.dart';
import 'package:mysticartes/main.dart';

void main() {
  test('les routes principales de MystiCartes sont distinctes', () {
    expect(
      {
        AppRoutes.auth,
        AppRoutes.startup,
        AppRoutes.chooseUsername,
        AppRoutes.tutorial,
        AppRoutes.firstBattle,
        AppRoutes.reward,
        AppRoutes.home,
        AppRoutes.collection,
        AppRoutes.decks,
        AppRoutes.battle,
        AppRoutes.settings,
      },
      hasLength(11),
    );
  });

  testWidgets('le bouton JOUER ouvre directement le duel en mode local',
      (tester) async {
    await tester.pumpWidget(const MystiCartesApp(localDemoMode: true));

    expect(find.textContaining('MODE LOCAL V2'), findsOneWidget);
    await tester.tap(find.text('JOUER'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Duel V2'), findsOneWidget);
    expect(find.text('Préparation du duel'), findsNothing);
  });
}
