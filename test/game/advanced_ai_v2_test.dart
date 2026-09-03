import 'package:mysticartes/game/ai/advanced_ai.dart';
import 'package:mysticartes/game/ai/beginner_ai.dart';
import 'package:mysticartes/game/battle_state.dart';
import 'package:mysticartes/game/card.dart';
import 'package:mysticartes/game/duel_engine.dart';
import 'package:mysticartes/game/duel_types.dart';
import 'package:mysticartes/game/effects/babi_effects.dart';
import 'package:mysticartes/game/player.dart';
import 'package:test/test.dart';

final class FixedRandom implements AiRandomSource {
  const FixedRandom();

  @override
  int nextInt(int max) => 0;
}

CardInstance card(
  String code, {
  required String id,
  DuelParticipant owner = DuelParticipant.ai,
  CardCategory category = CardCategory.character,
  String? subtype,
  String? effectKey,
  String? family,
  int? rank = 4,
  int? atk = 1500,
  int? def = 1500,
  bool faceUp = false,
  BattlePosition? position,
  int? zoneIndex,
  Map<String, Object?> effectData = const {},
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
    effectKey: effectKey,
    effectData: effectData,
    mythicSummonCondition: mythicCondition,
    owner: owner,
    controller: owner,
    faceUp: faceUp,
    position: position,
    atk: atk,
    def: def,
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
    banished: const [],
    mythicReserve: mythics,
  );
}

DuelState duel({
  PlayerFieldState? ai,
  PlayerFieldState? player,
  DuelPhase phase = DuelPhase.main1,
  int turn = 2,
  int aiLifePoints = 8000,
  int playerLifePoints = 8000,
}) {
  return DuelState(
    playerField: player ?? field(participant: DuelParticipant.player),
    aiField: ai ?? field(participant: DuelParticipant.ai),
    activePlayer: DuelParticipant.ai,
    startingPlayer: DuelParticipant.player,
    currentPhase: phase,
    turnNumber: turn,
    aiLifePoints: aiLifePoints,
    playerLifePoints: playerLifePoints,
  );
}

DuelState resolveCurrentChain(DuelEngine engine, DuelState state) {
  var current = state;
  var guard = 0;
  while (current.chain.isOpen && guard++ < 2) {
    final pass = engine.passPriority(
      state: current,
      participant: current.chain.priorityPlayer!,
    );
    expect(pass.succeeded, isTrue);
    current = pass.state;
  }
  return current;
}

