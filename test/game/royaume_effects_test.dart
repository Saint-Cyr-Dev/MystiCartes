import 'package:mysticartes/game/battle_state.dart';
import 'package:mysticartes/game/card.dart';
import 'package:mysticartes/game/duel_engine.dart';
import 'package:mysticartes/game/duel_types.dart';
import 'package:mysticartes/game/effects/royaume_effects.dart';
import 'package:mysticartes/game/player.dart';
import 'package:test/test.dart';

const _royalEffectKeys = <String, String>{
  'ROY-001': RoyaumeEffectKeys.roy001,
  'ROY-003': RoyaumeEffectKeys.roy003,
  'ROY-004': RoyaumeEffectKeys.roy004,
  'ROY-005': RoyaumeEffectKeys.roy005,
  'ROY-006': RoyaumeEffectKeys.roy006,
  'ROY-007': RoyaumeEffectKeys.roy007,
  'ROY-008': RoyaumeEffectKeys.roy008,
  'ROY-009': RoyaumeEffectKeys.roy009,
  'ROY-010': RoyaumeEffectKeys.roy010,
  'ROY-011': RoyaumeEffectKeys.roy011,
  'ROY-012': RoyaumeEffectKeys.roy012,
  'ROY-013': RoyaumeEffectKeys.roy013,
  'ROY-014': RoyaumeEffectKeys.roy014,
  'ROY-015': RoyaumeEffectKeys.roy015,
};

CardInstance royalCard(
  String code, {
  String? instanceId,
  DuelParticipant owner = DuelParticipant.player,
  DuelParticipant? controller,
  CardCategory category = CardCategory.character,
  String? subtype,
  String family = 'royaume',
  List<String> secondaryFamilies = const [],
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
    secondaryFamilies: secondaryFamilies,
    effectKey: _royalEffectKeys[code],
    atk: atk,
    def: def,
    owner: owner,
    controller: controller ?? owner,
    faceUp: faceUp,
    position: position,
    zoneIndex: zoneIndex,
  );
}

