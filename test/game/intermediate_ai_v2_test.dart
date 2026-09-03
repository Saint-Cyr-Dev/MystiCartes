import 'package:mysticartes/game/ai/beginner_ai.dart';
import 'package:mysticartes/game/ai/intermediate_ai.dart';
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
  int? rank = 4,
  int? atk = 1500,
  int? def = 1500,
  bool faceUp = false,
  BattlePosition? position,
  int? zoneIndex,
  Map<String, Object?> runtimeData = const {},
}) {
  return CardInstance(
    instanceId: id,
    cardId: 'catalog-$code',
    cardCode: code,
    cardRevision: 1,
    category: category,
    rank: rank,
    subtype: subtype,
    effectKey: effectKey,
    owner: owner,
    controller: owner,
    faceUp: faceUp,
    position: position,
    atk: atk,
    def: def,
    zoneIndex: zoneIndex,
    runtimeData: runtimeData,
  );
}

PlayerFieldState field({
  required DuelParticipant participant,
  List<FieldCardInstance?>? characters,
  List<CardInstance?>? actionTraps,
  List<CardInstance> deck = const [],
  List<CardInstance> hand = const [],
  List<CardInstance> graveyard = const [],
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
    mythicReserve: const [],
  );
}

DuelState duel({
  PlayerFieldState? ai,
  PlayerFieldState? player,
  DuelPhase phase = DuelPhase.main1,
  int turn = 2,
  ChainState? chain,
  DuelParticipant activePlayer = DuelParticipant.ai,
}) {
  return DuelState(
    playerField: player ?? field(participant: DuelParticipant.player),
    aiField: ai ?? field(participant: DuelParticipant.ai),
    activePlayer: activePlayer,
    startingPlayer: DuelParticipant.player,
    currentPhase: phase,
    turnNumber: turn,
    chain: chain,
  );
}

void main() {
  test("préfère le Personnage légal avec l'ATK la plus élevée", () {
    final weak = card('AI-001', id: 'weak', atk: 1200);
    final strong = card('AI-002', id: 'strong', atk: 2300);
    final engine = DuelEngine();
    final ai = IntermediateAi(engine: engine, random: const FixedRandom());

    final result = ai.playBestMonster(
      duel(ai: field(participant: DuelParticipant.ai, hand: [weak, strong])),
    )!;

    expect(result.succeeded, isTrue);
    expect(result.state.aiField.characterZones.first!.instanceId, 'strong');
    expect(result.state.aiField.characterZones.first!.faceUp, isTrue);
  });

  test("sacrifie un Personnage simple avant un Personnage à effet", () {
    final tribute = card('AI-005', id: 'tribute', rank: 5, atk: 2400);
    final simple = card(
      'AI-003',
      id: 'simple',
      atk: 1900,
      faceUp: true,
      position: BattlePosition.attack,
      zoneIndex: 0,
    );
    final effectMonster = card(
      'AI-004',
      id: 'effect',
      effectKey: 'valuable-effect',
      atk: 500,
      faceUp: true,
      position: BattlePosition.attack,
      zoneIndex: 1,
    );
    final engine = DuelEngine();
    final ai = IntermediateAi(engine: engine, random: const FixedRandom());

    final result = ai.playBestMonster(
      duel(
        ai: field(
          participant: DuelParticipant.ai,
          characters: [simple, effectMonster, null, null, null],
          hand: [tribute],
        ),
      ),
    )!;

    expect(result.succeeded, isTrue);
    expect(result.state.aiField.graveyard.single.instanceId, 'simple');
    expect(
      result.state.aiField.characterZones
          .whereType<CardInstance>()
          .map((entry) => entry.instanceId),
      contains('effect'),
    );
  });

  test('pose face cachée en Défense devant un attaquant trop fort', () {
    final defender = card('AI-001', id: 'defender', atk: 1800, def: 2500);
    final threat = card(
      'PL-001',
      id: 'threat',
      owner: DuelParticipant.player,
      atk: 2600,
      faceUp: true,
      position: BattlePosition.attack,
      zoneIndex: 0,
    );
    final engine = DuelEngine();
    final ai = IntermediateAi(engine: engine, random: const FixedRandom());

    final result = ai.playBestMonster(
      duel(
        ai: field(participant: DuelParticipant.ai, hand: [defender]),
        player: field(
          participant: DuelParticipant.player,
          characters: [threat, null, null, null, null],
        ),
      ),
    )!;

    final placed = result.state.aiField.characterZones.first!;
    expect(placed.faceUp, isFalse);
    expect(placed.position, BattlePosition.defense);
  });

  test('refuse un échange de combat clairement défavorable', () {
    final attacker = card(
      'AI-001',
      id: 'attacker',
      atk: 1500,
      faceUp: true,
      position: BattlePosition.attack,
      zoneIndex: 0,
    );
    final target = card(
      'PL-001',
      id: 'target',
      owner: DuelParticipant.player,
      atk: 2200,
      faceUp: true,
      position: BattlePosition.attack,
      zoneIndex: 0,
    );
    final ai = IntermediateAi(
      engine: DuelEngine(),
      random: const FixedRandom(),
    );

    final result = ai.declareBestAttack(
      duel(
        phase: DuelPhase.battle,
        ai: field(
          participant: DuelParticipant.ai,
          characters: [attacker, null, null, null, null],
        ),
        player: field(
          participant: DuelParticipant.player,
          characters: [target, null, null, null, null],
        ),
      ),
    );

    expect(result, isNull);
  });

  test('active un Piège pour éviter la perte d’un Personnage important', () {
    final important = card(
      'AI-007',
      id: 'important',
      atk: 2500,
      effectKey: 'important-effect',
      faceUp: true,
      position: BattlePosition.attack,
      zoneIndex: 0,
    );
    final trap = card(
      'AI-T01',
      id: 'trap',
      category: CardCategory.trap,
      effectKey: 'protect-effect',
      rank: null,
      atk: null,
      def: null,
      zoneIndex: 0,
    );
    final engine = DuelEngine(
      chainEffects: const {
        'opponent-effect': FakeEffect(),
        'protect-effect': FakeEffect(),
      },
    );
    final ai = IntermediateAi(engine: engine, random: const FixedRandom());
    final initial = duel(
      activePlayer: DuelParticipant.player,
      ai: field(
        participant: DuelParticipant.ai,
        characters: [important, null, null, null, null],
        actionTraps: [trap, null, null, null, null],
      ),
    );
    final opponentActivation = engine.activateChainEffect(
      state: initial,
      link: ChainLink(
        linkId: 'opponent-link',
        effectKey: 'opponent-effect',
        activatingPlayer: DuelParticipant.player,
        speed: ChainSpeed.speed1,
      ),
    );
    final protection = ChainLink(
      linkId: 'protect-link',
      effectKey: 'protect-effect',
      activatingPlayer: DuelParticipant.ai,
      speed: ChainSpeed.speed2,
      sourceCardInstanceId: 'trap',
      sourceCardCode: 'AI-T01',
      payload: const {
        'preventsDestruction': true,
        'protectedCardInstanceId': 'important',
      },
    );

    final decision = ai.handlePriority(
      state: opponentActivation.state,
      availableActivations: [protection],
    );

    expect(decision.passed, isFalse);
    expect(decision.activatedLink?.linkId, 'protect-link');
    expect(decision.state.chain.links, hasLength(2));
  });

  test("simule un tour complet de l'IA intermédiaire", () {
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
    final ai = IntermediateAi(engine: engine, random: const FixedRandom());

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
