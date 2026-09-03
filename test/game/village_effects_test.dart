import 'package:mysticartes/game/battle_state.dart';
import 'package:mysticartes/game/card.dart';
import 'package:mysticartes/game/duel_engine.dart';
import 'package:mysticartes/game/duel_types.dart';
import 'package:mysticartes/game/effects/village_effects.dart';
import 'package:mysticartes/game/player.dart';
import 'package:test/test.dart';

const _keys = <String, String>{
  'VIL-001': VillageEffectKeys.vil001,
  'VIL-002': VillageEffectKeys.vil002,
  'VIL-004': VillageEffectKeys.vil004,
  'VIL-005': VillageEffectKeys.vil005,
  'VIL-006': VillageEffectKeys.vil006,
  'VIL-007': VillageEffectKeys.vil007,
  'VIL-008': VillageEffectKeys.vil008,
  'VIL-009': VillageEffectKeys.vil009,
  'VIL-010': VillageEffectKeys.vil010,
  'VIL-011': VillageEffectKeys.vil011,
  'VIL-012': VillageEffectKeys.vil012,
  'VIL-013': VillageEffectKeys.vil013,
  'VIL-014': VillageEffectKeys.vil014,
  'VIL-015': VillageEffectKeys.vil015,
};

CardInstance card(
  String code, {
  String? id,
  DuelParticipant owner = DuelParticipant.player,
  CardCategory category = CardCategory.character,
  String? subtype,
  String family = 'village',
  int? rank = 4,
  int? atk = 1500,
  int? def = 1500,
  BattlePosition? position = BattlePosition.attack,
  Map<String, int> counters = const {},
  List<String> attached = const [],
  Map<String, Object?> runtimeData = const {},
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
      effectKey: _keys[code],
      owner: owner,
      controller: owner,
      faceUp: true,
      position: position,
      atk: atk,
      def: def,
      counters: counters,
      attachedCardInstanceIds: attached,
      runtimeData: runtimeData,
    );

CardInstance equipment(String code, {String? id}) => card(
      code,
      id: id,
      category: CardCategory.action,
      subtype: 'equipment',
      family: 'other',
      rank: null,
      atk: null,
      def: null,
      position: null,
    );

PlayerFieldState field({
  required DuelParticipant player,
  List<FieldCardInstance?>? characters,
  List<CardInstance?>? actions,
  CardInstance? terrain,
  List<CardInstance> deck = const [],
  List<CardInstance> hand = const [],
  List<CardInstance> grave = const [],
}) =>
    PlayerFieldState(
      participant: player,
      characterZones: characters ?? const [null, null, null, null, null],
      actionTrapZones: actions ?? const [null, null, null, null, null],
      terrainZone: terrain,
      deck: deck,
      hand: hand,
      graveyard: grave,
      banished: const [],
      mythicReserve: const [],
    );

DuelState duel({PlayerFieldState? player, PlayerFieldState? ai}) => DuelState(
      playerField: player ?? field(player: DuelParticipant.player),
      aiField: ai ?? field(player: DuelParticipant.ai),
      activePlayer: DuelParticipant.player,
      currentPhase: DuelPhase.main1,
      turnNumber: 2,
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

DuelState resolve(DuelState state, ChainLink effect,
    {Map<String, ChainEffectDefinition>? effects}) {
  final engine =
      DuelEngine(chainEffects: effects ?? VillageEffectRegistry.create());
  final activation = engine.activateChainEffect(state: state, link: effect);
  expect(activation.succeeded, isTrue, reason: activation.failure?.name);
  final first = engine.passPriority(
      state: activation.state, participant: DuelParticipant.ai);
  return engine
      .passPriority(state: first.state, participant: DuelParticipant.player)
      .state;
}

final class FusionRecorder implements VillageFusionSummonExtension {
  bool called = false;
  @override
  DuelState summonFromMythicReserve({
    required DuelState state,
    required DuelParticipant participant,
    required String triggerCardCode,
    required String mythicCardCode,
  }) {
    called = triggerCardCode == 'VIL-010' && mythicCardCode == 'VIL-015';
    return state;
  }
}

void main() {
  group('Effets Village', () {
    test('VIL-001 replace un Équipement du Cimetière sous le deck', () {
      final target = equipment('EQ-A', id: 'eq');
      final state = duel(
          player: field(
              player: DuelParticipant.player,
              grave: [card('VIL-001'), target]));
      final result = resolve(
          state,
          link('l1', VillageEffectKeys.vil001,
              sourceCode: 'VIL-001',
              target: ChainTarget(cardInstanceId: 'eq'),
              payload: const {'trigger': 'sent_from_field_to_graveyard'}));
      expect(result.playerField.graveyard.map((c) => c.instanceId),
          isNot(contains('eq')));
      expect(result.playerField.deck.last.instanceId, 'eq');
    });

    test('VIL-002 donne 300 DEF à un Personnage Village', () {
      final source = card('VIL-002', id: 'source');
      final target = card('ALLY', id: 'target', def: 1000);
      final result = resolve(
          duel(
              player: field(
                  player: DuelParticipant.player,
                  characters: [source, target, null, null, null])),
          link('l2', VillageEffectKeys.vil002,
              source: 'source',
              target: ChainTarget(cardInstanceId: 'target'),
              payload: const {'trigger': 'on_summon'}));
      expect(
          (result.playerField.characterZones[1] as CardInstance).effectiveDef,
          1300);
    });

    test('VIL-004 cherche un Équipement puis défausse une carte', () {
      final source = card('VIL-004', id: 'source');
      final eq = equipment('EQ-A', id: 'eq');
      final discard = card('HAND', id: 'discard', position: null);
      final result = resolve(
          duel(
              player: field(
                  player: DuelParticipant.player,
                  characters: [source, null, null, null, null],
                  deck: [eq],
                  hand: [discard])),
          link('l4', VillageEffectKeys.vil004,
              source: 'source',
              payload: const {
                'trigger': 'on_summon',
                'equipment_instance_id': 'eq',
                'discard_instance_id': 'discard'
              }));
      expect(result.playerField.hand.single.instanceId, 'eq');
      expect(result.playerField.graveyard.single.instanceId, 'discard');
    });

    test('VIL-005 gagne 500 PV puis pioche et défausse', () {
      final source = card('VIL-005', id: 'source');
      final top = card('TOP', id: 'top', position: null);
      final discard = card('HAND', id: 'discard', position: null);
      final result = resolve(
          duel(
              player: field(
                  player: DuelParticipant.player,
                  characters: [source, null, null, null, null],
                  deck: [top],
                  hand: [discard])),
          link('l5', VillageEffectKeys.vil005,
              source: 'source',
              payload: const {
                'trigger': 'equipped_card_left_field',
                'discard_instance_id': 'discard'
              }));
      expect(result.playerLifePoints, 8500);
      expect(result.playerField.hand.single.instanceId, 'top');
    });

    test('VIL-006 rééquipe un Équipement du Cimetière et le marque à bannir',
        () {
      final source = card('VIL-006', id: 'source');
      final target = card('ALLY', id: 'target');
      final eq = equipment('EQ-A', id: 'eq');
      final result = resolve(
          duel(
              player: field(
                  player: DuelParticipant.player,
                  characters: [source, target, null, null, null],
                  grave: [eq])),
          link('l6', VillageEffectKeys.vil006,
              source: 'source',
              target: ChainTarget(cardInstanceId: 'target'),
              payload: const {
                'mode': 'reequip',
                'equipment_instance_id': 'eq'
              }));
      expect(
          result.playerField.actionTrapZones
              .whereType<CardInstance>()
              .single
              .runtimeData['banish_when_leaves_field'],
          isTrue);
      expect(
          (result.playerField.characterZones[1] as CardInstance)
              .attachedCardInstanceIds,
          contains('eq'));
    });

    test('VIL-007 protège la première autre carte Village', () {
      final source = card('VIL-007', id: 'source');
      final target = card('ALLY', id: 'target');
      final result = resolve(
          duel(
              player: field(
                  player: DuelParticipant.player,
                  characters: [source, target, null, null, null])),
          link('l7', VillageEffectKeys.vil007,
              source: 'source',
              target: ChainTarget(cardInstanceId: 'target'),
              payload: const {
                'trigger': 'other_village_would_be_destroyed_by_opponent_effect'
              }));
      expect(result.preventedEffectDestructionInstanceIds, contains('target'));
    });

    test('VIL-008 gagne un marqueur Outil lors d’un équipement', () {
      final source = card('VIL-008',
          id: 'source',
          category: CardCategory.action,
          rank: null,
          atk: null,
          def: null,
          position: null);
      final result = resolve(
          duel(
              player: field(
                  player: DuelParticipant.player,
                  actions: [source, null, null, null, null])),
          link('l8', VillageEffectKeys.vil008,
              source: 'source', payload: const {'mode': 'equipment_attached'}));
      expect(result.playerField.actionTrapZones.first!.counters['outil'], 1);
    });

    test('VIL-009 équipe un Village et lui donne 400 DEF', () {
      final source = card('VIL-009',
          id: 'source',
          category: CardCategory.action,
          subtype: 'equipment',
          rank: null,
          atk: null,
          def: null,
          position: null);
      final target = card('ALLY', id: 'target', def: 1200);
      final result = resolve(
          duel(
              player: field(
                  player: DuelParticipant.player,
                  characters: [target, null, null, null, null],
                  actions: [source, null, null, null, null])),
          link('l9', VillageEffectKeys.vil009,
              source: 'source',
              target: ChainTarget(cardInstanceId: 'target'),
              payload: const {'mode': 'equip'}));
      expect(
          (result.playerField.characterZones.first as CardInstance)
              .effectiveDef,
          1600);
    });

    test('VIL-010 paie les trois matériaux et appelle l’extension Fusion', () {
      final recorder = FusionRecorder();
      final a = card('VIL-004', id: 'a');
      final b = card('VIL-006', id: 'b');
      final eq = equipment('EQ-A', id: 'eq');
      final source = card('VIL-010',
          id: 'source',
          category: CardCategory.action,
          rank: null,
          atk: null,
          def: null,
          position: null);
      final effects =
          VillageEffectRegistry.create(fusionSummonExtension: recorder);
      final result = resolve(
          duel(
              player: field(
                  player: DuelParticipant.player,
                  characters: [a, b, null, null, null],
                  actions: [source, eq, null, null, null])),
          link('l10', VillageEffectKeys.vil010,
              source: 'source',
              payload: const {
                'mode': 'fusion_cost',
                'material_instance_ids': ['a', 'b', 'eq']
              }),
          effects: effects);
      expect(result.playerField.graveyard.map((c) => c.instanceId),
          containsAll(['a', 'b', 'eq']));
      expect(recorder.called, isTrue);
    });

    test('VIL-011 donne 1000 DEF seulement pour le combat', () {
      final source = card('VIL-011',
          id: 'source',
          category: CardCategory.trap,
          rank: null,
          atk: null,
          def: null,
          position: null);
      final target = card('ALLY',
          id: 'target', def: 1500, position: BattlePosition.defense);
      final result = resolve(
          duel(
              player: field(
                  player: DuelParticipant.player,
                  characters: [target, null, null, null, null],
                  actions: [source, null, null, null, null])),
          link('l11', VillageEffectKeys.vil011,
              source: 'source',
              speed: ChainSpeed.speed2,
              target: ChainTarget(cardInstanceId: 'target'),
              payload: const {'trigger': 'village_defender_attacked'}));
      expect(
          (result.playerField.characterZones.first as CardInstance)
              .runtimeData[CardRuntimeKeys.combatOnlyDefDelta],
          1000);
    });

    test('VIL-012 annule et détruit la carte adverse menaçant un Équipement',
        () {
      final trap = card('VIL-012',
          id: 'trap',
          category: CardCategory.trap,
          rank: null,
          atk: null,
          def: null,
          position: null);
      final eq = equipment('EQ-A', id: 'eq');
      final enemy = card('ENEMY-EFFECT',
          id: 'enemy',
          owner: DuelParticipant.ai,
          category: CardCategory.action,
          rank: null,
          atk: null,
          def: null,
          position: null);
      final threatening = ChainLink(
          linkId: 'threat',
          effectKey: 'noop',
          activatingPlayer: DuelParticipant.ai,
          speed: ChainSpeed.speed2,
          sourceCardInstanceId: 'enemy');
      var state = duel(
          player: field(
              player: DuelParticipant.player,
              actions: [trap, eq, null, null, null]),
          ai: field(
              player: DuelParticipant.ai,
              actions: [enemy, null, null, null, null]));
      state = state.copyWith(
          chain: ChainState(
              links: [threatening],
              window: ResponseWindowType.effectActivation,
              priorityPlayer: DuelParticipant.player));
      final definition =
          VillageEffectRegistry.create()[VillageEffectKeys.vil012]!;
      final counter = link('counter', VillageEffectKeys.vil012,
          source: 'trap',
          speed: ChainSpeed.speed3,
          payload: const {
            'trigger': 'equipment_would_be_destroyed_or_banished',
            'target_link_id': 'threat',
            'equipment_instance_id': 'eq'
          });
      expect(definition.canActivate(state, counter), isTrue);
      final result = definition.resolve(state, counter);
      expect(result.chain.negatedLinkIds, contains('threat'));
      expect(result.aiField.graveyard.single.instanceId, 'enemy');
    });

    test('VIL-013 ranime un Village puis lui attache le premier Équipement',
        () {
      final terrain = card('VIL-013',
          id: 'terrain',
          category: CardCategory.terrain,
          rank: null,
          atk: null,
          def: null,
          position: null);
      final target = card('ALLY', id: 'target', position: null);
      final eq = equipment('EQ-A', id: 'eq');
      final result = resolve(
          duel(
              player: field(
                  player: DuelParticipant.player,
                  actions: [eq, null, null, null, null],
                  terrain: terrain,
                  grave: [target])),
          link('l13', VillageEffectKeys.vil013,
              source: 'terrain',
              target: ChainTarget(cardInstanceId: 'target'),
              payload: const {
                'mode': 'equip_village_from_grave',
                'equipment_instance_id': 'eq'
              }));
      final revived = result.playerField.characterZones.first as CardInstance;
      expect(revived.position, BattlePosition.defense);
      expect(revived.attachedCardInstanceIds, contains('eq'));
      expect(revived.runtimeData[CardRuntimeKeys.effectsNegatedUntilTurn], 2);
    });

    test('VIL-014 gagne 300 ATK/DEF par autre Équipement, maximum 900', () {
      final hammer = card('VIL-014',
          id: 'hammer',
          category: CardCategory.relic,
          rank: null,
          atk: null,
          def: null,
          position: null,
          runtimeData: const {CardRuntimeKeys.equippedToInstanceId: 'target'});
      final target = card('ALLY',
          id: 'target', atk: 1000, def: 1000, attached: const ['hammer']);
      final result = resolve(
          duel(
              player: field(player: DuelParticipant.player, characters: [
            target,
            null,
            null,
            null,
            null
          ], actions: [
            hammer,
            equipment('A'),
            equipment('B'),
            null,
            null
          ])),
          link('l14', VillageEffectKeys.vil014,
              source: 'hammer', payload: const {'mode': 'refresh_bonus'}));
      final boosted = result.playerField.characterZones.first!;
      expect(boosted.effectiveAtk, 1600);
      expect(boosted.effectiveDef, 1600);
    });

    test('VIL-015 équipe deux Équipements de noms différents du Cimetière', () {
      final source = card('VIL-015', id: 'source');
      final first = equipment('EQ-A', id: 'a');
      final second = equipment('EQ-B', id: 'b');
      final result = resolve(
          duel(
              player: field(
                  player: DuelParticipant.player,
                  characters: [source, null, null, null, null],
                  grave: [first, second])),
          link('l15', VillageEffectKeys.vil015,
              source: 'source',
              payload: const {
                'trigger': 'on_summon',
                'equipment_instance_ids': ['a', 'b']
              }));
      expect(
          (result.playerField.characterZones.first as CardInstance)
              .attachedCardInstanceIds,
          containsAll(['a', 'b']));
      expect(
          result.playerField.actionTrapZones.whereType<CardInstance>().length,
          2);
    });
  });
}
