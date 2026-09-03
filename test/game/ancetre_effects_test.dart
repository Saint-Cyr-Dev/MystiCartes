import 'package:mysticartes/game/battle_state.dart';
import 'package:mysticartes/game/card.dart';
import 'package:mysticartes/game/duel_engine.dart';
import 'package:mysticartes/game/duel_types.dart';
import 'package:mysticartes/game/effects/ancetre_effects.dart';
import 'package:mysticartes/game/player.dart';
import 'package:test/test.dart';

const _effectKeys = <String, String>{
  'ANC-001': AncetreEffectKeys.anc001,
  'ANC-002': AncetreEffectKeys.anc002,
  'ANC-004': AncetreEffectKeys.anc004,
  'ANC-005': AncetreEffectKeys.anc005,
  'ANC-006': AncetreEffectKeys.anc006,
  'ANC-007': AncetreEffectKeys.anc007,
  'ANC-008': AncetreEffectKeys.anc008,
  'ANC-009': AncetreEffectKeys.anc009,
  'ANC-010': AncetreEffectKeys.anc010,
  'ANC-011': AncetreEffectKeys.anc011,
  'ANC-012': AncetreEffectKeys.anc012,
  'ANC-013': AncetreEffectKeys.anc013,
  'ANC-014': AncetreEffectKeys.anc014,
  'ANC-015': AncetreEffectKeys.anc015,
};

CardInstance ancestorCard(
  String code, {
  String? instanceId,
  DuelParticipant owner = DuelParticipant.player,
  CardCategory category = CardCategory.character,
  String? subtype,
  String family = 'ancêtre',
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
    effectKey: _effectKeys[code],
    atk: atk,
    def: def,
    owner: owner,
    controller: owner,
    faceUp: faceUp,
    position: position,
    zoneIndex: zoneIndex,
  );
}

PlayerFieldState ancestorField({
  required DuelParticipant participant,
  List<FieldCardInstance?>? characters,
  List<CardInstance?>? actionTraps,
  CardInstance? terrain,
  List<CardInstance> deck = const [],
  List<CardInstance> hand = const [],
  List<CardInstance> graveyard = const [],
  List<CardInstance> banished = const [],
}) {
  return PlayerFieldState(
    participant: participant,
    characterZones: characters ?? const [null, null, null, null, null],
    actionTrapZones: actionTraps ?? const [null, null, null, null, null],
    terrainZone: terrain,
    deck: deck,
    hand: hand,
    graveyard: graveyard,
    banished: banished,
    mythicReserve: const [],
  );
}

DuelState ancestorDuel({
  PlayerFieldState? playerField,
  PlayerFieldState? aiField,
  DuelParticipant activePlayer = DuelParticipant.player,
  DuelPhase phase = DuelPhase.main1,
  int turnNumber = 2,
  bool drawPhaseResolved = false,
}) {
  return DuelState(
    playerField:
        playerField ?? ancestorField(participant: DuelParticipant.player),
    aiField: aiField ?? ancestorField(participant: DuelParticipant.ai),
    activePlayer: activePlayer,
    currentPhase: phase,
    turnNumber: turnNumber,
    drawPhaseResolved: drawPhaseResolved,
  );
}

