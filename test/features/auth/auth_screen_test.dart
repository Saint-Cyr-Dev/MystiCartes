import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysticartes/features/auth/auth_screen.dart';
import 'package:mysticartes/features/auth/auth_session_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('le choix de mémorisation est réellement persistant', () async {
    expect(await AuthSessionPreferences.rememberSession(), isTrue);

    await AuthSessionPreferences.setRememberSession(false);

    expect(await AuthSessionPreferences.rememberSession(), isFalse);
  });

  testWidgets('les options compte, langue et aide sont interactives',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: AuthScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Se connecter'), findsOneWidget);
    await tester.ensureVisible(find.text('Créer un nouveau compte'));
    await tester.tap(find.text('Créer un nouveau compte'));
    await tester.pumpAndSettle();
    expect(find.text('Créer mon compte'), findsOneWidget);

    await tester.ensureVisible(find.text('Français'));
    await tester.tap(find.text('Français'));
    await tester.pumpAndSettle();
    expect(find.text('Langue du jeu'), findsOneWidget);
    await tester.tap(find.text('Français').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Besoin d’aide ?'));
    await tester.tap(find.text('Besoin d’aide ?'));
    await tester.pumpAndSettle();
    expect(find.text('Compte inaccessible'), findsOneWidget);
    expect(find.text('J’ai compris'), findsOneWidget);
  });
}