void main() {
  test('préfère un effet avantageux au plus haut ATK brut', () {
    final brute = card('AI-003', id: 'brute', atk: 2200, def: 1600);
    final value = card(
      'AI-004',
      id: 'value',
      atk: 1900,
      def: 1600,
      effectKey: 'draw-on-summon',
      effectData: const {'on_summon_draw': true},
    );
    final engine = DuelEngine();
    final ai = AdvancedAi(engine: engine, random: const FixedRandom());

    final result = ai.playBestMonster(
      duel(ai: field(participant: DuelParticipant.ai, hand: [brute, value])),
    )!;

    expect(result.succeeded, isTrue);
    expect(result.state.aiField.characterZones.first!.instanceId, 'value');
  });

  test('déclenche une Fusion avantageuse et invoque la Mythique', () {
    final trigger = card(
      'BAB-010',
      id: 'trigger',
      category: CardCategory.action,
      effectKey: BabiEffectKeys.bab010,
      family: 'babi',
      rank: null,
      atk: null,
      def: null,
      faceUp: true,
      zoneIndex: 0,
    );
    final firstMaterial = card(
      'BAB-002',
      id: 'material-1',
      family: 'babi',
      faceUp: true,
      position: BattlePosition.attack,
      zoneIndex: 0,
    );
    final secondMaterial = card(
      'BAB-006',
      id: 'material-2',
      family: 'babi',
      faceUp: true,
      position: BattlePosition.attack,
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
      mythicCondition: const {
        'method': 'fusion',
        'trigger_card_code': 'BAB-010',
      },
    );
    final engine = DuelEngine(chainEffects: BabiEffectRegistry.create());
    final ai = AdvancedAi(engine: engine, random: const FixedRandom());
    final initial = duel(
      ai: field(
        participant: DuelParticipant.ai,
        characters: [firstMaterial, secondMaterial, null, null, null],
        actionTraps: [trigger, null, null, null, null],
        mythics: [mythic],
      ),
    );
    final fusionLink = ChainLink(
      linkId: 'advanced-fusion',
      effectKey: BabiEffectKeys.bab010,
      activatingPlayer: DuelParticipant.ai,
      speed: ChainSpeed.speed1,
      sourceCardInstanceId: 'trigger',
      sourceCardCode: 'BAB-010',
      payload: const {
        'material_instance_ids': ['material-1', 'material-2'],
      },
    );

    final decision = ai.activateProactively(
      state: initial,
      availableActivations: [fusionLink],
    );
    expect(decision.activatedLink?.linkId, 'advanced-fusion');

    final resolved = resolveCurrentChain(engine, decision.state);
    expect(resolved.aiField.graveyard, hasLength(2));
    expect(resolved.aiField.mythicReserve, isEmpty);
    expect(
      resolved.aiField.characterZones.whereType<CardInstance>().single.cardCode,
      'BAB-015',
    );
  });

  test('refuse de sur-étendre une attaque qui permettrait un létal adverse',
      () {
    final attacker = card(
      'AI-001',
      id: 'attacker',
      atk: 2000,
      faceUp: true,
      position: BattlePosition.attack,
      zoneIndex: 0,
    );
    final weakTarget = card(
      'PL-001',
      id: 'weak-target',
      owner: DuelParticipant.player,
      atk: 1000,
      faceUp: true,
      position: BattlePosition.attack,
      zoneIndex: 0,
    );
    final counterAttacker = card(
      'PL-002',
      id: 'counter-attacker',
      owner: DuelParticipant.player,
      atk: 3000,
      faceUp: true,
      position: BattlePosition.attack,
      zoneIndex: 1,
    );
    final ai = AdvancedAi(
      engine: DuelEngine(),
      random: const FixedRandom(),
    );

    final result = ai.declareBestAttack(
      duel(
        phase: DuelPhase.battle,
        aiLifePoints: 800,
        ai: field(
          participant: DuelParticipant.ai,
          characters: [attacker, null, null, null, null],
        ),
        player: field(
          participant: DuelParticipant.player,
          characters: [weakTarget, counterAttacker, null, null, null],
        ),
      ),
    );

    expect(result, isNull);
  });

  test('garde en main une Action qui exige plus de ressources', () {
    final futureAction = card(
      'AI-009',
      id: 'future-action',
      category: CardCategory.action,
      effectKey: 'future-effect',
      rank: null,
      atk: null,
      def: null,
      effectData: const {
        'requires_resources': 3,
        'future_value': true,
      },
    );
    final engine = DuelEngine();
    final ai = AdvancedAi(engine: engine, random: const FixedRandom());
    final initial = duel(
      ai: field(
        participant: DuelParticipant.ai,
        hand: [futureAction],
      ),
    );

    final result = ai.setStrategicBackrow(initial);

    expect(result, isNull);
    expect(initial.aiField.hand.single.instanceId, 'future-action');
  });

  test("simule un tour complet de l'IA avancée", () {
    final weak = card('AI-001', id: 'weak', atk: 1200);
    final strong = card('AI-002', id: 'strong', atk: 2100);
    final trap = card(
      'AI-T01',
      id: 'trap',
      category: CardCategory.trap,
      effectKey: 'trap-effect',
      rank: null,
      atk: null,
      def: null,
    );
    final draw = card(
      'AI-A01',
      id: 'draw',
      category: CardCategory.action,
      rank: null,
      atk: null,
      def: null,
    );
    final target = card(
      'PL-001',
      id: 'target',
      owner: DuelParticipant.player,
      atk: 900,
      faceUp: true,
      position: BattlePosition.attack,
      zoneIndex: 0,
    );
    final engine = DuelEngine();
    final ai = AdvancedAi(engine: engine, random: const FixedRandom());

    final result = ai.playUnopposedTurn(
      duel(
        phase: DuelPhase.draw,
        ai: field(
          participant: DuelParticipant.ai,
          deck: [draw],
          hand: [weak, strong, trap],
        ),
        player: field(
          participant: DuelParticipant.player,
          characters: [target, null, null, null, null],
        ),
      ),
    );

    expect(result.state.isFinished, isFalse);
    expect(result.state.activePlayer, DuelParticipant.player);
    expect(result.state.turnNumber, 3);
    expect(result.actions, contains('normal_monster_play'));
    expect(result.actions, contains('set_action_or_trap'));
    expect(result.actions, contains('attack'));
  });
}