ChainLink ancestorLink({
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

PriorityPassResult activateAndResolveAncestor(
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

final class StableShuffler implements AncetreDeckShuffler {
  const StableShuffler();

  @override
  List<CardInstance> shuffle(List<CardInstance> cards) =>
      List<CardInstance>.from(cards);
}

final class RecordingAncestorExtension
    implements AncetreAncestralSummonExtension {
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
  test('ANC-001 envoie la carte du dessus du deck au Cimetière', () {
    final bearer = ancestorCard('ANC-001', instanceId: 'bearer').copyWith(
      position: null,
      zoneIndex: null,
    );
    final top = ancestorCard('ANC-003', instanceId: 'top');
    final state = ancestorDuel(
      playerField: ancestorField(
        participant: DuelParticipant.player,
        deck: [top],
        graveyard: [bearer],
      ),
    );
    final engine = DuelEngine(chainEffects: AncetreEffectRegistry.create());

    final result = activateAndResolveAncestor(
      engine,
      state,
      ancestorLink(
        id: 'anc001-trigger',
        effectKey: AncetreEffectKeys.anc001,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'bearer',
        sourceCode: 'ANC-001',
        payload: const {'trigger': 'sent_from_field_to_graveyard'},
      ),
    );

    expect(result.state.playerField.deck, isEmpty);
    expect(
      result.state.playerField.graveyard.map((card) => card.instanceId),
      ['bearer', 'top'],
    );
  });

  test('ANC-002 place une carte Ancêtre du Cimetière sous le deck', () {
    final child = ancestorCard('ANC-002', instanceId: 'child', zoneIndex: 0);
    final target = ancestorCard('ANC-001', instanceId: 'target');
    final existing = ancestorCard('ANC-003', instanceId: 'existing');
    final state = ancestorDuel(
      playerField: ancestorField(
        participant: DuelParticipant.player,
        characters: [child, null, null, null, null],
        deck: [existing],
        graveyard: [target],
      ),
    );
    final engine = DuelEngine(chainEffects: AncetreEffectRegistry.create());

    final result = activateAndResolveAncestor(
      engine,
      state,
      ancestorLink(
        id: 'anc002-trigger',
        effectKey: AncetreEffectKeys.anc002,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'child',
        sourceCode: 'ANC-002',
        target: ChainTarget(cardInstanceId: 'target'),
        payload: const {'trigger': 'on_summon'},
      ),
    );

    expect(result.state.playerField.graveyard, isEmpty);
    expect(
      result.state.playerField.deck.map((card) => card.instanceId),
      ['existing', 'target'],
    );
  });

  test('ANC-004 envoie une autre carte Ancêtre du deck au Cimetière', () {
    final messenger = ancestorCard(
      'ANC-004',
      instanceId: 'messenger',
      zoneIndex: 0,
    );
    final selected = ancestorCard('ANC-001', instanceId: 'selected');
    final other = ancestorCard('ANC-004', instanceId: 'other-messenger');
    final state = ancestorDuel(
      playerField: ancestorField(
        participant: DuelParticipant.player,
        characters: [messenger, null, null, null, null],
        deck: [other, selected],
      ),
    );
    final engine = DuelEngine(chainEffects: AncetreEffectRegistry.create());

    final result = activateAndResolveAncestor(
      engine,
      state,
      ancestorLink(
        id: 'anc004-trigger',
        effectKey: AncetreEffectKeys.anc004,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'messenger',
        sourceCode: 'ANC-004',
        payload: const {
          'trigger': 'on_summon',
          'selected_instance_id': 'selected',
        },
      ),
    );

    expect(result.state.playerField.deck.single.instanceId, 'other-messenger');
    expect(result.state.playerField.graveyard.single.instanceId, 'selected');
  });

  test('ANC-005 se mélange au deck et récupère un Personnage faible', () {
    final guardian = ancestorCard(
      'ANC-005',
      instanceId: 'guardian',
      rank: 5,
      zoneIndex: 0,
    );
    final target = ancestorCard('ANC-003', instanceId: 'target', rank: 3);
    final deckCard = ancestorCard('ANC-001', instanceId: 'deck-card');
    final state = ancestorDuel(
      playerField: ancestorField(
        participant: DuelParticipant.player,
        characters: [guardian, null, null, null, null],
        deck: [deckCard],
        graveyard: [target],
      ),
    );
    final engine = DuelEngine(
      chainEffects: AncetreEffectRegistry.create(
        deckShuffler: const StableShuffler(),
      ),
    );

    final result = activateAndResolveAncestor(
      engine,
      state,
      ancestorLink(
        id: 'anc005-effect',
        effectKey: AncetreEffectKeys.anc005,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'guardian',
        sourceCode: 'ANC-005',
        target: ChainTarget(cardInstanceId: 'target'),
      ),
    );

    expect(result.state.playerField.characterZones.first, isNull);
    expect(result.state.playerField.hand.single.instanceId, 'target');
    expect(
      result.state.playerField.deck.map((card) => card.instanceId),
      ['deck-card', 'guardian'],
    );
  });

  test('ANC-006 invoque un petit Ancêtre après un sacrifice ou coût', () {
    final counsellor = ancestorCard(
      'ANC-006',
      instanceId: 'counsellor',
      rank: 6,
    ).copyWith(position: null, zoneIndex: null);
    final selected = ancestorCard('ANC-002', instanceId: 'selected', rank: 2);
    final state = ancestorDuel(
      playerField: ancestorField(
        participant: DuelParticipant.player,
        graveyard: [counsellor, selected],
      ),
    );
    final engine = DuelEngine(chainEffects: AncetreEffectRegistry.create());

    final result = activateAndResolveAncestor(
      engine,
      state,
      ancestorLink(
        id: 'anc006-trigger',
        effectKey: AncetreEffectKeys.anc006,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'counsellor',
        sourceCode: 'ANC-006',
        payload: const {
          'trigger': 'sent_as_sacrifice_or_cost',
          'selected_instance_id': 'selected',
        },
      ),
    );

    final summoned = result.state.playerField.characterZones.first!;
    expect(summoned.instanceId, 'selected');
    expect(summoned.position, BattlePosition.defense);
  });

  test('ANC-007 mélange trois Ancêtre, pioche et gagne 100 ATK chacun', () {
    final matriarch = ancestorCard(
      'ANC-007',
      instanceId: 'matriarch',
      rank: 8,
      atk: 2900,
      zoneIndex: 0,
    );
    final drawn = ancestorCard('ANC-003', instanceId: 'drawn');
    final first = ancestorCard('ANC-001', instanceId: 'first');
    final second = ancestorCard('ANC-002', instanceId: 'second');
    final third = ancestorCard('ANC-004', instanceId: 'third');
    final state = ancestorDuel(
      playerField: ancestorField(
        participant: DuelParticipant.player,
        characters: [matriarch, null, null, null, null],
        deck: [drawn],
        graveyard: [first, second, third],
      ),
    );
    final engine = DuelEngine(
      chainEffects: AncetreEffectRegistry.create(
        deckShuffler: const StableShuffler(),
      ),
    );

    final result = activateAndResolveAncestor(
      engine,
      state,
      ancestorLink(
        id: 'anc007-trigger',
        effectKey: AncetreEffectKeys.anc007,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'matriarch',
        sourceCode: 'ANC-007',
        payload: const {
          'trigger': 'on_summon',
          'target_instance_ids': ['first', 'second', 'third'],
        },
      ),
    );

    expect(result.state.playerField.hand.single.instanceId, 'drawn');
    expect(result.state.playerField.graveyard, isEmpty);
    expect(result.state.playerField.characterZones.first!.effectiveAtk, 3200);
  });

  test('ANC-008 récupère une Ancêtre puis défausse la carte choisie', () {
    final action = ancestorCard(
      'ANC-008',
      instanceId: 'word',
      category: CardCategory.action,
      subtype: 'normal',
      rank: null,
      atk: null,
      def: null,
      position: null,
      zoneIndex: 0,
    );
    final selected = ancestorCard('ANC-001', instanceId: 'selected');
    final discard = ancestorCard('ANC-003', instanceId: 'discard');
    final state = ancestorDuel(
      playerField: ancestorField(
        participant: DuelParticipant.player,
        actionTraps: [action, null, null, null, null],
        hand: [discard],
        graveyard: [selected],
      ),
    );
    final engine = DuelEngine(chainEffects: AncetreEffectRegistry.create());

    final result = activateAndResolveAncestor(
      engine,
      state,
      ancestorLink(
        id: 'anc008-action',
        effectKey: AncetreEffectKeys.anc008,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'word',
        sourceCode: 'ANC-008',
        payload: const {
          'selected_instance_id': 'selected',
          'discard_instance_id': 'discard',
        },
      ),
    );

    expect(result.state.playerField.hand.single.instanceId, 'selected');
    expect(result.state.playerField.graveyard.single.instanceId, 'discard');
  });

  test('ANC-009 renforce un Ancêtre et affaiblit un adversaire ce tour', () {
    final action = ancestorCard(
      'ANC-009',
      instanceId: 'hand-of-ancestors',
      category: CardCategory.action,
      subtype: 'quick',
      rank: null,
      atk: null,
      def: null,
      position: null,
      zoneIndex: 0,
    );
    final ally = ancestorCard(
      'ANC-003',
      instanceId: 'ally',
      atk: 1300,
      def: 1700,
      zoneIndex: 0,
    );
    final enemy = ancestorCard(
      'ENM-001',
      instanceId: 'enemy',
      owner: DuelParticipant.ai,
      family: 'babi',
      atk: 2000,
      def: 1800,
      zoneIndex: 0,
    );
    final state = ancestorDuel(
      playerField: ancestorField(
        participant: DuelParticipant.player,
        characters: [ally, null, null, null, null],
        actionTraps: [action, null, null, null, null],
      ),
      aiField: ancestorField(
        participant: DuelParticipant.ai,
        characters: [enemy, null, null, null, null],
      ),
    );
    final engine = DuelEngine(chainEffects: AncetreEffectRegistry.create());

    final result = activateAndResolveAncestor(
      engine,
      state,
      ancestorLink(
        id: 'anc009-action',
        effectKey: AncetreEffectKeys.anc009,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed2,
        sourceId: 'hand-of-ancestors',
        sourceCode: 'ANC-009',
        target: ChainTarget(cardInstanceId: 'ally'),
        payload: const {'enemy_instance_id': 'enemy'},
      ),
    );

    expect(result.state.playerField.characterZones.first!.effectiveAtk, 1900);
    expect(result.state.playerField.characterZones.first!.effectiveDef, 2300);
    expect(result.state.aiField.characterZones.first!.effectiveAtk, 1700);
    expect(result.state.aiField.characterZones.first!.effectiveDef, 1500);
  });

  test('ANC-010 bannit au moins 10 rangs puis appelle l’extension', () {
    final extension = RecordingAncestorExtension();
    final action = ancestorCard(
      'ANC-010',
      instanceId: 'call',
      category: CardCategory.action,
      subtype: 'normal',
      rank: null,
      atk: null,
      def: null,
      position: null,
      zoneIndex: 0,
    );
    final rankSix = ancestorCard('ANC-006', instanceId: 'rank6', rank: 6);
    final rankFour = ancestorCard('ANC-004', instanceId: 'rank4', rank: 4);
    final state = ancestorDuel(
      playerField: ancestorField(
        participant: DuelParticipant.player,
        actionTraps: [action, null, null, null, null],
        graveyard: [rankSix, rankFour],
      ),
    );
    final engine = DuelEngine(
      chainEffects: AncetreEffectRegistry.create(
        ancestralSummonExtension: extension,
      ),
    );

    final result = activateAndResolveAncestor(
      engine,
      state,
      ancestorLink(
        id: 'anc010-action',
        effectKey: AncetreEffectKeys.anc010,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'call',
        sourceCode: 'ANC-010',
        payload: const {
          'banish_instance_ids': ['rank6', 'rank4']
        },
      ),
    );

    expect(result.state.playerField.graveyard, isEmpty);
    expect(result.state.playerField.banished, hasLength(2));
    expect(extension.called, isTrue);
    expect(extension.triggerCode, 'ANC-010');
    expect(extension.mythicCode, 'ANC-015');
  });

  test('ANC-011 invoque un Ancêtre de rang inférieur en Défense', () {
    final trap = ancestorCard(
      'ANC-011',
      instanceId: 'council',
      category: CardCategory.trap,
      subtype: 'normal',
      rank: null,
      atk: null,
      def: null,
      faceUp: false,
      position: null,
      zoneIndex: 0,
    );
    final selected = ancestorCard('ANC-004', instanceId: 'selected', rank: 4);
    final state = ancestorDuel(
      playerField: ancestorField(
        participant: DuelParticipant.player,
        actionTraps: [trap, null, null, null, null],
        graveyard: [selected],
      ),
    );
    final engine = DuelEngine(chainEffects: AncetreEffectRegistry.create());

    final result = activateAndResolveAncestor(
      engine,
      state,
      ancestorLink(
        id: 'anc011-trap',
        effectKey: AncetreEffectKeys.anc011,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed2,
        sourceId: 'council',
        sourceCode: 'ANC-011',
        payload: const {
          'trigger': 'controlled_character_destroyed',
          'destroyed_rank': 5,
          'selected_instance_id': 'selected',
        },
      ),
    );

    expect(
        result.state.playerField.characterZones.first!.instanceId, 'selected');
    expect(
      result.state.playerField.characterZones.first!.position,
      BattlePosition.defense,
    );
  });

  test('ANC-012 annule le bannissement et détruit la carte adverse', () {
    const enemyEffectKey = 'test_enemy_banish';
    final graveTarget = ancestorCard('ANC-001', instanceId: 'grave-target');
    final refusal = ancestorCard(
      'ANC-012',
      instanceId: 'refusal',
      category: CardCategory.trap,
      subtype: 'counter',
      rank: null,
      atk: null,
      def: null,
      faceUp: false,
      position: null,
      zoneIndex: 0,
    );
    final enemyAction = ancestorCard(
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
    final state = ancestorDuel(
      activePlayer: DuelParticipant.ai,
      playerField: ancestorField(
        participant: DuelParticipant.player,
        actionTraps: [refusal, null, null, null, null],
        graveyard: [graveTarget],
      ),
      aiField: ancestorField(
        participant: DuelParticipant.ai,
        actionTraps: [enemyAction, null, null, null, null],
      ),
    );
    final engine = DuelEngine(
      chainEffects: {
        ...AncetreEffectRegistry.create(),
        enemyEffectKey: const _NoopEffect(),
      },
    );
    final enemyActivation = engine.activateChainEffect(
      state: state,
      link: ancestorLink(
        id: 'enemy-banish',
        effectKey: enemyEffectKey,
        player: DuelParticipant.ai,
        speed: ChainSpeed.speed1,
        sourceId: 'enemy-action',
        target: ChainTarget(cardInstanceId: 'grave-target'),
      ),
    );
    final counter = engine.activateChainEffect(
      state: enemyActivation.state,
      link: ancestorLink(
        id: 'anc012-counter',
        effectKey: AncetreEffectKeys.anc012,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed3,
        sourceId: 'refusal',
        sourceCode: 'ANC-012',
        payload: const {'target_link_id': 'enemy-banish'},
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

    expect(resolved.fizzledLinkIds, contains('enemy-banish'));
    expect(
        resolved.state.playerField.graveyard.single.instanceId, 'grave-target');
    expect(resolved.state.aiField.graveyard.single.instanceId, 'enemy-action');
  });

  test('ANC-013 place Mémoire puis en retire trois pour piocher/défausser', () {
    final grove = ancestorCard(
      'ANC-013',
      instanceId: 'grove',
      category: CardCategory.terrain,
      rank: null,
      atk: null,
      def: null,
      position: null,
    ).copyWith(counters: const {'mémoire': 2});
    final drawn = ancestorCard('ANC-001', instanceId: 'drawn');
    final discard = ancestorCard('ANC-003', instanceId: 'discard');
    final state = ancestorDuel(
      playerField: ancestorField(
        participant: DuelParticipant.player,
        terrain: grove,
        deck: [drawn],
        hand: [discard],
      ),
    );
    final engine = DuelEngine(chainEffects: AncetreEffectRegistry.create());

    final marked = activateAndResolveAncestor(
      engine,
      state,
      ancestorLink(
        id: 'anc013-memory',
        effectKey: AncetreEffectKeys.anc013,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'grove',
        sourceCode: 'ANC-013',
        payload: const {'mode': 'field_card_sent_to_graveyard'},
      ),
    );
    final spent = activateAndResolveAncestor(
      engine,
      marked.state,
      ancestorLink(
        id: 'anc013-spend',
        effectKey: AncetreEffectKeys.anc013,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'grove',
        sourceCode: 'ANC-013',
        payload: const {
          'mode': 'spend_memory',
          'discard_instance_id': 'discard',
        },
      ),
    );

    expect(spent.state.playerField.terrainZone!.counters['mémoire'], 0);
    expect(spent.state.playerField.hand.single.instanceId, 'drawn');
    expect(spent.state.playerField.graveyard.single.instanceId, 'discard');
  });

  test('ANC-014 gagne au début de la Préparation avec huit noms', () {
    var calabash = ancestorCard(
      'ANC-014',
      instanceId: 'calabash',
      category: CardCategory.relic,
      rank: null,
      atk: null,
      def: null,
      position: null,
      zoneIndex: 0,
    );
    var state = ancestorDuel(
      playerField: ancestorField(
        participant: DuelParticipant.player,
        actionTraps: [calabash, null, null, null, null],
        deck: [ancestorCard('ANC-003', instanceId: 'draw-card')],
      ),
    );
    final engine = DuelEngine(chainEffects: AncetreEffectRegistry.create());

    for (var index = 1; index <= 8; index++) {
      final result = activateAndResolveAncestor(
        engine,
        state,
        ancestorLink(
          id: 'anc014-name-$index',
          effectKey: AncetreEffectKeys.anc014,
          player: DuelParticipant.player,
          speed: ChainSpeed.speed1,
          sourceId: 'calabash',
          sourceCode: 'ANC-014',
          payload: {
            'mode': 'ancestor_character_sent_to_graveyard',
            'ancestor_card_code': 'ANC-NAME-$index',
          },
        ),
      );
      state = result.state;
    }
    calabash = state.playerField.actionTrapZones.first!;
    expect(calabash.counters['nom'], 8);

    final drawState = state.copyWith(
      currentPhase: DuelPhase.draw,
      drawPhaseResolved: true,
    );
    final preparation = engine.advancePhase(drawState);

    expect(preparation.state.currentPhase, DuelPhase.preparation);
    expect(preparation.state.winner, DuelParticipant.player);
    expect(preparation.state.endReason, DuelEndReason.cardEffect);
  });

  test('ANC-015 mélange cinq cartes, gagne des PV puis pioche une fois', () {
    final mother = ancestorCard(
      'ANC-015',
      instanceId: 'mother',
      category: CardCategory.mythic,
      rank: 10,
      atk: 3500,
      def: 3800,
      zoneIndex: 0,
    );
    final drawn = ancestorCard('ANC-003', instanceId: 'drawn');
    final first = ancestorCard('ANC-001', instanceId: 'first');
    final second = ancestorCard('ANC-002', instanceId: 'second');
    final state = ancestorDuel(
      playerField: ancestorField(
        participant: DuelParticipant.player,
        characters: [mother, null, null, null, null],
        deck: [drawn],
        graveyard: [first, second],
      ),
    );
    final engine = DuelEngine(
      chainEffects: AncetreEffectRegistry.create(
        deckShuffler: const StableShuffler(),
      ),
    );

    final summoned = activateAndResolveAncestor(
      engine,
      state,
      ancestorLink(
        id: 'anc015-summon',
        effectKey: AncetreEffectKeys.anc015,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'mother',
        sourceCode: 'ANC-015',
        payload: const {
          'trigger': 'on_summon',
          'target_instance_ids': ['first', 'second'],
        },
      ),
    );
    expect(summoned.state.playerLifePoints, 8600);
    expect(summoned.state.playerField.graveyard, isEmpty);

    final drawTrigger = activateAndResolveAncestor(
      engine,
      summoned.state,
      ancestorLink(
        id: 'anc015-draw',
        effectKey: AncetreEffectKeys.anc015,
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        sourceId: 'mother',
        sourceCode: 'ANC-015',
        payload: const {'trigger': 'ancestor_card_left_field'},
      ),
    );

    expect(drawTrigger.state.playerField.hand.single.instanceId, 'drawn');
  });
}
