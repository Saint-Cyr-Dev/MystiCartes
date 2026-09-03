import 'package:mysticartes/game/battle_state.dart';
import 'package:mysticartes/game/card.dart';
import 'package:mysticartes/game/duel_engine.dart';
import 'package:mysticartes/game/duel_types.dart';
import 'package:mysticartes/game/effects/lagune_effects.dart';
import 'package:mysticartes/game/player.dart';
import 'package:test/test.dart';

const _keys = <String, String>{
  'LAG-001': LaguneEffectKeys.lag001,
  'LAG-002': LaguneEffectKeys.lag002,
  'LAG-004': LaguneEffectKeys.lag004,
  'LAG-005': LaguneEffectKeys.lag005,
  'LAG-006': LaguneEffectKeys.lag006,
  'LAG-007': LaguneEffectKeys.lag007,
  'LAG-008': LaguneEffectKeys.lag008,
  'LAG-009': LaguneEffectKeys.lag009,
  'LAG-010': LaguneEffectKeys.lag010,
  'LAG-011': LaguneEffectKeys.lag011,
  'LAG-012': LaguneEffectKeys.lag012,
  'LAG-013': LaguneEffectKeys.lag013,
  'LAG-014': LaguneEffectKeys.lag014,
  'LAG-015': LaguneEffectKeys.lag015,
};

CardInstance lagoonCard(
  String code, {
  String? id,
  DuelParticipant owner = DuelParticipant.player,
  CardCategory category = CardCategory.character,
  String? subtype,
  String family = 'lagune',
  String? attribute = 'eau',
  int? rank = 4,
  int? atk = 1500,
  int? def = 1500,
  bool faceUp = true,
  BattlePosition? position = BattlePosition.attack,
  Map<String, int> counters = const {},
}) =>
    CardInstance(
      instanceId: id ?? code.toLowerCase(),
      cardId: 'catalog-$code',
      cardCode: code,
      cardRevision: 1,
      category: category,
      rank: rank,
      subtype: subtype,
      attribute: attribute,
      primaryFamily: family,
      effectKey: _keys[code],
      owner: owner,
      controller: owner,
      faceUp: faceUp,
      position: position,
      atk: atk,
      def: def,
      counters: counters,
    );

PlayerFieldState lagoonField({
  required DuelParticipant participant,
  List<FieldCardInstance?>? characters,
  List<CardInstance?>? actions,
  CardInstance? terrain,
  List<CardInstance> deck = const [],
  List<CardInstance> hand = const [],
  List<CardInstance> graveyard = const [],
}) =>
    PlayerFieldState(
      participant: participant,
      characterZones: characters ?? const [null, null, null, null, null],
      actionTrapZones: actions ?? const [null, null, null, null, null],
      terrainZone: terrain,
      deck: deck,
      hand: hand,
      graveyard: graveyard,
      banished: const [],
      mythicReserve: const [],
    );

DuelState lagoonDuel({
  PlayerFieldState? playerField,
  PlayerFieldState? aiField,
  DuelParticipant active = DuelParticipant.player,
  DuelPhase phase = DuelPhase.main1,
  int turn = 2,
}) =>
    DuelState(
      playerField:
          playerField ?? lagoonField(participant: DuelParticipant.player),
      aiField: aiField ?? lagoonField(participant: DuelParticipant.ai),
      activePlayer: active,
      currentPhase: phase,
      turnNumber: turn,
    );

ChainLink lagoonLink({
  required String id,
  required String key,
  required DuelParticipant player,
  ChainSpeed speed = ChainSpeed.speed1,
  String? sourceId,
  String? sourceCode,
  ChainTarget? target,
  Map<String, Object?> payload = const {},
}) =>
    ChainLink(
      linkId: id,
      effectKey: key,
      activatingPlayer: player,
      speed: speed,
      sourceCardInstanceId: sourceId,
      sourceCardCode: sourceCode,
      target: target,
      payload: payload,
    );

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
  final first = engine.passPriority(
    state: activation.state,
    participant: opponent,
  );
  return engine.passPriority(
    state: first.state,
    participant: link.activatingPlayer,
  );
}

