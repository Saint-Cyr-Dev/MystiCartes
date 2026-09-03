import 'package:mysticartes/game/ai/ai_strategy.dart';
import 'package:mysticartes/game/ai/beginner_ai.dart';
import 'package:mysticartes/game/ai/expert_ai.dart';
import 'package:mysticartes/game/battle_state.dart';
import 'package:mysticartes/game/card.dart';
import 'package:mysticartes/game/duel_engine.dart';
import 'package:mysticartes/game/duel_types.dart';
import 'package:mysticartes/game/player.dart';
import 'package:test/test.dart';

final class FixedRandom implements AiRandomSource {
  const FixedRandom();

  @override
  int nextInt(int max) => 0;
}

final class FakeEffect extends ChainEffectDefinition {
  const FakeEffect();

  @override
  DuelState resolve(DuelState state, ChainLink link) => state;
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
  Map<String, Object?> runtimeData = const {},
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
    runtimeData: runtimeData,
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

DuelState closeWindow(DuelEngine engine, DuelState state) {
  var current = state;
  var guard = 0;
  while (current.chain.isOpen && guard++ < 8) {
    current = engine
        .passPriority(
          state: current,
          participant: current.chain.priorityPlayer!,
        )
        .state;
  }
  return current;
}

void main() {
  test('séquence une petite attaque pour retirer la protection en premier', () {
    final breaker = card(
      'AI-001',
      id: 'breaker',
      atk: 1800,
      faceUp: true,
      position: BattlePosition.attack,
      zoneIndex: 0,
    );
    final finisher = card(
      'AI-007',
      id: 'finisher',
      atk: 3000,
      faceUp: true,
      position: BattlePosition.attack,
      zoneIndex: 1,
    );
    final guard = card(
      'ROY-003',
      id: 'guard',
      owner: DuelParticipant.player,
      family: 'royaume',
      atk: 1500,
      faceUp: true,
      position: BattlePosition.attack,
      zoneIndex: 0,
    );
    final protected = card(
      'ROY-006',
      id: 'protected',
      owner: DuelParticipant.player,
      family: 'royaume',
      effectKey: 'dangerous-effect',
      atk: 2500,
      faceUp: true,
      position: BattlePosition.attack,
      zoneIndex: 1,
    );
    final engine = DuelEngine();
    final ai = ExpertAi(engine: engine, random: const FixedRandom());

    final plan = ai.planAttackSequence(
      duel(
        phase: DuelPhase.battle,
        ai: field(
          participant: DuelParticipant.ai,
          characters: [breaker, finisher, null, null, null],
        ),
        player: field(
          participant: DuelParticipant.player,
          characters: [guard, protected, null, null, null],
        ),
      ),
    );

    expect(plan.steps, hasLength(2));
    expect(plan.steps.first.attackerInstanceId, 'breaker');
    expect(plan.steps.first.targetInstanceId, 'guard');
    expect(plan.steps.first.purpose, 'remove_protection');
    expect(plan.steps.last.attackerInstanceId, 'finisher');
    expect(plan.steps.last.targetInstanceId, 'protected');
  });

  test('utilise un effet appât devant une réponse adverse prévisible', () {
    final baitCard = card(
      'AI-008',
      id: 'bait-card',
      category: CardCategory.action,
      effectKey: 'bait-effect',
      rank: null,
      atk: null,
      def: null,
      faceUp: true,
      zoneIndex: 0,
    );
    final decisiveCard = card(
      'AI-010',
      id: 'decisive-card',
      category: CardCategory.action,
      effectKey: 'decisive-effect',
      rank: null,
      atk: null,
      def: null,
      faceUp: true,
      zoneIndex: 1,
    );
    final probableTrap = card(
      'PL-011',
      id: 'probable-trap',
      owner: DuelParticipant.player,
      category: CardCategory.trap,
      rank: null,
      atk: null,
      def: null,
      faceUp: false,
      zoneIndex: 0,
    );
    final unknownHandCard = card(
      'PL-HAND',
      id: 'unknown-hand',
      owner: DuelParticipant.player,
    );
    final engine = DuelEngine(chainEffects: const {
      'bait-effect': FakeEffect(),
      'decisive-effect': FakeEffect(),
    });
    final ai = ExpertAi(engine: engine, random: const FixedRandom());
    final state = duel(
      ai: field(
        participant: DuelParticipant.ai,
        actionTraps: [baitCard, decisiveCard, null, null, null],
      ),
      player: field(
        participant: DuelParticipant.player,
        actionTraps: [probableTrap, null, null, null, null],
        hand: [unknownHandCard],
      ),
    );
    final bait = ChainLink(
      linkId: 'bait-link',
      effectKey: 'bait-effect',
      activatingPlayer: DuelParticipant.ai,
      speed: ChainSpeed.speed1,
      sourceCardInstanceId: 'bait-card',
      sourceCardCode: 'AI-008',
      payload: const {'bait': true, 'createsAdvantage': true},
    );
    final decisive = ChainLink(
      linkId: 'decisive-link',
      effectKey: 'decisive-effect',
      activatingPlayer: DuelParticipant.ai,
      speed: ChainSpeed.speed1,
      sourceCardInstanceId: 'decisive-card',
      sourceCardCode: 'AI-010',
      payload: const {'highValue': true, 'createsAdvantage': true},
    );

    final decision = ai.activateWithForesight(
      state: state,
      availableActivations: [decisive, bait],
    );

    expect(decision.activatedLink?.linkId, 'bait-link');
  });

  test('prépare progressivement deux matériaux pour une Mythique', () {
    final trigger = card(
      'PLAN-010',
      id: 'trigger',
      category: CardCategory.action,
      rank: null,
      atk: null,
      def: null,
    );
    final materialA = card('MAT-A', id: 'material-a', atk: 1200);
    final materialB = card('MAT-B', id: 'material-b', atk: 1400);
    final mythic = card(
      'PLAN-015',
      id: 'mythic',
      category: CardCategory.mythic,
      rank: 9,
      atk: 3500,
      def: 3000,
      mythicCondition: const {
        'method': 'fusion',
        'trigger_card_code': 'PLAN-010',
        'source': 'field',
        'materials': [
          {'card_code': 'MAT-A', 'quantity': 1},
          {'card_code': 'MAT-B', 'quantity': 1},
        ],
      },
    );
    final engine = DuelEngine();
    final ai = ExpertAi(engine: engine, random: const FixedRandom());
    var state = duel(
      ai: field(
        participant: DuelParticipant.ai,
        hand: [trigger, materialA],
        mythics: [mythic],
      ),
    );

    final firstPlan = ai.updateMythicPlan(state)!;
    expect(firstPlan.missingMaterialCodes, containsAll(['MAT-A', 'MAT-B']));
    final firstPlay = ai.playBestMonster(state)!;
    expect(firstPlay.succeeded, isTrue);
    state = closeWindow(engine, firstPlay.state);

    state = state.copyWith(
      turnNumber: 3,
      currentPhase: DuelPhase.main1,
      normalSummonUsed: const {
        DuelParticipant.player: false,
        DuelParticipant.ai: false,
      },
      aiField: state.aiField.copyWith(
        hand: [...state.aiField.hand, materialB],
      ),
    );
    final secondPlay = ai.playBestMonster(state)!;
    expect(secondPlay.succeeded, isTrue);
    state = closeWindow(engine, secondPlay.state);
    final finalPlan = ai.updateMythicPlan(state)!;

    expect(
      state.aiField.characterZones
          .whereType<CardInstance>()
          .map((entry) => entry.cardCode),
      containsAll(['MAT-A', 'MAT-B']),
    );
    expect(finalPlan.ready, isTrue);
    expect(finalPlan.mythicInstanceId, firstPlan.mythicInstanceId);
  });

  test('est prudente en avance et agressive lorsqu’elle est condamnée', () {
    final valuable = card(
      'AI-BOSS',
      id: 'valuable',
      atk: 3000,
      def: 2500,
      faceUp: true,
      position: BattlePosition.attack,
      zoneIndex: 0,
    );
    final probableTrap = card(
      'PL-011',
      id: 'trap',
      owner: DuelParticipant.player,
      category: CardCategory.trap,
      rank: null,
      atk: null,
      def: null,
      faceUp: false,
      zoneIndex: 0,
    );
    final handCard = card(
      'PL-HAND',
      id: 'hand',
      owner: DuelParticipant.player,
    );
    final engine = DuelEngine();
    final ai = ExpertAi(engine: engine, random: const FixedRandom());
    final strongState = duel(
      phase: DuelPhase.battle,
      playerLifePoints: 7000,
      ai: field(
        participant: DuelParticipant.ai,
        characters: [valuable, null, null, null, null],
      ),
      player: field(
        participant: DuelParticipant.player,
        actionTraps: [probableTrap, null, null, null, null],
        hand: [handCard],
      ),
    );

    expect(ai.riskPosture(strongState), RiskPosture.prudent);
    expect(ai.declareNextAttack(strongState), isNull);

    final desperateAttacker = card(
      'AI-WEAK',
      id: 'desperate',
      atk: 1500,
      faceUp: true,
      position: BattlePosition.attack,
      zoneIndex: 0,
    );
    final strongerTarget = card(
      'PL-STRONG',
      id: 'strong-target',
      owner: DuelParticipant.player,
      atk: 2200,
      faceUp: true,
      position: BattlePosition.attack,
      zoneIndex: 0,
    );
    final weakState = duel(
      phase: DuelPhase.battle,
      aiLifePoints: 1000,
      ai: field(
        participant: DuelParticipant.ai,
        characters: [desperateAttacker, null, null, null, null],
      ),
      player: field(
        participant: DuelParticipant.player,
        characters: [strongerTarget, null, null, null, null],
      ),
    );

    expect(ai.riskPosture(weakState), RiskPosture.desperate);
    expect(ai.declareNextAttack(weakState), isNotNull);
  });

  test("simule un tour complet de l'IA experte", () {
    final monster = card('AI-001', id: 'monster', atk: 2100);
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
    final ai = ExpertAi(engine: engine, random: const FixedRandom());

    final result = ai.playUnopposedTurn(
      duel(
        phase: DuelPhase.draw,
        ai: field(
          participant: DuelParticipant.ai,
          deck: [draw],
          hand: [monster, trap],
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

  test('le sélecteur construit les quatre niveaux indépendamment', () {
    final engine = DuelEngine();
    for (final difficulty in AiDifficulty.values) {
      final strategy = createDuelAi(
        difficulty: difficulty,
        engine: engine,
        random: const FixedRandom(),
      );
      expect(strategy.difficulty, difficulty);
    }
  });
}
