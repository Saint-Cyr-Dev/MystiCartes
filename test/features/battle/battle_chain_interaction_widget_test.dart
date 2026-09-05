import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysticartes/features/battle/battle_screen.dart';
import 'package:mysticartes/features/battle/local_duel.dart';
import 'package:mysticartes/game/ai/ai_strategy.dart';
import 'package:mysticartes/game/battle_state.dart';
import 'package:mysticartes/game/card.dart';
import 'package:mysticartes/game/duel_engine.dart';
import 'package:mysticartes/game/duel_types.dart';
import 'package:mysticartes/game/effects/babi_effects.dart';
import 'package:mysticartes/game/effects/effect_registry.dart';
import 'package:mysticartes/game/effects/masque_effects.dart';
import 'package:mysticartes/game/player.dart';

final class _PassingAi implements DuelAiStrategy {
  const _PassingAi();

  @override
  AiDifficulty get difficulty => AiDifficulty.beginner;

  @override
  ChainLink? chooseChainActivation({
    required DuelState state,
    required List<ChainLink> availableActivations,
  }) =>
      null;

  @override
  AttackDeclarationResult? declareAttack(DuelState state) => null;

  @override
  DuelActionResult? discardExcessHand(DuelState state) => null;

  @override
  DuelAiTurnResult playTurn(DuelState state) => DuelAiTurnResult(state: state);

  @override
  DuelActionResult? playMainMonster(DuelState state) => null;

  @override
  DuelActionResult? setBackrow(DuelState state) => null;
}

final class _TypedRevealThreat extends ChainEffectDefinition {
  const _TypedRevealThreat();

  @override
  Iterable<PendingDuelEvent> pendingEvents(DuelState state, ChainLink link) => [
        FaceDownRevealPending(
          sourceLinkId: link.linkId,
          cardInstanceIds: const ['hidden-mask'],
        ),
      ];

  @override
  DuelState resolve(DuelState state, ChainLink link) => state;
}

final class _NoopEffect extends ChainEffectDefinition {
  const _NoopEffect();

  @override
  DuelState resolve(DuelState state, ChainLink link) => state;
}

CardInstance _card({
  required String id,
  required String code,
  required DuelParticipant owner,
  required CardCategory category,
  String? subtype,
  String? effectKey,
  String family = 'babi',
  bool faceUp = true,
  BattlePosition? position,
  int? zoneIndex,
}) =>
    CardInstance(
      instanceId: id,
      cardId: 'card-$code',
      cardCode: code,
      cardRevision: 1,
      category: category,
      rank: category == CardCategory.character ? 4 : null,
      subtype: subtype,
      primaryFamily: family,
      effectKey: effectKey,
      owner: owner,
      controller: owner,
      faceUp: faceUp,
      position: category == CardCategory.character ? position : null,
      zoneIndex: zoneIndex,
      atk: category == CardCategory.character ? 1700 : null,
      def: category == CardCategory.character ? 1600 : null,
      runtimeData: category == CardCategory.trap
          ? const {CardRuntimeKeys.setOnTurn: 1}
          : const {},
    );

LocalCardPresentation _presentation(
  CardInstance card, {
  required String name,
}) =>
    LocalCardPresentation(
      code: card.cardCode,
      name: name,
      category: card.category,
      family: card.primaryFamily ?? '—',
      attribute: 'Esprit',
      rank: card.rank,
      atk: card.atk,
      def: card.def,
      subtype: card.subtype,
      effectKey: card.effectKey,
    );

PlayerFieldState _field({
  required DuelParticipant participant,
  List<CardInstance> hand = const [],
  List<CardInstance?> characters = const [],
  List<CardInstance?> backrow = const [],
}) =>
    PlayerFieldState.empty(participant: participant, deck: const []).copyWith(
      hand: hand,
      characterZones: [
        ...characters,
        ...List<CardInstance?>.filled(5 - characters.length, null),
      ],
      actionTrapZones: [
        ...backrow,
        ...List<CardInstance?>.filled(5 - backrow.length, null),
      ],
    );

