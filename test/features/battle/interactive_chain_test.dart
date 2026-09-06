import 'package:flutter_test/flutter_test.dart';
import 'package:mysticartes/features/battle/local_duel.dart';
import 'package:mysticartes/game/ai/ai_strategy.dart';
import 'package:mysticartes/game/ai/beginner_ai.dart';
import 'package:mysticartes/game/battle_state.dart';
import 'package:mysticartes/game/card.dart';
import 'package:mysticartes/game/duel_engine.dart';
import 'package:mysticartes/game/duel_types.dart';
import 'package:mysticartes/game/effects/babi_effects.dart';
import 'package:mysticartes/game/effects/effect_registry.dart';
import 'package:mysticartes/game/effects/foret_effects.dart';
import 'package:mysticartes/game/player.dart';

final class _ZeroRandom implements AiRandomSource {
  const _ZeroRandom();

  @override
  int nextInt(int max) => 0;
}

final class _AttackResponderAi implements DuelAiStrategy {
  const _AttackResponderAi();

  @override
  AiDifficulty get difficulty => AiDifficulty.beginner;

  @override
  ChainLink? chooseChainActivation({
    required DuelState state,
    required List<ChainLink> availableActivations,
  }) {
    // Répond à la déclaration d'attaque, puis passe après la contre-réponse
    // du joueur afin de permettre les deux passes réglementaires.
    return state.chain.links.isEmpty && availableActivations.isNotEmpty
        ? availableActivations.first
        : null;
  }

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

CardInstance _card({
  required String id,
  required String code,
  required DuelParticipant owner,
  required CardCategory category,
  String? effectKey,
  String? subtype,
  int? atk,
  int? def,
  BattlePosition? position,
  bool faceUp = true,
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
      primaryFamily: 'babi',
      effectKey: effectKey,
      owner: owner,
      controller: owner,
      faceUp: faceUp,
      position: position,
      zoneIndex: zoneIndex,
      atk: atk,
      def: def,
    );

void main() {
  test('BAB-011 interrompt réellement une attaque IA via la priorité UI', () {
    final engine = DuelEngine(chainEffects: V2EffectRegistry.create());
    final attacker = _card(
      id: 'ai-attacker',
      code: 'BAB-003',
      owner: DuelParticipant.ai,
      category: CardCategory.character,
      atk: 1800,
      def: 1700,
      position: BattlePosition.attack,
      zoneIndex: 0,
    );
    final trap = _card(
      id: 'player-trap',
      code: 'BAB-011',
      owner: DuelParticipant.player,
      category: CardCategory.trap,
      subtype: 'normal',
      effectKey: BabiEffectKeys.bab011,
      faceUp: false,
      zoneIndex: 0,
    );
    final state = DuelState(
      turnNumber: 2,
      activePlayer: DuelParticipant.ai,
      currentPhase: DuelPhase.battle,
      playerField: PlayerFieldState.empty(
        participant: DuelParticipant.player,
        deck: const [],
      ).copyWith(actionTrapZones: [trap, null, null, null, null]),
      aiField: PlayerFieldState.empty(
        participant: DuelParticipant.ai,
        deck: const [],
      ).copyWith(characterZones: [attacker, null, null, null, null]),
    );
    final ai = createDuelAi(
      difficulty: AiDifficulty.beginner,
      engine: engine,
      random: const _ZeroRandom(),
    );
    final controller = LocalDuelController.forTesting(
      engine: engine,
      ai: ai,
      presentations: const {
        'BAB-003': LocalCardPresentation(
          code: 'BAB-003',
          name: 'Gardien du Carrefour',
          category: CardCategory.character,
          family: 'Babi',
          attribute: 'Terre',
          rank: 4,
          atk: 1800,
          def: 1700,
        ),
        'BAB-011': LocalCardPresentation(
          code: 'BAB-011',
          name: 'Feu Rouge Mystique',
          category: CardCategory.trap,
          family: 'Babi',
          attribute: 'Feu',
          subtype: 'normal',
          effectKey: BabiEffectKeys.bab011,
        ),
      },
      state: state,
    );

    controller.playAiUntilPlayerDecision();
    expect(controller.awaitingPlayerPriority, isTrue);
    expect(controller.pendingAiAttack, isNotNull);
    final option = controller.availablePlayerResponses().single;
    expect(option.card.cardCode, 'BAB-011');

    expect(controller.activatePlayerResponse(option: option).succeeded, isTrue);
    expect(controller.awaitingPlayerPriority, isTrue);
    expect(controller.passPlayerPriority().succeeded, isTrue);
    controller.playAiUntilPlayerDecision();

    expect(controller.state.playerLifePoints, 8000);
    final resolvedAttacker = controller.state.aiField.characterZones.first!;
    expect(resolvedAttacker.position, BattlePosition.defense);
    expect(resolvedAttacker.attackedThisTurn, isTrue);
    expect(controller.lastChainEvents.join(' '), contains('Résolu'));
  });

  test("FOR-011 n'ouvre pas Passer en boucle après avoir annulé l'attaque IA",
      () {
    final engine = DuelEngine(chainEffects: V2EffectRegistry.create());
    final attacker = _card(
      id: 'ai-buffle',
      code: 'SAV-003',
      owner: DuelParticipant.ai,
      category: CardCategory.character,
      atk: 2000,
      def: 1600,
      position: BattlePosition.attack,
      zoneIndex: 0,
    );
    final trap = _card(
      id: 'player-liane',
      code: 'FOR-011',
      owner: DuelParticipant.player,
      category: CardCategory.trap,
      subtype: 'normal',
      effectKey: ForetEffectKeys.for011,
      faceUp: false,
      zoneIndex: 0,
    );
    final state = DuelState(
      turnNumber: 2,
      activePlayer: DuelParticipant.ai,
      currentPhase: DuelPhase.battle,
      playerField: PlayerFieldState.empty(
        participant: DuelParticipant.player,
        deck: const [],
      ).copyWith(actionTrapZones: [trap, null, null, null, null]),
      aiField: PlayerFieldState.empty(
        participant: DuelParticipant.ai,
        deck: const [],
      ).copyWith(characterZones: [attacker, null, null, null, null]),
    );
    final controller = LocalDuelController.forTesting(
      engine: engine,
      ai: createDuelAi(
        difficulty: AiDifficulty.beginner,
        engine: engine,
        random: const _ZeroRandom(),
      ),
      presentations: const {
        'SAV-003': LocalCardPresentation(
          code: 'SAV-003',
          name: 'Buffle des Plaines Rouges',
          category: CardCategory.character,
          family: 'Savane',
          attribute: 'Terre',
          rank: 4,
          atk: 2000,
          def: 1600,
        ),
        'FOR-011': LocalCardPresentation(
          code: 'FOR-011',
          name: 'Liane Entravante',
          category: CardCategory.trap,
          family: 'Forêt',
          attribute: 'Nature',
          subtype: 'normal',
          effectKey: ForetEffectKeys.for011,
        ),
      },
      state: state,
    );

    controller.playAiUntilPlayerDecision();
    expect(controller.awaitingPlayerPriority, isTrue);
    final option = controller.availablePlayerResponses().single;
    expect(option.card.cardCode, 'FOR-011');
    expect(controller.activatePlayerResponse(option: option).succeeded, isTrue);
    expect(controller.passPlayerPriority().succeeded, isTrue);

    controller.playAiUntilPlayerDecision();

    expect(controller.awaitingPlayerPriority, isFalse);
    expect(controller.pendingAiAttack, isNull);
    expect(
      controller.state.aiField.characterZones.first!.attackedThisTurn,
      isTrue,
    );
    expect(
      controller.state.playerField.graveyard
          .whereType<CardInstance>()
          .map((card) => card.cardCode),
      contains('FOR-011'),
    );
  });

  test(
      'une réponse IA à une attaque rend la priorité au joueur avant résolution',
      () {
    final engine = DuelEngine(chainEffects: V2EffectRegistry.create());
    final attacker = _card(
      id: 'player-attacker',
      code: 'BAB-003',
      owner: DuelParticipant.player,
      category: CardCategory.character,
      atk: 1800,
      def: 1700,
      position: BattlePosition.attack,
      zoneIndex: 0,
    );
    final quickAction = _card(
      id: 'player-quick',
      code: 'BAB-008',
      owner: DuelParticipant.player,
      category: CardCategory.action,
      subtype: 'quick',
      effectKey: BabiEffectKeys.bab008,
    );
    final aiTrap = _card(
      id: 'ai-trap',
      code: 'BAB-011',
      owner: DuelParticipant.ai,
      category: CardCategory.trap,
      subtype: 'normal',
      effectKey: BabiEffectKeys.bab011,
      faceUp: false,
      zoneIndex: 0,
    );
    final state = DuelState(
      turnNumber: 2,
      activePlayer: DuelParticipant.player,
      currentPhase: DuelPhase.battle,
      playerField: PlayerFieldState.empty(
        participant: DuelParticipant.player,
        deck: const [],
      ).copyWith(
        hand: [quickAction],
        characterZones: [attacker, null, null, null, null],
      ),
      aiField: PlayerFieldState.empty(
        participant: DuelParticipant.ai,
        deck: const [],
      ).copyWith(actionTrapZones: [aiTrap, null, null, null, null]),
    );
    final controller = LocalDuelController.forTesting(
      engine: engine,
      ai: const _AttackResponderAi(),
      presentations: const {
        'BAB-003': LocalCardPresentation(
          code: 'BAB-003',
          name: 'Gardien du Carrefour',
          category: CardCategory.character,
          family: 'Babi',
          attribute: 'Terre',
          rank: 4,
          atk: 1800,
          def: 1700,
        ),
        'BAB-008': LocalCardPresentation(
          code: 'BAB-008',
          name: 'Trajet Express',
          category: CardCategory.action,
          family: 'Babi',
          attribute: 'Vent',
          subtype: 'quick',
          effectKey: BabiEffectKeys.bab008,
        ),
        'BAB-011': LocalCardPresentation(
          code: 'BAB-011',
          name: 'Feu Rouge Mystique',
          category: CardCategory.trap,
          family: 'Babi',
          attribute: 'Feu',
          subtype: 'normal',
          effectKey: BabiEffectKeys.bab011,
        ),
      },
      state: state,
    );

    final attack = controller.attack(attackerInstanceId: attacker.instanceId);

    expect(attack.succeeded, isTrue);
    expect(controller.pendingPlayerAttack, isNotNull);
    expect(controller.awaitingPlayerPriority, isTrue);
    expect(controller.state.chain.links.single.sourceCardCode, 'BAB-011');

    final counterResponse = controller.availablePlayerResponses().singleWhere(
          (option) => option.card.cardCode == 'BAB-008',
        );
    expect(
      controller.activatePlayerResponse(option: counterResponse).succeeded,
      isTrue,
    );
    expect(controller.awaitingPlayerPriority, isTrue);
    expect(controller.state.chain.links, hasLength(2));

    expect(controller.passPlayerPriority().succeeded, isTrue);
    expect(controller.state.chain.isOpen, isFalse);
    expect(controller.pendingPlayerAttack, isNull);
    expect(controller.state.playerLifePoints, 8000);
    expect(controller.state.aiLifePoints, 8000);
  });
}
