import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysticartes/features/battle/battle_screen.dart';
import 'package:mysticartes/features/battle/local_duel.dart';
import 'package:mysticartes/game/ai/ai_strategy.dart';
import 'package:mysticartes/game/ai/beginner_ai.dart';
import 'package:mysticartes/game/battle_state.dart';
import 'package:mysticartes/game/card.dart';
import 'package:mysticartes/game/duel_engine.dart';
import 'package:mysticartes/game/duel_types.dart';
import 'package:mysticartes/game/effects/effect_registry.dart';
import 'package:mysticartes/game/effects/foret_effects.dart';
import 'package:mysticartes/game/player.dart';

final class _ZeroRandom implements AiRandomSource {
  const _ZeroRandom();

  @override
  int nextInt(int max) => 0;
}

LocalDuelController _chainController() {
  final engine = DuelEngine(chainEffects: V2EffectRegistry.create());
  final quick = CardInstance(
    instanceId: 'quick-forest',
    cardId: 'card-for-008',
    cardCode: 'FOR-008',
    cardRevision: 1,
    category: CardCategory.action,
    rank: null,
    subtype: 'quick',
    primaryFamily: 'forêt',
    effectKey: ForetEffectKeys.for008,
    owner: DuelParticipant.player,
    controller: DuelParticipant.player,
    faceUp: false,
    position: null,
  );
  final state = DuelState(
    turnNumber: 2,
    activePlayer: DuelParticipant.ai,
    currentPhase: DuelPhase.main1,
    chain: ChainState(
      links: [
        ChainLink(
          linkId: 'enemy-action',
          effectKey: 'dummy',
          activatingPlayer: DuelParticipant.ai,
          speed: ChainSpeed.speed1,
        ),
      ],
      window: ResponseWindowType.effectActivation,
      priorityPlayer: DuelParticipant.player,
    ),
    playerField: PlayerFieldState.empty(
      participant: DuelParticipant.player,
      deck: const [],
    ).copyWith(hand: [quick]),
    aiField: PlayerFieldState.empty(
      participant: DuelParticipant.ai,
      deck: const [],
    ),
  );
  return LocalDuelController.forTesting(
    engine: engine,
    ai: createDuelAi(
      difficulty: AiDifficulty.beginner,
      engine: engine,
      random: const _ZeroRandom(),
    ),
    presentations: const {
      'FOR-008': LocalCardPresentation(
        code: 'FOR-008',
        name: 'Souffle de Germination',
        category: CardCategory.action,
        family: 'Forêt',
        attribute: 'Nature',
        subtype: 'quick',
        effectKey: ForetEffectKeys.for008,
      ),
    },
    state: state,
  );
}

LocalDuelController _combatController(
    {bool withTarget = false, int aiLifePoints = 8000}) {
  final engine = DuelEngine(chainEffects: V2EffectRegistry.create());
  CardInstance character({
    required String id,
    required String code,
    required DuelParticipant owner,
    required int atk,
    required int def,
  }) =>
      CardInstance(
        instanceId: id,
        cardId: 'card-$id',
        cardCode: code,
        cardRevision: 1,
        category: CardCategory.character,
        rank: 4,
        primaryFamily: 'babi',
        owner: owner,
        controller: owner,
        faceUp: true,
        position: BattlePosition.attack,
        zoneIndex: 0,
        atk: atk,
        def: def,
      );

  final attacker = character(
    id: 'player-attacker',
    code: 'TEST-PLAYER',
    owner: DuelParticipant.player,
    atk: 1800,
    def: 1200,
  );
  final target = character(
    id: 'ai-target',
    code: 'TEST-TARGET',
    owner: DuelParticipant.ai,
    atk: 500,
    def: 500,
  );
  final state = DuelState(
    turnNumber: 2,
    activePlayer: DuelParticipant.player,
    currentPhase: DuelPhase.battle,
    aiLifePoints: aiLifePoints,
    playerField: PlayerFieldState.empty(
      participant: DuelParticipant.player,
      deck: const [],
    ).copyWith(characterZones: [attacker, null, null, null, null]),
    aiField: PlayerFieldState.empty(
      participant: DuelParticipant.ai,
      deck: const [],
    ).copyWith(
      characterZones: withTarget
          ? [target, null, null, null, null]
          : List<FieldCardInstance?>.filled(5, null),
    ),
  );
  return LocalDuelController.forTesting(
    engine: engine,
    ai: createDuelAi(
      difficulty: AiDifficulty.beginner,
      engine: engine,
      random: const _ZeroRandom(),
    ),
    presentations: const {
      'TEST-PLAYER': LocalCardPresentation(
        code: 'TEST-PLAYER',
        name: 'Attaquant',
        category: CardCategory.character,
        family: 'Babi',
        attribute: 'Feu',
        rank: 4,
        atk: 1800,
        def: 1200,
      ),
      'TEST-TARGET': LocalCardPresentation(
        code: 'TEST-TARGET',
        name: 'Cible fragile',
        category: CardCategory.character,
        family: 'Babi',
        attribute: 'Terre',
        rank: 4,
        atk: 500,
        def: 500,
      ),
    },
    state: state,
  );
}

