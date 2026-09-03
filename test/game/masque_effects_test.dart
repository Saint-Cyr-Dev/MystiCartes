import 'package:mysticartes/game/battle_state.dart';
import 'package:mysticartes/game/card.dart';
import 'package:mysticartes/game/duel_engine.dart';
import 'package:mysticartes/game/duel_types.dart';
import 'package:mysticartes/game/effects/masque_effects.dart';
import 'package:mysticartes/game/player.dart';
import 'package:test/test.dart';

const _effectKeys = <String, String>{
  'MAS-001': MasqueEffectKeys.mas001,
  'MAS-002': MasqueEffectKeys.mas002,
  'MAS-004': MasqueEffectKeys.mas004,
  'MAS-005': MasqueEffectKeys.mas005,
  'MAS-006': MasqueEffectKeys.mas006,
  'MAS-007': MasqueEffectKeys.mas007,
  'MAS-008': MasqueEffectKeys.mas008,
  'MAS-009': MasqueEffectKeys.mas009,
  'MAS-010': MasqueEffectKeys.mas010,
  'MAS-011': MasqueEffectKeys.mas011,
  'MAS-012': MasqueEffectKeys.mas012,
  'MAS-013': MasqueEffectKeys.mas013,
  'MAS-014': MasqueEffectKeys.mas014,
  'MAS-015': MasqueEffectKeys.mas015,
};

CardInstance maskCard(
  String code, {
  String? instanceId,
  DuelParticipant owner = DuelParticipant.player,
  CardCategory category = CardCategory.character,
  String? subtype,
  String family = 'masque',
  int? rank = 4,
  int? atk = 1500,
  int? def = 1500,
  bool faceUp = true,
  BattlePosition? position = BattlePosition.attack,
  int? zoneIndex,
  Map<String, Object?> runtimeData = const {},
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
    effectKey: _effectKeys[code],
    atk: atk,
    def: def,
    owner: owner,
    controller: owner,
    faceUp: faceUp,
    position: position,
    zoneIndex: zoneIndex,
    runtimeData: runtimeData,
  );
}

PlayerFieldState maskField({
  required DuelParticipant participant,
  List<FieldCardInstance?>? characters,
  List<CardInstance?>? actionTraps,
  CardInstance? terrain,
  List<CardInstance> deck = const [],
  List<CardInstance> hand = const [],
  List<CardInstance> graveyard = const [],
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
    mythicReserve: const [],
  );
}

DuelState maskDuel({
  PlayerFieldState? playerField,
  PlayerFieldState? aiField,
  DuelParticipant activePlayer = DuelParticipant.player,
  DuelPhase phase = DuelPhase.main1,
  int turnNumber = 2,
}) {
  return DuelState(
    playerField: playerField ?? maskField(participant: DuelParticipant.player),
    aiField: aiField ?? maskField(participant: DuelParticipant.ai),
    activePlayer: activePlayer,
    currentPhase: phase,
    turnNumber: turnNumber,
  );
}

