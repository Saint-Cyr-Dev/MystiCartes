// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:mysticartes/app/app_routes.dart';

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
}
