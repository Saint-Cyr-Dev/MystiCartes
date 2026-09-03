import 'package:mysticartes/game/battle_state.dart';
import 'package:mysticartes/game/card.dart';
import 'package:mysticartes/game/duel_engine.dart';
import 'package:mysticartes/game/duel_types.dart';
import 'package:mysticartes/game/effects/ancetre_effects.dart';
import 'package:mysticartes/game/effects/babi_effects.dart';
import 'package:mysticartes/game/effects/foret_effects.dart';
import 'package:mysticartes/game/effects/masque_effects.dart';
import 'package:mysticartes/game/effects/royaume_effects.dart';
import 'package:mysticartes/game/player.dart';
import 'package:test/test.dart';

CardInstance card(
  String code, {
  required String id,
  DuelParticipant owner = DuelParticipant.player,
  CardCategory category = CardCategory.character,
  String? effectKey,
  String? family,
  String? subtype,
  int? rank = 4,
  int? atk = 1500,
  int? def = 1500,
  bool faceUp = true,
  BattlePosition? position = BattlePosition.attack,
  int? zoneIndex,
  Map<String, Object?> mythicCondition = const {},
}) {
  return CardInstance(
    instanceId: id,
    cardId: 'catalog-$code',
    cardCode: code,
    cardRevision: 1,
    category: category,
    rank: rank,
    subtype: subtype,
    primaryFamily: family,
    mythicSummonCondition: mythicCondition,
    effectKey: effectKey,
    owner: owner,
    controller: owner,
    faceUp: faceUp,
    position: position,
    atk: atk,
    def: def,
    zoneIndex: zoneIndex,
  );
}

TokenInstance sylve(String id, int zoneIndex) {
  return TokenInstance(
    instanceId: id,
    tokenKey: 'sylve',
    owner: DuelParticipant.player,
    controller: DuelParticipant.player,
    faceUp: true,
    position: BattlePosition.defense,
    atk: 500,
    def: 500,
    zoneIndex: zoneIndex,
  );
}

PlayerFieldState field({
  required DuelParticipant participant,
  List<FieldCardInstance?>? characters,
  List<CardInstance?>? actionTraps,
  List<CardInstance> deck = const [],
  List<CardInstance> hand = const [],
  List<CardInstance> graveyard = const [],
  List<CardInstance> banished = const [],
  List<CardInstance> mythics = const [],
}) {
  return PlayerFieldState(
    participant: participant,
    characterZones: characters ?? const [null, null, null, null, null],
    actionTrapZones: actionTraps ?? const [null, null, null, null, null],
    terrainZone: null,
    deck: deck,
    hand: hand,
    graveyard: graveyard,
    banished: banished,
    mythicReserve: mythics,
  );
}

DuelState duel({
  required PlayerFieldState player,
  PlayerFieldState? ai,
  DuelPhase phase = DuelPhase.main1,
}) {
  return DuelState(
    playerField: player,
    aiField: ai ?? field(participant: DuelParticipant.ai),
    activePlayer: DuelParticipant.player,
    currentPhase: phase,
    turnNumber: 2,
  );
}

ChainLink activation({
  required String effectKey,
  required String sourceId,
  required String sourceCode,
  Map<String, Object?> payload = const {},
}) {
  return ChainLink(
    linkId: 'activate-$sourceCode',
    effectKey: effectKey,
    activatingPlayer: DuelParticipant.player,
    speed: ChainSpeed.speed1,
    sourceCardInstanceId: sourceId,
    sourceCardCode: sourceCode,
    payload: payload,
  );
}

DuelState resolveChain(DuelEngine engine, DuelState state) {
  final first = engine.passPriority(
    state: state,
    participant: state.chain.priorityPlayer!,
  );
  expect(first.succeeded, isTrue);
  final second = engine.passPriority(
    state: first.state,
    participant: first.state.chain.priorityPlayer!,
  );
  expect(second.succeeded, isTrue);
  return second.state;
}

DuelState activateAndResolve(
  DuelEngine engine,
  DuelState state,
  ChainLink link,
) {
  final activated = engine.activateChainEffect(state: state, link: link);
  expect(activated.succeeded, isTrue, reason: activated.failure?.name);
  return resolveChain(engine, activated.state);
}

