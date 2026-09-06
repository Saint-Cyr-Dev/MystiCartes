import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysticartes/features/battle/widgets/battle_backdrop.dart';

class _BackgroundBundle extends CachingAssetBundle {
  _BackgroundBundle({this.missingVariants = false});

  final bool missingVariants;

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage(<String, Object>{})!;
    }
    if (key.endsWith('.png') &&
        (!missingVariants || key == BattleBackdrop.legacyAsset)) {
      final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAF'
        'gAI/ScLbtAAAAABJRU5ErkJggg==',
      );
      return ByteData.sublistView(bytes);
    }
    throw FlutterError('Test asset absent: $key');
  }
}

void main() {
  test('selects the least-cropped composition by actual aspect ratio', () {
    expect(BattleBackdrop.assetForSize(const Size(390, 844)),
        endsWith('battle-portrait-v2.png'));
    expect(BattleBackdrop.assetForSize(const Size(900, 900)),
        endsWith('battle-square-v2.png'));
    expect(BattleBackdrop.assetForSize(const Size(1200, 800)),
        endsWith('battle-landscape-v2.png'));
    expect(BattleBackdrop.assetForSize(const Size(1920, 800)),
        endsWith('battle-ultrawide-v2.png'));
    // The same width can require a different composition after rotation/resize.
    expect(BattleBackdrop.assetForSize(const Size(800, 1600)),
        endsWith('battle-portrait-v2.png'));
    expect(BattleBackdrop.assetForSize(const Size(800, 360)),
        endsWith('battle-ultrawide-v2.png'));
  });

  testWidgets('fills the viewport and updates artwork when resized',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final bundle = _BackgroundBundle();
    for (final viewport in [
      const Size(320, 568),
      const Size(844, 390),
      const Size(1024, 768),
      const Size(1440, 900),
      const Size(900, 900),
    ]) {
      await tester.binding.setSurfaceSize(viewport);
      await tester.pumpWidget(DefaultAssetBundle(
        bundle: bundle,
        child: const MaterialApp(home: BattleBackdrop()),
      ));
      await tester.pumpAndSettle();

      final image = tester.widget<Image>(
        find.byKey(const Key('battle-backdrop-image')),
      );
      expect((image.image as AssetImage).assetName,
          BattleBackdrop.assetForSize(viewport));
      expect(image.fit, BoxFit.cover);
      expect(tester.getRect(find.byKey(const Key('battle-backdrop'))),
          Offset.zero & viewport);
      expect(tester.getRect(find.byKey(const Key('battle-backdrop-image'))),
          Offset.zero & viewport);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('uses existing artwork if a new composition is absent',
      (tester) async {
    await tester.pumpWidget(DefaultAssetBundle(
      bundle: _BackgroundBundle(missingVariants: true),
      child: const MaterialApp(home: BattleBackdrop()),
    ));
    await tester.pumpAndSettle();
    final fallback = tester.widget<Image>(
      find.byKey(const Key('battle-backdrop-legacy')),
    );
    expect(
        (fallback.image as AssetImage).assetName, BattleBackdrop.legacyAsset);
    expect(fallback.fit, BoxFit.cover);
    expect(tester.takeException(), isNull);
  });
}
