// Optional visual QA: flutter test tool/capture_battle_ui_test.dart --no-pub
// Writes actual Flutter renders to build/visual-review (not golden baselines).
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysticartes/features/battle/battle_screen.dart';
import 'package:mysticartes/features/battle/widgets/battle_loading_view.dart';

void main() {
  testWidgets('capture battle and loading with real artwork', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // Load real glyphs for human inspection (normal widget tests use Ahem).
    await tester.runAsync(() async {
      if (Platform.isWindows) {
        for (final font in [
          ('VisualQaSans', 'C:/Windows/Fonts/segoeui.ttf'),
          ('serif', 'C:/Windows/Fonts/times.ttf')
        ]) {
          final loader = FontLoader(font.$1)
            ..addFont(File(font.$2)
                .readAsBytes()
                .then((bytes) => ByteData.sublistView(bytes)));
          await loader.load();
        }
      }
      await (FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
          .load();
    });
    for (final viewport in [const Size(390, 844), const Size(1440, 900)]) {
      for (final battle in [false, true]) {
        await tester.binding.setSurfaceSize(viewport);
        final key = GlobalKey();
        await tester.pumpWidget(MaterialApp(
            theme: ThemeData.dark().copyWith(
                textTheme: ThemeData.dark()
                    .textTheme
                    .apply(fontFamily: 'VisualQaSans')),
            home: RepaintBoundary(
                key: key,
                child: battle
                    ? const BattleScreen.local()
                    : BattleLoadingView(
                        status: 'Chargement des cartes et des ressources…',
                        onBack: () {},
                        onRetry: () {}))));
        await tester.runAsync(() async {
          final context = key.currentContext!;
          for (final asset in [
            'assets/images/backgrounds/loading-portrait-v2.png',
            'assets/images/backgrounds/loading-landscape-v2.png',
            'assets/images/backgrounds/battle-portrait-v2.png',
            'assets/images/backgrounds/battle-landscape-v2.png',
            for (var i = 1; i <= 15; i++)
              'assets/images/cards/bab-${i.toString().padLeft(3, '0')}.png',
          ]) {
            await precacheImage(AssetImage(asset), context,
                onError: (error, _) {
              if (asset.contains('backgrounds/')) {
                throw StateError('Missing QA artwork: $asset — $error');
              }
            });
          }
        });
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump();
        expect(tester.takeException(), isNull);
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        await tester.runAsync(() async {
          final bytes =
              (await image.toByteData(format: ui.ImageByteFormat.png))!;
          final directory = Directory('build/visual-review')
            ..createSync(recursive: true);
          File('${directory.path}/${battle ? 'battle' : 'loading'}-${viewport.width.toInt()}.png')
              .writeAsBytesSync(bytes.buffer.asUint8List());
          image.dispose();
        });
        await tester.pumpWidget(const SizedBox());
      }
    }
  });
}
