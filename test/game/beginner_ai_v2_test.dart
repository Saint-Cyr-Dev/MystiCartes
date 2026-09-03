import 'package:mysticartes/game/ai/beginner_ai.dart';
import 'package:mysticartes/game/battle_state.dart';
import 'package:mysticartes/game/card.dart';
import 'package:mysticartes/game/duel_engine.dart';
import 'package:mysticartes/game/duel_types.dart';
import 'package:mysticartes/game/player.dart';
import 'package:test/test.dart';

final class SequenceRandom implements AiRandomSource {
  SequenceRandom([this.values = const [0]]);

  final List<int> values;
  int _index = 0;

  @override
  int nextInt(int max) {
    final value = values[_index++ % values.length];
    return value % max;
  }
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
}) {
  return DuelState(
    playerField: player ?? field(participant: DuelParticipant.player),
    aiField: ai ?? field(participant: DuelParticipant.ai),
    activePlayer: DuelParticipant.ai,
    startingPlayer: DuelParticipant.player,
    currentPhase: phase,
    turnNumber: turn,
    chain: chain,
  );
}

DuelState closeWindow(DuelEngine engine, DuelState state) {
  var current = state;
  while (current.chain.isOpen) {
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
  test('invoque un Personnage légal', () {
    final monster = card('AI-001', id: 'monster');
    final engine = DuelEngine();
    final ai = BeginnerAi(engine: engine, random: SequenceRandom([0]));

    final result = ai.playRandomMonster(
      duel(ai: field(participant: DuelParticipant.ai, hand: [monster])),
    );

    expect(result, isNotNull);
    expect(result!.succeeded, isTrue);
    final summoned = result.state.aiField.characterZones.first!;
    expect(summoned.instanceId, 'monster');
    expect(summoned.faceUp, isTrue);
    expect(summoned.position, BattlePosition.attack);
    expect(result.state.normalSummonUsed[DuelParticipant.ai], isTrue);
  });

  test('sacrifie correctement pour un Personnage de rang 5', () {
    final highRank = card('AI-005', id: 'high-rank', rank: 5);
    final first = card(
      'AI-S1',
      id: 'sacrifice-1',
      faceUp: true,
      position: BattlePosition.attack,
      zoneIndex: 0,
    );
    final second = card(
      'AI-S2',
      id: 'sacrifice-2',
      faceUp: true,
      position: BattlePosition.attack,
      zoneIndex: 1,
    );
    final engine = DuelEngine();
    final ai = BeginnerAi(
      engine: engine,
      random: SequenceRandom([0, 1, 0]),
    );

    final result = ai.playRandomMonster(
      duel(
        ai: field(
          participant: DuelParticipant.ai,
          characters: [first, second, null, null, null],
          hand: [highRank],
        ),
      ),
    )!;

    expect(result.succeeded, isTrue);
    expect(result.state.aiField.graveyard.single.instanceId, 'sacrifice-1');
    expect(
      result.state.aiField.characterZones
          .whereType<CardInstance>()
          .map((card) => card.instanceId),
      containsAll(['high-rank', 'sacrifice-2']),
    );
  });

  test('pose une Action ou un Piège depuis sa main', () {
    final trap = card(
      'AI-T01',
      id: 'trap',
      category: CardCategory.trap,
      rank: null,
      atk: null,
      def: null,
    );
    final engine = DuelEngine();
    final ai = BeginnerAi(engine: engine, random: SequenceRandom());

    final result = ai.setRandomActionOrTrap(
      duel(ai: field(participant: DuelParticipant.ai, hand: [trap])),
    );

    expect(result, isNotNull);
    expect(result!.succeeded, isTrue);
    expect(result.state.aiField.hand, isEmpty);
    expect(result.state.aiField.actionTrapZones.first!.instanceId, 'trap');
    expect(result.state.normalSummonUsed[DuelParticipant.ai], isFalse);
  });

  test('déclare une attaque légale vers une cible adverse', () {
    final attacker = card(
      'AI-ATK',
      id: 'attacker',
      atk: 2000,
      faceUp: true,
      position: BattlePosition.attack,
      zoneIndex: 0,
    );
    final target = card(
      'PL-DEF',
      id: 'target',
      owner: DuelParticipant.player,
      atk: 1000,
      faceUp: true,
      position: BattlePosition.attack,
      zoneIndex: 0,
    );
    final engine = DuelEngine();
    final ai = BeginnerAi(engine: engine, random: SequenceRandom());
    final state = duel(
      phase: DuelPhase.battle,
      ai: field(
        participant: DuelParticipant.ai,
        characters: [attacker, null, null, null, null],
      ),
      player: field(
        participant: DuelParticipant.player,
        characters: [target, null, null, null, null],
      ),
    );

    final declared = ai.declareRandomAttack(state)!;
    expect(declared.declaration!.targetInstanceId, 'target');
    final resolved = engine.resolveAttack(
      state: closeWindow(engine, declared.state),
      declaration: declared.declaration!,
    );
    expect(resolved.state.playerField.characterZones.first, isNull);
    expect(resolved.state.playerLifePoints, 7000);
  });

  test('passe systématiquement face à une activation adverse', () {
    final quick = card(
      'AI-Q01',
      id: 'quick',
      category: CardCategory.action,
      subtype: 'quick',
      effectKey: 'quick-effect',
      rank: null,
      atk: null,
      def: null,
      zoneIndex: 0,
    );
    final engine = DuelEngine(
      chainEffects: const {
        'opponent-effect': FakeEffect(),
        'quick-effect': FakeEffect(),
      },
    );
    final ai = BeginnerAi(engine: engine, random: SequenceRandom());
    final initial = duel(
      ai: field(
        participant: DuelParticipant.ai,
        actionTraps: [quick, null, null, null, null],
      ),
    ).copyWith(activePlayer: DuelParticipant.player);
    final opponent = engine.activateChainEffect(
      state: initial,
      link: ChainLink(
        linkId: 'opponent-link',
        effectKey: 'opponent-effect',
        activatingPlayer: DuelParticipant.player,
        speed: ChainSpeed.speed1,
      ),
    );
    final quickResponse = ChainLink(
      linkId: 'ai-response',
      effectKey: 'quick-effect',
      activatingPlayer: DuelParticipant.ai,
      speed: ChainSpeed.speed2,
      sourceCardInstanceId: 'quick',
      sourceCardCode: 'AI-Q01',
    );

    final decision = ai.handlePriority(
      state: opponent.state,
      availableActivations: [quickResponse],
    );

    expect(decision.passed, isTrue);
    expect(decision.activatedLink, isNull);
    expect(decision.state.chain.links, hasLength(1));
    expect(decision.state.chain.consecutivePasses, 1);
  });

  test('peut activer aléatoirement une Action rapide dans sa propre fenêtre',
      () {
    final quick = card(
      'AI-Q01',
      id: 'quick',
      category: CardCategory.action,
      subtype: 'quick',
      effectKey: 'quick-effect',
      rank: null,
      atk: null,
      def: null,
      zoneIndex: 0,
    );
    final engine = DuelEngine(
      chainEffects: const {'quick-effect': FakeEffect()},
    );
    final ai = BeginnerAi(engine: engine, random: SequenceRandom());
    final state = duel(
      ai: field(
        participant: DuelParticipant.ai,
        actionTraps: [quick, null, null, null, null],
      ),
      chain: ChainState(
        window: ResponseWindowType.summon,
        priorityPlayer: DuelParticipant.ai,
      ),
    );
    final candidate = ChainLink(
      linkId: 'ai-quick',
      effectKey: 'quick-effect',
      activatingPlayer: DuelParticipant.ai,
      speed: ChainSpeed.speed2,
      sourceCardInstanceId: 'quick',
      sourceCardCode: 'AI-Q01',
    );

    final decision = ai.handlePriority(
      state: state,
      availableActivations: [candidate],
    );

    expect(decision.passed, isFalse);
    expect(decision.activatedLink?.linkId, 'ai-quick');
    expect(decision.state.chain.links.single.linkId, 'ai-quick');
  });

  test('défausse aléatoirement jusqu’à six cartes en fin de tour', () {
    final hand = List.generate(
      8,
      (index) => card('AI-H$index', id: 'hand-$index'),
    );
    final engine = DuelEngine();
    final ai = BeginnerAi(
      engine: engine,
      random: SequenceRandom([0, 1, 2, 3, 4, 5, 6, 7]),
    );

    final result = ai.discardExcessHand(
      duel(
        phase: DuelPhase.end,
        ai: field(participant: DuelParticipant.ai, hand: hand),
      ),
    );

    expect(result, isNotNull);
    expect(result!.succeeded, isTrue);
    expect(result.state.aiField.hand, hasLength(6));
    expect(result.state.aiField.graveyard, hasLength(2));
  });

  test('simule un tour complet de l’IA débutante sans erreur', () {
    final monster = card('AI-001', id: 'monster', atk: 1800);
    final trap = card(
      'AI-T01',
      id: 'trap',
      category: CardCategory.trap,
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
      atk: 800,
      faceUp: true,
      position: BattlePosition.attack,
      zoneIndex: 0,
    );
    final engine = DuelEngine();
    final ai = BeginnerAi(engine: engine, random: SequenceRandom([0]));
    final initial = duel(
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
    );

    final result = ai.playUnopposedTurn(initial);

    expect(result.state.isFinished, isFalse);
    expect(result.state.activePlayer, DuelParticipant.player);
    expect(result.state.turnNumber, 3);
    expect(result.state.currentPhase, DuelPhase.draw);
    expect(result.actions, contains('normal_monster_play'));
    expect(result.actions, contains('set_action_or_trap'));
    expect(result.actions, contains('attack'));
  });
}
