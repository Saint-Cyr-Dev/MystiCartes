import 'package:mysticartes/game/battle_state.dart';
import 'package:mysticartes/game/card.dart';
import 'package:mysticartes/game/duel_engine.dart';
import 'package:mysticartes/game/duel_types.dart';
import 'package:mysticartes/game/effects/savane_effects.dart';
import 'package:mysticartes/game/player.dart';
import 'package:test/test.dart';

const keys = <String, String>{
  'SAV-001': SavaneEffectKeys.sav001,
  'SAV-002': SavaneEffectKeys.sav002,
  'SAV-004': SavaneEffectKeys.sav004,
  'SAV-005': SavaneEffectKeys.sav005,
  'SAV-006': SavaneEffectKeys.sav006,
  'SAV-007': SavaneEffectKeys.sav007,
  'SAV-008': SavaneEffectKeys.sav008,
  'SAV-009': SavaneEffectKeys.sav009,
  'SAV-010': SavaneEffectKeys.sav010,
  'SAV-011': SavaneEffectKeys.sav011,
  'SAV-012': SavaneEffectKeys.sav012,
  'SAV-013': SavaneEffectKeys.sav013,
  'SAV-014': SavaneEffectKeys.sav014,
  'SAV-015': SavaneEffectKeys.sav015,
};

CardInstance card(
  String code, {
  String? id,
  DuelParticipant owner = DuelParticipant.player,
  CardCategory category = CardCategory.character,
  String family = 'savane',
  int? rank = 4,
  int? atk = 1500,
  int? def = 1500,
  BattlePosition? position = BattlePosition.attack,
  bool faceUp = true,
  bool attacked = false,
}) =>
    CardInstance(
      instanceId: id ?? code.toLowerCase(),
      cardId: 'catalog-$code',
      cardCode: code,
      cardRevision: 1,
      category: category,
      rank: rank,
      attribute: 'feu',
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
  DuelParticipant active = DuelParticipant.player,
  DuelPhase phase = DuelPhase.main1,
}) =>
    DuelState(
      playerField: player ?? field(player: DuelParticipant.player),
      aiField: ai ?? field(player: DuelParticipant.ai),
      activePlayer: active,
      currentPhase: phase,
      turnNumber: 2,
    );

ChainLink link(
  String id,
  String key, {
  String? source,
  String? sourceCode,
  ChainTarget? target,
  Map<String, Object?> payload = const {},
  DuelParticipant player = DuelParticipant.player,
  ChainSpeed speed = ChainSpeed.speed1,
}) =>
    ChainLink(
      linkId: id,
      effectKey: key,
      activatingPlayer: player,
      speed: speed,
      sourceCardInstanceId: source,
      sourceCardCode: sourceCode,
      target: target,
      payload: payload,
    );

DuelState resolve(DuelEngine engine, DuelState state, ChainLink effect) {
  final activation = engine.activateChainEffect(state: state, link: effect);
  expect(activation.succeeded, isTrue, reason: activation.failure?.name);
  final opponent = effect.activatingPlayer == DuelParticipant.player
      ? DuelParticipant.ai
      : DuelParticipant.player;
  final first =
      engine.passPriority(state: activation.state, participant: opponent);
  return engine
      .passPriority(state: first.state, participant: effect.activatingPlayer)
      .state;
}

DuelState close(DuelEngine engine, DuelState state) {
  final first = engine.passPriority(
      state: state, participant: state.chain.priorityPlayer!);
  return engine
      .passPriority(
          state: first.state, participant: first.state.chain.priorityPlayer!)
      .state;
}

final class FusionRecorder implements SavaneFusionSummonExtension {
  bool called = false;
  @override
  DuelState summonFromMythicReserve(
      {required DuelState state,
      required DuelParticipant participant,
      required String triggerCardCode,
      required String mythicCardCode}) {
    called = triggerCardCode == 'SAV-010' && mythicCardCode == 'SAV-015';
    return state;
  }
}

