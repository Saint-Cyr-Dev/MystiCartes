import 'package:mysticartes/game/battle_state.dart';
import 'package:mysticartes/game/card.dart';
import 'package:mysticartes/game/duel_engine.dart';
import 'package:mysticartes/game/duel_types.dart';
import 'package:mysticartes/game/effects/dozo_effects.dart';
import 'package:mysticartes/game/player.dart';
import 'package:test/test.dart';

const _keys = <String, String>{
  'DOZ-001': DozoEffectKeys.doz001,
  'DOZ-002': DozoEffectKeys.doz002,
  'DOZ-004': DozoEffectKeys.doz004,
  'DOZ-005': DozoEffectKeys.doz005,
  'DOZ-006': DozoEffectKeys.doz006,
  'DOZ-007': DozoEffectKeys.doz007,
  'DOZ-008': DozoEffectKeys.doz008,
  'DOZ-009': DozoEffectKeys.doz009,
  'DOZ-010': DozoEffectKeys.doz010,
  'DOZ-011': DozoEffectKeys.doz011,
  'DOZ-012': DozoEffectKeys.doz012,
  'DOZ-013': DozoEffectKeys.doz013,
  'DOZ-014': DozoEffectKeys.doz014,
  'DOZ-015': DozoEffectKeys.doz015,
};

CardInstance dozoCard(
  String code, {
  String? id,
  DuelParticipant owner = DuelParticipant.player,
  CardCategory category = CardCategory.character,
  String? subtype,
  String family = 'dozo',
  int? rank = 4,
  int? atk = 1500,
  int? def = 1500,
  bool faceUp = true,
  BattlePosition? position = BattlePosition.attack,
  int? zoneIndex,
  Map<String, int> counters = const {},
  Map<String, Object?> runtimeData = const {},
  String? effectKey,
}) =>
    CardInstance(
      instanceId: id ?? code.toLowerCase(),
      cardId: 'catalog-$code',
      cardCode: code,
      cardRevision: 1,
      category: category,
      rank: rank,
      subtype: subtype,
      primaryFamily: family,
      effectKey: effectKey ?? _keys[code],
      owner: owner,
      controller: owner,
      faceUp: faceUp,
      position: position,
      atk: atk,
      def: def,
      zoneIndex: zoneIndex,
      counters: counters,
      runtimeData: runtimeData,
    );