LocalDuelController _aiCombatController() {
  final engine = DuelEngine(chainEffects: V2EffectRegistry.create());
  final attacker = CardInstance(
    instanceId: 'ai-attacker',
    cardId: 'card-ai-attacker',
    cardCode: 'TEST-AI-ATTACK',
    cardRevision: 1,
    category: CardCategory.character,
    rank: 4,
    primaryFamily: 'babi',
    owner: DuelParticipant.ai,
    controller: DuelParticipant.ai,
    faceUp: true,
    position: BattlePosition.attack,
    zoneIndex: 0,
    atk: 1200,
    def: 900,
  );
  final state = DuelState(
    turnNumber: 2,
    activePlayer: DuelParticipant.ai,
    currentPhase: DuelPhase.battle,
    playerField: PlayerFieldState.empty(
      participant: DuelParticipant.player,
      deck: const [],
    ),
    aiField: PlayerFieldState.empty(
      participant: DuelParticipant.ai,
      deck: const [],
    ).copyWith(characterZones: [attacker, null, null, null, null]),
  );
  return LocalDuelController.forTesting(
    engine: engine,
    ai: createDuelAi(
      difficulty: AiDifficulty.beginner,
      engine: engine,
      random: const _ZeroRandom(),
    ),
    presentations: const {
      'TEST-AI-ATTACK': LocalCardPresentation(
        code: 'TEST-AI-ATTACK',
        name: 'Assaillant IA',
        category: CardCategory.character,
        family: 'Babi',
        attribute: 'Feu',
        rank: 4,
        atk: 1200,
        def: 900,
      ),
    },
    state: state,
  );
}

LocalDuelController _aiSetController() {
  final engine = DuelEngine(chainEffects: V2EffectRegistry.create());
  final trap = CardInstance(
    instanceId: 'ai-trap',
    cardId: 'card-ai-trap',
    cardCode: 'TEST-AI-TRAP',
    cardRevision: 1,
    category: CardCategory.trap,
    rank: null,
    subtype: 'normal',
    primaryFamily: 'babi',
    owner: DuelParticipant.ai,
    controller: DuelParticipant.ai,
    faceUp: false,
    position: null,
  );
  final state = DuelState(
    turnNumber: 2,
    activePlayer: DuelParticipant.ai,
    currentPhase: DuelPhase.main1,
    playerField: PlayerFieldState.empty(
      participant: DuelParticipant.player,
      deck: const [],
    ),
    aiField: PlayerFieldState.empty(
      participant: DuelParticipant.ai,
      deck: const [],
    ).copyWith(hand: [trap]),
  );
  return LocalDuelController.forTesting(
    engine: engine,
    ai: createDuelAi(
      difficulty: AiDifficulty.beginner,
      engine: engine,
      random: const _ZeroRandom(),
    ),
    presentations: const {
      'TEST-AI-TRAP': LocalCardPresentation(
        code: 'TEST-AI-TRAP',
        name: 'Piège secret IA',
        category: CardCategory.trap,
        family: 'Babi',
        attribute: 'Ombre',
        subtype: 'normal',
      ),
    },
    state: state,
  );
}