void main() {
  group('Effets Savane', () {
    test('SAV-001 ajoute le dessus Savane puis place une carte sous le deck',
        () {
      final source = card('SAV-001', id: 'source');
      final top = card('X', id: 'top');
      final bottom = card('Y', id: 'bottom', position: null);
      final state = duel(
          player: field(
              player: DuelParticipant.player,
              monsters: [source, null, null, null, null],
              deck: [top],
              hand: [bottom]));
      final result = resolve(
          DuelEngine(chainEffects: SavaneEffectRegistry.create()),
          state,
          link('l1', SavaneEffectKeys.sav001, source: 'source', payload: const {
            'trigger': 'on_summon',
            'take_top': true,
            'bottom_instance_id': 'bottom'
          }));
      expect(result.playerField.hand.single.instanceId, 'top');
      expect(result.playerField.deck.last.instanceId, 'bottom');
    });

    test('SAV-002 gagne 300 ATK seulement pendant une attaque directe', () {
      final gazelle = card('SAV-002', id: 'gazelle', atk: 1500);
      final engine = DuelEngine(chainEffects: SavaneEffectRegistry.create());
      var state = duel(
          phase: DuelPhase.battle,
          player: field(
              player: DuelParticipant.player,
              monsters: [gazelle, null, null, null, null]));
      final declaration = engine.declareAttack(
          state: state,
          participant: DuelParticipant.player,
          attackerInstanceId: 'gazelle');
      state = close(engine, declaration.state);
      final combat = engine.resolveAttack(
          state: state, declaration: declaration.declaration!);
      expect(combat.state.aiLifePoints, 6200);
    });

    test(
        'SAV-004 obtient une attaque supplémentaire uniquement contre un Personnage',
        () {
      final hyena = card('SAV-004', id: 'hyena', attacked: true);
      final enemy = card('X', id: 'enemy', owner: DuelParticipant.ai);
      final engine = DuelEngine(chainEffects: SavaneEffectRegistry.create());
      var state = duel(
          player: field(
              player: DuelParticipant.player,
              monsters: [hyena, null, null, null, null]),
          ai: field(
              player: DuelParticipant.ai,
              monsters: [enemy, null, null, null, null]));
      state = resolve(
          engine,
          state,
          link('l4', SavaneEffectKeys.sav004,
              source: 'hyena',
              payload: const {'trigger': 'other_savane_destroyed_in_combat'}));
      state = state.copyWith(currentPhase: DuelPhase.battle);
      expect(
          engine
              .declareAttack(
                  state: state,
                  participant: DuelParticipant.player,
                  attackerInstanceId: 'hyena')
              .failure,
          DuelActionFailure.directAttackBlocked);
      expect(
          engine
              .declareAttack(
                  state: state,
                  participant: DuelParticipant.player,
                  attackerInstanceId: 'hyena',
                  targetInstanceId: 'enemy')
              .succeeded,
          isTrue);
    });

    test('SAV-005 retire 300 ATK par autre Savane contrôlée', () {
      final scout = card('SAV-005', id: 'scout');
      final ally1 = card('X', id: 'a1');
      final ally2 = card('Y', id: 'a2');
      final enemy =
          card('Z', id: 'enemy', owner: DuelParticipant.ai, atk: 2000);
      final state = duel(
          player: field(
              player: DuelParticipant.player,
              monsters: [scout, ally1, ally2, null, null]),
          ai: field(
              player: DuelParticipant.ai,
              monsters: [enemy, null, null, null, null]));
      final result = resolve(
          DuelEngine(chainEffects: SavaneEffectRegistry.create()),
          state,
          link('l5', SavaneEffectKeys.sav005,
              source: 'scout',
              target: ChainTarget(cardInstanceId: 'enemy'),
              payload: const {'trigger': 'on_summon'}));
      expect(result.aiField.characterZones.first!.effectiveAtk, 1400);
    });

    test('SAV-006 inflige la moitié de la différence contre la Défense', () {
      final elephant = card('SAV-006', id: 'elephant', atk: 2600);
      final wall = card('X',
          id: 'wall',
          owner: DuelParticipant.ai,
          def: 2000,
          position: BattlePosition.defense);
      final engine = DuelEngine(chainEffects: SavaneEffectRegistry.create());
      var state = duel(
          phase: DuelPhase.battle,
          player: field(
              player: DuelParticipant.player,
              monsters: [elephant, null, null, null, null]),
          ai: field(
              player: DuelParticipant.ai,
              monsters: [wall, null, null, null, null]));
      final declaration = engine.declareAttack(
          state: state,
          participant: DuelParticipant.player,
          attackerInstanceId: 'elephant',
          targetInstanceId: 'wall');
      state = close(engine, declaration.state);
      final result = engine.resolveAttack(
          state: state, declaration: declaration.declaration!);
      expect(result.state.aiLifePoints, 7700);
      expect(result.destroyedCardInstanceIds, contains('wall'));
    });

    test('SAV-007 renforce les autres puis les passe en Défense après attaque',
        () {
      final lioness = card('SAV-007', id: 'lioness');
      final ally = card('X', id: 'ally', atk: 1500);
      final enemy =
          card('Y', id: 'enemy', owner: DuelParticipant.ai, atk: 1700);
      final engine = DuelEngine(chainEffects: SavaneEffectRegistry.create());
      var state = duel(
          phase: DuelPhase.battle,
          player: field(
              player: DuelParticipant.player,
              monsters: [lioness, ally, null, null, null]),
          ai: field(
              player: DuelParticipant.ai,
              monsters: [enemy, null, null, null, null]));
      final declaration = engine.declareAttack(
          state: state,
          participant: DuelParticipant.player,
          attackerInstanceId: 'ally',
          targetInstanceId: 'enemy');
      state = close(engine, declaration.state);
      state = engine
          .resolveAttack(state: state, declaration: declaration.declaration!)
          .state
          .copyWith(currentPhase: DuelPhase.main2);
      state = resolve(
          engine,
          state,
          link('l7', SavaneEffectKeys.sav007,
              source: 'lioness',
              target: ChainTarget(cardInstanceId: 'ally'),
              payload: const {'mode': 'other_savane_attacked'}));
      expect(state.aiField.graveyard.single.instanceId, 'enemy');
      expect(state.playerField.characterZones[1]!.position,
          BattlePosition.defense);
    });

    test(
        'SAV-008 renforce trois Savane puis les passe en Défense après attaque',
        () {
      final action = card('SAV-008',
          id: 'rush',
          category: CardCategory.action,
          rank: null,
          atk: null,
          def: null,
          position: null);
      final ally = card('X', id: 'ally', atk: 1000);
      final engine = DuelEngine(chainEffects: SavaneEffectRegistry.create());
      var state = duel(
          player: field(
              player: DuelParticipant.player,
              monsters: [ally, null, null, null, null],
              actions: [action, null, null, null, null]));
      state = resolve(
          engine,
          state,
          link('l8a', SavaneEffectKeys.sav008, source: 'rush', payload: const {
            'mode': 'activate',
            'target_instance_ids': ['ally']
          }));
      expect(state.playerField.characterZones.first!.effectiveAtk, 1300);
      state = resolve(
          engine,
          state,
          link('l8b', SavaneEffectKeys.sav008,
              source: 'rush',
              target: ChainTarget(cardInstanceId: 'ally'),
              payload: const {'mode': 'after_attack'}));
      expect(state.playerField.characterZones.first!.position,
          BattlePosition.defense);
    });

    test('SAV-009 donne 700 ATK pour un seul calcul puis expire', () {
      final action = card('SAV-009',
          id: 'jump',
          category: CardCategory.action,
          rank: null,
          atk: null,
          def: null,
          position: null);
      final ally = card('X', id: 'ally', atk: 1500);
      final enemy =
          card('Y', id: 'enemy', owner: DuelParticipant.ai, atk: 2000);
      final engine = DuelEngine(chainEffects: SavaneEffectRegistry.create());
      var state = duel(
          phase: DuelPhase.battle,
          player: field(
              player: DuelParticipant.player,
              monsters: [ally, null, null, null, null],
              actions: [action, null, null, null, null]),
          ai: field(
              player: DuelParticipant.ai,
              monsters: [enemy, null, null, null, null]));
      state = resolve(
          engine,
          state,
          link('l9', SavaneEffectKeys.sav009,
              source: 'jump',
              target: ChainTarget(cardInstanceId: 'ally'),
              speed: ChainSpeed.speed2));
      final declaration = engine.declareAttack(
          state: state,
          participant: DuelParticipant.player,
          attackerInstanceId: 'ally',
          targetInstanceId: 'enemy');
      state = close(engine, declaration.state);
      final result = engine.resolveAttack(
          state: state, declaration: declaration.declaration!);
      expect(result.state.aiField.graveyard.single.instanceId, 'enemy');
      expect(
          (result.state.playerField.characterZones.first as CardInstance)
              .runtimeData[CardRuntimeKeys.combatOnlyAtkDelta],
          isNull);
    });

    test('SAV-010 envoie les deux matériels précis et appelle la Fusion', () {
      final recorder = FusionRecorder();
      final action = card('SAV-010',
          id: 'roar',
          category: CardCategory.action,
          rank: null,
          atk: null,
          def: null,
          position: null);
      final elephant = card('SAV-006', id: 'elephant');
      final lioness = card('SAV-007', id: 'lioness');
      final state = duel(
          player: field(
              player: DuelParticipant.player,
              monsters: [elephant, lioness, null, null, null],
              actions: [action, null, null, null, null]));
      final result = resolve(
          DuelEngine(
              chainEffects:
                  SavaneEffectRegistry.create(fusionSummonExtension: recorder)),
          state,
          link('l10', SavaneEffectKeys.sav010, source: 'roar', payload: const {
            'material_instance_ids': ['elephant', 'lioness']
          }));
      expect(recorder.called, isTrue);
      expect(result.playerField.graveyard, hasLength(2));
    });

    test('SAV-011 retire 1000 ATK pendant le combat puis passe en Défense', () {
      final trap = card('SAV-011',
          id: 'dust',
          category: CardCategory.trap,
          rank: null,
          atk: null,
          def: null,
          position: null);
      final enemy =
          card('X', id: 'enemy', owner: DuelParticipant.ai, atk: 2000);
      final engine = DuelEngine(chainEffects: SavaneEffectRegistry.create());
      var state = duel(
          player: field(
              player: DuelParticipant.player,
              actions: [trap, null, null, null, null]),
          ai: field(
              player: DuelParticipant.ai,
              monsters: [enemy, null, null, null, null]));
      state = resolve(
          engine,
          state,
          link('l11a', SavaneEffectKeys.sav011,
              source: 'dust',
              target: ChainTarget(cardInstanceId: 'enemy'),
              speed: ChainSpeed.speed2,
              payload: const {'mode': 'attack_declared'}));
      expect(
          (state.aiField.characterZones.first as CardInstance)
              .runtimeData[CardRuntimeKeys.combatOnlyAtkDelta],
          -1000);
      state = resolve(
          engine,
          state,
          link('l11b', SavaneEffectKeys.sav011,
              source: 'dust',
              target: ChainTarget(cardInstanceId: 'enemy'),
              speed: ChainSpeed.speed2,
              payload: const {'mode': 'after_combat'}));
      expect(
          state.aiField.characterZones.first!.position, BattlePosition.defense);
    });

    test('SAV-012 redirige une attaque vers une autre Savane', () {
      final trap = card('SAV-012',
          id: 'circle',
          category: CardCategory.trap,
          rank: null,
          atk: null,
          def: null,
          position: null);
      final alternate = card('X', id: 'alternate');
      final state = duel(
          player: field(
              player: DuelParticipant.player,
              monsters: [alternate, null, null, null, null],
              actions: [trap, null, null, null, null]));
      final result = resolve(
          DuelEngine(chainEffects: SavaneEffectRegistry.create()),
          state,
          link('l12', SavaneEffectKeys.sav012,
              source: 'circle',
              target: ChainTarget(cardInstanceId: 'alternate'),
              speed: ChainSpeed.speed2,
              payload: const {'attack_declaration_id': 'attack-1'}));
      expect(result.attackTargetOverrides['attack-1'], 'alternate');
    });

    test('SAV-013 applique -100 DEF et soigne de 200 après destruction', () {
      final terrain = card('SAV-013',
          id: 'plain',
          category: CardCategory.terrain,
          rank: null,
          atk: null,
          def: null,
          position: null);
      final ally = card('X', id: 'ally', def: 1000);
      final engine = DuelEngine(chainEffects: SavaneEffectRegistry.create());
      var state = duel(
          player: field(
              player: DuelParticipant.player,
              monsters: [ally, null, null, null, null],
              terrain: terrain));
      state = resolve(
          engine,
          state,
          link('l13a', SavaneEffectKeys.sav013,
              source: 'plain', payload: const {'mode': 'continuous_refresh'}));
      state = resolve(
          engine,
          state,
          link('l13b', SavaneEffectKeys.sav013,
              source: 'plain',
              payload: const {
                'mode': 'savane_destroyed_in_combat',
                'destroyer_controller': 'player'
              }));
      expect(state.playerField.characterZones.first!.effectiveDef, 900);
      expect(state.playerLifePoints, 8200);
    });

    test('SAV-014 donne 500 ATK contre un rang supérieur puis fait piocher',
        () {
      final spear = card('SAV-014',
          id: 'spear',
          category: CardCategory.relic,
          rank: null,
          atk: null,
          def: null,
          position: null);
      final ally = card('X', id: 'ally', rank: 4, atk: 1800);
      final enemy =
          card('Y', id: 'enemy', owner: DuelParticipant.ai, rank: 6, atk: 2200);
      final drawn = card('D', id: 'drawn', position: null);
      final engine = DuelEngine(chainEffects: SavaneEffectRegistry.create());
      var state = duel(
          player: field(
              player: DuelParticipant.player,
              monsters: [ally, null, null, null, null],
              actions: [spear, null, null, null, null],
              deck: [drawn]),
          ai: field(
              player: DuelParticipant.ai,
              monsters: [enemy, null, null, null, null]));
      state = resolve(
          engine,
          state,
          link('l14a', SavaneEffectKeys.sav014,
              source: 'spear',
              target: ChainTarget(cardInstanceId: 'ally'),
              payload: const {'mode': 'equip'}));
      state = state.copyWith(currentPhase: DuelPhase.battle);
      final declaration = engine.declareAttack(
          state: state,
          participant: DuelParticipant.player,
          attackerInstanceId: 'ally',
          targetInstanceId: 'enemy');
      state = close(engine, declaration.state);
      state = engine
          .resolveAttack(state: state, declaration: declaration.declaration!)
          .state
          .copyWith(currentPhase: DuelPhase.main2);
      expect(state.aiField.graveyard.single.instanceId, 'enemy');
      state = resolve(
          engine,
          state,
          link('l14b', SavaneEffectKeys.sav014,
              source: 'spear',
              payload: const {'mode': 'destroyed_higher_rank'}));
      expect(state.playerField.hand.single.instanceId, 'drawn');
    });

    test('SAV-015 reçoit exactement une seconde attaque contre un Personnage',
        () {
      final mythic = card('SAV-015',
          id: 'mythic',
          category: CardCategory.mythic,
          rank: 10,
          attacked: true);
      final enemy = card('X', id: 'enemy', owner: DuelParticipant.ai);
      final engine = DuelEngine(chainEffects: SavaneEffectRegistry.create());
      var state = duel(
          player: field(
              player: DuelParticipant.player,
              monsters: [mythic, null, null, null, null]),
          ai: field(
              player: DuelParticipant.ai,
              monsters: [enemy, null, null, null, null]));
      state = resolve(
          engine,
          state,
          link('l15', SavaneEffectKeys.sav015,
              source: 'mythic',
              payload: const {
                'trigger': 'self_destroyed_character_in_combat'
              }));
      state = state.copyWith(currentPhase: DuelPhase.battle);
      expect(
          engine
              .declareAttack(
                  state: state,
                  participant: DuelParticipant.player,
                  attackerInstanceId: 'mythic',
                  targetInstanceId: 'enemy')
              .succeeded,
          isTrue);
      final again = engine.activateChainEffect(
          state: state.copyWith(currentPhase: DuelPhase.main2),
          link: link('l15b', SavaneEffectKeys.sav015,
              source: 'mythic',
              payload: const {
                'trigger': 'self_destroyed_character_in_combat'
              }));
      expect(again.failure, DuelActionFailure.chainActivationConditionNotMet);
    });
  });
}
