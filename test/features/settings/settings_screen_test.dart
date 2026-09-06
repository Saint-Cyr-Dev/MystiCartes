import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysticartes/features/settings/settings_screen.dart';

void main() {
  Future<void> pumpMore(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: SettingsScreen(localDemoMode: true)),
    );
    await tester.pump();
  }

  testWidgets('Plus contient toutes les destinations et la déconnexion',
      (tester) async {
    await pumpMore(tester);

    for (final label in const [
      'Premium',
      'Profil',
      'Récompenses',
      'Événements',
      'Quêtes',
      'Classement',
      'Prix',
      'Amis',
      'Messages',
      'Paramètres',
      'Support',
      'DÉCONNEXION',
    ]) {
      expect(find.text(label, skipOffstage: false), findsOneWidget);
    }
  });

  testWidgets('une destination future donne un retour clair', (tester) async {
    await pumpMore(tester);

    await tester.tap(find.text('Premium'));
    await tester.pump();

    expect(
      find.text('Premium sera disponible prochainement dans MystiCartes.'),
      findsOneWidget,
    );
  });

  testWidgets('Profil et Paramètres ouvrent leurs contenus existants',
      (tester) async {
    await pumpMore(tester);

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('more-profile-account')), findsOneWidget);
    expect(find.textContaining('Mode local'), findsOneWidget);
    Navigator.of(tester.element(find.byKey(const Key('more-profile-account'))))
        .pop();
    await tester.pumpAndSettle();

    final settingsEntry = find.text('Paramètres', skipOffstage: false);
    await tester.drag(
      find.byKey(const Key('more-list')),
      const Offset(0, -520),
    );
    await tester.pumpAndSettle();
    await tester.tap(settingsEntry);
    await tester.pumpAndSettle();
    expect(find.text('Sons du jeu'), findsOneWidget);
    expect(find.text('Animations'), findsOneWidget);
  });

  testWidgets('la déconnexion reste sûre en mode local', (tester) async {
    await pumpMore(tester);

    final signOut = find.byKey(const Key('more-sign-out'), skipOffstage: false);
    await tester.drag(
      find.byKey(const Key('more-list')),
      const Offset(0, -800),
    );
    await tester.pumpAndSettle();
    await tester.tap(signOut);
    await tester.pump();

    expect(
        find.text('Aucun compte à déconnecter en mode local.'), findsOneWidget);
  });
}
