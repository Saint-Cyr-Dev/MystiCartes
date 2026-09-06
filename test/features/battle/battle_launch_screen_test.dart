import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysticartes/features/battle/battle_launch_screen.dart';
import 'package:mysticartes/features/battle/battle_deck_repository.dart';
import 'package:mysticartes/features/battle/battle_screen.dart';
import 'package:mysticartes/features/battle/local_duel.dart';
import 'package:mysticartes/features/battle/progression.dart';
import 'package:mysticartes/features/battle/progression_repository.dart';
import 'package:mysticartes/features/battle/widgets/battle_loading_view.dart';
import 'package:mysticartes/game/ai/ai_strategy.dart';
import 'package:mysticartes/game/duel_types.dart';

class _Assets extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage(<String, Object>{})!;
    }
    if (key.endsWith('.png')) {
      return ByteData.sublistView(base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg=='));
    }
    return rootBundle.load(key);
  }
}

class _Progression implements ProgressionRepository {
  final pending = Completer<PlayerBattleSetup>();
  @override
  Future<PlayerBattleSetup> prepareBattle() => pending.future;
}

class _Decks implements BattleDeckDataSource {
  final pending = Completer<BattleDeckData>();
  String? requestedId;
  @override
  Future<BattleDeckData> load(String id) {
    requestedId = id;
    return pending.future;
  }
}

PlayerBattleSetup get _setup => PlayerBattleSetup(
    deckId: 'deck-test',
    playerName: 'Junior',
    accountLevel: 1,
    totalXp: 0,
    difficulty: AiDifficulty.beginner);

Widget _app(Widget page) => DefaultAssetBundle(
    bundle: _Assets(), child: MaterialApp(theme: ThemeData.dark(), home: page));

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
    const Size(1440, 900)
  ]) {
    testWidgets('chargement adapté à $size avec conseils fonctionnels',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(BattleLoadingView(
          status: 'Chargement du deck actif…', onBack: () {}, onRetry: () {})));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const Key('loading-mysticartes-logo')), findsOneWidget);
      expect(find.text('Chargement du deck actif…'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
      await tester.tap(find.byKey(const Key('loading-tip-next')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.textContaining('40 cartes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('les étapes suivent le vrai chargement puis ouvrent le bon deck',
      (tester) async {
    final progression = _Progression();
    final decks = _Decks();
    await tester.pumpWidget(_app(BattleLaunchScreen(
        progressionRepository: progression, deckRepository: decks)));
    expect(find.text('Préparation de ton profil…'), findsOneWidget);
    progression.pending.complete(_setup);
    await tester.pump();
    expect(decks.requestedId, 'deck-test');
    expect(find.text('Chargement du deck actif…'), findsOneWidget);
    // A slow network never navigates just because the reveal delay has elapsed.
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(BattleScreen), findsNothing);
    decks.pending.complete(BattleDeckData(
        deckId: 'deck-test',
        mythicReserve: const [],
        mainDeck: List.filled(
            40,
            const LocalCardPresentation(
                code: 'BAB-003',
                name: 'Gardien du Carrefour',
                category: CardCategory.character,
                family: 'Babi',
                attribute: 'Terre',
                rank: 4,
                atk: 1800,
                def: 1700))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    final battle = tester.widget<BattleScreen>(find.byType(BattleScreen));
    expect(battle.deckId, 'deck-test');
    expect(battle.playerDeck, hasLength(40));
    expect(tester.takeException(), isNull);
  });

  testWidgets('erreur visible avec Réessayer et Retour opérationnels',
      (tester) async {
    var retries = 0;
    var backs = 0;
    await tester.pumpWidget(_app(BattleLoadingView(
        status: '',
        error: 'Aucun deck prêt',
        onBack: () => backs++,
        onRetry: () => retries++)));
    await tester.pump();
    expect(find.text('Aucun deck prêt'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.tap(find.text('Réessayer'));
    await tester.tap(find.byKey(const Key('battle-loading-back')));
    expect(retries, 1);
    expect(backs, 1);
  });

  testWidgets('quitter pendant le chargement ne déclenche pas un duel tardif',
      (tester) async {
    final progression = _Progression();
    final decks = _Decks();
    await tester.pumpWidget(_app(BattleLaunchScreen(
        progressionRepository: progression, deckRepository: decks)));
    await tester.pumpWidget(_app(const Text('Accueil')));
    progression.pending.complete(_setup);
    await tester.pump(const Duration(seconds: 3));
    expect(decks.requestedId, isNull);
    expect(find.byType(BattleScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