PlayerFieldState dozoField({
  required DuelParticipant participant,
  List<FieldCardInstance?>? characters,
  List<CardInstance?>? actionTraps,
  CardInstance? terrain,
  List<CardInstance> deck = const [],
  List<CardInstance> hand = const [],
  List<CardInstance> graveyard = const [],
  List<CardInstance> banished = const [],
}) =>
    PlayerFieldState(
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

DuelState dozoDuel({
  PlayerFieldState? playerField,
  PlayerFieldState? aiField,
  DuelParticipant active = DuelParticipant.player,
  DuelPhase phase = DuelPhase.main1,
  int turn = 2,
}) =>
    DuelState(
      playerField:
          playerField ?? dozoField(participant: DuelParticipant.player),
      aiField: aiField ?? dozoField(participant: DuelParticipant.ai),
      activePlayer: active,
      currentPhase: phase,
      turnNumber: turn,
    );

ChainLink dozoLink({
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

DuelState closeEmptyWindow(DuelEngine engine, DuelState state) {
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

final class RecordingDozoExtension implements DozoAncestralSummonExtension {
  bool called = false;

  @override
  DuelState summonFromMythicReserve({
    required DuelState state,
    required DuelParticipant participant,
    required String triggerCardCode,
    required String mythicCardCode,
  }) {
    called = triggerCardCode == 'DOZ-010' && mythicCardCode == 'DOZ-015';
    return state;
  }
}

void main() {
  group('Effets Dozo', () {
    test('DOZ-001 révèle au contrôleur le dessus du deck adverse', () {
      final source = dozoCard('DOZ-001', id: 'source');
      final top = dozoCard('X', id: 'top', owner: DuelParticipant.ai);
      final state = dozoDuel(
        playerField: dozoField(
          participant: DuelParticipant.player,
          characters: [source, null, null, null, null],
        ),
        aiField: dozoField(participant: DuelParticipant.ai, deck: [top]),
      );
      final result = activateAndResolve(
        DuelEngine(chainEffects: DozoEffectRegistry.create()),
        state,
        dozoLink(
          id: 'l1',
          key: DozoEffectKeys.doz001,
          player: DuelParticipant.player,
          sourceId: 'source',
          payload: const {'trigger': 'on_summon'},
        ),
      );
      expect(result.state.playerField.revealedCardInstanceIds, contains('top'));
      expect(result.state.aiField.deck.first.instanceId, 'top');
    });

    test('DOZ-002 gagne 300 ATK uniquement contre une Défense', () {
      final attacker = dozoCard('DOZ-002', id: 'archer', atk: 1500);
      final defender = dozoCard(
        'X',
        id: 'wall',
        owner: DuelParticipant.ai,
        family: 'savane',
        def: 1700,
        position: BattlePosition.defense,
      );
      final engine = DuelEngine(chainEffects: DozoEffectRegistry.create());
      var state = dozoDuel(
        phase: DuelPhase.battle,
        playerField: dozoField(
          participant: DuelParticipant.player,
          characters: [attacker, null, null, null, null],
        ),
        aiField: dozoField(
          participant: DuelParticipant.ai,
          characters: [defender, null, null, null, null],
        ),
      );
      final declaration = engine.declareAttack(
        state: state,
        participant: DuelParticipant.player,
        attackerInstanceId: 'archer',
        targetInstanceId: 'wall',
      );
      state = closeEmptyWindow(engine, declaration.state);
      final combat = engine.resolveAttack(
          state: state, declaration: declaration.declaration!);
      expect(combat.destroyedCardInstanceIds, contains('wall'));
      expect(combat.state.playerLifePoints, 8000);
    });

    test('DOZ-004 cherche un Piège Dozo puis met une carte sous le deck', () {
      final source = dozoCard('DOZ-004', id: 'reader');
      final trap = dozoCard(
        'T',
        id: 'trap',
        category: CardCategory.trap,
        family: 'dozo',
        rank: null,
        atk: null,
        def: null,
        position: null,
      );
      final handCard = dozoCard('H', id: 'hand');
      final state = dozoDuel(
        playerField: dozoField(
          participant: DuelParticipant.player,
          characters: [source, null, null, null, null],
          deck: [trap],
          hand: [handCard],
        ),
      );
      final result = activateAndResolve(
        DuelEngine(chainEffects: DozoEffectRegistry.create()),
        state,
        dozoLink(
          id: 'l4',
          key: DozoEffectKeys.doz004,
          player: DuelParticipant.player,
          sourceId: 'reader',
          payload: const {
            'trigger': 'on_summon',
            'trap_instance_id': 'trap',
            'bottom_instance_id': 'hand',
          },
        ),
      );
      expect(result.state.playerField.hand.single.instanceId, 'trap');
      expect(result.state.playerField.deck.last.instanceId, 'hand');
    });

    test('DOZ-005 marque une Proie et gagne 300 ATK contre elle', () {
      final hunter = dozoCard('DOZ-005', id: 'hunter', atk: 2200);
      final prey = dozoCard(
        'X',
        id: 'prey',
        owner: DuelParticipant.ai,
        family: 'savane',
        atk: 2400,
      );
      final engine = DuelEngine(chainEffects: DozoEffectRegistry.create());
      var state = dozoDuel(
        playerField: dozoField(
          participant: DuelParticipant.player,
          characters: [hunter, null, null, null, null],
        ),
        aiField: dozoField(
          participant: DuelParticipant.ai,
          characters: [prey, null, null, null, null],
        ),
      );
      state = activateAndResolve(
        engine,
        state,
        dozoLink(
          id: 'l5',
          key: DozoEffectKeys.doz005,
          player: DuelParticipant.player,
          sourceId: 'hunter',
          target: ChainTarget(cardInstanceId: 'prey'),
        ),
      ).state.copyWith(currentPhase: DuelPhase.battle);
      final declaration = engine.declareAttack(
        state: state,
        participant: DuelParticipant.player,
        attackerInstanceId: 'hunter',
        targetInstanceId: 'prey',
      );
      state = closeEmptyWindow(engine, declaration.state);
      final combat = engine.resolveAttack(
          state: state, declaration: declaration.declaration!);
      expect(combat.state.aiField.graveyard.single.instanceId, 'prey');
      expect(combat.state.aiLifePoints, 7900);
    });

    test('DOZ-006 autorise un Piège Dozo posé ce tour', () {
      final master = dozoCard('DOZ-006', id: 'master');
      final trap = dozoCard(
        'DOZ-011',
        id: 'trap',
        category: CardCategory.trap,
        subtype: 'normal',
        rank: null,
        atk: null,
        def: null,
        faceUp: false,
        position: null,
        runtimeData: const {CardRuntimeKeys.setOnTurn: 2},
      );
      final attacker = dozoCard(
        'X',
        id: 'attacker',
        owner: DuelParticipant.ai,
        family: 'savane',
      );
      final state = dozoDuel(
        playerField: dozoField(
          participant: DuelParticipant.player,
          characters: [master, null, null, null, null],
          actionTraps: [trap, null, null, null, null],
        ),
        aiField: dozoField(
          participant: DuelParticipant.ai,
          characters: [attacker, null, null, null, null],
        ),
      );
      final engine = DuelEngine(chainEffects: DozoEffectRegistry.create());
      final enabled = activateAndResolve(
        engine,
        state,
        dozoLink(
          id: 'l6',
          key: DozoEffectKeys.doz006,
          player: DuelParticipant.player,
          sourceId: 'master',
          target: ChainTarget(cardInstanceId: 'trap'),
        ),
      ).state;
      expect(
        enabled.playerField.actionTrapZones.first!
            .runtimeData[CardRuntimeKeys.sameTurnTrapActivationAllowed],
        2,
      );
      final activation = engine.activateChainEffect(
        state: enabled,
        link: dozoLink(
          id: 'trap-link',
          key: DozoEffectKeys.doz011,
          player: DuelParticipant.player,
          speed: ChainSpeed.speed2,
          sourceId: 'trap',
          target: ChainTarget(cardInstanceId: 'attacker'),
          payload: const {
            'trigger': 'opponent_attack_declared',
            'attack_declaration_id': 'attack-x',
          },
        ),
      );
      expect(activation.succeeded, isTrue);
    });

    test('DOZ-007 marque les adversaires puis bannit une Proie détruite', () {
      final captain = dozoCard('DOZ-007', id: 'captain');
      final enemy1 = dozoCard('X', id: 'e1', owner: DuelParticipant.ai);
      final enemy2 = dozoCard(
        'Y',
        id: 'e2',
        owner: DuelParticipant.ai,
        faceUp: false,
      );
      final engine = DuelEngine(chainEffects: DozoEffectRegistry.create());
      var state = dozoDuel(
        playerField: dozoField(
          participant: DuelParticipant.player,
          characters: [captain, null, null, null, null],
        ),
        aiField: dozoField(
          participant: DuelParticipant.ai,
          characters: [enemy1, enemy2, null, null, null],
        ),
      );
      state = activateAndResolve(
        engine,
        state,
        dozoLink(
          id: 'l7a',
          key: DozoEffectKeys.doz007,
          player: DuelParticipant.player,
          sourceId: 'captain',
          payload: const {'mode': 'on_summon'},
        ),
      ).state;
      expect(
          (state.aiField.characterZones.first as CardInstance)
              .counters['proie'],
          1);
      expect(
          (state.aiField.characterZones[1] as CardInstance).counters['proie'],
          isNull);
      final dead =
          dozoCard('X', id: 'dead', owner: DuelParticipant.ai, position: null);
      state = state.copyWith(
        aiField: state.aiField.copyWith(graveyard: [dead]),
      );
      state = activateAndResolve(
        engine,
        state,
        dozoLink(
          id: 'l7b',
          key: DozoEffectKeys.doz007,
          player: DuelParticipant.player,
          sourceId: 'captain',
          target: ChainTarget(cardInstanceId: 'dead'),
          payload: const {
            'mode': 'prey_destroyed_in_combat',
            'destroyed_had_prey': true,
          },
        ),
      ).state;
      expect(state.aiField.graveyard, isEmpty);
      expect(state.aiField.banished.single.instanceId, 'dead');
    });

    test('DOZ-008 marque une Proie et cherche un petit Personnage Dozo', () {
      final source = dozoCard(
        'DOZ-008',
        id: 'track',
        category: CardCategory.action,
        rank: null,
        atk: null,
        def: null,
        position: null,
      );
      final searched = dozoCard('X', id: 'searched', rank: 4);
      final enemy = dozoCard('Y', id: 'enemy', owner: DuelParticipant.ai);
      final state = dozoDuel(
        playerField: dozoField(
          participant: DuelParticipant.player,
          actionTraps: [source, null, null, null, null],
          deck: [searched],
        ),
        aiField: dozoField(
          participant: DuelParticipant.ai,
          characters: [enemy, null, null, null, null],
        ),
      );
      final result = activateAndResolve(
        DuelEngine(chainEffects: DozoEffectRegistry.create()),
        state,
        dozoLink(
          id: 'l8',
          key: DozoEffectKeys.doz008,
          player: DuelParticipant.player,
          sourceId: 'track',
          target: ChainTarget(cardInstanceId: 'enemy'),
          payload: const {'search_instance_id': 'searched'},
        ),
      );
      expect(
          (result.state.aiField.characterZones.first as CardInstance)
              .counters['proie'],
          1);
      expect(result.state.playerField.hand.single.instanceId, 'searched');
    });

    test('DOZ-009 retire 700 ATK/DEF à une Proie en Défense', () {
      final source = dozoCard(
        'DOZ-009',
        id: 'shot',
        category: CardCategory.action,
        subtype: 'quick',
        rank: null,
        atk: null,
        def: null,
        position: null,
      );
      final target = dozoCard(
        'X',
        id: 'prey',
        owner: DuelParticipant.ai,
        family: 'savane',
        atk: 2000,
        def: 1800,
        position: BattlePosition.defense,
        counters: const {'proie': 1},
      );
      final state = dozoDuel(
        playerField: dozoField(
          participant: DuelParticipant.player,
          actionTraps: [source, null, null, null, null],
        ),
        aiField: dozoField(
          participant: DuelParticipant.ai,
          characters: [target, null, null, null, null],
        ),
      );
      final result = activateAndResolve(
        DuelEngine(chainEffects: DozoEffectRegistry.create()),
        state,
        dozoLink(
          id: 'l9',
          key: DozoEffectKeys.doz009,
          player: DuelParticipant.player,
          speed: ChainSpeed.speed2,
          sourceId: 'shot',
          target: ChainTarget(cardInstanceId: 'prey'),
        ),
      );
      final modified = result.state.aiField.characterZones.first!;
      expect(modified.effectiveAtk, 1300);
      expect(modified.effectiveDef, 1100);
    });

    test('DOZ-010 paie le sacrifice et bannit exactement deux Pièges', () {
      final extension = RecordingDozoExtension();
      final source = dozoCard(
        'DOZ-010',
        id: 'oath',
        category: CardCategory.action,
        rank: null,
        atk: null,
        def: null,
        position: null,
      );
      final material = dozoCard('X', id: 'material', rank: 6);
      CardInstance trap(String id) => dozoCard(
            id,
            id: id,
            category: CardCategory.trap,
            rank: null,
            atk: null,
            def: null,
            position: null,
          );
      final state = dozoDuel(
        playerField: dozoField(
          participant: DuelParticipant.player,
          characters: [material, null, null, null, null],
          actionTraps: [source, null, null, null, null],
          graveyard: [trap('t1'), trap('t2')],
        ),
      );
      final result = activateAndResolve(
        DuelEngine(
          chainEffects: DozoEffectRegistry.create(
            ancestralSummonExtension: extension,
          ),
        ),
        state,
        dozoLink(
          id: 'l10',
          key: DozoEffectKeys.doz010,
          player: DuelParticipant.player,
          sourceId: 'oath',
          payload: const {
            'sacrifice_instance_id': 'material',
            'banish_trap_instance_ids': ['t1', 't2'],
          },
        ),
      );
      expect(extension.called, isTrue);
      expect(result.state.playerField.characterZones.first, isNull);
      expect(result.state.playerField.graveyard.single.instanceId, 'material');
      expect(result.state.playerField.banished.map((card) => card.instanceId),
          containsAll(['t1', 't2']));
    });

    test('DOZ-011 annule, passe en Défense et marque l’attaquant', () {
      final source = dozoCard(
        'DOZ-011',
        id: 'snare',
        category: CardCategory.trap,
        rank: null,
        atk: null,
        def: null,
        position: null,
      );
      final attacker = dozoCard('X', id: 'attacker', owner: DuelParticipant.ai);
      final state = dozoDuel(
        playerField: dozoField(
          participant: DuelParticipant.player,
          actionTraps: [source, null, null, null, null],
        ),
        aiField: dozoField(
          participant: DuelParticipant.ai,
          characters: [attacker, null, null, null, null],
        ),
      );
      final result = activateAndResolve(
        DuelEngine(chainEffects: DozoEffectRegistry.create()),
        state,
        dozoLink(
          id: 'l11',
          key: DozoEffectKeys.doz011,
          player: DuelParticipant.player,
          speed: ChainSpeed.speed2,
          sourceId: 'snare',
          target: ChainTarget(cardInstanceId: 'attacker'),
          payload: const {
            'trigger': 'opponent_attack_declared',
            'attack_declaration_id': 'attack-1',
          },
        ),
      );
      final changed = result.state.aiField.characterZones.first as CardInstance;
      expect(result.state.cancelledAttackDeclarationIds, contains('attack-1'));
      expect(changed.position, BattlePosition.defense);
      expect(changed.counters['proie'], 1);
    });

    test('DOZ-012 annule l’effet d’une Proie et bannit ce Personnage', () {
      final prey = dozoCard(
        'DOZ-002',
        id: 'prey',
        owner: DuelParticipant.ai,
        counters: const {'proie': 1},
      );
      final counter = dozoCard(
        'DOZ-012',
        id: 'counter',
        category: CardCategory.trap,
        subtype: 'counter',
        rank: null,
        atk: null,
        def: null,
        position: null,
      );
      final state = dozoDuel(
        active: DuelParticipant.ai,
        playerField: dozoField(
          participant: DuelParticipant.player,
          actionTraps: [counter, null, null, null, null],
        ),
        aiField: dozoField(
          participant: DuelParticipant.ai,
          characters: [prey, null, null, null, null],
        ),
      );
      final engine = DuelEngine(chainEffects: DozoEffectRegistry.create());
      final first = engine.activateChainEffect(
        state: state,
        link: dozoLink(
          id: 'prey-effect',
          key: DozoEffectKeys.doz002,
          player: DuelParticipant.ai,
          sourceId: 'prey',
          payload: const {'trigger': 'combat_calculation_refresh'},
        ),
      );
      final response = engine.activateChainEffect(
        state: first.state,
        link: dozoLink(
          id: 'counter-effect',
          key: DozoEffectKeys.doz012,
          player: DuelParticipant.player,
          speed: ChainSpeed.speed3,
          sourceId: 'counter',
          payload: const {'target_link_id': 'prey-effect'},
        ),
      );
      expect(response.succeeded, isTrue, reason: response.failure?.name);
      final pass1 = engine.passPriority(
          state: response.state, participant: DuelParticipant.ai);
      final result = engine.passPriority(
          state: pass1.state, participant: DuelParticipant.player);
      expect(result.fizzledLinkIds, contains('prey-effect'));
      expect(result.state.aiField.characterZones.first, isNull);
      expect(result.state.aiField.banished.single.instanceId, 'prey');
    });

    test('DOZ-013 applique son aura et marque une Proie après un Piège', () {
      final terrain = dozoCard(
        'DOZ-013',
        id: 'camp',
        category: CardCategory.terrain,
        rank: null,
        atk: null,
        def: null,
        position: null,
      );
      final ally = dozoCard('X', id: 'ally', atk: 1000, def: 1000);
      final enemy = dozoCard('Y', id: 'enemy', owner: DuelParticipant.ai);
      final engine = DuelEngine(chainEffects: DozoEffectRegistry.create());
      var state = dozoDuel(
        playerField: dozoField(
          participant: DuelParticipant.player,
          characters: [ally, null, null, null, null],
          terrain: terrain,
        ),
        aiField: dozoField(
          participant: DuelParticipant.ai,
          characters: [enemy, null, null, null, null],
        ),
      );
      state = activateAndResolve(
        engine,
        state,
        dozoLink(
          id: 'l13a',
          key: DozoEffectKeys.doz013,
          player: DuelParticipant.player,
          sourceId: 'camp',
          payload: const {'mode': 'continuous_refresh'},
        ),
      ).state;
      expect(state.playerField.characterZones.first!.effectiveAtk, 1200);
      expect(state.playerField.characterZones.first!.effectiveDef, 1200);
      state = activateAndResolve(
        engine,
        state,
        dozoLink(
          id: 'l13b',
          key: DozoEffectKeys.doz013,
          player: DuelParticipant.player,
          sourceId: 'camp',
          target: ChainTarget(cardInstanceId: 'enemy'),
          payload: const {'mode': 'trap_activated'},
        ),
      ).state;
      expect(
          (state.aiField.characterZones.first as CardInstance)
              .counters['proie'],
          1);
    });

    test('DOZ-014 équipe +400 ATK puis pose un Piège Dozo de la main', () {
      final relic = dozoCard(
        'DOZ-014',
        id: 'horn',
        category: CardCategory.relic,
        rank: null,
        atk: null,
        def: null,
        position: null,
      );
      final ally = dozoCard('X', id: 'ally', atk: 1800);
      final trap = dozoCard(
        'T',
        id: 'trap',
        category: CardCategory.trap,
        rank: null,
        atk: null,
        def: null,
        position: null,
      );
      final engine = DuelEngine(chainEffects: DozoEffectRegistry.create());
      var state = dozoDuel(
        playerField: dozoField(
          participant: DuelParticipant.player,
          characters: [ally, null, null, null, null],
          actionTraps: [relic, null, null, null, null],
          hand: [trap],
        ),
      );
      state = activateAndResolve(
        engine,
        state,
        dozoLink(
          id: 'l14a',
          key: DozoEffectKeys.doz014,
          player: DuelParticipant.player,
          sourceId: 'horn',
          target: ChainTarget(cardInstanceId: 'ally'),
          payload: const {'mode': 'equip'},
        ),
      ).state;
      expect(state.playerField.characterZones.first!.effectiveAtk, 2200);
      state = activateAndResolve(
        engine,
        state,
        dozoLink(
          id: 'l14b',
          key: DozoEffectKeys.doz014,
          player: DuelParticipant.player,
          sourceId: 'horn',
          payload: const {
            'mode': 'equipped_destroyed_prey',
            'destroyed_had_prey': true,
            'trap_instance_id': 'trap',
          },
        ),
      ).state;
      expect(state.playerField.hand, isEmpty);
      expect(state.playerField.actionTrapZones[1]!.instanceId, 'trap');
      expect(state.playerField.actionTrapZones[1]!.faceUp, isFalse);
    });

    test('DOZ-015 force les Proies à le cibler puis bannit une Proie', () {
      final mythic = dozoCard('DOZ-015',
          id: 'mythic',
          category: CardCategory.mythic,
          rank: 10,
          atk: 3600,
          def: 3500);
      final ally = dozoCard('X', id: 'ally');
      final prey = dozoCard(
        'Y',
        id: 'prey',
        owner: DuelParticipant.ai,
        family: 'savane',
        counters: const {'proie': 1},
      );
      final engine = DuelEngine(chainEffects: DozoEffectRegistry.create());
      var state = dozoDuel(
        active: DuelParticipant.ai,
        phase: DuelPhase.battle,
        playerField: dozoField(
          participant: DuelParticipant.player,
          characters: [mythic, ally, null, null, null],
        ),
        aiField: dozoField(
          participant: DuelParticipant.ai,
          characters: [prey, null, null, null, null],
        ),
      );
      final forbidden = engine.declareAttack(
        state: state,
        participant: DuelParticipant.ai,
        attackerInstanceId: 'prey',
        targetInstanceId: 'ally',
      );
      expect(forbidden.failure, DuelActionFailure.invalidAttackTarget);
      state = state.copyWith(
        activePlayer: DuelParticipant.player,
        currentPhase: DuelPhase.main1,
      );
      state = activateAndResolve(
        engine,
        state,
        dozoLink(
          id: 'l15',
          key: DozoEffectKeys.doz015,
          player: DuelParticipant.player,
          sourceId: 'mythic',
          target: ChainTarget(cardInstanceId: 'prey'),
          payload: const {'mode': 'banish_prey'},
        ),
      ).state;
      expect(state.aiField.characterZones.first, isNull);
      expect(state.aiField.banished.single.instanceId, 'prey');
      state = state.copyWith(currentPhase: DuelPhase.battle);
      final attack = engine.declareAttack(
        state: state,
        participant: DuelParticipant.player,
        attackerInstanceId: 'mythic',
      );
      expect(attack.failure, DuelActionFailure.attackerCannotAttackByEffect);
    });
  });
}