ChainState _responseTo(ChainLink link) => ChainState(
      links: [link],
      window: ResponseWindowType.effectActivation,
      priorityPlayer: DuelParticipant.player,
    );

LocalDuelController _controller({
  required DuelEngine engine,
  required DuelState state,
  required Iterable<MapEntry<CardInstance, String>> cards,
}) =>
    LocalDuelController.forTesting(
      engine: engine,
      ai: const _PassingAi(),
      presentations: {
        for (final entry in cards)
          entry.key.cardCode: _presentation(entry.key, name: entry.value),
      },
      state: state,
    );

Future<void> _pumpBattle(
  WidgetTester tester,
  LocalDuelController controller,
) async {
  await tester.binding.setSurfaceSize(const Size(1200, 1100));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(home: BattleScreen.local(controller: controller)),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('un tap sur une Action rapide révèle ses cibles sur le plateau',
      (tester) async {
    const threatKey = 'noop-widget';
    final engine = DuelEngine(chainEffects: {
      ...V2EffectRegistry.create(),
      threatKey: const _NoopEffect(),
    });
    final quick = _card(
      id: 'quick-position',
      code: 'BAB-008',
      owner: DuelParticipant.player,
      category: CardCategory.action,
      subtype: 'quick',
      effectKey: BabiEffectKeys.bab008,
    );
    final first = _card(
      id: 'babi-first',
      code: 'BAB-T1',
      owner: DuelParticipant.player,
      category: CardCategory.character,
      position: BattlePosition.attack,
      zoneIndex: 0,
    );
    final second = _card(
      id: 'babi-second',
      code: 'BAB-T2',
      owner: DuelParticipant.player,
      category: CardCategory.character,
      position: BattlePosition.defense,
      zoneIndex: 1,
    );
    final threat = ChainLink(
      linkId: 'enemy-effect',
      effectKey: threatKey,
      activatingPlayer: DuelParticipant.ai,
      speed: ChainSpeed.speed1,
    );
    final state = DuelState(
      turnNumber: 2,
      activePlayer: DuelParticipant.player,
      currentPhase: DuelPhase.main1,
      playerField: _field(
        participant: DuelParticipant.player,
        hand: [quick],
        characters: [first, second],
      ),
      aiField: _field(participant: DuelParticipant.ai),
      chain: _responseTo(threat),
    );
    final controller = _controller(
      engine: engine,
      state: state,
      cards: [
        MapEntry(quick, 'Trajet Express'),
        MapEntry(first, 'Premier Babi'),
        MapEntry(second, 'Second Babi'),
      ],
    );
    await _pumpBattle(tester, controller);

    expect(find.byKey(const Key('battle-chain-pass')), findsOneWidget);
    await tester
        .tap(find.byKey(const Key('battle-activatable-quick-position')));
    await tester.pump();

    expect(find.byKey(const Key('battle-target-babi-first')), findsOneWidget);
    expect(find.byKey(const Key('battle-target-babi-second')), findsOneWidget);
    expect(find.text('Choisis une cible lumineuse'), findsOneWidget);

    await tester.tap(find.byKey(const Key('battle-target-babi-second')));
    await tester.pump();
    expect(controller.state.chain.links, hasLength(2));

    await tester.tap(find.byKey(const Key('battle-chain-pass')));
    await tester.pump();
    expect(controller.state.chain.isOpen, isFalse);
    expect(
      controller.state.playerField.characterZones[1]?.position,
      BattlePosition.attack,
    );
  });

  testWidgets(
      'plusieurs coûts ouvrent une feuille et le choix est réellement payé',
      (tester) async {
    final engine = DuelEngine(chainEffects: V2EffectRegistry.create());
    final counter = _card(
      id: 'counter-cut',
      code: 'BAB-012',
      owner: DuelParticipant.player,
      category: CardCategory.trap,
      subtype: 'counter',
      effectKey: BabiEffectKeys.bab012,
      faceUp: false,
      zoneIndex: 0,
    );
    final discardA = _card(
      id: 'discard-a',
      code: 'COST-A',
      owner: DuelParticipant.player,
      category: CardCategory.character,
    );
    final discardB = _card(
      id: 'discard-b',
      code: 'COST-B',
      owner: DuelParticipant.player,
      category: CardCategory.character,
    );
    final enemyAction = _card(
      id: 'enemy-action',
      code: 'BAB-009',
      owner: DuelParticipant.ai,
      category: CardCategory.action,
      subtype: 'normal',
      effectKey: BabiEffectKeys.bab009,
      zoneIndex: 0,
    );
    final threat = ChainLink(
      linkId: 'enemy-action-link',
      effectKey: BabiEffectKeys.bab009,
      activatingPlayer: DuelParticipant.ai,
      speed: ChainSpeed.speed1,
      sourceCardInstanceId: enemyAction.instanceId,
      sourceCardCode: enemyAction.cardCode,
    );
    final state = DuelState(
      turnNumber: 2,
      activePlayer: DuelParticipant.player,
      currentPhase: DuelPhase.main1,
      playerField: _field(
        participant: DuelParticipant.player,
        hand: [discardA, discardB],
        backrow: [counter],
      ),
      aiField: _field(
        participant: DuelParticipant.ai,
        backrow: [enemyAction],
      ),
      chain: _responseTo(threat),
    );
    final controller = _controller(
      engine: engine,
      state: state,
      cards: [
        MapEntry(counter, 'Coupure de Courant'),
        MapEntry(discardA, 'Coût A'),
        MapEntry(discardB, 'Coût B'),
        MapEntry(enemyAction, 'Réseau Saturé'),
      ],
    );
    await _pumpBattle(tester, controller);

    await tester.tap(find.byKey(const Key('battle-activatable-counter-cut')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Choisis le coût ou la combinaison'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.tap(find.textContaining('COST-A').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(
      controller.state.playerField.hand
          .any((card) => card.instanceId == discardA.instanceId),
      isFalse,
    );
    expect(
      controller.state.playerField.graveyard
          .any((card) => card.instanceId == discardA.instanceId),
      isTrue,
    );
    expect(find.byKey(const Key('battle-chain-pass')), findsOneWidget);
  });

  testWidgets('un événement de révélation typé allume réellement MAS-012',
      (tester) async {
    const threatKey = 'typed-reveal-widget';
    final engine = DuelEngine(chainEffects: {
      ...V2EffectRegistry.create(),
      threatKey: const _TypedRevealThreat(),
    });
    final hidden = _card(
      id: 'hidden-mask',
      code: 'MAS-HIDDEN',
      owner: DuelParticipant.player,
      category: CardCategory.character,
      family: 'masque',
      faceUp: false,
      position: BattlePosition.defense,
      zoneIndex: 0,
    );
    final counter = _card(
      id: 'forbidden-face',
      code: 'MAS-012',
      owner: DuelParticipant.player,
      category: CardCategory.trap,
      subtype: 'counter',
      family: 'masque',
      effectKey: MasqueEffectKeys.mas012,
      faceUp: false,
      zoneIndex: 0,
    );
    final threat = ChainLink(
      linkId: 'typed-reveal-link',
      effectKey: threatKey,
      activatingPlayer: DuelParticipant.ai,
      speed: ChainSpeed.speed1,
    );
    final state = DuelState(
      turnNumber: 2,
      activePlayer: DuelParticipant.player,
      currentPhase: DuelPhase.main1,
      playerField: _field(
        participant: DuelParticipant.player,
        characters: [hidden],
        backrow: [counter],
      ),
      aiField: _field(participant: DuelParticipant.ai),
      chain: _responseTo(threat),
    );
    final controller = _controller(
      engine: engine,
      state: state,
      cards: [
        MapEntry(hidden, 'M'),
        MapEntry(counter, 'V'),
      ],
    );
    await _pumpBattle(tester, controller);

    final glowingCounter =
        find.byKey(const Key('battle-activatable-forbidden-face'));
    expect(glowingCounter, findsOneWidget);
    await tester.tap(glowingCounter);
    await tester.pump();

    expect(controller.state.chain.links, hasLength(2));
    expect(find.byKey(const Key('battle-chain-pass')), findsOneWidget);
  });
}
