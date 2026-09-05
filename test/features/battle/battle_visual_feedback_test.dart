import 'package:flutter/material.dart';
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

LocalDuelController _combatController({bool withTarget = false}) {
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
    expect(find.byKey(const Key('battle-attack-impact')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 320));
    expect(find.byKey(const Key('battle-life-float')), findsOneWidget);
    expect(find.text('-1800'), findsOneWidget);
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
