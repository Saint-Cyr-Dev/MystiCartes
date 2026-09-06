import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysticartes/app/app_routes.dart';
import 'package:mysticartes/features/home/home_screen.dart';

Widget _app() => MaterialApp(
      home: const HomeScreen(localDemoMode: true),
      routes: {
        AppRoutes.battle: (_) => const Scaffold(body: Text('écran-combat')),
        AppRoutes.collection: (_) =>
            const Scaffold(body: Text('écran-bibliothèque')),
        AppRoutes.decks: (_) => const Scaffold(body: Text('écran-decks')),
        AppRoutes.settings: (_) => const Scaffold(body: Text('écran-profil')),
        AppRoutes.shop: (_) => const Scaffold(body: Text('écran-shop')),
      },
    );

void main() {
  for (final destination in const [
    ('JOUER', 'écran-combat'),
    ('BIBLIOTHÈQUE', 'écran-bibliothèque'),
    ('MES DECKS', 'écran-decks'),
  ]) {
    testWidgets('${destination.$1} ouvre son écran', (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_app());
      await tester.pump();
      await tester.ensureVisible(find.text(destination.$1));
      await tester.tap(find.text(destination.$1));
      await tester.pumpAndSettle();
      expect(find.text(destination.$2), findsOneWidget);
    });
  }

  testWidgets('les Défis donnent un retour sans écran vide', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.ensureVisible(find.text('DÉFIS'));
    await tester.tap(find.text('DÉFIS'));
    await tester.pump();
    expect(find.text('La section Défis arrive bientôt dans MystiCartes.'),
        findsOneWidget);
  });

  testWidgets('sur téléphone le profil et les monnaies restent sur une ligne',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app());
    await tester.pump();

    final profileY = tester.getCenter(find.text('Invocateur')).dy;
    final goldY = tester.getCenter(find.text('1230')).dy;
    final gemsY = tester.getCenter(find.text('5')).dy;
    expect((profileY - goldY).abs(), lessThan(30));
    expect((profileY - gemsY).abs(), lessThan(30));
    for (final label in ['Invocateur', '1230', '5']) {
      final rect = tester.getRect(find.text(label));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(390));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('le menu Plus inférieur ouvre son espace', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    expect(find.text('écran-profil'), findsOneWidget);
  });

  testWidgets('les gros boutons ne montrent plus de sous-titres',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app());
    await tester.pump();

    expect(find.text('Découvrez et gérez vos cartes'), findsNothing);
    expect(find.text('Créez et personnalisez vos decks'), findsNothing);
    final navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(
      navigation.labelBehavior,
      NavigationDestinationLabelBehavior.alwaysHide,
    );
    expect(tester.takeException(), isNull);
  });
}