LocalDuelController _drawController() {
  final engine = DuelEngine(chainEffects: V2EffectRegistry.create());
  final drawn = CardInstance(
    instanceId: 'drawn-card',
    cardId: 'drawn-card-id',
    cardCode: 'TEST-DRAW',
    cardRevision: 1,
    category: CardCategory.action,
    rank: null,
    subtype: 'normal',
    primaryFamily: 'babi',
    owner: DuelParticipant.player,
    controller: DuelParticipant.player,
    faceUp: false,
    position: null,
  );
  final state = DuelState(
    turnNumber: 2,
    activePlayer: DuelParticipant.player,
    currentPhase: DuelPhase.draw,
    playerField: PlayerFieldState.empty(
      participant: DuelParticipant.player,
      deck: [drawn],
    ),
    aiField: PlayerFieldState.empty(
      participant: DuelParticipant.ai,
      deck: const [],
    ),
  );
  return LocalDuelController.forTesting(
    engine: engine,
    ai: createDuelAi(
      difficulty: AiDifficulty.beginner,
      engine: engine,
      random: const _ZeroRandom(),
    ),
    presentations: const {
      'TEST-DRAW': LocalCardPresentation(
        code: 'TEST-DRAW',
        name: 'Carte piochée',
        category: CardCategory.action,
        family: 'Babi',
        attribute: 'Vent',
        subtype: 'normal',
      ),
    },
    state: state,
  );
}

LocalDuelController _summonController() {
  final engine = DuelEngine(chainEffects: V2EffectRegistry.create());
  final character = CardInstance(
    instanceId: 'player-summon',
    cardId: 'card-player-summon',
    cardCode: 'TEST-SUMMON',
    cardRevision: 1,
    category: CardCategory.character,
    rank: 4,
    primaryFamily: 'babi',
    owner: DuelParticipant.player,
    controller: DuelParticipant.player,
    faceUp: false,
    position: null,
    atk: 1400,
    def: 1000,
  );
  final state = DuelState(
    turnNumber: 2,
    activePlayer: DuelParticipant.player,
    currentPhase: DuelPhase.main1,
    playerField: PlayerFieldState.empty(
      participant: DuelParticipant.player,
      deck: const [],
    ).copyWith(hand: [character]),
    aiField: PlayerFieldState.empty(
      participant: DuelParticipant.ai,
      deck: const [],
    ),
  );
  return LocalDuelController.forTesting(
    engine: engine,
    ai: createDuelAi(
      difficulty: AiDifficulty.beginner,
      engine: engine,
      random: const _ZeroRandom(),
    ),
    presentations: const {
      'TEST-SUMMON': LocalCardPresentation(
        code: 'TEST-SUMMON',
        name: 'Éclaireuse test',
        category: CardCategory.character,
        family: 'Babi',
        attribute: 'Vent',
        rank: 4,
        atk: 1400,
        def: 1000,
      ),
    },
    state: state,
  );
}