PlayerFieldState royalField({
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

DuelState royalDuel({
  PlayerFieldState? playerField,
  PlayerFieldState? aiField,
  DuelParticipant activePlayer = DuelParticipant.player,
  DuelPhase phase = DuelPhase.main1,
  int turnNumber = 2,
}) {
  return DuelState(
    playerField: playerField ?? royalField(participant: DuelParticipant.player),
    aiField: aiField ?? royalField(participant: DuelParticipant.ai),
    activePlayer: activePlayer,
    currentPhase: phase,
    turnNumber: turnNumber,
  );
}

ChainLink royalLink({
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

PriorityPassResult activateAndResolveRoyal(
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

final class _NoopEffect extends ChainEffectDefinition {
  const _NoopEffect();

  @override
  bool isTargetLegal(DuelState state, ChainLink link) => true;

  @override
  DuelState resolve(DuelState state, ChainLink link) => state;
}

final class RecordingAncestralExtension
    implements RoyaumeAncestralSummonExtension {
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
  test('ROY-001 pioche après son sacrifice pour un Personnage Royaume', () {
    final page = royalCard('ROY-001', instanceId: 'page').copyWith(
      position: null,
      zoneIndex: null,
    );
    final drawn = royalCard('ROY-002', instanceId: 'drawn');
    final state = royalDuel(
      playerField: royalField(
        participant: DuelParticipant.player,
        deck: [drawn],
        graveyard: [page],
      ),
    );
    final engine = DuelEngine(chainEffects: RoyaumeEffectRegistry.create());

    final result = activateAndResolveRoyal(
      engine,
      state,
      royalLink(
        id: 'roy001-trigger',
        effectKey: RoyaumeEffectKeys.roy001,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'page',
        sourceCode: 'ROY-001',
        payload: const {'trigger': 'sacrificed_for_kingdom_summon'},
      ),
    );

    expect(result.state.playerField.deck, isEmpty);
    expect(result.state.playerField.hand.single.instanceId, 'drawn');
  });

  test('ROY-003 protège les autres Personnages Royaume des attaques', () {
    final attacker = royalCard(
      'ATT-001',
      instanceId: 'attacker',
      owner: DuelParticipant.player,
      family: 'babi',
      atk: 2000,
      zoneIndex: 0,
    );
    final guard = royalCard(
      'ROY-003',
      instanceId: 'guard',
      owner: DuelParticipant.ai,
      zoneIndex: 0,
    );
    final protected = royalCard(
      'ROY-002',
      instanceId: 'protected',
      owner: DuelParticipant.ai,
      zoneIndex: 1,
    );
    final state = royalDuel(
      phase: DuelPhase.battle,
      playerField: royalField(
        participant: DuelParticipant.player,
        characters: [attacker, null, null, null, null],
      ),
      aiField: royalField(
        participant: DuelParticipant.ai,
        characters: [guard, protected, null, null, null],
      ),
    );
    final engine = DuelEngine(chainEffects: RoyaumeEffectRegistry.create());

    final blocked = engine.declareAttack(
      state: state,
      participant: DuelParticipant.player,
      attackerInstanceId: 'attacker',
      targetInstanceId: 'protected',
    );
    final guardAttack = engine.declareAttack(
      state: state,
      participant: DuelParticipant.player,
      attackerInstanceId: 'attacker',
      targetInstanceId: 'guard',
    );

    expect(blocked.failure, DuelActionFailure.invalidAttackTarget);
    expect(guardAttack.succeeded, isTrue);
  });

  test('ROY-004 choisit une Royaume parmi les trois cartes regardées', () {
    final source = royalCard('ROY-004', instanceId: 'strategist', zoneIndex: 0);
    final first = royalCard('ROY-001', instanceId: 'first');
    final other = royalCard(
      'BAB-001',
      instanceId: 'other',
      family: 'babi',
    );
    final selected = royalCard('ROY-002', instanceId: 'selected');
    final tail = royalCard('ROY-003', instanceId: 'tail');
    final state = royalDuel(
      playerField: royalField(
        participant: DuelParticipant.player,
        characters: [source, null, null, null, null],
        deck: [first, other, selected, tail],
      ),
    );
    final engine = DuelEngine(chainEffects: RoyaumeEffectRegistry.create());

    final result = activateAndResolveRoyal(
      engine,
      state,
      royalLink(
        id: 'roy004-trigger',
        effectKey: RoyaumeEffectKeys.roy004,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'strategist',
        sourceCode: 'ROY-004',
        payload: const {
          'trigger': 'on_summon',
          'selected_instance_id': 'selected',
          'remaining_order_instance_ids': ['other', 'first'],
        },
      ),
    );

    expect(result.state.playerField.hand.single.instanceId, 'selected');
    expect(
      result.state.playerField.deck.map((card) => card.instanceId),
      ['tail', 'other', 'first'],
    );
  });

  test('ROY-005 gagne 400 ATK pendant son tour d’invocation', () {
    final source = royalCard(
      'ROY-005',
      instanceId: 'cavalier',
      rank: 5,
      atk: 2200,
      zoneIndex: 0,
    );
    final state = royalDuel(
      playerField: royalField(
        participant: DuelParticipant.player,
        characters: [source, null, null, null, null],
      ),
    );
    final engine = DuelEngine(chainEffects: RoyaumeEffectRegistry.create());

    final result = activateAndResolveRoyal(
      engine,
      state,
      royalLink(
        id: 'roy005-trigger',
        effectKey: RoyaumeEffectKeys.roy005,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'cavalier',
        sourceCode: 'ROY-005',
        payload: const {
          'trigger': 'on_summon',
          'sacrificed_for_summon': true,
        },
      ),
    );

    expect(result.state.playerField.characterZones.first!.effectiveAtk, 2600);
  });

  test('ROY-006 défausse puis empêche une destruction par effet', () {
    final queen = royalCard(
      'ROY-006',
      instanceId: 'queen',
      rank: 6,
      zoneIndex: 0,
    );
    final target = royalCard('ROY-002', instanceId: 'target', zoneIndex: 1);
    final discard = royalCard('ROY-001', instanceId: 'discard');
    final state = royalDuel(
      playerField: royalField(
        participant: DuelParticipant.player,
        characters: [queen, target, null, null, null],
        hand: [discard],
      ),
    );
    final engine = DuelEngine(chainEffects: RoyaumeEffectRegistry.create());

    final protection = activateAndResolveRoyal(
      engine,
      state,
      royalLink(
        id: 'roy006-trigger',
        effectKey: RoyaumeEffectKeys.roy006,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed2,
        sourceId: 'queen',
        sourceCode: 'ROY-006',
        target: ChainTarget(cardInstanceId: 'target'),
        payload: const {
          'trigger': 'effect_destruction_pending',
          'discard_instance_id': 'discard',
        },
      ),
    );
    final destruction = engine.destroyCardByEffect(
      state: protection.state,
      cardInstanceId: 'target',
    );

    expect(destruction.status, EffectDestructionStatus.prevented);
    expect(destruction.state.playerField.characterZones[1], isNotNull);
    expect(destruction.state.playerField.hand, isEmpty);
    expect(
        destruction.state.playerField.graveyard.single.instanceId, 'discard');
  });

  test('ROY-007 ranime deux Royaume faibles en Défense avec effets annulés',
      () {
    final king = royalCard(
      'ROY-007',
      instanceId: 'king',
      rank: 8,
      zoneIndex: 0,
    );
    final first = royalCard('ROY-001', instanceId: 'first', rank: 1);
    final second = royalCard('ROY-004', instanceId: 'second', rank: 4);
    final state = royalDuel(
      playerField: royalField(
        participant: DuelParticipant.player,
        characters: [king, null, null, null, null],
        graveyard: [first, second],
      ),
    );
    final engine = DuelEngine(chainEffects: RoyaumeEffectRegistry.create());

    final result = activateAndResolveRoyal(
      engine,
      state,
      royalLink(
        id: 'roy007-trigger',
        effectKey: RoyaumeEffectKeys.roy007,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'king',
        sourceCode: 'ROY-007',
        payload: const {
          'trigger': 'tribute_summon',
          'target_instance_ids': ['first', 'second'],
        },
      ),
    );

    final revived = result.state.playerField.characterZones
        .whereType<CardInstance>()
        .where((card) => card.instanceId != 'king')
        .toList();
    expect(revived, hasLength(2));
    expect(revived.every((card) => card.position == BattlePosition.defense),
        isTrue);
    expect(
      revived.every(
        (card) =>
            card.runtimeData[CardRuntimeKeys.effectsNegatedUntilTurn] == 2,
      ),
      isTrue,
    );
  });

  test('ROY-008 ajoute un Personnage Royaume de rang 4 ou moins', () {
    final action = royalCard(
      'ROY-008',
      instanceId: 'decree',
      category: CardCategory.action,
      subtype: 'normal',
      rank: null,
      atk: null,
      def: null,
      position: null,
      zoneIndex: 0,
    );
    final selected = royalCard('ROY-004', instanceId: 'selected', rank: 4);
    final other = royalCard('ROY-005', instanceId: 'other', rank: 5);
    final state = royalDuel(
      playerField: royalField(
        participant: DuelParticipant.player,
        actionTraps: [action, null, null, null, null],
        deck: [other, selected],
      ),
    );
    final engine = DuelEngine(chainEffects: RoyaumeEffectRegistry.create());

    final result = activateAndResolveRoyal(
      engine,
      state,
      royalLink(
        id: 'roy008-action',
        effectKey: RoyaumeEffectKeys.roy008,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'decree',
        sourceCode: 'ROY-008',
        payload: const {'selected_instance_id': 'selected'},
      ),
    );

    expect(result.state.playerField.hand.single.instanceId, 'selected');
    expect(result.state.playerField.deck.single.instanceId, 'other');
  });

  test('ROY-009 sacrifie un autre Personnage et empêche la destruction', () {
    final action = royalCard(
      'ROY-009',
      instanceId: 'relief',
      category: CardCategory.action,
      subtype: 'quick',
      rank: null,
      atk: null,
      def: null,
      position: null,
      zoneIndex: 0,
    );
    final target = royalCard('ROY-002', instanceId: 'target', zoneIndex: 0);
    final tribute = royalCard(
      'OTH-001',
      instanceId: 'tribute',
      family: 'babi',
      zoneIndex: 1,
    );
    final state = royalDuel(
      playerField: royalField(
        participant: DuelParticipant.player,
        characters: [target, tribute, null, null, null],
        actionTraps: [action, null, null, null, null],
      ),
    );
    final engine = DuelEngine(chainEffects: RoyaumeEffectRegistry.create());

    final protection = activateAndResolveRoyal(
      engine,
      state,
      royalLink(
        id: 'roy009-action',
        effectKey: RoyaumeEffectKeys.roy009,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed2,
        sourceId: 'relief',
        sourceCode: 'ROY-009',
        target: ChainTarget(cardInstanceId: 'target'),
        payload: const {
          'trigger': 'destruction_pending',
          'sacrifice_instance_id': 'tribute',
        },
      ),
    );
    final destruction = engine.destroyCardByEffect(
      state: protection.state,
      cardInstanceId: 'target',
    );

    expect(destruction.status, EffectDestructionStatus.prevented);
    expect(destruction.state.playerField.characterZones[1], isNull);
    expect(
        destruction.state.playerField.graveyard.single.instanceId, 'tribute');
  });

  test('ROY-010 sacrifie au moins 9 rangs puis appelle l’extension', () {
    final extension = RecordingAncestralExtension();
    final action = royalCard(
      'ROY-010',
      instanceId: 'coronation',
      category: CardCategory.action,
      subtype: 'normal',
      rank: null,
      atk: null,
      def: null,
      position: null,
      zoneIndex: 0,
    );
    final rankFour = royalCard('ROY-004', instanceId: 'rank4', rank: 4);
    final rankFive = royalCard(
      'OTH-005',
      instanceId: 'rank5',
      family: 'babi',
      rank: 5,
      zoneIndex: 1,
    );
    final state = royalDuel(
      playerField: royalField(
        participant: DuelParticipant.player,
        characters: [rankFour, rankFive, null, null, null],
        actionTraps: [action, null, null, null, null],
      ),
    );
    final engine = DuelEngine(
      chainEffects: RoyaumeEffectRegistry.create(
        ancestralSummonExtension: extension,
      ),
    );

    final result = activateAndResolveRoyal(
      engine,
      state,
      royalLink(
        id: 'roy010-action',
        effectKey: RoyaumeEffectKeys.roy010,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'coronation',
        sourceCode: 'ROY-010',
        payload: const {
          'sacrifice_instance_ids': ['rank4', 'rank5']
        },
      ),
    );

    expect(result.state.playerField.graveyard, hasLength(2));
    expect(extension.called, isTrue);
    expect(extension.triggerCode, 'ROY-010');
    expect(extension.mythicCode, 'ROY-015');
  });

  test('ROY-011 réduit l’attaquant et annule si son ATK devient inférieure',
      () {
    final attacker = royalCard(
      'ATT-001',
      instanceId: 'attacker',
      owner: DuelParticipant.player,
      family: 'babi',
      atk: 2500,
      zoneIndex: 0,
    );
    final target = royalCard(
      'ROY-002',
      instanceId: 'target',
      owner: DuelParticipant.ai,
      atk: 2000,
      zoneIndex: 0,
    );
    final trap = royalCard(
      'ROY-011',
      instanceId: 'portcullis',
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
    final state = royalDuel(
      phase: DuelPhase.battle,
      playerField: royalField(
        participant: DuelParticipant.player,
        characters: [attacker, null, null, null, null],
      ),
      aiField: royalField(
        participant: DuelParticipant.ai,
        characters: [target, null, null, null, null],
        actionTraps: [trap, null, null, null, null],
      ),
    );
    final engine = DuelEngine(chainEffects: RoyaumeEffectRegistry.create());
    final declaration = engine.declareAttack(
      state: state,
      participant: DuelParticipant.player,
      attackerInstanceId: 'attacker',
      targetInstanceId: 'target',
    );

    final activation = engine.activateChainEffect(
      state: declaration.state,
      link: royalLink(
        id: 'roy011-trap',
        effectKey: RoyaumeEffectKeys.roy011,
        player: DuelParticipant.ai,
        speed: ChainSpeed.speed2,
        sourceId: 'portcullis',
        sourceCode: 'ROY-011',
        target: ChainTarget(cardInstanceId: 'attacker'),
        payload: {
          'trigger': 'attack_declared',
          'attack_declaration_id': declaration.declaration!.declarationId,
          'attack_target_instance_id': 'target',
        },
      ),
    );
    final firstPass = engine.passPriority(
      state: activation.state,
      participant: DuelParticipant.player,
    );
    final resolved = engine.passPriority(
      state: firstPass.state,
      participant: DuelParticipant.ai,
    );
    final combat = engine.resolveAttack(
      state: resolved.state,
      declaration: declaration.declaration!,
    );

    expect(
      resolved.state.playerField.characterZones.first!.effectiveAtk,
      1700,
    );
    expect(combat.status, CombatResolutionStatus.cancelled);
  });

  test('ROY-012 annule l’effet ciblant une Royaume et détruit sa source', () {
    const enemyEffectKey = 'test_enemy_target_effect';
    final target = royalCard('ROY-002', instanceId: 'target', zoneIndex: 0);
    final seal = royalCard(
      'ROY-012',
      instanceId: 'seal',
      category: CardCategory.trap,
      subtype: 'counter',
      rank: null,
      atk: null,
      def: null,
      faceUp: false,
      position: null,
      zoneIndex: 0,
    );
    final enemyAction = royalCard(
      'ACT-001',
      instanceId: 'enemy-action',
      owner: DuelParticipant.ai,
      family: 'babi',
      category: CardCategory.action,
      subtype: 'normal',
      rank: null,
      atk: null,
      def: null,
      position: null,
      zoneIndex: 0,
    );
    final state = royalDuel(
      activePlayer: DuelParticipant.ai,
      playerField: royalField(
        participant: DuelParticipant.player,
        characters: [target, null, null, null, null],
        actionTraps: [seal, null, null, null, null],
      ),
      aiField: royalField(
        participant: DuelParticipant.ai,
        actionTraps: [enemyAction, null, null, null, null],
      ),
    );
    final effects = <String, ChainEffectDefinition>{
      ...RoyaumeEffectRegistry.create(),
      enemyEffectKey: const _NoopEffect(),
    };
    final engine = DuelEngine(chainEffects: effects);
    final enemyActivation = engine.activateChainEffect(
      state: state,
      link: royalLink(
        id: 'enemy-link',
        effectKey: enemyEffectKey,
        player: DuelParticipant.ai,
        speed: ChainSpeed.speed1,
        sourceId: 'enemy-action',
        target: ChainTarget(cardInstanceId: 'target'),
      ),
    );

    final counter = engine.activateChainEffect(
      state: enemyActivation.state,
      link: royalLink(
        id: 'roy012-counter',
        effectKey: RoyaumeEffectKeys.roy012,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed3,
        sourceId: 'seal',
        sourceCode: 'ROY-012',
        payload: const {'target_link_id': 'enemy-link'},
      ),
    );
    final firstPass = engine.passPriority(
      state: counter.state,
      participant: DuelParticipant.ai,
    );
    final resolved = engine.passPriority(
      state: firstPass.state,
      participant: DuelParticipant.player,
    );

    expect(resolved.fizzledLinkIds, contains('enemy-link'));
    expect(
      resolved.state.aiField.graveyard.single.instanceId,
      'enemy-action',
    );
  });

  test('ROY-013 compte les Serments et applique ses bonus Royaume', () {
    final terrain = royalCard(
      'ROY-013',
      instanceId: 'court',
      category: CardCategory.terrain,
      rank: null,
      atk: null,
      def: null,
      position: null,
    );
    final allied = royalCard(
      'ROY-002',
      instanceId: 'allied',
      atk: 1500,
      def: 1200,
      zoneIndex: 0,
    );
    final enemy = royalCard(
      'ROY-002',
      instanceId: 'enemy',
      owner: DuelParticipant.ai,
      atk: 1500,
      def: 1200,
      zoneIndex: 0,
    );
    final state = royalDuel(
      playerField: royalField(
        participant: DuelParticipant.player,
        characters: [allied, null, null, null, null],
        terrain: terrain,
      ),
      aiField: royalField(
        participant: DuelParticipant.ai,
        characters: [enemy, null, null, null, null],
      ),
    );
    final engine = DuelEngine(chainEffects: RoyaumeEffectRegistry.create());

    final result = activateAndResolveRoyal(
      engine,
      state,
      royalLink(
        id: 'roy013-trigger',
        effectKey: RoyaumeEffectKeys.roy013,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'court',
        sourceCode: 'ROY-013',
        payload: const {
          'trigger': 'character_sacrificed',
          'sacrifice_count': 3,
        },
      ),
    );

    expect(result.state.playerField.terrainZone!.counters['serment'], 3);
    expect(result.state.playerField.characterZones.first!.effectiveAtk, 1800);
    expect(result.state.playerField.characterZones.first!.effectiveDef, 1400);
    expect(result.state.aiField.characterZones.first!.effectiveAtk, 1500);
    expect(result.state.aiField.characterZones.first!.effectiveDef, 1400);
  });

  test('ROY-014 équipe, renforce puis revient en main si sa cible part', () {
    final crown = royalCard(
      'ROY-014',
      instanceId: 'crown',
      category: CardCategory.relic,
      rank: null,
      atk: null,
      def: null,
      position: null,
      zoneIndex: 0,
    );
    final target = royalCard(
      'ROY-005',
      instanceId: 'target',
      rank: 5,
      atk: 2200,
      def: 1700,
      zoneIndex: 0,
    );
    final state = royalDuel(
      playerField: royalField(
        participant: DuelParticipant.player,
        characters: [target, null, null, null, null],
        actionTraps: [crown, null, null, null, null],
      ),
    );
    final engine = DuelEngine(chainEffects: RoyaumeEffectRegistry.create());

    final equipped = activateAndResolveRoyal(
      engine,
      state,
      royalLink(
        id: 'roy014-equip',
        effectKey: RoyaumeEffectKeys.roy014,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'crown',
        sourceCode: 'ROY-014',
        target: ChainTarget(cardInstanceId: 'target'),
        payload: const {'mode': 'equip'},
      ),
    );
    final strengthened =
        equipped.state.playerField.characterZones.first! as CardInstance;
    expect(strengthened.effectiveAtk, 2600);
    expect(strengthened.effectiveDef, 2100);

    final leftField = equipped.state.copyWith(
      playerField: equipped.state.playerField.copyWith(
        characterZones: const [null, null, null, null, null],
        graveyard: [target],
      ),
    );
    final returned = activateAndResolveRoyal(
      engine,
      leftField,
      royalLink(
        id: 'roy014-return',
        effectKey: RoyaumeEffectKeys.roy014,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'crown',
        sourceCode: 'ROY-014',
        payload: const {'mode': 'equipped_character_left'},
      ),
    );

    expect(returned.state.playerField.actionTrapZones.first, isNull);
    expect(returned.state.playerField.hand.single.instanceId, 'crown');
  });

  test('ROY-015 ranime puis annule une Vitesse 2 en payant un sacrifice', () {
    const enemyEffectKey = 'test_enemy_speed2';
    final sovereign = royalCard(
      'ROY-015',
      instanceId: 'sovereign',
      category: CardCategory.mythic,
      rank: 10,
      atk: 3700,
      def: 3400,
      zoneIndex: 0,
    );
    final revived = royalCard('ROY-007', instanceId: 'revived', rank: 8);
    final enemyAction = royalCard(
      'ACT-002',
      instanceId: 'enemy-action',
      owner: DuelParticipant.ai,
      family: 'babi',
      category: CardCategory.action,
      subtype: 'quick',
      rank: null,
      atk: null,
      def: null,
      position: null,
      zoneIndex: 0,
    );
    final state = royalDuel(
      playerField: royalField(
        participant: DuelParticipant.player,
        characters: [sovereign, null, null, null, null],
        graveyard: [revived],
      ),
      aiField: royalField(
        participant: DuelParticipant.ai,
        actionTraps: [enemyAction, null, null, null, null],
      ),
    );
    final effects = <String, ChainEffectDefinition>{
      ...RoyaumeEffectRegistry.create(),
      enemyEffectKey: const _NoopEffect(),
    };
    final engine = DuelEngine(chainEffects: effects);

    final summoned = activateAndResolveRoyal(
      engine,
      state,
      royalLink(
        id: 'roy015-summon',
        effectKey: RoyaumeEffectKeys.roy015,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'sovereign',
        sourceCode: 'ROY-015',
        payload: const {
          'trigger': 'on_summon',
          'target_instance_ids': ['revived'],
        },
      ),
    );
    final revivedOnField = summoned.state.playerField.characterZones[1]!;
    expect(revivedOnField.position, BattlePosition.defense);
    expect(
      (revivedOnField as CardInstance)
          .runtimeData
          .containsKey(CardRuntimeKeys.effectsNegatedUntilTurn),
      isFalse,
    );

    final enemyTurnState = summoned.state.copyWith(
      activePlayer: DuelParticipant.ai,
    );
    final enemyActivation = engine.activateChainEffect(
      state: enemyTurnState,
      link: royalLink(
        id: 'enemy-speed2',
        effectKey: enemyEffectKey,
        player: DuelParticipant.ai,
        speed: ChainSpeed.speed2,
        sourceId: 'enemy-action',
      ),
    );
    final sovereignResponse = engine.activateChainEffect(
      state: enemyActivation.state,
      link: royalLink(
        id: 'roy015-negate',
        effectKey: RoyaumeEffectKeys.roy015,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed2,
        sourceId: 'sovereign',
        sourceCode: 'ROY-015',
        payload: const {
          'trigger': 'speed2_effect_activated',
          'target_link_id': 'enemy-speed2',
          'sacrifice_instance_id': 'revived',
        },
      ),
    );
    final firstPass = engine.passPriority(
      state: sovereignResponse.state,
      participant: DuelParticipant.ai,
    );
    final resolved = engine.passPriority(
      state: firstPass.state,
      participant: DuelParticipant.player,
    );

    expect(resolved.fizzledLinkIds, contains('enemy-speed2'));
    expect(resolved.state.playerField.graveyard.single.instanceId, 'revived');
    expect(resolved.state.aiField.graveyard.single.instanceId, 'enemy-action');
  });
}
