import 'package:mysticartes/game/battle_state.dart';
import 'package:mysticartes/game/card.dart';
import 'package:mysticartes/game/duel_engine.dart';
import 'package:mysticartes/game/duel_types.dart';
import 'package:mysticartes/game/effects/foret_effects.dart';
import 'package:mysticartes/game/player.dart';
import 'package:test/test.dart';

const _keys = <String, String>{
  'FOR-001': ForetEffectKeys.for001,
  'FOR-002': ForetEffectKeys.for002,
  'FOR-004': ForetEffectKeys.for004,
  'FOR-005': ForetEffectKeys.for005,
  'FOR-006': ForetEffectKeys.for006,
  'FOR-007': ForetEffectKeys.for007,
  'FOR-008': ForetEffectKeys.for008,
  'FOR-009': ForetEffectKeys.for009,
  'FOR-010': ForetEffectKeys.for010,
  'FOR-011': ForetEffectKeys.for011,
  'FOR-012': ForetEffectKeys.for012,
  'FOR-013': ForetEffectKeys.for013,
  'FOR-014': ForetEffectKeys.for014,
  'FOR-015': ForetEffectKeys.for015,
};

CardInstance forestCard(
  String code, {
  String? id,
  DuelParticipant owner = DuelParticipant.player,
  CardCategory category = CardCategory.character,
  String? subtype,
  String family = 'forêt',
  int? rank = 4,
  int? atk = 1500,
  int? def = 1500,
  bool faceUp = true,
  BattlePosition? position = BattlePosition.attack,
  int? zoneIndex,
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
      primaryFamily: family,
      effectKey: _keys[code],
      owner: owner,
      controller: owner,
      faceUp: faceUp,
      position: position,
      atk: atk,
      def: def,
      zoneIndex: zoneIndex,
      counters: counters,
    );

TokenInstance sylve(
  String id, {
  DuelParticipant owner = DuelParticipant.player,
  Map<String, Object?> runtimeData = const {},
}) =>
    TokenInstance(
      instanceId: id,
      tokenKey: 'sylve',
      owner: owner,
      controller: owner,
      position: BattlePosition.defense,
      atk: 500,
      def: 500,
      runtimeData: runtimeData,
    );

PlayerFieldState forestField({
  required DuelParticipant participant,
  List<FieldCardInstance?>? characters,
  List<CardInstance?>? actionTraps,
  CardInstance? terrain,
  List<CardInstance> deck = const [],
  List<CardInstance> hand = const [],
  List<CardInstance> graveyard = const [],
}) =>
    PlayerFieldState(
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

DuelState forestDuel({
  PlayerFieldState? playerField,
  PlayerFieldState? aiField,
  DuelParticipant active = DuelParticipant.player,
  DuelPhase phase = DuelPhase.main1,
  int turn = 2,
}) =>
    DuelState(
      playerField:
          playerField ?? forestField(participant: DuelParticipant.player),
      aiField: aiField ?? forestField(participant: DuelParticipant.ai),
      activePlayer: active,
      currentPhase: phase,
      turnNumber: turn,
    );

ChainLink forestLink({
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

String testTokenId(
  DuelState state,
  DuelParticipant participant,
  int sequence,
) =>
    'sylve-${state.turnNumber}-${participant.name}-$sequence';

final class RecordingForestFusion implements ForetFusionSummonExtension {
  bool called = false;

  @override
  DuelState summonFromMythicReserve({
    required DuelState state,
    required DuelParticipant participant,
    required String triggerCardCode,
    required String mythicCardCode,
  }) {
    called = triggerCardCode == 'FOR-010' && mythicCardCode == 'FOR-015';
    return state;
  }
}

void main() {
  group('Effets Forêt', () {
    test('FOR-001 crée un Jeton Sylve quand elle rejoint le Cimetière', () {
      final source = forestCard(
        'FOR-001',
        id: 'seed',
        position: null,
      );
      final state = forestDuel(
        playerField: forestField(
          participant: DuelParticipant.player,
          graveyard: [source],
        ),
      );
      final result = activateAndResolve(
        DuelEngine(
          chainEffects: ForetEffectRegistry.create(
            tokenIdGenerator: testTokenId,
          ),
        ),
        state,
        forestLink(
          id: 'l1',
          key: ForetEffectKeys.for001,
          player: DuelParticipant.player,
          sourceId: 'seed',
          sourceCode: 'FOR-001',
          payload: const {'trigger': 'sent_from_field_to_graveyard'},
        ),
      );
      final token = result.state.playerField.characterZones.first;
      expect(token, isA<TokenInstance>());
      expect((token! as TokenInstance).tokenKey, 'sylve');
      expect(token.position, BattlePosition.defense);
    });

    test('FOR-002 gagne 300 ATK après un gain de PV, une fois par tour', () {
      final source = forestCard('FOR-002', id: 'monkey', atk: 1000);
      final state = forestDuel(
        playerField: forestField(
          participant: DuelParticipant.player,
          characters: [source, null, null, null, null],
        ),
      );
      final engine = DuelEngine(chainEffects: ForetEffectRegistry.create());
      final result = activateAndResolve(
        engine,
        state,
        forestLink(
          id: 'l2',
          key: ForetEffectKeys.for002,
          player: DuelParticipant.player,
          sourceId: 'monkey',
          payload: const {'trigger': 'life_gained', 'amount': 500},
        ),
      );
      expect(result.state.playerField.characterZones.first!.effectiveAtk, 1300);
      final second = engine.activateChainEffect(
        state: result.state,
        link: forestLink(
          id: 'l2b',
          key: ForetEffectKeys.for002,
          player: DuelParticipant.player,
          sourceId: 'monkey',
          payload: const {'trigger': 'life_gained', 'amount': 200},
        ),
      );
      expect(second.failure, DuelActionFailure.chainActivationConditionNotMet);
    });

    test('FOR-004 gagne 500 PV à l’invocation puis 200 à la création', () {
      final source = forestCard('FOR-004', id: 'healer');
      final state = forestDuel(
        playerField: forestField(
          participant: DuelParticipant.player,
          characters: [source, null, null, null, null],
        ),
      );
      final engine = DuelEngine(chainEffects: ForetEffectRegistry.create());
      var next = activateAndResolve(
        engine,
        state,
        forestLink(
          id: 'l4a',
          key: ForetEffectKeys.for004,
          player: DuelParticipant.player,
          sourceId: 'healer',
          payload: const {'trigger': 'on_summon'},
        ),
      ).state;
      next = activateAndResolve(
        engine,
        next,
        forestLink(
          id: 'l4b',
          key: ForetEffectKeys.for004,
          player: DuelParticipant.player,
          sourceId: 'healer',
          payload: const {'trigger': 'token_created_on_own_field'},
        ),
      ).state;
      expect(next.playerLifePoints, 8700);
    });

    test('FOR-005 attaque directement à demi-dégâts avec un Jeton Sylve', () {
      final panther = forestCard('FOR-005', id: 'panther', atk: 2201);
      final token = sylve('token');
      final defender = forestCard(
        'X',
        id: 'defender',
        owner: DuelParticipant.ai,
        family: 'savane',
      );
      final engine = DuelEngine(chainEffects: ForetEffectRegistry.create());
      var state = forestDuel(
        phase: DuelPhase.battle,
        playerField: forestField(
          participant: DuelParticipant.player,
          characters: [panther, token, null, null, null],
        ),
        aiField: forestField(
          participant: DuelParticipant.ai,
          characters: [defender, null, null, null, null],
        ),
      );
      final declaration = engine.declareAttack(
        state: state,
        participant: DuelParticipant.player,
        attackerInstanceId: 'panther',
      );
      expect(declaration.succeeded, isTrue);
      state = closeWindow(engine, declaration.state);
      final combat = engine.resolveAttack(
        state: state,
        declaration: declaration.declaration!,
      );
      expect(combat.state.aiLifePoints, 6899);
    });

    test('FOR-006 sacrifie un Jeton et empêche une destruction Forêt', () {
      final guardian = forestCard('FOR-006', id: 'guardian');
      final token = sylve('token');
      final state = forestDuel(
        playerField: forestField(
          participant: DuelParticipant.player,
          characters: [guardian, token, null, null, null],
        ),
      );
      final engine = DuelEngine(chainEffects: ForetEffectRegistry.create());
      final protected = activateAndResolve(
        engine,
        state,
        forestLink(
          id: 'l6',
          key: ForetEffectKeys.for006,
          player: DuelParticipant.player,
          sourceId: 'guardian',
          target: ChainTarget(cardInstanceId: 'guardian'),
          payload: const {
            'trigger': 'forest_card_would_be_destroyed',
            'token_instance_id': 'token',
          },
        ),
      ).state;
      expect(protected.playerField.characterZones[1], isNull);
      final destruction = engine.destroyCardByEffect(
        state: protected,
        cardInstanceId: 'guardian',
      );
      expect(destruction.status, EffectDestructionStatus.prevented);
      expect(destruction.state.playerField.characterZones.first, isNotNull);
    });

    test('FOR-007 crée deux Sylves et leur donne 300 DEF', () {
      final elephant = forestCard('FOR-007', id: 'elephant');
      final state = forestDuel(
        playerField: forestField(
          participant: DuelParticipant.player,
          characters: [elephant, null, null, null, null],
        ),
      );
      final result = activateAndResolve(
        DuelEngine(
          chainEffects: ForetEffectRegistry.create(
            tokenIdGenerator: testTokenId,
          ),
        ),
        state,
        forestLink(
          id: 'l7',
          key: ForetEffectKeys.for007,
          player: DuelParticipant.player,
          sourceId: 'elephant',
          payload: const {'mode': 'on_summon', 'token_count': 2},
        ),
      );
      final tokens = result.state.playerField.characterZones
          .whereType<TokenInstance>()
          .toList();
      expect(tokens, hasLength(2));
      expect(tokens.every((token) => token.effectiveDef == 800), isTrue);
    });

    test('FOR-008 crée un Sylve impossible à sacrifier ce tour', () {
      final action = forestCard(
        'FOR-008',
        id: 'germination',
        category: CardCategory.action,
        subtype: 'quick',
        rank: null,
        atk: null,
        def: null,
        position: null,
      );
      final highRank = forestCard('X', id: 'rank5', rank: 5);
      final state = forestDuel(
        playerField: forestField(
          participant: DuelParticipant.player,
          actionTraps: [action, null, null, null, null],
          hand: [highRank],
        ),
      );
      final engine = DuelEngine(
        chainEffects: ForetEffectRegistry.create(
          tokenIdGenerator: testTokenId,
        ),
      );
      final created = activateAndResolve(
        engine,
        state,
        forestLink(
          id: 'l8',
          key: ForetEffectKeys.for008,
          player: DuelParticipant.player,
          speed: ChainSpeed.speed2,
          sourceId: 'germination',
        ),
      ).state;
      final token = created.playerField.characterZones.first!;
      final summon = engine.normalSummon(
        state: created,
        participant: DuelParticipant.player,
        cardInstanceId: 'rank5',
        sacrificeInstanceIds: [token.instanceId],
      );
      expect(summon.failure, DuelActionFailure.invalidSacrifice);
    });

    test('FOR-009 gagne une Graine puis en retire deux pour 500 PV', () {
      final rain = forestCard(
        'FOR-009',
        id: 'rain',
        category: CardCategory.action,
        subtype: 'continuous',
        rank: null,
        atk: null,
        def: null,
        position: null,
        counters: const {'graine': 1},
      );
      final state = forestDuel(
        phase: DuelPhase.preparation,
        playerField: forestField(
          participant: DuelParticipant.player,
          actionTraps: [rain, null, null, null, null],
        ),
      );
      final engine = DuelEngine(
        chainEffects: ForetEffectRegistry.create(
          tokenIdGenerator: testTokenId,
        ),
      );
      var next = activateAndResolve(
        engine,
        state,
        forestLink(
          id: 'l9a',
          key: ForetEffectKeys.for009,
          player: DuelParticipant.player,
          sourceId: 'rain',
          payload: const {'mode': 'preparation'},
        ),
      ).state.copyWith(currentPhase: DuelPhase.main1);
      next = activateAndResolve(
        engine,
        next,
        forestLink(
          id: 'l9b',
          key: ForetEffectKeys.for009,
          player: DuelParticipant.player,
          sourceId: 'rain',
          payload: const {'mode': 'gain_life'},
        ),
      ).state;
      expect(next.playerLifePoints, 8500);
      expect(next.playerField.actionTrapZones.first!.counters['graine'], 0);
    });

    test('FOR-010 envoie Gardien Iroko et deux Sylves pour la Fusion', () {
      final extension = RecordingForestFusion();
      final action = forestCard(
        'FOR-010',
        id: 'roots',
        category: CardCategory.action,
        rank: null,
        atk: null,
        def: null,
        position: null,
      );
      final iroko = forestCard('FOR-006', id: 'iroko');
      final state = forestDuel(
        playerField: forestField(
          participant: DuelParticipant.player,
          characters: [iroko, sylve('t1'), sylve('t2'), null, null],
          actionTraps: [action, null, null, null, null],
        ),
      );
      final result = activateAndResolve(
        DuelEngine(
          chainEffects: ForetEffectRegistry.create(
            fusionSummonExtension: extension,
          ),
        ),
        state,
        forestLink(
          id: 'l10',
          key: ForetEffectKeys.for010,
          player: DuelParticipant.player,
          sourceId: 'roots',
          payload: const {
            'iroko_instance_id': 'iroko',
            'token_instance_ids': ['t1', 't2'],
          },
        ),
      );
      expect(extension.called, isTrue);
      expect(result.state.playerField.characterZones.take(3),
          everyElement(isNull));
      expect(result.state.playerField.graveyard.single.instanceId, 'iroko');
    });

    test('FOR-011 annule l’attaque et verrouille la prochaine position', () {
      final trap = forestCard(
        'FOR-011',
        id: 'vine',
        category: CardCategory.trap,
        rank: null,
        atk: null,
        def: null,
        position: null,
      );
      final attacker = forestCard(
        'X',
        id: 'attacker',
        owner: DuelParticipant.ai,
        family: 'savane',
      );
      final state = forestDuel(
        playerField: forestField(
          participant: DuelParticipant.player,
          actionTraps: [trap, null, null, null, null],
        ),
        aiField: forestField(
          participant: DuelParticipant.ai,
          characters: [attacker, null, null, null, null],
        ),
      );
      final result = activateAndResolve(
        DuelEngine(chainEffects: ForetEffectRegistry.create()),
        state,
        forestLink(
          id: 'l11',
          key: ForetEffectKeys.for011,
          player: DuelParticipant.player,
          sourceId: 'vine',
          target: ChainTarget(cardInstanceId: 'attacker'),
          payload: const {
            'trigger': 'opponent_attack_declared',
            'attack_declaration_id': 'attack-1',
          },
        ),
      );
      final locked = result.state.aiField.characterZones.first as CardInstance;
      expect(result.state.cancelledAttackDeclarationIds, contains('attack-1'));
      expect(locked.runtimeData[CardRuntimeKeys.positionLockedTurn], 4);
    });

    test('FOR-012 crée une Sylve après destruction d’une carte Forêt', () {
      final trap = forestCard(
        'FOR-012',
        id: 'wild',
        category: CardCategory.trap,
        subtype: 'continuous',
        rank: null,
        atk: null,
        def: null,
        position: null,
      );
      final state = forestDuel(
        playerField: forestField(
          participant: DuelParticipant.player,
          actionTraps: [trap, null, null, null, null],
        ),
      );
      final result = activateAndResolve(
        DuelEngine(
          chainEffects: ForetEffectRegistry.create(
            tokenIdGenerator: testTokenId,
          ),
        ),
        state,
        forestLink(
          id: 'l12',
          key: ForetEffectKeys.for012,
          player: DuelParticipant.player,
          sourceId: 'wild',
          payload: const {
            'trigger': 'controlled_forest_destroyed',
            'destroyed_was_forest': true,
          },
        ),
      );
      expect(
          result.state.playerField.characterZones.first, isA<TokenInstance>());
    });

    test('FOR-013 donne +200 aux Forêt et +500 aux Sylves', () {
      final terrain = forestCard(
        'FOR-013',
        id: 'forest',
        category: CardCategory.terrain,
        rank: null,
        atk: null,
        def: null,
        position: null,
      );
      final ally = forestCard('X', id: 'ally', atk: 1000, def: 1000);
      final token = sylve('token');
      final state = forestDuel(
        playerField: forestField(
          participant: DuelParticipant.player,
          characters: [ally, token, null, null, null],
          terrain: terrain,
        ),
      );
      final result = activateAndResolve(
        DuelEngine(chainEffects: ForetEffectRegistry.create()),
        state,
        forestLink(
          id: 'l13',
          key: ForetEffectKeys.for013,
          player: DuelParticipant.player,
          sourceId: 'forest',
          payload: const {'mode': 'continuous_refresh'},
        ),
      );
      expect(result.state.playerField.characterZones.first!.effectiveAtk, 1200);
      expect(result.state.playerField.characterZones[1]!.effectiveAtk, 1000);
      expect(result.state.playerField.characterZones[1]!.effectiveDef, 1000);
    });

    test('FOR-014 invoque un rang 7-8 à la troisième Préparation', () {
      final relic = forestCard(
        'FOR-014',
        id: 'origin',
        category: CardCategory.relic,
        rank: null,
        atk: null,
        def: null,
        position: null,
      );
      final selected = forestCard('X', id: 'rank8', rank: 8);
      final engine = DuelEngine(chainEffects: ForetEffectRegistry.create());
      var state = forestDuel(
        playerField: forestField(
          participant: DuelParticipant.player,
          actionTraps: [relic, null, null, null, null],
          deck: [selected],
        ),
      );
      state = activateAndResolve(
        engine,
        state,
        forestLink(
          id: 'l14a',
          key: ForetEffectKeys.for014,
          player: DuelParticipant.player,
          sourceId: 'origin',
          payload: const {'mode': 'activate'},
        ),
      ).state;
      for (var count = 1; count <= 3; count++) {
        state = state.copyWith(
          currentPhase: DuelPhase.preparation,
          turnNumber: count * 2,
        );
        state = activateAndResolve(
          engine,
          state,
          forestLink(
            id: 'l14p$count',
            key: ForetEffectKeys.for014,
            player: DuelParticipant.player,
            sourceId: 'origin',
            payload: {
              'mode': 'preparation',
              if (count == 3) 'selected_instance_id': 'rank8',
            },
          ),
        ).state;
      }
      expect(state.playerField.actionTrapZones.first, isNull);
      expect(state.playerField.graveyard.single.instanceId, 'origin');
      final summoned = state.playerField.characterZones.first as CardInstance;
      expect(summoned.instanceId, 'rank8');
      expect(summoned.runtimeData[CardRuntimeKeys.effectsNegatedUntilTurn], 6);
    });

    test('FOR-015 crée trois Sylves puis en sacrifie une pour PV et ATK', () {
      final iroko = forestCard(
        'FOR-015',
        id: 'world',
        category: CardCategory.mythic,
        rank: 10,
        atk: 3500,
        def: 4000,
      );
      final engine = DuelEngine(
        chainEffects: ForetEffectRegistry.create(
          tokenIdGenerator: testTokenId,
        ),
      );
      var state = forestDuel(
        playerField: forestField(
          participant: DuelParticipant.player,
          characters: [iroko, null, null, null, null],
        ),
      );
      state = activateAndResolve(
        engine,
        state,
        forestLink(
          id: 'l15a',
          key: ForetEffectKeys.for015,
          player: DuelParticipant.player,
          sourceId: 'world',
          payload: const {'mode': 'on_summon', 'token_count': 3},
        ),
      ).state;
      final tokenId = state.playerField.characterZones
          .whereType<TokenInstance>()
          .first
          .instanceId;
      state = activateAndResolve(
        engine,
        state,
        forestLink(
          id: 'l15b',
          key: ForetEffectKeys.for015,
          player: DuelParticipant.player,
          sourceId: 'world',
          payload: {
            'mode': 'sacrifice_token',
            'token_instance_id': tokenId,
          },
        ),
      ).state;
      expect(state.playerField.characterZones.whereType<TokenInstance>(),
          hasLength(2));
      expect(state.playerLifePoints, 8800);
      expect(state.playerField.characterZones.first!.effectiveAtk, 3900);
    });
  });
}