// Interaction fixtures have synthetic catalogue codes, with tiny test artwork.
class _InteractionAssets extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage(<String, Object>{})!;
    }
    if (key.endsWith('.png')) {
      return ByteData.sublistView(base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAF'
          'gAI/ScLbtAAAAABJRU5ErkJggg=='));
    }
    return rootBundle.load(key);
  }
}

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

  testWidgets('les noms et le profil restent horizontaux sur téléphone',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: BattleScreen.local()));
    await tester.pump();

    final aiName = find.text('IA débutant');
    expect(aiName, findsOneWidget);
    final nameRect = tester.getRect(aiName);
    expect(nameRect.width, greaterThan(nameRect.height * 2));
    expect(nameRect.right, lessThanOrEqualTo(390));
    expect(find.text('Vous'), findsOneWidget);
    expect(find.byKey(const Key('battle-fitted-board')), findsOneWidget);
    expect(find.text('Tour 1'), findsOneWidget);
    final phaseBar = tester.getRect(
      find.byKey(const Key('battle-top-phase-bar')),
    );
    expect(phaseBar.bottom, lessThanOrEqualTo(nameRect.top));
    expect(find.byType(SingleChildScrollView), findsNothing);
    final handCaption = tester.getRect(
      find.text('Main — touchez une carte pour la jouer'),
    );
    expect(handCaption.bottom, lessThanOrEqualTo(844));
    expect(tester.takeException(), isNull);
  });

  for (final size in <Size>[
    const Size(320, 568),
    const Size(390, 844),
    const Size(1024, 600),
    const Size(1440, 900),
  ]) {
    testWidgets('le plateau entier tient dans ${size.width}x${size.height}',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: BattleScreen.local()));
      await tester.pump();

      final board = tester.getRect(
        find.byKey(const Key('battle-fitted-board')),
      );
      expect(board.left, greaterThanOrEqualTo(0));
      expect(board.right, lessThanOrEqualTo(size.width));
      expect(board.bottom, lessThanOrEqualTo(size.height));
      expect(find.byType(SingleChildScrollView), findsNothing);
      final exception = tester.takeException();
      expect(
        exception,
        isNull,
        reason: exception is FlutterError
            ? exception.toStringDeep()
            : exception?.toString(),
      );
    });
  }

  testWidgets('un changement de phase montre son identité visuelle',
      (tester) async {
    await pumpBattle(tester);
    await tester.pump(const Duration(milliseconds: 1300));

    await tester.tap(find.byKey(const Key('battle-draw-pile')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('PHASE DE PRÉPARATION'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('la pile affiche le deck restant et permet de piocher',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = _drawController();
    await tester.pumpWidget(
      MaterialApp(
        home: BattleScreen.local(controller: controller),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('battle-draw-pile')), findsOneWidget);
    expect(find.byKey(const Key('battle-draw-pile-count')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('battle-draw-pile')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    final actionRow = tester.getRect(
      find.byKey(const Key('battle-player-action-row')),
    );
    final drawButton = tester.getRect(
      find.byKey(const Key('battle-draw-pile')),
    );
    final playerProfile = tester.getRect(find.text('Vous'));
    expect(drawButton.top, greaterThanOrEqualTo(actionRow.top));
    expect(drawButton.bottom, lessThanOrEqualTo(actionRow.bottom));
    expect(actionRow.bottom, lessThanOrEqualTo(playerProfile.top));

    await tester.tap(find.byKey(const Key('battle-draw-pile')));
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('Carte piochée'), findsOneWidget);
    expect(controller.state.playerField.deck, isEmpty);
    expect(controller.state.playerField.hand.single.instanceId, 'drawn-card');
    expect(find.text('PHASE DE PRÉPARATION'), findsOneWidget);
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

  testWidgets(
      'la priorité fait pulser la carte et affiche Passer sans dialogue',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: BattleScreen.local(controller: _chainController()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 80));

    expect(
      find.byKey(const Key('battle-activatable-quick-forest')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('battle-chain-pass')), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('battle-player-action-row')),
        matching: find.byKey(const Key('battle-chain-pass')),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('battle-activatable-quick-forest')),
    );
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byKey(const Key('battle-chain-pass')), findsOneWidget);
  });

  testWidgets('une attaque produit un impact puis des dégâts flottants',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: BattleScreen.local(controller: _combatController()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 80));

    await tester.tap(find.text('Attaquant'));
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      find.byKey(const Key('battle-attack-source-player-attacker')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('battle-attack-impact')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 320));
    expect(find.byKey(const Key('battle-life-float')), findsOneWidget);
    expect(find.text('-1800'), findsOneWidget);
  });

  testWidgets("une attaque de l'IA montre aussi clairement sa carte source",
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = _aiCombatController();
    controller.playAiUntilPlayerDecision();
    await tester.pumpWidget(
      MaterialApp(home: BattleScreen.local(controller: controller)),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const Key('battle-attack-source-ai-attacker')),
      findsOneWidget,
    );
    expect(find.text('Assaillant IA'), findsWidgets);
    expect(find.text('ATTAQUE'), findsOneWidget);
  });

  testWidgets("une carte posée par l'IA est animée sans révéler son identité",
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = _aiSetController();
    controller.playAiUntilPlayerDecision();
    await tester.pumpWidget(
      MaterialApp(home: BattleScreen.local(controller: controller)),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const Key('battle-card-played-ai-trap')),
      findsOneWidget,
    );
    expect(find.text('CARTE POSÉE'), findsOneWidget);
    expect(find.text('Carte adverse'), findsOneWidget);
    expect(find.text('Piège secret IA'), findsNothing);
  });

  testWidgets('une carte jouée apparaît en grand avant de rejoindre le terrain',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: BattleScreen.local(controller: _summonController()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Éclaireuse test'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Invoquer en Attaque'));
    await tester.pump(const Duration(milliseconds: 80));

    expect(
      find.byKey(const Key('battle-card-played-player-summon')),
      findsOneWidget,
    );
    expect(find.text('CARTE JOUÉE'), findsOneWidget);
    // The card remains fully readable well beyond the former 760ms flash.
    await tester.pump(const Duration(milliseconds: 1000));
    final spotlight = find.byKey(const Key('battle-card-played-player-summon'));
    expect(spotlight, findsOneWidget);
    expect(
        tester
            .widget<Opacity>(find
                .descendant(of: spotlight, matching: find.byType(Opacity))
                .first)
            .opacity,
        1);
  });

  testWidgets('une Action rapide activée identifie clairement sa carte source',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: BattleScreen.local(controller: _chainController()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 80));

    await tester.tap(
      find.byKey(const Key('battle-activatable-quick-forest')),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const Key('battle-card-played-quick-forest')),
      findsOneWidget,
    );
    expect(find.text('CARTE JOUÉE'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pump(const Duration(milliseconds: 1000));

    expect(
      find.byKey(const Key('battle-effect-source-quick-forest')),
      findsOneWidget,
    );
    expect(find.text('EFFET ACTIVÉ'), findsOneWidget);
    expect(find.text('Souffle de Germination'), findsWidgets);
  });

  testWidgets(
      'les paramètres figent une attaque et reprennent sans réinitialiser',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = _combatController();
    await tester.pumpWidget(DefaultAssetBundle(
        bundle: _InteractionAssets(),
        child: MaterialApp(
          home: BattleScreen.local(controller: controller),
        )));
    await tester.pump();
    await tester.tap(find.text('Attaquant'));
    await tester.pump(const Duration(milliseconds: 100));
    final stateBeforePause = controller.state;
    await tester.tap(find.byKey(const Key('battle-settings')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Partie en pause'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    expect(identical(controller.state, stateBeforePause), isTrue);
    expect(
        find.byKey(const Key('battle-attack-source-player-attacker'),
            skipOffstage: false),
        findsOneWidget);
    await tester.tap(find.byKey(const Key('battle-resume')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Partie en pause'), findsNothing);
    expect(identical(controller.state, stateBeforePause), isTrue);
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(const Key('battle-attack-source-player-attacker')),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pause empêche le tour IA en attente puis le laisse reprendre',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = _drawController();
    await tester.pumpWidget(DefaultAssetBundle(
        bundle: _InteractionAssets(),
        child: MaterialApp(home: BattleScreen.local(controller: controller))));
    await tester.pump();
    // Complete the player's phases through the existing UI; the AI delay is
    // now scheduled but has not elapsed yet.
    for (var i = 0;
        i < 8 && controller.state.activePlayer == DuelParticipant.player;
        i++) {
      final draw = find.byKey(const Key('battle-draw-pile'));
      final next = find.byKey(const Key('battle-next-phase'));
      if (draw.evaluate().isNotEmpty) {
        await tester.tap(draw);
      } else {
        await tester.tap(next);
      }
      await tester.pump();
    }
    expect(controller.state.activePlayer, DuelParticipant.ai);
    final waitingState = controller.state;
    await tester.tap(find.byKey(const Key('battle-settings')));
    await tester.pump(const Duration(seconds: 4));
    expect(identical(controller.state, waitingState), isTrue);
    await tester.tap(find.byKey(const Key('battle-resume')));
    await tester.pump(const Duration(milliseconds: 600));
    expect(identical(controller.state, waitingState), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la victoire attend la fin de l’animation sans retarder la règle',
      (tester) async {
    final controller = _combatController(aiLifePoints: 1000);
    await tester.pumpWidget(DefaultAssetBundle(
        bundle: _InteractionAssets(),
        child: MaterialApp(home: BattleScreen.local(controller: controller))));
    await tester.pump();
    await tester.tap(find.text('Attaquant'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.state.isFinished, isTrue);
    expect(find.text('Victoire !'), findsNothing);
    expect(find.byKey(const Key('battle-attack-source-player-attacker')),
        findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Victoire !'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('une carte détruite part visuellement vers le Cimetière',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: BattleScreen.local(
          controller: _combatController(withTarget: true),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 80));

    await tester.tap(find.text('Attaquant'));
    await tester.pump(const Duration(milliseconds: 30));
    await tester.tap(find.text('Cible fragile'));
    await tester.pump(const Duration(milliseconds: 410));

    expect(find.byKey(const Key('battle-destruction-float')), findsOneWidget);
    expect(find.text('Cible fragile'), findsOneWidget);
  });
}