ChainLink maskLink({
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

PriorityPassResult activateAndResolveMask(
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

final class RecordingMaskFusionExtension
    implements MasqueFusionSummonExtension {
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

final class _NoopEffect extends ChainEffectDefinition {
  const _NoopEffect();

  @override
  bool isTargetLegal(DuelState state, ChainLink link) => true;

  @override
  DuelState resolve(DuelState state, ChainLink link) => state;
}

void main() {
  test('MAS-001 se déclenche automatiquement après retournement au combat', () {
    final attacker = maskCard(
      'ATT-001',
      instanceId: 'attacker',
      family: 'babi',
      atk: 1000,
      def: 1000,
      zoneIndex: 0,
    );
    final novice = maskCard(
      'MAS-001',
      instanceId: 'novice',
      owner: DuelParticipant.ai,
      rank: 2,
      atk: 700,
      def: 1400,
      faceUp: false,
      position: BattlePosition.defense,
      zoneIndex: 0,
    );
    final drawn = maskCard(
      'MAS-003',
      instanceId: 'drawn',
      owner: DuelParticipant.ai,
    );
    final discard = maskCard(
      'MAS-002',
      instanceId: 'discard',
      owner: DuelParticipant.ai,
    );
    final state = maskDuel(
      phase: DuelPhase.battle,
      playerField: maskField(
        participant: DuelParticipant.player,
        characters: [attacker, null, null, null, null],
      ),
      aiField: maskField(
        participant: DuelParticipant.ai,
        characters: [novice, null, null, null, null],
        deck: [drawn],
        hand: [discard],
      ),
    );
    final engine = DuelEngine(
      chainEffects: MasqueEffectRegistry.create(),
      combatFlipTriggerLinkFactory: ({
        required state,
        required flippedCard,
      }) {
        return maskLink(
          id: 'automatic-flip-${flippedCard.instanceId}',
          effectKey: flippedCard.effectKey!,
          player: flippedCard.controller,
          speed: ChainSpeed.speed1,
          sourceId: flippedCard.instanceId,
          sourceCode: flippedCard.cardCode,
          payload: const {
            'trigger': 'flipped_face_up',
            'discard_instance_id': 'discard',
          },
        );
      },
    );
    final declaration = engine.declareAttack(
      state: state,
      participant: DuelParticipant.player,
      attackerInstanceId: 'attacker',
      targetInstanceId: 'novice',
    );
    final emptyPassOne = engine.passPriority(
      state: declaration.state,
      participant: DuelParticipant.ai,
    );
    final emptyPassTwo = engine.passPriority(
      state: emptyPassOne.state,
      participant: DuelParticipant.player,
    );

    final combat = engine.resolveAttack(
      state: emptyPassTwo.state,
      declaration: declaration.declaration!,
    );
    expect(combat.targetFlippedFaceUp, isTrue);
    expect(combat.state.chain.links.single.effectKey, MasqueEffectKeys.mas001);

    final flipPassOne = engine.passPriority(
      state: combat.state,
      participant: DuelParticipant.player,
    );
    final resolved = engine.passPriority(
      state: flipPassOne.state,
      participant: DuelParticipant.ai,
    );

    expect(resolved.state.aiField.hand.single.instanceId, 'drawn');
    expect(resolved.state.aiField.graveyard.single.instanceId, 'discard');
    expect(resolved.state.aiField.characterZones.first!.faceUp, isTrue);
  });

  test('MAS-002 passe en Défense et gagne 300 DEF ce tour', () {
    final dancer = maskCard(
      'MAS-002',
      instanceId: 'dancer',
      rank: 3,
      def: 1300,
      zoneIndex: 0,
    );
    final state = maskDuel(
      playerField: maskField(
        participant: DuelParticipant.player,
        characters: [dancer, null, null, null, null],
      ),
    );
    final engine = DuelEngine(chainEffects: MasqueEffectRegistry.create());

    final result = activateAndResolveMask(
      engine,
      state,
      maskLink(
        id: 'mas002-effect',
        effectKey: MasqueEffectKeys.mas002,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'dancer',
        sourceCode: 'MAS-002',
      ),
    );

    final changed = result.state.playerField.characterZones.first!;
    expect(changed.position, BattlePosition.defense);
    expect(changed.effectiveDef, 1600);
  });

  test('MAS-004 échange temporairement l’ATK et la DEF adverses', () {
    final laugher = maskCard('MAS-004', instanceId: 'laugher', zoneIndex: 0);
    final enemy = maskCard(
      'ENM-001',
      instanceId: 'enemy',
      owner: DuelParticipant.ai,
      family: 'babi',
      atk: 2400,
      def: 1200,
      zoneIndex: 0,
    );
    final state = maskDuel(
      playerField: maskField(
        participant: DuelParticipant.player,
        characters: [laugher, null, null, null, null],
      ),
      aiField: maskField(
        participant: DuelParticipant.ai,
        characters: [enemy, null, null, null, null],
      ),
    );
    final engine = DuelEngine(chainEffects: MasqueEffectRegistry.create());

    final result = activateAndResolveMask(
      engine,
      state,
      maskLink(
        id: 'mas004-flip',
        effectKey: MasqueEffectKeys.mas004,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'laugher',
        sourceCode: 'MAS-004',
        target: ChainTarget(cardInstanceId: 'enemy'),
        payload: const {'trigger': 'flipped_face_up'},
      ),
    );

    expect(result.state.aiField.characterZones.first!.effectiveAtk, 1200);
    expect(result.state.aiField.characterZones.first!.effectiveDef, 2400);
  });

  test('MAS-005 pose un petit Personnage Masque sans consommer la pose', () {
    final sculptor = maskCard(
      'MAS-005',
      instanceId: 'sculptor',
      rank: 5,
      zoneIndex: 0,
    );
    final selected = maskCard('MAS-002', instanceId: 'selected', rank: 3);
    final state = maskDuel(
      playerField: maskField(
        participant: DuelParticipant.player,
        characters: [sculptor, null, null, null, null],
        hand: [selected],
      ),
    );
    final engine = DuelEngine(chainEffects: MasqueEffectRegistry.create());

    final result = activateAndResolveMask(
      engine,
      state,
      maskLink(
        id: 'mas005-trigger',
        effectKey: MasqueEffectKeys.mas005,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'sculptor',
        sourceCode: 'MAS-005',
        payload: const {
          'trigger': 'on_summon',
          'use_effect': true,
          'selected_instance_id': 'selected',
        },
      ),
    );

    final setCard = result.state.playerField.characterZones[1]!;
    expect(setCard.faceUp, isFalse);
    expect(setCard.position, BattlePosition.defense);
    expect(result.state.normalSummonUsed[DuelParticipant.player], isFalse);
  });

  test('MAS-006 protège les cartes cachées et retourne un autre Masque', () {
    const enemyEffect = 'test_target_effect';
    final guardian = maskCard(
      'MAS-006',
      instanceId: 'guardian',
      rank: 6,
      zoneIndex: 0,
    );
    final hidden = maskCard(
      'MAS-001',
      instanceId: 'hidden',
      faceUp: false,
      position: BattlePosition.defense,
      zoneIndex: 1,
    );
    final visible = maskCard('MAS-002', instanceId: 'visible', zoneIndex: 2);
    final state = maskDuel(
      activePlayer: DuelParticipant.ai,
      playerField: maskField(
        participant: DuelParticipant.player,
        characters: [guardian, hidden, visible, null, null],
      ),
    );
    final engine = DuelEngine(
      chainEffects: {
        ...MasqueEffectRegistry.create(),
        enemyEffect: const _NoopEffect(),
      },
    );
    final blocked = engine.activateChainEffect(
      state: state,
      link: maskLink(
        id: 'enemy-target',
        effectKey: enemyEffect,
        player: DuelParticipant.ai,
        speed: ChainSpeed.speed1,
        target: ChainTarget(cardInstanceId: 'hidden'),
      ),
    );
    expect(blocked.failure, DuelActionFailure.illegalChainTarget);

    final ownTurn = state.copyWith(activePlayer: DuelParticipant.player);
    final setResult = activateAndResolveMask(
      engine,
      ownTurn,
      maskLink(
        id: 'mas006-effect',
        effectKey: MasqueEffectKeys.mas006,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'guardian',
        sourceCode: 'MAS-006',
        target: ChainTarget(cardInstanceId: 'visible'),
        payload: const {'mode': 'set_other'},
      ),
    );
    expect(setResult.state.playerField.characterZones[2]!.faceUp, isFalse);
  });

  test('MAS-007 place un Masque contrôlé en Défense puis face cachée', () {
    final mistress = maskCard(
      'MAS-007',
      instanceId: 'mistress',
      rank: 7,
      zoneIndex: 0,
    );
    final target = maskCard('MAS-002', instanceId: 'target', zoneIndex: 1);
    final state = maskDuel(
      playerField: maskField(
        participant: DuelParticipant.player,
        characters: [mistress, target, null, null, null],
      ),
    );
    final engine = DuelEngine(chainEffects: MasqueEffectRegistry.create());

    final result = activateAndResolveMask(
      engine,
      state,
      maskLink(
        id: 'mas007-effect',
        effectKey: MasqueEffectKeys.mas007,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'mistress',
        sourceCode: 'MAS-007',
        target: ChainTarget(cardInstanceId: 'target'),
        payload: const {'set_face_down_after': true},
      ),
    );

    final changed = result.state.playerField.characterZones[1]!;
    expect(changed.position, BattlePosition.defense);
    expect(changed.faceUp, isFalse);
  });

  test('MAS-008 retourne un Personnage Masque face visible', () {
    final action = maskCard(
      'MAS-008',
      instanceId: 'change',
      category: CardCategory.action,
      subtype: 'quick',
      rank: null,
      atk: null,
      def: null,
      position: null,
      zoneIndex: 0,
    );
    final target = maskCard(
      'MAS-001',
      instanceId: 'target',
      faceUp: false,
      position: BattlePosition.defense,
      zoneIndex: 0,
    );
    final state = maskDuel(
      playerField: maskField(
        participant: DuelParticipant.player,
        characters: [target, null, null, null, null],
        actionTraps: [action, null, null, null, null],
      ),
    );
    final engine = DuelEngine(chainEffects: MasqueEffectRegistry.create());

    final result = activateAndResolveMask(
      engine,
      state,
      maskLink(
        id: 'mas008-action',
        effectKey: MasqueEffectKeys.mas008,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed2,
        sourceId: 'change',
        sourceCode: 'MAS-008',
        target: ChainTarget(cardInstanceId: 'target'),
        payload: const {'turn_face_up': true},
      ),
    );

    final revealed =
        result.state.playerField.characterZones.first! as CardInstance;
    expect(revealed.faceUp, isTrue);
    expect(
      revealed.runtimeData[CardRuntimeKeys.flippedFaceUpTurn],
      state.turnNumber,
    );
  });

  test('MAS-009 révèle jusqu’à deux Personnages face cachée', () {
    final action = maskCard(
      'MAS-009',
      instanceId: 'dance',
      category: CardCategory.action,
      subtype: 'normal',
      rank: null,
      atk: null,
      def: null,
      position: null,
      zoneIndex: 0,
    );
    final own = maskCard(
      'MAS-001',
      instanceId: 'own',
      faceUp: false,
      position: BattlePosition.defense,
      zoneIndex: 0,
    );
    final enemy = maskCard(
      'MAS-003',
      instanceId: 'enemy',
      owner: DuelParticipant.ai,
      faceUp: false,
      position: BattlePosition.defense,
      zoneIndex: 0,
    );
    final state = maskDuel(
      playerField: maskField(
        participant: DuelParticipant.player,
        characters: [own, null, null, null, null],
        actionTraps: [action, null, null, null, null],
      ),
      aiField: maskField(
        participant: DuelParticipant.ai,
        characters: [enemy, null, null, null, null],
      ),
    );
    final engine = DuelEngine(chainEffects: MasqueEffectRegistry.create());

    final result = activateAndResolveMask(
      engine,
      state,
      maskLink(
        id: 'mas009-action',
        effectKey: MasqueEffectKeys.mas009,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'dance',
        sourceCode: 'MAS-009',
        payload: const {
          'reveal_instance_ids': ['own', 'enemy']
        },
      ),
    );

    expect(result.state.playerField.characterZones.first!.faceUp, isTrue);
    expect(result.state.aiField.characterZones.first!.faceUp, isTrue);
  });

  test('MAS-010 paie ses deux matériels puis appelle l’extension Fusion', () {
    final extension = RecordingMaskFusionExtension();
    final action = maskCard(
      'MAS-010',
      instanceId: 'rhythm',
      category: CardCategory.action,
      subtype: 'normal',
      rank: null,
      atk: null,
      def: null,
      position: null,
      zoneIndex: 0,
    );
    final laugher = maskCard('MAS-004', instanceId: 'laugher', zoneIndex: 0);
    final guardian = maskCard(
      'MAS-006',
      instanceId: 'guardian',
      rank: 6,
      zoneIndex: 1,
    );
    final state = maskDuel(
      playerField: maskField(
        participant: DuelParticipant.player,
        characters: [laugher, guardian, null, null, null],
        actionTraps: [action, null, null, null, null],
      ),
    );
    final engine = DuelEngine(
      chainEffects: MasqueEffectRegistry.create(
        fusionSummonExtension: extension,
      ),
    );

    final result = activateAndResolveMask(
      engine,
      state,
      maskLink(
        id: 'mas010-action',
        effectKey: MasqueEffectKeys.mas010,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'rhythm',
        sourceCode: 'MAS-010',
        payload: const {
          'material_instance_ids': ['laugher', 'guardian']
        },
      ),
    );

    expect(result.state.playerField.graveyard, hasLength(2));
    expect(extension.called, isTrue);
    expect(extension.triggerCode, 'MAS-010');
    expect(extension.mythicCode, 'MAS-015');
  });

  test('MAS-011 redirige l’attaque visant un Personnage face cachée', () {
    final attacker = maskCard(
      'ATT-001',
      instanceId: 'attacker',
      family: 'babi',
      atk: 2000,
      zoneIndex: 0,
    );
    final hidden = maskCard(
      'MAS-001',
      instanceId: 'hidden',
      owner: DuelParticipant.ai,
      faceUp: false,
      position: BattlePosition.defense,
      zoneIndex: 0,
    );
    final replacement = maskCard(
      'MAS-003',
      instanceId: 'replacement',
      owner: DuelParticipant.ai,
      atk: 1000,
      def: 1000,
      zoneIndex: 1,
    );
    final trap = maskCard(
      'MAS-011',
      instanceId: 'false-move',
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
    final state = maskDuel(
      phase: DuelPhase.battle,
      playerField: maskField(
        participant: DuelParticipant.player,
        characters: [attacker, null, null, null, null],
      ),
      aiField: maskField(
        participant: DuelParticipant.ai,
        characters: [hidden, replacement, null, null, null],
        actionTraps: [trap, null, null, null, null],
      ),
    );
    final engine = DuelEngine(chainEffects: MasqueEffectRegistry.create());
    final declaration = engine.declareAttack(
      state: state,
      participant: DuelParticipant.player,
      attackerInstanceId: 'attacker',
      targetInstanceId: 'hidden',
    );
    final activation = engine.activateChainEffect(
      state: declaration.state,
      link: maskLink(
        id: 'mas011-trap',
        effectKey: MasqueEffectKeys.mas011,
        player: DuelParticipant.ai,
        speed: ChainSpeed.speed2,
        sourceId: 'false-move',
        sourceCode: 'MAS-011',
        target: ChainTarget(cardInstanceId: 'hidden'),
        payload: {
          'trigger': 'face_down_character_attacked',
          'attack_declaration_id': declaration.declaration!.declarationId,
          'new_target_instance_id': 'replacement',
        },
      ),
    );
    final passOne = engine.passPriority(
      state: activation.state,
      participant: DuelParticipant.player,
    );
    final resolved = engine.passPriority(
      state: passOne.state,
      participant: DuelParticipant.ai,
    );
    final combat = engine.resolveAttack(
      state: resolved.state,
      declaration: declaration.declaration!,
    );

    expect(combat.destroyedCardInstanceIds, ['replacement']);
    expect(combat.state.aiField.characterZones.first!.faceUp, isFalse);
  });

  test('MAS-012 annule la révélation et détruit sa source adverse', () {
    const revealEffect = 'test_reveal_effect';
    final hidden = maskCard(
      'MAS-001',
      instanceId: 'hidden',
      faceUp: false,
      position: BattlePosition.defense,
      zoneIndex: 0,
    );
    final counterTrap = maskCard(
      'MAS-012',
      instanceId: 'forbidden-face',
      category: CardCategory.trap,
      subtype: 'counter',
      rank: null,
      atk: null,
      def: null,
      faceUp: false,
      position: null,
      zoneIndex: 0,
    );
    final enemyAction = maskCard(
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
    final state = maskDuel(
      activePlayer: DuelParticipant.ai,
      playerField: maskField(
        participant: DuelParticipant.player,
        characters: [hidden, null, null, null, null],
        actionTraps: [counterTrap, null, null, null, null],
      ),
      aiField: maskField(
        participant: DuelParticipant.ai,
        actionTraps: [enemyAction, null, null, null, null],
      ),
    );
    final engine = DuelEngine(
      chainEffects: {
        ...MasqueEffectRegistry.create(),
        revealEffect: const _NoopEffect(),
      },
    );
    final enemyActivation = engine.activateChainEffect(
      state: state,
      link: maskLink(
        id: 'enemy-reveal',
        effectKey: revealEffect,
        player: DuelParticipant.ai,
        speed: ChainSpeed.speed1,
        sourceId: 'enemy-action',
        target: ChainTarget(cardInstanceId: 'hidden'),
      ),
    );
    final counter = engine.activateChainEffect(
      state: enemyActivation.state,
      link: maskLink(
        id: 'mas012-counter',
        effectKey: MasqueEffectKeys.mas012,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed3,
        sourceId: 'forbidden-face',
        sourceCode: 'MAS-012',
        payload: const {'target_link_id': 'enemy-reveal'},
      ),
    );
    final passOne = engine.passPriority(
      state: counter.state,
      participant: DuelParticipant.ai,
    );
    final resolved = engine.passPriority(
      state: passOne.state,
      participant: DuelParticipant.player,
    );

    expect(resolved.fizzledLinkIds, contains('enemy-reveal'));
    expect(resolved.state.playerField.characterZones.first!.faceUp, isFalse);
    expect(resolved.state.aiField.graveyard.single.instanceId, 'enemy-action');
  });

  test('MAS-013 donne 200 DEF et 300 PV au premier retournement', () {
    final terrain = maskCard(
      'MAS-013',
      instanceId: 'secret-place',
      category: CardCategory.terrain,
      rank: null,
      atk: null,
      def: null,
      position: null,
    );
    final own = maskCard('MAS-002', instanceId: 'own', def: 1300, zoneIndex: 0);
    final flipped = maskCard(
      'MAS-003',
      instanceId: 'flipped',
      owner: DuelParticipant.ai,
      def: 2100,
      zoneIndex: 0,
    );
    final state = maskDuel(
      playerField: maskField(
        participant: DuelParticipant.player,
        characters: [own, null, null, null, null],
        terrain: terrain,
      ),
      aiField: maskField(
        participant: DuelParticipant.ai,
        characters: [flipped, null, null, null, null],
      ),
    );
    final engine = DuelEngine(chainEffects: MasqueEffectRegistry.create());

    final result = activateAndResolveMask(
      engine,
      state,
      maskLink(
        id: 'mas013-trigger',
        effectKey: MasqueEffectKeys.mas013,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'secret-place',
        sourceCode: 'MAS-013',
        payload: const {
          'mode': 'card_flipped_face_up',
          'flipped_instance_id': 'flipped',
        },
      ),
    );

    expect(result.state.playerField.characterZones.first!.effectiveDef, 1500);
    expect(result.state.aiField.characterZones.first!.effectiveDef, 2300);
    expect(result.state.aiLifePoints, 8300);
  });

  test('MAS-014 équipe un Masque puis pose un Piège après retournement', () {
    final scissors = maskCard(
      'MAS-014',
      instanceId: 'scissors',
      category: CardCategory.relic,
      rank: null,
      atk: null,
      def: null,
      position: null,
      zoneIndex: 0,
    );
    final target = maskCard(
      'MAS-002',
      instanceId: 'target',
      atk: 1400,
      def: 1300,
      zoneIndex: 0,
      runtimeData: const {CardRuntimeKeys.flippedFaceUpTurn: 2},
    );
    final trap = maskCard(
      'MAS-011',
      instanceId: 'trap',
      category: CardCategory.trap,
      subtype: 'normal',
      rank: null,
      atk: null,
      def: null,
      position: null,
    );
    final state = maskDuel(
      playerField: maskField(
        participant: DuelParticipant.player,
        characters: [target, null, null, null, null],
        actionTraps: [scissors, null, null, null, null],
        hand: [trap],
      ),
    );
    final engine = DuelEngine(chainEffects: MasqueEffectRegistry.create());

    final equipped = activateAndResolveMask(
      engine,
      state,
      maskLink(
        id: 'mas014-equip',
        effectKey: MasqueEffectKeys.mas014,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'scissors',
        sourceCode: 'MAS-014',
        target: ChainTarget(cardInstanceId: 'target'),
        payload: const {'mode': 'equip'},
      ),
    );
    expect(equipped.state.playerField.characterZones.first!.effectiveAtk, 1700);
    expect(equipped.state.playerField.characterZones.first!.effectiveDef, 1600);

    final setTrap = activateAndResolveMask(
      engine,
      equipped.state,
      maskLink(
        id: 'mas014-set',
        effectKey: MasqueEffectKeys.mas014,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'scissors',
        sourceCode: 'MAS-014',
        payload: const {'mode': 'set_trap', 'trap_instance_id': 'trap'},
      ),
    );

    expect(setTrap.state.playerField.hand, isEmpty);
    expect(setTrap.state.playerField.actionTrapZones[1]!.instanceId, 'trap');
    expect(setTrap.state.playerField.actionTrapZones[1]!.faceUp, isFalse);
  });

  test('MAS-015 cache deux adversaires puis gagne 500 ATK sur retournement',
      () {
    final mythic = maskCard(
      'MAS-015',
      instanceId: 'first-rhythm',
      category: CardCategory.mythic,
      rank: 9,
      atk: 3100,
      def: 3300,
      zoneIndex: 0,
    );
    final first = maskCard(
      'ENM-001',
      instanceId: 'first',
      owner: DuelParticipant.ai,
      family: 'babi',
      zoneIndex: 0,
    );
    final second = maskCard(
      'ENM-002',
      instanceId: 'second',
      owner: DuelParticipant.ai,
      family: 'royaume',
      zoneIndex: 1,
    );
    final state = maskDuel(
      playerField: maskField(
        participant: DuelParticipant.player,
        characters: [mythic, null, null, null, null],
      ),
      aiField: maskField(
        participant: DuelParticipant.ai,
        characters: [first, second, null, null, null],
      ),
    );
    final engine = DuelEngine(chainEffects: MasqueEffectRegistry.create());

    final summoned = activateAndResolveMask(
      engine,
      state,
      maskLink(
        id: 'mas015-summon',
        effectKey: MasqueEffectKeys.mas015,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'first-rhythm',
        sourceCode: 'MAS-015',
        payload: const {
          'trigger': 'on_summon',
          'target_instance_ids': ['first', 'second'],
        },
      ),
    );
    expect(summoned.state.aiField.characterZones.first!.faceUp, isFalse);
    expect(summoned.state.aiField.characterZones[1]!.faceUp, isFalse);

    final boost = activateAndResolveMask(
      engine,
      summoned.state,
      maskLink(
        id: 'mas015-boost',
        effectKey: MasqueEffectKeys.mas015,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'first-rhythm',
        sourceCode: 'MAS-015',
        payload: const {
          'trigger': 'card_flipped_face_up',
          'choice': 'boost',
        },
      ),
    );

    expect(boost.state.playerField.characterZones.first!.effectiveAtk, 3600);
  });
}
