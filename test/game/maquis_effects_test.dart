import 'package:mysticartes/game/battle_state.dart';
import 'package:mysticartes/game/card.dart';
import 'package:mysticartes/game/duel_engine.dart';
import 'package:mysticartes/game/duel_types.dart';
import 'package:mysticartes/game/effects/maquis_effects.dart';
import 'package:mysticartes/game/player.dart';
import 'package:test/test.dart';

const keys = <String, String>{
  'MAQ-001': MaquisEffectKeys.maq001,
  'MAQ-002': MaquisEffectKeys.maq002,
  'MAQ-004': MaquisEffectKeys.maq004,
  'MAQ-005': MaquisEffectKeys.maq005,
  'MAQ-006': MaquisEffectKeys.maq006,
  'MAQ-007': MaquisEffectKeys.maq007,
  'MAQ-008': MaquisEffectKeys.maq008,
  'MAQ-009': MaquisEffectKeys.maq009,
  'MAQ-010': MaquisEffectKeys.maq010,
  'MAQ-011': MaquisEffectKeys.maq011,
  'MAQ-012': MaquisEffectKeys.maq012,
  'MAQ-013': MaquisEffectKeys.maq013,
  'MAQ-014': MaquisEffectKeys.maq014,
  'MAQ-015': MaquisEffectKeys.maq015,
};

CardInstance card(
  String code, {
  String? id,
  DuelParticipant owner = DuelParticipant.player,
  CardCategory category = CardCategory.character,
  String family = 'maquis',
  int? rank = 4,
  int? atk = 1500,
  int? def = 1500,
  bool faceUp = true,
  BattlePosition? position = BattlePosition.attack,
  bool attacked = false,
}) =>
    CardInstance(
      instanceId: id ?? code.toLowerCase(),
      cardId: 'catalog-$code',
      cardCode: code,
      cardRevision: 1,
      category: category,
      rank: rank,
      primaryFamily: family,
      effectKey: keys[code],
      owner: owner,
      controller: owner,
      faceUp: faceUp,
      position: position,
      atk: atk,
      def: def,
      attackedThisTurn: attacked,
    );

PlayerFieldState field({
  required DuelParticipant player,
  List<FieldCardInstance?>? monsters,
  List<CardInstance?>? actions,
  CardInstance? terrain,
  List<CardInstance> deck = const [],
  List<CardInstance> hand = const [],
  List<CardInstance> grave = const [],
}) =>
    PlayerFieldState(
      participant: player,
      characterZones: monsters ?? const [null, null, null, null, null],
      actionTrapZones: actions ?? const [null, null, null, null, null],
      terrainZone: terrain,
      deck: deck,
      hand: hand,
      graveyard: grave,
      banished: const [],
      mythicReserve: const [],
    );

DuelState duel({
  PlayerFieldState? player,
  PlayerFieldState? ai,
  DuelPhase phase = DuelPhase.main1,
  int turn = 2,
}) =>
    DuelState(
      playerField: player ?? field(player: DuelParticipant.player),
      aiField: ai ?? field(player: DuelParticipant.ai),
      activePlayer: DuelParticipant.player,
      currentPhase: phase,
      turnNumber: turn,
    );

ChainLink link(
  String id,
  String key, {
  String? source,
  String? sourceCode,
  ChainTarget? target,
  Map<String, Object?> payload = const {},
  ChainSpeed speed = ChainSpeed.speed1,
}) =>
    ChainLink(
      linkId: id,
      effectKey: key,
      activatingPlayer: DuelParticipant.player,
      speed: speed,
      sourceCardInstanceId: source,
      sourceCardCode: sourceCode,
      target: target,
      payload: payload,
    );

DuelState resolve(DuelEngine engine, DuelState state, ChainLink effect) {
  final activated = engine.activateChainEffect(state: state, link: effect);
  expect(activated.succeeded, isTrue, reason: activated.failure?.name);
  final first = engine.passPriority(
      state: activated.state, participant: DuelParticipant.ai);
  return engine
      .passPriority(state: first.state, participant: DuelParticipant.player)
      .state;
}

final class Recorder implements MaquisAncestralSummonExtension {
  bool called = false;
  @override
  DuelState summonFromMythicReserve({
    required DuelState state,
    required DuelParticipant participant,
    required String triggerCardCode,
    required String mythicCardCode,
  }) {
    called = triggerCardCode == 'MAQ-010' && mythicCardCode == 'MAQ-015';
    return state;
  }
}

final class _LifeLossEffect extends ChainEffectDefinition {
  const _LifeLossEffect();
  @override
  DuelState resolve(DuelState state, ChainLink link) =>
      state.copyWith(playerLifePoints: state.playerLifePoints - 1000);
}