DuelState closeWindow(DuelEngine engine, DuelState state) {
  final first = engine.passPriority(
    state: state,
    participant: state.chain.priorityPlayer!,
  );
  return engine
      .passPriority(
        state: first.state,
        participant: first.state.chain.priorityPlayer!,
      )
      .state;
}

final class RecordingLagoonSummon implements LaguneAncestralSummonExtension {
  bool called = false;

  @override
  DuelState summonFromMythicReserve({
    required DuelState state,
    required DuelParticipant participant,
    required String triggerCardCode,
    required String mythicCardCode,
  }) {
    called = triggerCardCode == 'LAG-010' && mythicCardCode == 'LAG-015';
    return state;
  }
}

final class TargetedDummyDestruction extends ChainEffectDefinition {
  const TargetedDummyDestruction();

  @override
  bool isTargetLegal(DuelState state, ChainLink link) => link.target != null;

  @override
  DuelState resolve(DuelState state, ChainLink link) => state;
}

void main() {
  group('Effets Lagune', () {
    test('LAG-001 pioche puis défausse après son retour en main', () {
      final source = lagoonCard('LAG-001', id: 'boat', position: null);
      final discarded = lagoonCard('X', id: 'discarded', position: null);
      final drawn = lagoonCard('Y', id: 'drawn', position: null);
      final state = lagoonDuel(
        playerField: lagoonField(
          participant: DuelParticipant.player,
          hand: [source, discarded],
          deck: [drawn],
        ),
      );
      final result = activateAndResolve(
        DuelEngine(chainEffects: LaguneEffectRegistry.create()),
        state,
        lagoonLink(
          id: 'l1',
          key: LaguneEffectKeys.lag001,
          player: DuelParticipant.player,
          sourceId: 'boat',
          sourceCode: 'LAG-001',
          payload: const {
            'trigger': 'returned_to_own_hand_by_effect',
            'discard_instance_id': 'discarded',
          },
        ),
      );
      expect(
        result.state.playerField.hand.map((card) => card.instanceId),
        containsAll(['boat', 'drawn']),
      );
      expect(result.state.playerField.graveyard.single.instanceId, 'discarded');
    });

    test('LAG-002 gagne 300 DEF lorsqu’il passe en Défense', () {
      final crab = lagoonCard(
        'LAG-002',
        id: 'crab',
        def: 1500,
        position: BattlePosition.defense,
      );
      final state = lagoonDuel(
        playerField: lagoonField(
          participant: DuelParticipant.player,
          characters: [crab, null, null, null, null],
        ),
      );
      final result = activateAndResolve(
        DuelEngine(chainEffects: LaguneEffectRegistry.create()),
        state,
        lagoonLink(
          id: 'l2',
          key: LaguneEffectKeys.lag002,
          player: DuelParticipant.player,
          sourceId: 'crab',
          payload: const {'trigger': 'entered_defense'},
        ),
      );
      expect(result.state.playerField.characterZones.first!.effectiveDef, 1800);
    });

    test('LAG-004 replace une Lagune sous le deck et gagne 300 PV', () {
      final diver = lagoonCard('LAG-004', id: 'diver');
      final pearl = lagoonCard('X', id: 'pearl', position: null);
      final state = lagoonDuel(
        playerField: lagoonField(
          participant: DuelParticipant.player,
          characters: [diver, null, null, null, null],
          graveyard: [pearl],
        ),
      );
      final result = activateAndResolve(
        DuelEngine(chainEffects: LaguneEffectRegistry.create()),
        state,
        lagoonLink(
          id: 'l4',
          key: LaguneEffectKeys.lag004,
          player: DuelParticipant.player,
          sourceId: 'diver',
          target: ChainTarget(cardInstanceId: 'pearl'),
          payload: const {'trigger': 'on_summon'},
        ),
      );
      expect(result.state.playerField.graveyard, isEmpty);
      expect(result.state.playerField.deck.last.instanceId, 'pearl');
      expect(result.state.playerLifePoints, 8300);
    });

    test('LAG-005 renvoie une autre Lagune et passe un adversaire en Défense',
        () {
      final guardian = lagoonCard('LAG-005', id: 'guardian');
      final returned = lagoonCard('X', id: 'returned');
      final enemy = lagoonCard(
        'Y',
        id: 'enemy',
        owner: DuelParticipant.ai,
        family: 'savane',
      );
      final state = lagoonDuel(
        playerField: lagoonField(
          participant: DuelParticipant.player,
          characters: [guardian, returned, null, null, null],
        ),
        aiField: lagoonField(
          participant: DuelParticipant.ai,
          characters: [enemy, null, null, null, null],
        ),
      );
      final result = activateAndResolve(
        DuelEngine(chainEffects: LaguneEffectRegistry.create()),
        state,
        lagoonLink(
          id: 'l5',
          key: LaguneEffectKeys.lag005,
          player: DuelParticipant.player,
          sourceId: 'guardian',
          target: ChainTarget(cardInstanceId: 'enemy'),
          payload: const {'return_instance_id': 'returned'},
        ),
      );
      expect(result.state.playerField.hand.single.instanceId, 'returned');
      expect(
        result.state.aiField.characterZones.first!.position,
        BattlePosition.defense,
      );
    });

    test('LAG-006 gagne 300 ATK au plus deux fois par tour', () {
      final prince = lagoonCard('LAG-006', id: 'prince', atk: 2500);
      final state = lagoonDuel(
        playerField: lagoonField(
          participant: DuelParticipant.player,
          characters: [prince, null, null, null, null],
        ),
      );
      final engine = DuelEngine(chainEffects: LaguneEffectRegistry.create());
      var next = state;
      for (var count = 1; count <= 2; count++) {
        next = activateAndResolve(
          engine,
          next,
          lagoonLink(
            id: 'l6-$count',
            key: LaguneEffectKeys.lag006,
            player: DuelParticipant.player,
            sourceId: 'prince',
            payload: const {'trigger': 'card_returned_to_hand'},
          ),
        ).state;
      }
      expect(next.playerField.characterZones.first!.effectiveAtk, 3100);
      final third = engine.activateChainEffect(
        state: next,
        link: lagoonLink(
          id: 'l6-3',
          key: LaguneEffectKeys.lag006,
          player: DuelParticipant.player,
          sourceId: 'prince',
          payload: const {'trigger': 'card_returned_to_hand'},
        ),
      );
      expect(third.failure, DuelActionFailure.chainActivationConditionNotMet);
    });

    test(
        'LAG-007 paie un retour, détruit une carte et résiste au renvoi adverse',
        () {
      final hippo = lagoonCard('LAG-007', id: 'hippo', rank: 8);
      final returned = lagoonCard('X', id: 'returned');
      final enemyAction = lagoonCard(
        'Y',
        id: 'enemy-action',
        owner: DuelParticipant.ai,
        family: 'savane',
        category: CardCategory.action,
        rank: null,
        atk: null,
        def: null,
        position: null,
      );
      final inverse = lagoonCard(
        'LAG-008',
        id: 'inverse',
        owner: DuelParticipant.ai,
        category: CardCategory.action,
        rank: null,
        atk: null,
        def: null,
        position: null,
      );
      final aiLagoon = lagoonCard(
        'Z',
        id: 'ai-lagoon',
        owner: DuelParticipant.ai,
        rank: 8,
      );
      final engine = DuelEngine(chainEffects: LaguneEffectRegistry.create());
      var state = lagoonDuel(
        playerField: lagoonField(
          participant: DuelParticipant.player,
          characters: [hippo, returned, null, null, null],
        ),
        aiField: lagoonField(
          participant: DuelParticipant.ai,
          characters: [aiLagoon, null, null, null, null],
          actions: [enemyAction, inverse, null, null, null],
        ),
      );
      state = activateAndResolve(
        engine,
        state,
        lagoonLink(
          id: 'l7',
          key: LaguneEffectKeys.lag007,
          player: DuelParticipant.player,
          sourceId: 'hippo',
          target: ChainTarget(cardInstanceId: 'enemy-action'),
          payload: const {'return_instance_id': 'returned'},
        ),
      ).state;
      expect(state.aiField.graveyard.single.instanceId, 'enemy-action');
      expect(state.playerField.hand.single.instanceId, 'returned');

      state = state.copyWith(activePlayer: DuelParticipant.ai);
      final blocked = engine.activateChainEffect(
        state: state,
        link: lagoonLink(
          id: 'l7-blocked',
          key: LaguneEffectKeys.lag008,
          player: DuelParticipant.ai,
          speed: ChainSpeed.speed2,
          sourceId: 'inverse',
          target: ChainTarget(cardInstanceId: 'ai-lagoon'),
          payload: const {'opponent_instance_id': 'hippo'},
        ),
      );
      expect(blocked.failure, DuelActionFailure.illegalChainTarget);
    });

    test('LAG-008 renvoie les deux Personnages dans leurs mains', () {
      final action = lagoonCard(
        'LAG-008',
        id: 'inverse',
        category: CardCategory.action,
        rank: null,
        atk: null,
        def: null,
        position: null,
      );
      final own = lagoonCard('X', id: 'own', rank: 4);
      final enemy = lagoonCard(
        'Y',
        id: 'enemy',
        owner: DuelParticipant.ai,
        family: 'savane',
        rank: 3,
      );
      final state = lagoonDuel(
        playerField: lagoonField(
          participant: DuelParticipant.player,
          characters: [own, null, null, null, null],
          actions: [action, null, null, null, null],
        ),
        aiField: lagoonField(
          participant: DuelParticipant.ai,
          characters: [enemy, null, null, null, null],
        ),
      );
      final result = activateAndResolve(
        DuelEngine(chainEffects: LaguneEffectRegistry.create()),
        state,
        lagoonLink(
          id: 'l8',
          key: LaguneEffectKeys.lag008,
          player: DuelParticipant.player,
          speed: ChainSpeed.speed2,
          sourceId: 'inverse',
          target: ChainTarget(cardInstanceId: 'own'),
          payload: const {'opponent_instance_id': 'enemy'},
        ),
      );
      expect(result.state.playerField.hand.single.instanceId, 'own');
      expect(result.state.aiField.hand.single.instanceId, 'enemy');
    });

    test('LAG-009 gagne 400 PV et change une position', () {
      final tide = lagoonCard(
        'LAG-009',
        id: 'tide',
        category: CardCategory.action,
        subtype: 'continuous',
        rank: null,
        atk: null,
        def: null,
        position: null,
      );
      final target = lagoonCard('X', id: 'target');
      final state = lagoonDuel(
        playerField: lagoonField(
          participant: DuelParticipant.player,
          characters: [target, null, null, null, null],
          actions: [tide, null, null, null, null],
        ),
      );
      final result = activateAndResolve(
        DuelEngine(chainEffects: LaguneEffectRegistry.create()),
        state,
        lagoonLink(
          id: 'l9',
          key: LaguneEffectKeys.lag009,
          player: DuelParticipant.player,
          sourceId: 'tide',
          target: ChainTarget(cardInstanceId: 'target'),
          payload: const {'trigger': 'own_lagoon_returned_to_hand'},
        ),
      );
      expect(result.state.playerLifePoints, 8400);
      expect(
        result.state.playerField.characterZones.first!.position,
        BattlePosition.defense,
      );
    });

    test('LAG-010 sacrifie au moins neuf rangs Eau et paie un retour', () {
      final extension = RecordingLagoonSummon();
      final chant = lagoonCard(
        'LAG-010',
        id: 'chant',
        category: CardCategory.action,
        rank: null,
        atk: null,
        def: null,
        position: null,
      );
      final water5 = lagoonCard('X', id: 'water5', rank: 5);
      final water4 = lagoonCard('Y', id: 'water4', rank: 4);
      final returned = lagoonCard(
        'Z',
        id: 'returned',
        category: CardCategory.trap,
        rank: null,
        atk: null,
        def: null,
        position: null,
      );
      final state = lagoonDuel(
        playerField: lagoonField(
          participant: DuelParticipant.player,
          characters: [water5, water4, null, null, null],
          actions: [chant, returned, null, null, null],
        ),
      );
      final result = activateAndResolve(
        DuelEngine(
          chainEffects: LaguneEffectRegistry.create(
            ancestralSummonExtension: extension,
          ),
        ),
        state,
        lagoonLink(
          id: 'l10',
          key: LaguneEffectKeys.lag010,
          player: DuelParticipant.player,
          sourceId: 'chant',
          payload: const {
            'sacrifice_instance_ids': ['water5', 'water4'],
            'return_instance_id': 'returned',
          },
        ),
      );
      expect(extension.called, isTrue);
      expect(result.state.playerField.graveyard, hasLength(2));
      expect(result.state.playerField.hand.single.instanceId, 'returned');
    });

    test('LAG-011 passe le nouveau rang 5 en Défense et annule ses effets', () {
      final net = lagoonCard(
        'LAG-011',
        id: 'net',
        category: CardCategory.trap,
        rank: null,
        atk: null,
        def: null,
        position: null,
      );
      final summoned = lagoonCard(
        'X',
        id: 'summoned',
        owner: DuelParticipant.ai,
        family: 'savane',
        rank: 5,
      );
      final state = lagoonDuel(
        playerField: lagoonField(
          participant: DuelParticipant.player,
          actions: [net, null, null, null, null],
        ),
        aiField: lagoonField(
          participant: DuelParticipant.ai,
          characters: [summoned, null, null, null, null],
        ),
      );
      final result = activateAndResolve(
        DuelEngine(chainEffects: LaguneEffectRegistry.create()),
        state,
        lagoonLink(
          id: 'l11',
          key: LaguneEffectKeys.lag011,
          player: DuelParticipant.player,
          speed: ChainSpeed.speed2,
          sourceId: 'net',
          target: ChainTarget(cardInstanceId: 'summoned'),
          payload: const {'trigger': 'opponent_character_summoned'},
        ),
      );
      final changed = result.state.aiField.characterZones.first as CardInstance;
      expect(changed.position, BattlePosition.defense);
      expect(changed.runtimeData[CardRuntimeKeys.effectsNegatedUntilTurn], 2);
    });

    test('LAG-012 renvoie la Lagune menacée et annule l’effet', () {
      final reflux = lagoonCard(
        'LAG-012',
        id: 'reflux',
        category: CardCategory.trap,
        subtype: 'counter',
        rank: null,
        atk: null,
        def: null,
        position: null,
      );
      final protected = lagoonCard('X', id: 'protected');
      final enemySource = lagoonCard(
        'Y',
        id: 'enemy-source',
        owner: DuelParticipant.ai,
        family: 'savane',
      );
      final effects = <String, ChainEffectDefinition>{
        ...LaguneEffectRegistry.create(),
        'destroy-target': const TargetedDummyDestruction(),
      };
      final engine = DuelEngine(chainEffects: effects);
      final state = lagoonDuel(
        active: DuelParticipant.ai,
        playerField: lagoonField(
          participant: DuelParticipant.player,
          characters: [protected, null, null, null, null],
          actions: [reflux, null, null, null, null],
        ),
        aiField: lagoonField(
          participant: DuelParticipant.ai,
          characters: [enemySource, null, null, null, null],
        ),
      );
      final first = engine.activateChainEffect(
        state: state,
        link: lagoonLink(
          id: 'destroy',
          key: 'destroy-target',
          player: DuelParticipant.ai,
          sourceId: 'enemy-source',
          target: ChainTarget(cardInstanceId: 'protected'),
        ),
      );
      final response = engine.activateChainEffect(
        state: first.state,
        link: lagoonLink(
          id: 'reflux-link',
          key: LaguneEffectKeys.lag012,
          player: DuelParticipant.player,
          speed: ChainSpeed.speed3,
          sourceId: 'reflux',
          target: ChainTarget(cardInstanceId: 'protected'),
          payload: const {'target_link_id': 'destroy'},
        ),
      );
      expect(response.succeeded, isTrue, reason: response.failure?.name);
      final pass1 = engine.passPriority(
        state: response.state,
        participant: DuelParticipant.ai,
      );
      final result = engine.passPriority(
        state: pass1.state,
        participant: DuelParticipant.player,
      );
      expect(result.fizzledLinkIds, contains('destroy'));
      expect(result.state.playerField.hand.single.instanceId, 'protected');
    });

    test('LAG-013 donne 200 DEF puis fait piocher et défausser', () {
      final terrain = lagoonCard(
        'LAG-013',
        id: 'lagoon',
        category: CardCategory.terrain,
        rank: null,
        atk: null,
        def: null,
        position: null,
      );
      final ally = lagoonCard('X', id: 'ally', def: 1000);
      final hand = lagoonCard('H', id: 'discarded', position: null);
      final drawn = lagoonCard('D', id: 'drawn', position: null);
      final engine = DuelEngine(chainEffects: LaguneEffectRegistry.create());
      var state = lagoonDuel(
        playerField: lagoonField(
          participant: DuelParticipant.player,
          characters: [ally, null, null, null, null],
          terrain: terrain,
          hand: [hand],
          deck: [drawn],
        ),
      );
      state = activateAndResolve(
        engine,
        state,
        lagoonLink(
          id: 'l13a',
          key: LaguneEffectKeys.lag013,
          player: DuelParticipant.player,
          sourceId: 'lagoon',
          payload: const {'mode': 'continuous_refresh'},
        ),
      ).state;
      expect(state.playerField.characterZones.first!.effectiveDef, 1200);
      state = activateAndResolve(
        engine,
        state,
        lagoonLink(
          id: 'l13b',
          key: LaguneEffectKeys.lag013,
          player: DuelParticipant.player,
          sourceId: 'lagoon',
          payload: const {
            'mode': 'card_returned_to_hand',
            'returned_owner': 'player',
            'discard_instance_id': 'discarded',
          },
        ),
      ).state;
      expect(state.playerField.hand.single.instanceId, 'drawn');
      expect(state.playerField.graveyard.single.instanceId, 'discarded');
    });

    test('LAG-014 s’équipe, revient en main et protège réellement au combat',
        () {
      final paddle = lagoonCard(
        'LAG-014',
        id: 'paddle',
        category: CardCategory.relic,
        rank: null,
        atk: null,
        def: null,
        position: null,
      );
      final ally = lagoonCard('X', id: 'ally', atk: 1000, def: 1000);
      final attacker = lagoonCard(
        'Y',
        id: 'attacker',
        owner: DuelParticipant.ai,
        family: 'savane',
        atk: 2000,
      );
      final engine = DuelEngine(chainEffects: LaguneEffectRegistry.create());
      var state = lagoonDuel(
        playerField: lagoonField(
          participant: DuelParticipant.player,
          characters: [ally, null, null, null, null],
          actions: [paddle, null, null, null, null],
        ),
        aiField: lagoonField(
          participant: DuelParticipant.ai,
          characters: [attacker, null, null, null, null],
        ),
      );
      state = activateAndResolve(
        engine,
        state,
        lagoonLink(
          id: 'l14a',
          key: LaguneEffectKeys.lag014,
          player: DuelParticipant.player,
          sourceId: 'paddle',
          target: ChainTarget(cardInstanceId: 'ally'),
          payload: const {'mode': 'equip'},
        ),
      ).state;
      expect(state.playerField.characterZones.first!.effectiveAtk, 1300);
      state = activateAndResolve(
        engine,
        state,
        lagoonLink(
          id: 'l14b',
          key: LaguneEffectKeys.lag014,
          player: DuelParticipant.player,
          sourceId: 'paddle',
          payload: const {'mode': 'return_and_protect'},
        ),
      ).state;
      expect(state.playerField.hand.single.instanceId, 'paddle');
      expect(state.playerField.characterZones.first!.effectiveAtk, 1000);

      state = state.copyWith(
        activePlayer: DuelParticipant.ai,
        currentPhase: DuelPhase.battle,
      );
      final declaration = engine.declareAttack(
        state: state,
        participant: DuelParticipant.ai,
        attackerInstanceId: 'attacker',
        targetInstanceId: 'ally',
      );
      state = closeWindow(engine, declaration.state);
      final combat = engine.resolveAttack(
        state: state,
        declaration: declaration.declaration!,
      );
      expect(combat.destroyedCardInstanceIds, isNot(contains('ally')));
      expect(combat.state.playerField.characterZones.first, isNotNull);
      expect(combat.state.playerLifePoints, 7000);
    });

    test('LAG-015 renvoie deux cartes puis interdit attaque et effets', () {
      final queen = lagoonCard(
        'LAG-015',
        id: 'queen',
        category: CardCategory.mythic,
        rank: 9,
        atk: 3300,
        def: 3600,
      );
      final enemy1 = lagoonCard(
        'LAG-002',
        id: 'enemy1',
        owner: DuelParticipant.ai,
        position: BattlePosition.defense,
      );
      final enemy2 = lagoonCard(
        'Y',
        id: 'enemy2',
        owner: DuelParticipant.ai,
        family: 'savane',
      );
      final locked = lagoonCard(
        'LAG-002',
        id: 'locked',
        owner: DuelParticipant.ai,
      );
      final engine = DuelEngine(chainEffects: LaguneEffectRegistry.create());
      var state = lagoonDuel(
        playerField: lagoonField(
          participant: DuelParticipant.player,
          characters: [queen, null, null, null, null],
        ),
        aiField: lagoonField(
          participant: DuelParticipant.ai,
          characters: [enemy1, enemy2, locked, null, null],
        ),
      );
      state = activateAndResolve(
        engine,
        state,
        lagoonLink(
          id: 'l15a',
          key: LaguneEffectKeys.lag015,
          player: DuelParticipant.player,
          sourceId: 'queen',
          payload: const {
            'mode': 'on_summon',
            'target_instance_ids': ['enemy1', 'enemy2'],
          },
        ),
      ).state;
      expect(state.aiField.hand, hasLength(2));
      state = activateAndResolve(
        engine,
        state,
        lagoonLink(
          id: 'l15b',
          key: LaguneEffectKeys.lag015,
          player: DuelParticipant.player,
          sourceId: 'queen',
          target: ChainTarget(cardInstanceId: 'locked'),
          payload: const {'mode': 'card_returned_to_hand'},
        ),
      ).state;
      state = state.copyWith(
        activePlayer: DuelParticipant.ai,
        currentPhase: DuelPhase.battle,
      );
      final attack = engine.declareAttack(
        state: state,
        participant: DuelParticipant.ai,
        attackerInstanceId: 'locked',
        targetInstanceId: 'queen',
      );
      expect(attack.failure, DuelActionFailure.attackerCannotAttackByEffect);
      final lockedCard = state.aiField.characterZones[2] as CardInstance;
      expect(
          lockedCard.runtimeData[CardRuntimeKeys.effectsNegatedUntilTurn], 2);
    });
  });
}
