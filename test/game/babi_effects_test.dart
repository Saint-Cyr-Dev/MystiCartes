import 'package:mysticartes/game/battle_state.dart';
import 'package:mysticartes/game/card.dart';
import 'package:mysticartes/game/duel_engine.dart';
import 'package:mysticartes/game/duel_types.dart';
import 'package:mysticartes/game/effects/babi_effects.dart';
import 'package:mysticartes/game/player.dart';
import 'package:test/test.dart';

CardInstance babiCard(
  String code, {
  String? instanceId,
  DuelParticipant owner = DuelParticipant.player,
  CardCategory category = CardCategory.character,
  String? subtype,
  String family = 'babi',
  int? rank = 4,
  int? atk = 1500,
  int? def = 1500,
  bool faceUp = true,
  BattlePosition? position = BattlePosition.attack,
  int? zoneIndex,
}) {
  return CardInstance(
    instanceId: instanceId ?? code.toLowerCase(),
    cardId: 'catalog-$code',
    cardCode: code,
    cardRevision: 1,
    category: category,
    rank: rank,
    subtype: subtype,
    primaryFamily: family,
    effectKey: code == 'BAB-003'
        ? null
        : 'bab_${code.substring(4).padLeft(3, '0')}_test',
    atk: atk,
    def: def,
    owner: owner,
    controller: owner,
    faceUp: faceUp,
    position: position,
    zoneIndex: zoneIndex,
  );
}

PlayerFieldState babiField({
  required DuelParticipant participant,
  List<FieldCardInstance?>? characters,
  List<CardInstance?>? actionTraps,
  CardInstance? terrain,
  List<CardInstance> deck = const [],
  List<CardInstance> hand = const [],
  List<CardInstance> graveyard = const [],
  List<CardInstance> mythicReserve = const [],
}) {
  return PlayerFieldState(
    participant: participant,
    characterZones: characters ?? const [null, null, null, null, null],
    actionTrapZones: actionTraps ?? const [null, null, null, null, null],
    terrainZone: terrain,
    deck: deck,
    hand: hand,
    graveyard: graveyard,
    banished: const [],
    mythicReserve: mythicReserve,
  );
}

DuelState babiDuel({
  PlayerFieldState? playerField,
  PlayerFieldState? aiField,
  DuelPhase phase = DuelPhase.main1,
  int turnNumber = 2,
}) {
  return DuelState(
    playerField: playerField ?? babiField(participant: DuelParticipant.player),
    aiField: aiField ?? babiField(participant: DuelParticipant.ai),
    activePlayer: DuelParticipant.player,
    currentPhase: phase,
    turnNumber: turnNumber,
  );
}

ChainLink babiLink({
  required String id,
  required String effectKey,
  required DuelParticipant player,
  required ChainSpeed speed,
  String? sourceId,
  String? sourceCode,
  ChainTarget? target,
  Map<String, Object?> payload = const {},
}) {
  return ChainLink(
    linkId: id,
    effectKey: effectKey,
    activatingPlayer: player,
    speed: speed,
    sourceCardInstanceId: sourceId,
    sourceCardCode: sourceCode,
    target: target,
    payload: payload,
  );
}

PriorityPassResult activateAndResolve(
  DuelEngine engine,
  DuelState state,
  ChainLink link,
) {
  final activation = engine.activateChainEffect(state: state, link: link);
  expect(activation.succeeded, isTrue, reason: activation.failure?.name);
  final opponent = link.activatingPlayer == DuelParticipant.player
      ? DuelParticipant.ai
      : DuelParticipant.player;
  final firstPass = engine.passPriority(
    state: activation.state,
    participant: opponent,
  );
  return engine.passPriority(
    state: firstPass.state,
    participant: link.activatingPlayer,
  );
}

final class RecordingFusionExtension implements BabiFusionSummonExtension {
  bool called = false;
  String? triggerCode;
  String? mythicCode;