void main() {
  group('Effets Maquis', () {
    test('MAQ-001 renvoie une autre carte Maquis et gagne 300 PV', () {
      final source = card('MAQ-001', id: 'source');
      final target = card('X', id: 'target');
      final state = duel(
          player: field(
        player: DuelParticipant.player,
        monsters: [source, target, null, null, null],
      ));
      final result = resolve(
        DuelEngine(chainEffects: MaquisEffectRegistry.create()),
        state,
        link('l1', MaquisEffectKeys.maq001,
            source: 'source',
            target: ChainTarget(cardInstanceId: 'target'),
            payload: const {'trigger': 'on_summon'}),
      );
      expect(result.playerLifePoints, 8300);
      expect(result.playerField.hand.single.instanceId, 'target');
    });

    test('MAQ-002 donne 300 ATK après un gain de PV', () {
      final source = card('MAQ-002', id: 'source');
      final target = card('X', id: 'target', atk: 1000);
      final state = duel(
          player: field(
        player: DuelParticipant.player,
        monsters: [source, target, null, null, null],
      ));
      final result = resolve(
        DuelEngine(chainEffects: MaquisEffectRegistry.create()),
        state,
        link('l2', MaquisEffectKeys.maq002,
            source: 'source',
            target: ChainTarget(cardInstanceId: 'target'),
            payload: const {'trigger': 'controller_gained_life'}),
      );
      expect(
          (result.playerField.characterZones[1] as CardInstance).effectiveAtk,
          1300);
    });

    test('MAQ-004 gagne 400 ATK à la première Action Maquis', () {
      final source = card('MAQ-004', id: 'source', atk: 1700);
      final result = resolve(
        DuelEngine(chainEffects: MaquisEffectRegistry.create()),
        duel(
            player: field(
          player: DuelParticipant.player,
          monsters: [source, null, null, null, null],
        )),
        link('l4', MaquisEffectKeys.maq004,
            source: 'source',
            payload: const {'trigger': 'maquis_action_activated'}),
      );
      expect(
          (result.playerField.characterZones.first as CardInstance)
              .effectiveAtk,
          2100);
    });

    test('MAQ-005 choisit une Action Maquis parmi les trois cartes révélées',
        () {
      final source = card('MAQ-005', id: 'source');
      final one = card('A', id: 'one');
      final chosen = card('B',
          id: 'chosen',
          category: CardCategory.action,
          rank: null,
          atk: null,
          def: null,
          position: null);
      final three = card('C', id: 'three');
      final tail = card('D', id: 'tail');
      final result = resolve(
        DuelEngine(chainEffects: MaquisEffectRegistry.create()),
        duel(
            player: field(
          player: DuelParticipant.player,
          monsters: [source, null, null, null, null],
          deck: [one, chosen, three, tail],
        )),
        link('l5', MaquisEffectKeys.maq005, source: 'source', payload: const {
          'trigger': 'on_summon',
          'chosen_action_instance_id': 'chosen',
          'bottom_order_instance_ids': ['three', 'one'],
        }),
      );
      expect(result.playerField.hand.single.instanceId, 'chosen');
      expect(result.playerField.deck.map((c) => c.instanceId),
          ['tail', 'three', 'one']);
    });

    test('MAQ-006 gagne 400 PV puis pioche-défausse au seuil de 800', () {
      final source = card('MAQ-006', id: 'source');
      final top = card('T', id: 'top');
      final result = resolve(
        DuelEngine(chainEffects: MaquisEffectRegistry.create()),
        duel(
            player: field(
          player: DuelParticipant.player,
          monsters: [source, null, null, null, null],
          deck: [top],
        )),
        link('l6', MaquisEffectKeys.maq006, source: 'source', payload: const {
          'trigger': 'maquis_action_resolved',
          'life_gained_before_resolution': 400,
          'discard_instance_id': 'top',
        }),
      );
      expect(result.playerLifePoints, 8400);
      expect(result.playerField.graveyard.single.instanceId, 'top');
    });

    test('MAQ-007 défausse une Action et prépare une seconde attaque réduite',
        () {
      final source = card('MAQ-007', id: 'source', attacked: true);
      final action = card('A',
          id: 'action',
          category: CardCategory.action,
          rank: null,
          atk: null,
          def: null,
          position: null);
      final result = resolve(
        DuelEngine(chainEffects: MaquisEffectRegistry.create()),
        duel(
            player: field(
          player: DuelParticipant.player,
          monsters: [source, null, null, null, null],
          hand: [action],
        )),
        link('l7', MaquisEffectKeys.maq007,
            source: 'source', payload: const {'discard_instance_id': 'action'}),
      );
      final updated = result.playerField.characterZones.first as CardInstance;
      expect(updated.attackedThisTurn, isFalse);
      expect(updated.runtimeData[CardRuntimeKeys.combatDamageDivisor], 2);
      expect(result.playerField.graveyard.single.instanceId, 'action');
    });

    test('MAQ-008 soigne les deux joueurs puis pioche et défausse', () {
      final source = card('MAQ-008',
          id: 'source',
          category: CardCategory.action,
          rank: null,
          atk: null,
          def: null,
          position: null);
      final top = card('T', id: 'top');
      final result = resolve(
        DuelEngine(chainEffects: MaquisEffectRegistry.create()),
        duel(
            player: field(
          player: DuelParticipant.player,
          actions: [source, null, null, null, null],
          deck: [top],
        )),
        link('l8', MaquisEffectKeys.maq008,
            source: 'source', payload: const {'discard_instance_id': 'top'}),
      );
      expect(result.playerLifePoints, 8500);
      expect(result.aiLifePoints, 8500);
      expect(result.playerField.graveyard.single.instanceId, 'top');
    });

    test('MAQ-009 renvoie la cible puis invoque un Maquis de rang inférieur',
        () {
      final source = card('MAQ-009',
          id: 'source',
          category: CardCategory.action,
          rank: null,
          atk: null,
          def: null,
          position: null);
      final target = card('X', id: 'target', rank: 5);
      final summon =
          card('Y', id: 'summon', rank: 3, position: null, faceUp: false);
      final result = resolve(
        DuelEngine(chainEffects: MaquisEffectRegistry.create()),
        duel(
            player: field(
          player: DuelParticipant.player,
          monsters: [target, null, null, null, null],
          actions: [source, null, null, null, null],
          hand: [summon],
        )),
        link('l9', MaquisEffectKeys.maq009,
            source: 'source',
            target: ChainTarget(cardInstanceId: 'target'),
            payload: const {'summon_instance_id': 'summon'},
            speed: ChainSpeed.speed2),
      );
      expect(result.playerField.hand.single.instanceId, 'target');
      expect(
          (result.playerField.characterZones.first as CardInstance).instanceId,
          'summon');
    });

    test('MAQ-010 paie deux Actions distinctes et au moins 8 rangs', () {
      final recorder = Recorder();
      final source = card('MAQ-010',
          id: 'source',
          category: CardCategory.action,
          rank: null,
          atk: null,
          def: null,
          position: null);
      final a = card('A1',
          id: 'a',
          category: CardCategory.action,
          rank: null,
          atk: null,
          def: null,
          position: null);
      final b = card('A2',
          id: 'b',
          category: CardCategory.action,
          rank: null,
          atk: null,
          def: null,
          position: null);
      final m1 = card('M1', id: 'm1', rank: 4);
      final m2 = card('M2', id: 'm2', rank: 4);
      final result = resolve(
        DuelEngine(
            chainEffects: MaquisEffectRegistry.create(
                ancestralSummonExtension: recorder)),
        duel(
            player: field(
          player: DuelParticipant.player,
          monsters: [m1, m2, null, null, null],
          actions: [source, null, null, null, null],
          hand: [a, b],
        )),
        link('l10', MaquisEffectKeys.maq010, source: 'source', payload: const {
          'discard_action_instance_ids': ['a', 'b'],
          'sacrifice_instance_ids': ['m1', 'm2'],
        }),
      );
      expect(recorder.called, isTrue);
      expect(result.playerField.graveyard.map((c) => c.instanceId),
          containsAll(['a', 'b', 'm1', 'm2']));
    });

    test('MAQ-011 annule une attaque et renvoie un Maquis', () {
      final source = card('MAQ-011',
          id: 'source',
          category: CardCategory.trap,
          rank: null,
          atk: null,
          def: null,
          position: null);
      final target = card('X', id: 'target');
      final result = resolve(
        DuelEngine(chainEffects: MaquisEffectRegistry.create()),
        duel(
            player: field(
          player: DuelParticipant.player,
          monsters: [target, null, null, null, null],
          actions: [source, null, null, null, null],
        )),
        link('l11', MaquisEffectKeys.maq011,
            source: 'source',
            speed: ChainSpeed.speed2,
            target: ChainTarget(cardInstanceId: 'target'),
            payload: const {
              'trigger': 'opponent_attack_declared',
              'attack_declaration_id': 'attack-1',
            }),
      );
      expect(result.cancelledAttackDeclarationIds, contains('attack-1'));
      expect(result.playerField.hand.single.instanceId, 'target');
    });

    test('MAQ-012 annule une perte de PV hors combat et gagne 300 PV', () {
      final trap = card('MAQ-012',
          id: 'trap',
          category: CardCategory.trap,
          rank: null,
          atk: null,
          def: null,
          position: null);
      final discard = card('D', id: 'discard', position: null);
      final engine = DuelEngine(chainEffects: {
        ...MaquisEffectRegistry.create(),
        'fake_loss': const _LifeLossEffect(),
      });
      var state = duel(
          player: field(
        player: DuelParticipant.player,
        actions: [trap, null, null, null, null],
        hand: [discard],
      )).copyWith(activePlayer: DuelParticipant.ai);
      final adverse = ChainLink(
        linkId: 'loss',
        effectKey: 'fake_loss',
        activatingPlayer: DuelParticipant.ai,
        speed: ChainSpeed.speed1,
      );
      state = engine.activateChainEffect(state: state, link: adverse).state;
      final counter = link('counter', MaquisEffectKeys.maq012,
          source: 'trap',
          speed: ChainSpeed.speed3,
          payload: const {
            'trigger': 'opponent_effect_life_loss',
            'target_link_id': 'loss',
            'discard_instance_id': 'discard',
          });
      final activated = engine.activateChainEffect(state: state, link: counter);
      expect(activated.succeeded, isTrue, reason: activated.failure?.name);
      final first = engine.passPriority(
          state: activated.state, participant: DuelParticipant.ai);
      final result = engine
          .passPriority(state: first.state, participant: DuelParticipant.player)
          .state;
      expect(result.playerLifePoints, 8300);
      expect(result.playerField.graveyard.single.instanceId, 'discard');
    });

    test('MAQ-013 renforce les Maquis et soigne son propriétaire', () {
      final terrain = card('MAQ-013',
          id: 'terrain',
          category: CardCategory.terrain,
          rank: null,
          atk: null,
          def: null,
          position: null);
      final monster = card('X', id: 'monster', atk: 1000, def: 1000);
      final engine = DuelEngine(chainEffects: MaquisEffectRegistry.create());
      var state = duel(
          player: field(
        player: DuelParticipant.player,
        monsters: [monster, null, null, null, null],
        terrain: terrain,
      ));
      state = resolve(
          engine,
          state,
          link('aura', MaquisEffectKeys.maq013,
              source: 'terrain',
              payload: const {'mode': 'continuous_refresh'}));
      state = resolve(
          engine,
          state,
          link('heal', MaquisEffectKeys.maq013,
              source: 'terrain',
              payload: const {
                'mode': 'other_card_life_gain',
                'source_card_instance_id': 'other',
              }));
      expect(
          (state.playerField.characterZones.first as CardInstance).effectiveAtk,
          1200);
      expect(state.playerLifePoints, 8200);
    });

    test('MAQ-014 reçoit 3 Portions puis en consomme une pour 600 PV', () {
      final relic = card('MAQ-014',
          id: 'relic',
          category: CardCategory.relic,
          rank: null,
          atk: null,
          def: null,
          position: null,
          faceUp: false);
      final engine = DuelEngine(chainEffects: MaquisEffectRegistry.create());
      var state = duel(
          player: field(
        player: DuelParticipant.player,
        actions: [relic, null, null, null, null],
      ));
      state = resolve(
          engine,
          state,
          link('open', MaquisEffectKeys.maq014,
              source: 'relic', payload: const {'mode': 'activate'}));
      state = resolve(
          engine,
          state,
          link('use', MaquisEffectKeys.maq014,
              source: 'relic', payload: const {'mode': 'consume'}));
      expect(state.playerLifePoints, 8600);
      expect(state.playerField.actionTrapZones.first!.counters['portion'], 2);
    });

    test('MAQ-015 gagne 1000 PV, récupère une Action puis détruit une carte',
        () {
      final mythic = card('MAQ-015', id: 'mythic', rank: 9);
      final action = card('A',
          id: 'action',
          category: CardCategory.action,
          rank: null,
          atk: null,
          def: null,
          position: null);
      final enemy = card('E', id: 'enemy', owner: DuelParticipant.ai);
      final engine = DuelEngine(chainEffects: MaquisEffectRegistry.create());
      var state = duel(
        player: field(
            player: DuelParticipant.player,
            monsters: [mythic, null, null, null, null],
            grave: [action]),
        ai: field(
            player: DuelParticipant.ai,
            monsters: [enemy, null, null, null, null]),
      );
      state = resolve(
          engine,
          state,
          link('summon', MaquisEffectKeys.maq015,
              source: 'mythic',
              payload: const {
                'mode': 'on_summon',
                'recover_action_instance_id': 'action',
              }));
      state = resolve(
          engine,
          state,
          link('destroy', MaquisEffectKeys.maq015,
              source: 'mythic',
              target: ChainTarget(cardInstanceId: 'enemy'),
              payload: const {'mode': 'second_action_resolved'}));
      expect(state.playerLifePoints, 9000);
      expect(state.playerField.hand.single.instanceId, 'action');
      expect(state.aiField.characterZones.first, isNull);
      expect(state.aiField.graveyard.single.instanceId, 'enemy');
    });
  });
}