Map<String, Object?> condition(String method, String trigger) => {
      'method': method,
      'trigger_card_code': trigger,
    };

void main() {
  group('Invocations Mythiques génériques', () {
    test('BAB-010 paie sa Fusion, invoque BAB-015 et déclenche son effet', () {
      final trigger = card(
        'BAB-010',
        id: 'trigger',
        category: CardCategory.action,
        effectKey: BabiEffectKeys.bab010,
        family: 'babi',
        rank: null,
        atk: null,
        def: null,
        position: null,
      );
      final firstMaterial = card(
        'BAB-002',
        id: 'material-1',
        family: 'babi',
        zoneIndex: 0,
      );
      final secondMaterial = card(
        'BAB-006',
        id: 'material-2',
        family: 'babi',
        zoneIndex: 1,
      );
      final mythic = card(
        'BAB-015',
        id: 'mythic',
        category: CardCategory.mythic,
        effectKey: BabiEffectKeys.bab015,
        family: 'babi',
        rank: 9,
        atk: 3200,
        def: 2800,
        faceUp: false,
        position: null,
        mythicCondition: condition('fusion', 'BAB-010'),
      );
      final setTrap = card(
        'TEST-TRAP',
        id: 'set-trap',
        owner: DuelParticipant.ai,
        category: CardCategory.trap,
        rank: null,
        atk: null,
        def: null,
        faceUp: false,
        position: null,
      );
      final engine = DuelEngine(chainEffects: BabiEffectRegistry.create());
      final state = duel(
        player: field(
          participant: DuelParticipant.player,
          characters: [firstMaterial, secondMaterial, null, null, null],
          actionTraps: [trigger, null, null, null, null],
          mythics: [mythic],
        ),
        ai: field(
          participant: DuelParticipant.ai,
          actionTraps: [setTrap, null, null, null, null],
        ),
      );

      var result = activateAndResolve(
        engine,
        state,
        activation(
          effectKey: BabiEffectKeys.bab010,
          sourceId: 'trigger',
          sourceCode: 'BAB-010',
          payload: const {
            'material_instance_ids': ['material-1', 'material-2'],
          },
        ),
      );

      expect(result.playerField.graveyard, hasLength(2));
      expect(result.playerField.mythicReserve, isEmpty);
      expect(
          result.playerField.characterZones
              .whereType<CardInstance>()
              .single
              .cardCode,
          'BAB-015');
      expect(result.chain.links.single.effectKey, BabiEffectKeys.bab015);

      result = resolveChain(engine, result);
      expect(result.aiField.actionTrapZones.first, isNull);
      expect(result.aiField.hand.single.instanceId, 'set-trap');
    });

    test('ROY-010 paie les sacrifices, invoque ROY-015 et ranime', () {
      final trigger = card(
        'ROY-010',
        id: 'trigger',
        category: CardCategory.action,
        effectKey: RoyaumeEffectKeys.roy010,
        family: 'royaume',
        rank: null,
        atk: null,
        def: null,
        position: null,
      );
      final rankFive = card(
        'ROY-005',
        id: 'rank-5',
        family: 'royaume',
        rank: 5,
        zoneIndex: 0,
      );
      final rankFour = card(
        'ROY-004',
        id: 'rank-4',
        family: 'royaume',
        rank: 4,
        zoneIndex: 1,
      );
      final mythic = card(
        'ROY-015',
        id: 'mythic',
        category: CardCategory.mythic,
        effectKey: RoyaumeEffectKeys.roy015,
        family: 'royaume',
        rank: 10,
        atk: 3700,
        def: 3400,
        faceUp: false,
        position: null,
        mythicCondition: condition('ancestrale', 'ROY-010'),
      );
      final engine = DuelEngine(chainEffects: RoyaumeEffectRegistry.create());
      var result = activateAndResolve(
        engine,
        duel(
          player: field(
            participant: DuelParticipant.player,
            characters: [rankFive, rankFour, null, null, null],
            actionTraps: [trigger, null, null, null, null],
            mythics: [mythic],
          ),
        ),
        activation(
          effectKey: RoyaumeEffectKeys.roy010,
          sourceId: 'trigger',
          sourceCode: 'ROY-010',
          payload: const {
            'sacrifice_instance_ids': ['rank-5', 'rank-4'],
          },
        ),
      );

      expect(result.chain.links.single.effectKey, RoyaumeEffectKeys.roy015);
      result = resolveChain(engine, result);
      final characters =
          result.playerField.characterZones.whereType<CardInstance>().toList();
      expect(characters.map((card) => card.cardCode),
          containsAll(['ROY-015', 'ROY-005', 'ROY-004']));
      expect(
        characters
            .where((card) => card.cardCode != 'ROY-015')
            .every((card) => card.position == BattlePosition.defense),
        isTrue,
      );
    });

    test('FOR-010 invoque FOR-015 puis crée trois Jetons Sylve', () {
      final trigger = card(
        'FOR-010',
        id: 'trigger',
        category: CardCategory.action,
        effectKey: ForetEffectKeys.for010,
        family: 'forêt',
        rank: null,
        atk: null,
        def: null,
        position: null,
      );
      final material = card(
        'FOR-006',
        id: 'iroko',
        family: 'forêt',
        rank: 6,
        zoneIndex: 0,
      );
      final mythic = card(
        'FOR-015',
        id: 'mythic',
        category: CardCategory.mythic,
        effectKey: ForetEffectKeys.for015,
        family: 'forêt',
        rank: 10,
        atk: 3500,
        def: 4000,
        faceUp: false,
        position: null,
        mythicCondition: condition('fusion', 'FOR-010'),
      );
      final engine = DuelEngine(chainEffects: ForetEffectRegistry.create());
      var result = activateAndResolve(
        engine,
        duel(
          player: field(
            participant: DuelParticipant.player,
            characters: [
              material,
              sylve('token-1', 1),
              sylve('token-2', 2),
              null,
              null,
            ],
            actionTraps: [trigger, null, null, null, null],
            mythics: [mythic],
          ),
        ),
        activation(
          effectKey: ForetEffectKeys.for010,
          sourceId: 'trigger',
          sourceCode: 'FOR-010',
          payload: const {
            'iroko_instance_id': 'iroko',
            'token_instance_ids': ['token-1', 'token-2'],
          },
        ),
      );

      expect(result.chain.links.single.effectKey, ForetEffectKeys.for015);
      result = resolveChain(engine, result);
      expect(
        result.playerField.characterZones.whereType<TokenInstance>(),
        hasLength(3),
      );
      expect(
        result.playerField.characterZones
            .whereType<CardInstance>()
            .single
            .cardCode,
        'FOR-015',
      );
    });

    test('zone pleine : le coût reste payé et la Mythique reste en Réserve',
        () {
      final trigger = card(
        'ANC-010',
        id: 'trigger',
        category: CardCategory.action,
        effectKey: AncetreEffectKeys.anc010,
        family: 'ancêtre',
        rank: null,
        atk: null,
        def: null,
        position: null,
      );
      final graveOne = card(
        'ANC-004',
        id: 'grave-1',
        family: 'ancêtre',
        rank: 5,
        position: null,
      );
      final graveTwo = card(
        'ANC-006',
        id: 'grave-2',
        family: 'ancêtre',
        rank: 5,
        position: null,
      );
      final mythic = card(
        'ANC-015',
        id: 'mythic',
        category: CardCategory.mythic,
        effectKey: AncetreEffectKeys.anc015,
        family: 'ancêtre',
        rank: 10,
        faceUp: false,
        position: null,
        mythicCondition: condition('ancestrale', 'ANC-010'),
      );
      final occupied = List<FieldCardInstance?>.generate(
        5,
        (index) => card(
          'FILL-$index',
          id: 'fill-$index',
          family: 'babi',
          zoneIndex: index,
        ),
      );
      final engine = DuelEngine(chainEffects: AncetreEffectRegistry.create());
      final result = activateAndResolve(
        engine,
        duel(
          player: field(
            participant: DuelParticipant.player,
            characters: occupied,
            actionTraps: [trigger, null, null, null, null],
            graveyard: [graveOne, graveTwo],
            mythics: [mythic],
          ),
        ),
        activation(
          effectKey: AncetreEffectKeys.anc010,
          sourceId: 'trigger',
          sourceCode: 'ANC-010',
          payload: const {
            'banish_instance_ids': ['grave-1', 'grave-2'],
          },
        ),
      );

      expect(result.playerField.graveyard, isEmpty);
      expect(result.playerField.banished, hasLength(2));
      expect(result.playerField.mythicReserve.single.cardCode, 'ANC-015');
      expect(
        result.playerField.characterZones.whereType<CardInstance>(),
        hasLength(5),
      );
      expect(result.chain.isOpen, isFalse);
    });

    test('matériaux absents : activation refusée sans payer de coût', () {
      final trigger = card(
        'BAB-010',
        id: 'trigger',
        category: CardCategory.action,
        effectKey: BabiEffectKeys.bab010,
        family: 'babi',
        rank: null,
        atk: null,
        def: null,
        position: null,
      );
      final wrong = card(
        'BAB-002',
        id: 'only-material',
        family: 'babi',
        zoneIndex: 0,
      );
      final mythic = card(
        'BAB-015',
        id: 'mythic',
        category: CardCategory.mythic,
        effectKey: BabiEffectKeys.bab015,
        family: 'babi',
        rank: 9,
        faceUp: false,
        position: null,
        mythicCondition: condition('fusion', 'BAB-010'),
      );
      final state = duel(
        player: field(
          participant: DuelParticipant.player,
          characters: [wrong, null, null, null, null],
          actionTraps: [trigger, null, null, null, null],
          mythics: [mythic],
        ),
      );
      final engine = DuelEngine(chainEffects: BabiEffectRegistry.create());
      final result = engine.activateChainEffect(
        state: state,
        link: activation(
          effectKey: BabiEffectKeys.bab010,
          sourceId: 'trigger',
          sourceCode: 'BAB-010',
          payload: const {
            'material_instance_ids': ['only-material'],
          },
        ),
      );

      expect(result.succeeded, isFalse);
      expect(result.failure, DuelActionFailure.chainActivationConditionNotMet);
      expect(result.state.playerField.characterZones.first, same(wrong));
      expect(result.state.playerField.graveyard, isEmpty);
      expect(result.state.playerField.mythicReserve.single, same(mythic));
    });
  });

  test('MAS-004 déclenche automatiquement son retournement sans factory', () {
    final attacker = card(
      'ATT-001',
      id: 'attacker',
      family: 'babi',
      atk: 1000,
      def: 2000,
      zoneIndex: 0,
    );
    final mask = card(
      'MAS-004',
      id: 'mask',
      owner: DuelParticipant.ai,
      effectKey: MasqueEffectKeys.mas004,
      family: 'masque',
      atk: 800,
      def: 2500,
      faceUp: false,
      position: BattlePosition.defense,
      zoneIndex: 0,
    );
    final state = duel(
      phase: DuelPhase.battle,
      player: field(
        participant: DuelParticipant.player,
        characters: [attacker, null, null, null, null],
      ),
      ai: field(
        participant: DuelParticipant.ai,
        characters: [mask, null, null, null, null],
      ),
    );
    final engine = DuelEngine(chainEffects: MasqueEffectRegistry.create());
    final declared = engine.declareAttack(
      state: state,
      participant: DuelParticipant.player,
      attackerInstanceId: 'attacker',
      targetInstanceId: 'mask',
    );
    final afterWindow = resolveChain(engine, declared.state);
    final combat = engine.resolveAttack(
      state: afterWindow,
      declaration: declared.declaration!,
    );

    expect(combat.targetFlippedFaceUp, isTrue);
    expect(combat.state.chain.links.single.effectKey, MasqueEffectKeys.mas004);
    final resolved = resolveChain(engine, combat.state);
    final updated = resolved.playerField.characterZones.first!;
    expect(updated.effectiveAtk, 2000);
    expect(updated.effectiveDef, 1000);
  });
}