  @override
  DuelState summonFromMythicReserve({
    required DuelState state,
    required DuelParticipant participant,
    required String triggerCardCode,
    required String mythicCardCode,
  }) {
    called = true;
    triggerCode = triggerCardCode;
    mythicCode = mythicCardCode;
    return state;
  }
}

void main() {
  test('BAB-001 pioche une carte puis défausse la carte choisie', () {
    final source = babiCard('BAB-001', instanceId: 'bab001', zoneIndex: 0);
    final discarded = babiCard('BAB-003', instanceId: 'discarded');
    final drawn = babiCard('BAB-008', instanceId: 'drawn');
    final state = babiDuel(
      playerField: babiField(
        participant: DuelParticipant.player,
        characters: [source, null, null, null, null],
        deck: [drawn],
        hand: [discarded],
      ),
    );
    final engine = DuelEngine(chainEffects: BabiEffectRegistry.create());

    final result = activateAndResolve(
      engine,
      state,
      babiLink(
        id: 'bab001-trigger',
        effectKey: BabiEffectKeys.bab001,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'bab001',
        sourceCode: 'BAB-001',
        payload: const {
          'trigger': 'on_summon',
          'use_effect': true,
          'discard_instance_id': 'discarded',
        },
      ),
    );

    expect(result.state.playerField.deck, isEmpty);
    expect(result.state.playerField.hand.single.instanceId, 'drawn');
    expect(result.state.playerField.graveyard.single.instanceId, 'discarded');
  });

  test('BAB-002 change la position d’un autre Personnage contrôlé', () {
    final source = babiCard('BAB-002', instanceId: 'bab002', zoneIndex: 0);
    final target = babiCard('BAB-003', instanceId: 'target', zoneIndex: 1);
    final state = babiDuel(
      playerField: babiField(
        participant: DuelParticipant.player,
        characters: [source, target, null, null, null],
      ),
    );
    final engine = DuelEngine(chainEffects: BabiEffectRegistry.create());

    final result = activateAndResolve(
      engine,
      state,
      babiLink(
        id: 'bab002-trigger',
        effectKey: BabiEffectKeys.bab002,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'bab002',
        sourceCode: 'BAB-002',
        target: ChainTarget(cardInstanceId: 'target'),
        payload: const {'trigger': 'on_summon'},
      ),
    );

    final changed = result.state.playerField.characterZones[1]!;
    expect(changed.position, BattlePosition.defense);
    expect(changed.positionChangedThisTurn, isTrue);
  });

  test('BAB-004 gagne 300 ATK après une Action rapide', () {
    final source = babiCard(
      'BAB-004',
      instanceId: 'bab004',
      atk: 1700,
      zoneIndex: 0,
    );
    final state = babiDuel(
      playerField: babiField(
        participant: DuelParticipant.player,
        characters: [source, null, null, null, null],
      ),
    );
    final engine = DuelEngine(chainEffects: BabiEffectRegistry.create());

    final result = activateAndResolve(
      engine,
      state,
      babiLink(
        id: 'bab004-trigger',
        effectKey: BabiEffectKeys.bab004,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'bab004',
        sourceCode: 'BAB-004',
        payload: const {'trigger': 'quick_action_activated'},
      ),
    );

    expect(
      result.state.playerField.characterZones.first!.effectiveAtk,
      2000,
    );

    var endOfTurnState = result.state;
    for (var step = 0; step < 4; step++) {
      final transition = engine.advancePhase(endOfTurnState);
      expect(transition.succeeded, isTrue);
      endOfTurnState = transition.state;
    }
    expect(
      endOfTurnState.playerField.characterZones.first!.effectiveAtk,
      1700,
    );
  });

  test('BAB-005 regarde puis renvoie une carte adverse posée', () {
    final source = babiCard('BAB-005', instanceId: 'bab005', zoneIndex: 0);
    final setCard = babiCard(
      'BAB-011',
      instanceId: 'set-card',
      owner: DuelParticipant.ai,
      category: CardCategory.trap,
      rank: null,
      atk: null,
      def: null,
      faceUp: false,
      position: null,
      zoneIndex: 0,
    );
    final state = babiDuel(
      playerField: babiField(
        participant: DuelParticipant.player,
        characters: [source, null, null, null, null],
      ),
      aiField: babiField(
        participant: DuelParticipant.ai,
        actionTraps: [setCard, null, null, null, null],
      ),
    );
    final engine = DuelEngine(chainEffects: BabiEffectRegistry.create());

    final result = activateAndResolve(
      engine,
      state,
      babiLink(
        id: 'bab005-trigger',
        effectKey: BabiEffectKeys.bab005,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'bab005',
        sourceCode: 'BAB-005',
        target: ChainTarget(cardInstanceId: 'set-card'),
        payload: const {'trigger': 'on_summon', 'return_to_hand': true},
      ),
    );

    expect(
      result.state.playerField.revealedCardInstanceIds,
      contains('set-card'),
    );
    expect(result.state.aiField.actionTrapZones.first, isNull);
    expect(result.state.aiField.hand.single.instanceId, 'set-card');
  });

  test('BAB-006 pioche puis défausse après une destruction au combat', () {
    final source = babiCard('BAB-006', instanceId: 'bab006', zoneIndex: 0);
    final discarded = babiCard('BAB-003', instanceId: 'discarded');
    final drawn = babiCard('BAB-008', instanceId: 'drawn');
    final state = babiDuel(
      playerField: babiField(
        participant: DuelParticipant.player,
        characters: [source, null, null, null, null],
        deck: [drawn],
        hand: [discarded],
      ),
    );
    final engine = DuelEngine(chainEffects: BabiEffectRegistry.create());

    final result = activateAndResolve(
      engine,
      state,
      babiLink(
        id: 'bab006-trigger',
        effectKey: BabiEffectKeys.bab006,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'bab006',
        sourceCode: 'BAB-006',
        payload: const {
          'trigger': 'destroyed_character_in_combat',
          'discard_instance_id': 'discarded',
        },
      ),
    );

    expect(result.state.playerField.hand.single.instanceId, 'drawn');
    expect(result.state.playerField.graveyard.single.instanceId, 'discarded');
    expect(
      (result.state.playerField.characterZones.first! as CardInstance)
          .effectUsageTurns,
      isNotEmpty,
    );
  });

  test('BAB-007 renvoie une carte Babi puis attaque directement à moitié', () {
    final queen = babiCard(
      'BAB-007',
      instanceId: 'queen',
      atk: 2701,
      zoneIndex: 0,
    );
    final returned = babiCard('BAB-003', instanceId: 'returned', zoneIndex: 1);
    final defender = babiCard(
      'ROY-001',
      instanceId: 'defender',
      owner: DuelParticipant.ai,
      family: 'royaume',
      zoneIndex: 0,
    );
    final state = babiDuel(
      playerField: babiField(
        participant: DuelParticipant.player,
        characters: [queen, returned, null, null, null],
      ),
      aiField: babiField(
        participant: DuelParticipant.ai,
        characters: [defender, null, null, null, null],
      ),
    );
    final engine = DuelEngine(chainEffects: BabiEffectRegistry.create());
    final effectResult = activateAndResolve(
      engine,
      state,
      babiLink(
        id: 'bab007-effect',
        effectKey: BabiEffectKeys.bab007,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'queen',
        sourceCode: 'BAB-007',
        target: ChainTarget(cardInstanceId: 'returned'),
      ),
    );
    final battleState = effectResult.state.copyWith(
      currentPhase: DuelPhase.battle,
    );
    final declaration = engine.declareAttack(
      state: battleState,
      participant: DuelParticipant.player,
      attackerInstanceId: 'queen',
    );
    final firstPass = engine.passPriority(
      state: declaration.state,
      participant: DuelParticipant.ai,
    );
    final secondPass = engine.passPriority(
      state: firstPass.state,
      participant: DuelParticipant.player,
    );
    final combat = engine.resolveAttack(
      state: secondPass.state,
      declaration: declaration.declaration!,
    );

    expect(effectResult.state.playerField.hand.single.instanceId, 'returned');
    expect(declaration.succeeded, isTrue);
    expect(combat.state.aiLifePoints, 6649);

    var endOfTurnState = combat.state;
    for (var step = 0; step < 3; step++) {
      final transition = engine.advancePhase(endOfTurnState);
      expect(transition.succeeded, isTrue);
      endOfTurnState = transition.state;
    }
    final expiredQueen =
        endOfTurnState.playerField.characterZones.first! as CardInstance;
    expect(
      expiredQueen.runtimeData,
      isNot(contains(CardRuntimeKeys.directAttackAllowedTurn)),
    );
  });

  test('BAB-008 change la position et donne 300 ATK en passant en Attaque', () {
    final action = babiCard(
      'BAB-008',
      instanceId: 'bab008',
      category: CardCategory.action,
      subtype: 'quick',
      rank: null,
      atk: null,
      def: null,
      position: null,
      zoneIndex: 0,
    );
    final target = babiCard(
      'BAB-003',
      instanceId: 'target',
      atk: 1800,
      position: BattlePosition.defense,
      zoneIndex: 0,
    );
    final state = babiDuel(
      playerField: babiField(
        participant: DuelParticipant.player,
        characters: [target, null, null, null, null],
        actionTraps: [action, null, null, null, null],
      ),
    );
    final engine = DuelEngine(chainEffects: BabiEffectRegistry.create());

    final result = activateAndResolve(
      engine,
      state,
      babiLink(
        id: 'bab008-action',
        effectKey: BabiEffectKeys.bab008,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed2,
        sourceId: 'bab008',
        sourceCode: 'BAB-008',
        target: ChainTarget(cardInstanceId: 'target'),
      ),
    );

    final changed = result.state.playerField.characterZones.first!;
    expect(changed.position, BattlePosition.attack);
    expect(changed.effectiveAtk, 2100);
  });

  test('BAB-009 renvoie une carte adverse posée dans sa main', () {
    final action = babiCard(
      'BAB-009',
      instanceId: 'bab009',
      category: CardCategory.action,
      rank: null,
      atk: null,
      def: null,
      position: null,
      zoneIndex: 0,
    );
    final setCard = babiCard(
      'ROY-011',
      instanceId: 'set-card',
      owner: DuelParticipant.ai,
      category: CardCategory.trap,
      family: 'royaume',
      rank: null,
      atk: null,
      def: null,
      faceUp: false,
      position: null,
      zoneIndex: 0,
    );
    final state = babiDuel(
      playerField: babiField(
        participant: DuelParticipant.player,
        actionTraps: [action, null, null, null, null],
      ),
      aiField: babiField(
        participant: DuelParticipant.ai,
        actionTraps: [setCard, null, null, null, null],
      ),
    );
    final engine = DuelEngine(chainEffects: BabiEffectRegistry.create());

    final result = activateAndResolve(
      engine,
      state,
      babiLink(
        id: 'bab009-action',
        effectKey: BabiEffectKeys.bab009,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'bab009',
        sourceCode: 'BAB-009',
        target: ChainTarget(cardInstanceId: 'set-card'),
      ),
    );

    expect(result.state.aiField.actionTrapZones.first, isNull);
    expect(result.state.aiField.hand.single.instanceId, 'set-card');
  });

  test('BAB-010 paie les deux matériels puis appelle l’extension Fusion', () {
    final material1 =
        babiCard('BAB-002', instanceId: 'material-1', zoneIndex: 0);
    final material2 =
        babiCard('BAB-006', instanceId: 'material-2', zoneIndex: 1);
    final action = babiCard(
      'BAB-010',
      instanceId: 'bab010',
      category: CardCategory.action,
      rank: null,
      atk: null,
      def: null,
      position: null,
      zoneIndex: 0,
    );
    final state = babiDuel(
      playerField: babiField(
        participant: DuelParticipant.player,
        characters: [material1, material2, null, null, null],
        actionTraps: [action, null, null, null, null],
      ),
    );
    final extension = RecordingFusionExtension();
    final engine = DuelEngine(
      chainEffects: BabiEffectRegistry.create(fusionExtension: extension),
    );

    final result = activateAndResolve(
      engine,
      state,
      babiLink(
        id: 'bab010-action',
        effectKey: BabiEffectKeys.bab010,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'bab010',
        sourceCode: 'BAB-010',
        payload: const {
          'material_instance_ids': ['material-1', 'material-2'],
        },
      ),
    );

    expect(
        result.state.playerField.characterZones.take(2), everyElement(isNull));
    expect(result.state.playerField.graveyard, hasLength(2));
    expect(extension.called, isTrue);
    expect(extension.triggerCode, 'BAB-010');
    expect(extension.mythicCode, 'BAB-015');
  });

  test('BAB-011 annule une attaque et passe l’attaquant en Défense', () {
    final attacker = babiCard(
      'ROY-003',
      instanceId: 'attacker',
      owner: DuelParticipant.player,
      family: 'royaume',
      atk: 1800,
      zoneIndex: 0,
    );
    final trap = babiCard(
      'BAB-011',
      instanceId: 'bab011',
      owner: DuelParticipant.ai,
      category: CardCategory.trap,
      subtype: 'normal',
      rank: null,
      atk: null,
      def: null,
      faceUp: false,
      position: null,
      zoneIndex: 0,
    );
    final state = babiDuel(
      phase: DuelPhase.battle,
      playerField: babiField(
        participant: DuelParticipant.player,
        characters: [attacker, null, null, null, null],
      ),
      aiField: babiField(
        participant: DuelParticipant.ai,
        actionTraps: [trap, null, null, null, null],
      ),
    );
    final engine = DuelEngine(chainEffects: BabiEffectRegistry.create());
    final declaration = engine.declareAttack(
      state: state,
      participant: DuelParticipant.player,
      attackerInstanceId: 'attacker',
    );
    final trapActivation = engine.activateChainEffect(
      state: declaration.state,
      link: babiLink(
        id: 'bab011-trap',
        effectKey: BabiEffectKeys.bab011,
        player: DuelParticipant.ai,
        speed: ChainSpeed.speed2,
        sourceId: 'bab011',
        sourceCode: 'BAB-011',
        payload: {
          'trigger': 'attack_declared',
          'attack_declaration_id': declaration.declaration!.declarationId,
          'attacker_instance_id': 'attacker',
        },
      ),
    );
    final firstPass = engine.passPriority(
      state: trapActivation.state,
      participant: DuelParticipant.player,
    );
    final resolution = engine.passPriority(
      state: firstPass.state,
      participant: DuelParticipant.ai,
    );
    final combat = engine.resolveAttack(
      state: resolution.state,
      declaration: declaration.declaration!,
    );

    expect(
      resolution.state.playerField.characterZones.first!.position,
      BattlePosition.defense,
    );
    expect(combat.status, CombatResolutionStatus.cancelled);
    expect(combat.state.aiLifePoints, 8000);
  });

  test('BAB-012 paie une défausse, annule et détruit l’Action', () {
    final action = babiCard(
      'BAB-009',
      instanceId: 'action-source',
      category: CardCategory.action,
      rank: null,
      atk: null,
      def: null,
      position: null,
      zoneIndex: 0,
    );
    final actionTarget = babiCard(
      'ROY-011',
      instanceId: 'action-target',
      owner: DuelParticipant.ai,
      category: CardCategory.trap,
      family: 'royaume',
      rank: null,
      atk: null,
      def: null,
      faceUp: false,
      position: null,
      zoneIndex: 1,
    );
    final counter = babiCard(
      'BAB-012',
      instanceId: 'counter-source',
      owner: DuelParticipant.ai,
      category: CardCategory.trap,
      subtype: 'counter',
      rank: null,
      atk: null,
      def: null,
      position: null,
      zoneIndex: 0,
    );
    final discard = babiCard(
      'ROY-001',
      instanceId: 'discard-cost',
      owner: DuelParticipant.ai,
      family: 'royaume',
    );
    final state = babiDuel(
      playerField: babiField(
        participant: DuelParticipant.player,
        actionTraps: [action, null, null, null, null],
      ),
      aiField: babiField(
        participant: DuelParticipant.ai,
        actionTraps: [counter, actionTarget, null, null, null],
        hand: [discard],
      ),
    );
    final engine = DuelEngine(chainEffects: BabiEffectRegistry.create());
    final actionActivation = engine.activateChainEffect(
      state: state,
      link: babiLink(
        id: 'action-link',
        effectKey: BabiEffectKeys.bab009,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'action-source',
        sourceCode: 'BAB-009',
        target: ChainTarget(cardInstanceId: 'action-target'),
      ),
    );
    final counterActivation = engine.activateChainEffect(
      state: actionActivation.state,
      link: babiLink(
        id: 'counter-link',
        effectKey: BabiEffectKeys.bab012,
        player: DuelParticipant.ai,
        speed: ChainSpeed.speed3,
        sourceId: 'counter-source',
        sourceCode: 'BAB-012',
        payload: const {
          'target_link_id': 'action-link',
          'discard_instance_id': 'discard-cost',
        },
      ),
    );
    final firstPass = engine.passPriority(
      state: counterActivation.state,
      participant: DuelParticipant.player,
    );
    final resolution = engine.passPriority(
      state: firstPass.state,
      participant: DuelParticipant.ai,
    );

    expect(resolution.fizzledLinkIds, contains('action-link'));
    expect(resolution.state.playerField.actionTrapZones.first, isNull);
    expect(
      resolution.state.playerField.graveyard.single.instanceId,
      'action-source',
    );
    expect(
      resolution.state.aiField.graveyard.single.instanceId,
      'discard-cost',
    );
    expect(
      resolution.state.aiField.actionTrapZones[1]!.instanceId,
      'action-target',
    );
  });

  test('BAB-013 donne 200 ATK/DEF et protège la première Action rapide', () {
    final terrain = babiCard(
      'BAB-013',
      instanceId: 'bab013',
      category: CardCategory.terrain,
      rank: null,
      atk: null,
      def: null,
      position: null,
    );
    final ownBabi = babiCard('BAB-003', instanceId: 'own-babi', zoneIndex: 0);
    final enemyBabi = babiCard(
      'BAB-003',
      instanceId: 'enemy-babi',
      owner: DuelParticipant.ai,
      zoneIndex: 0,
    );
    final quickAction = babiCard(
      'BAB-008',
      instanceId: 'quick-action',
      category: CardCategory.action,
      subtype: 'quick',
      rank: null,
      atk: null,
      def: null,
      position: null,
      zoneIndex: 0,
    );
    final state = babiDuel(
      playerField: babiField(
        participant: DuelParticipant.player,
        characters: [ownBabi, null, null, null, null],
        actionTraps: [quickAction, null, null, null, null],
        terrain: terrain,
      ),
      aiField: babiField(
        participant: DuelParticipant.ai,
        characters: [enemyBabi, null, null, null, null],
      ),
    );
    final engine = DuelEngine(chainEffects: BabiEffectRegistry.create());
    final terrainResult = activateAndResolve(
      engine,
      state,
      babiLink(
        id: 'terrain-effect',
        effectKey: BabiEffectKeys.bab013,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'bab013',
        sourceCode: 'BAB-013',
      ),
    );
    final quickActivation = engine.activateChainEffect(
      state: terrainResult.state,
      link: babiLink(
        id: 'quick-action-link',
        effectKey: BabiEffectKeys.bab008,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed2,
        sourceId: 'quick-action',
        sourceCode: 'BAB-008',
        target: ChainTarget(cardInstanceId: 'own-babi'),
      ),
    );

    expect(
      terrainResult.state.playerField.characterZones.first!.effectiveAtk,
      1700,
    );
    expect(
      terrainResult.state.aiField.characterZones.first!.effectiveDef,
      1700,
    );
    expect(quickActivation.link!.protectedFromSpeed2Negation, isTrue);
  });

  test('BAB-014 s’équipe puis regarde et replace le dessus du deck', () {
    final relic = babiCard(
      'BAB-014',
      instanceId: 'bab014',
      category: CardCategory.relic,
      subtype: 'equipment',
      rank: null,
      atk: null,
      def: null,
      position: null,
      zoneIndex: 0,
    );
    final target = babiCard('BAB-003', instanceId: 'target', zoneIndex: 0);
    final top = babiCard('BAB-001', instanceId: 'top');
    final next = babiCard('BAB-002', instanceId: 'next');
    final state = babiDuel(
      playerField: babiField(
        participant: DuelParticipant.player,
        characters: [target, null, null, null, null],
        actionTraps: [relic, null, null, null, null],
        deck: [top, next],
      ),
    );
    final engine = DuelEngine(chainEffects: BabiEffectRegistry.create());
    final equipResult = activateAndResolve(
      engine,
      state,
      babiLink(
        id: 'equip',
        effectKey: BabiEffectKeys.bab014,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'bab014',
        sourceCode: 'BAB-014',
        target: ChainTarget(cardInstanceId: 'target'),
        payload: const {'mode': 'equip'},
      ),
    );
    final inspectResult = activateAndResolve(
      engine,
      equipResult.state,
      babiLink(
        id: 'inspect',
        effectKey: BabiEffectKeys.bab014,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'bab014',
        sourceCode: 'BAB-014',
        payload: const {'mode': 'inspect_top', 'place_under_deck': true},
      ),
    );

    expect(
      (equipResult.state.playerField.characterZones.first! as CardInstance)
          .attachedCardInstanceIds,
      contains('bab014'),
    );
    expect(inspectResult.state.playerField.deck.first.instanceId, 'next');
    expect(inspectResult.state.playerField.deck.last.instanceId, 'top');
    expect(
      inspectResult.state.playerField.revealedCardInstanceIds,
      contains('top'),
    );
  });

  test('BAB-015 renvoie deux cartes posées puis gagne 500 ATK', () {
    final genie = babiCard(
      'BAB-015',
      instanceId: 'bab015',
      category: CardCategory.mythic,
      rank: 9,
      atk: 3200,
      def: 2800,
      zoneIndex: 0,
    );
    final set1 = babiCard(
      'ROY-011',
      instanceId: 'set-1',
      owner: DuelParticipant.ai,
      category: CardCategory.trap,
      family: 'royaume',
      rank: null,
      atk: null,
      def: null,
      faceUp: false,
      position: null,
      zoneIndex: 0,
    );
    final set2 = babiCard(
      'ROY-012',
      instanceId: 'set-2',
      owner: DuelParticipant.ai,
      category: CardCategory.trap,
      family: 'royaume',
      rank: null,
      atk: null,
      def: null,
      faceUp: false,
      position: null,
      zoneIndex: 1,
    );
    final state = babiDuel(
      playerField: babiField(
        participant: DuelParticipant.player,
        characters: [genie, null, null, null, null],
      ),
      aiField: babiField(
        participant: DuelParticipant.ai,
        actionTraps: [set1, set2, null, null, null],
      ),
    );
    final engine = DuelEngine(chainEffects: BabiEffectRegistry.create());
    final summonResult = activateAndResolve(
      engine,
      state,
      babiLink(
        id: 'summon-trigger',
        effectKey: BabiEffectKeys.bab015,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'bab015',
        sourceCode: 'BAB-015',
        payload: const {
          'trigger': 'on_summon',
          'target_instance_ids': ['set-1', 'set-2'],
        },
      ),
    );
    final boostResult = activateAndResolve(
      engine,
      summonResult.state,
      babiLink(
        id: 'quick-trigger',
        effectKey: BabiEffectKeys.bab015,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'bab015',
        sourceCode: 'BAB-015',
        payload: const {'trigger': 'quick_action_activated'},
      ),
    );

    expect(summonResult.state.aiField.hand, hasLength(2));
    expect(
      boostResult.state.playerField.characterZones.first!.effectiveAtk,
      3700,
    );
  });
}
