import 'package:mysticartes/game/battle_state.dart';
import 'package:mysticartes/game/card.dart';
import 'package:mysticartes/game/duel_engine.dart';
import 'package:mysticartes/game/duel_types.dart';
import 'package:mysticartes/game/player.dart';
import 'package:test/test.dart';

typedef StateCallback = DuelState Function(DuelState state, ChainLink link);
typedef LegalityCallback = bool Function(DuelState state, ChainLink link);

final class MockChainEffect extends ChainEffectDefinition {
  MockChainEffect({
    required this.onResolve,
    this.onPayCost,
    this.onTargetLegal,
    this.onCanActivate,
  });

  final StateCallback onResolve;
  final StateCallback? onPayCost;
  final LegalityCallback? onTargetLegal;
  final LegalityCallback? onCanActivate;

  @override
  bool canActivate(DuelState state, ChainLink link) {
    return onCanActivate?.call(state, link) ?? true;
  }

  @override
  DuelState payCost(DuelState state, ChainLink link) {
    return onPayCost?.call(state, link) ?? state;
  }

  @override
  bool isTargetLegal(DuelState state, ChainLink link) {
    return onTargetLegal?.call(state, link) ?? link.target == null;
  }

  @override
  DuelState resolve(DuelState state, ChainLink link) {
    return onResolve(state, link);
  }
}

DuelState chainDuel({
  int playerLifePoints = 8000,
  int aiLifePoints = 8000,
  PlayerFieldState? aiField,
}) {
  return DuelState(
    playerField: PlayerFieldState.empty(
      participant: DuelParticipant.player,
    ),
    aiField: aiField ??
        PlayerFieldState.empty(
          participant: DuelParticipant.ai,
        ),
    playerLifePoints: playerLifePoints,
    aiLifePoints: aiLifePoints,
    turnNumber: 2,
    activePlayer: DuelParticipant.player,
    currentPhase: DuelPhase.main1,
  );
}

ChainLink link({
  required String id,
  required String effectKey,
  required DuelParticipant player,
  required ChainSpeed speed,
  ChainTarget? target,
}) {
  return ChainLink(
    linkId: id,
    effectKey: effectKey,
    activatingPlayer: player,
    speed: speed,
    target: target,
  );
}

PriorityPassResult resolveWithTwoPasses(
  DuelEngine engine,
  DuelState state, {
  required DuelParticipant firstPassPlayer,
}) {
  final firstPass = engine.passPriority(
    state: state,
    participant: firstPassPlayer,
  );
  expect(firstPass.succeeded, isTrue);
  expect(firstPass.resolutionTriggered, isFalse);
  return engine.passPriority(
    state: firstPass.state,
    participant: firstPassPlayer == DuelParticipant.player
        ? DuelParticipant.ai
        : DuelParticipant.player,
  );
}

bool containsTarget(DuelState state, String instanceId) {
  return [...state.playerField.characterZones, ...state.aiField.characterZones]
      .whereType<FieldCardInstance>()
      .any((card) => card.instanceId == instanceId);
}

void main() {
  test('une Chaîne à deux éléments se résout en ordre inverse', () {
    final resolutionLog = <String>[];
    final engine = DuelEngine(
      chainEffects: {
        'first': MockChainEffect(
          onResolve: (state, link) {
            resolutionLog.add(link.effectKey);
            return state;
          },
        ),
        'second': MockChainEffect(
          onResolve: (state, link) {
            resolutionLog.add(link.effectKey);
            return state;
          },
        ),
      },
    );
    final first = engine.activateChainEffect(
      state: chainDuel(),
      link: link(
        id: 'link-1',
        effectKey: 'first',
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
      ),
    );
    final second = engine.activateChainEffect(
      state: first.state,
      link: link(
        id: 'link-2',
        effectKey: 'second',
        player: DuelParticipant.ai,
        speed: ChainSpeed.speed2,
      ),
    );

    expect(first.succeeded, isTrue);
    expect(first.state.chain.priorityPlayer, DuelParticipant.ai);
    expect(second.succeeded, isTrue);
    expect(second.state.chain.priorityPlayer, DuelParticipant.player);

    final resolution = resolveWithTwoPasses(
      engine,
      second.state,
      firstPassPlayer: DuelParticipant.player,
    );

    expect(resolution.succeeded, isTrue);
    expect(resolution.resolutionTriggered, isTrue);
    expect(resolution.resolvedLinkIds, ['link-2', 'link-1']);
    expect(resolutionLog, ['second', 'first']);
    expect(resolution.state.chain.isOpen, isFalse);
  });

  test('une Vitesse 1 est refusée en réponse à une Chaîne existante', () {
    final effect = MockChainEffect(onResolve: (state, link) => state);
    final engine = DuelEngine(chainEffects: {'mock': effect});
    final first = engine.activateChainEffect(
      state: chainDuel(),
      link: link(
        id: 'link-1',
        effectKey: 'mock',
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
      ),
    );

    final response = engine.activateChainEffect(
      state: first.state,
      link: link(
        id: 'link-2',
        effectKey: 'mock',
        player: DuelParticipant.ai,
        speed: ChainSpeed.speed1,
      ),
    );

    expect(response.succeeded, isFalse);
    expect(response.failure, DuelActionFailure.illegalChainSpeed);
    expect(response.state.chain.links, hasLength(1));
  });

  test('une Vitesse 2 peut répondre aux Vitesses 1 puis 2', () {
    final effect = MockChainEffect(onResolve: (state, link) => state);
    final engine = DuelEngine(chainEffects: {'mock': effect});
    final first = engine.activateChainEffect(
      state: chainDuel(),
      link: link(
        id: 'link-1',
        effectKey: 'mock',
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
      ),
    );
    final responseToSpeed1 = engine.activateChainEffect(
      state: first.state,
      link: link(
        id: 'link-2',
        effectKey: 'mock',
        player: DuelParticipant.ai,
        speed: ChainSpeed.speed2,
      ),
    );
    final responseToSpeed2 = engine.activateChainEffect(
      state: responseToSpeed1.state,
      link: link(
        id: 'link-3',
        effectKey: 'mock',
        player: DuelParticipant.player,
        speed: ChainSpeed.speed2,
      ),
    );

    expect(responseToSpeed1.succeeded, isTrue);
    expect(responseToSpeed2.succeeded, isTrue);
    expect(responseToSpeed2.state.chain.links, hasLength(3));
  });

  test('seule une autre Vitesse 3 peut répondre à une Vitesse 3', () {
    final effect = MockChainEffect(onResolve: (state, link) => state);
    final engine = DuelEngine(chainEffects: {'mock': effect});
    final first = engine.activateChainEffect(
      state: chainDuel(),
      link: link(
        id: 'link-1',
        effectKey: 'mock',
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
      ),
    );
    final speed3 = engine.activateChainEffect(
      state: first.state,
      link: link(
        id: 'link-2',
        effectKey: 'mock',
        player: DuelParticipant.ai,
        speed: ChainSpeed.speed3,
      ),
    );
    final rejectedSpeed2 = engine.activateChainEffect(
      state: speed3.state,
      link: link(
        id: 'link-3',
        effectKey: 'mock',
        player: DuelParticipant.player,
        speed: ChainSpeed.speed2,
      ),
    );
    final acceptedSpeed3 = engine.activateChainEffect(
      state: rejectedSpeed2.state,
      link: link(
        id: 'link-4',
        effectKey: 'mock',
        player: DuelParticipant.player,
        speed: ChainSpeed.speed3,
      ),
    );

    expect(speed3.succeeded, isTrue);
    expect(rejectedSpeed2.succeeded, isFalse);
    expect(rejectedSpeed2.failure, DuelActionFailure.illegalChainSpeed);
    expect(acceptedSpeed3.succeeded, isTrue);
  });

  test('une victoire pendant la résolution interrompt les maillons restants',
      () {
    final resolutionLog = <String>[];
    final engine = DuelEngine(
      chainEffects: {
        'remaining': MockChainEffect(
          onResolve: (state, link) {
            resolutionLog.add(link.effectKey);
            return state.copyWith(aiLifePoints: 7000);
          },
        ),
        'lethal': MockChainEffect(
          onResolve: (state, link) {
            resolutionLog.add(link.effectKey);
            return state.copyWith(playerLifePoints: 0);
          },
        ),
      },
    );
    final first = engine.activateChainEffect(
      state: chainDuel(),
      link: link(
        id: 'link-1',
        effectKey: 'remaining',
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
      ),
    );
    final lethalResponse = engine.activateChainEffect(
      state: first.state,
      link: link(
        id: 'link-2',
        effectKey: 'lethal',
        player: DuelParticipant.ai,
        speed: ChainSpeed.speed2,
      ),
    );

    final resolution = resolveWithTwoPasses(
      engine,
      lethalResponse.state,
      firstPassPlayer: DuelParticipant.player,
    );

    expect(resolution.interruptedByVictory, isTrue);
    expect(resolution.resolvedLinkIds, ['link-2']);
    expect(resolutionLog, ['lethal']);
    expect(resolution.state.winner, DuelParticipant.ai);
    expect(resolution.state.playerLifePoints, 0);
    expect(resolution.state.chain.isOpen, isFalse);
  });

  test(
      'une cible devenue illégale fait échouer l’effet sans rembourser le coût',
      () {
    final target = CardInstance(
      instanceId: 'target',
      cardId: 'catalog-target',
      cardCode: 'TARGET',
      cardRevision: 1,
      category: CardCategory.character,
      rank: 3,
      atk: 1200,
      def: 1000,
      owner: DuelParticipant.ai,
      controller: DuelParticipant.ai,
      faceUp: true,
      position: BattlePosition.attack,
      zoneIndex: 0,
    );
    final aiField = PlayerFieldState(
      participant: DuelParticipant.ai,
      characterZones: [target, null, null, null, null],
      actionTrapZones: const [null, null, null, null, null],
      terrainZone: null,
      deck: const [],
      hand: const [],
      graveyard: const [],
      banished: const [],
      mythicReserve: const [],
    );
    final resolutionLog = <String>[];
    final targetedEffect = MockChainEffect(
      onTargetLegal: (state, link) =>
          containsTarget(state, link.target!.cardInstanceId),
      onPayCost: (state, link) => state.copyWith(
        playerLifePoints: state.playerLifePoints - 300,
      ),
      onResolve: (state, link) {
        resolutionLog.add('targeted');
        return state;
      },
    );
    final removeTarget = MockChainEffect(
      onResolve: (state, link) {
        resolutionLog.add('remove');
        final zones = List<FieldCardInstance?>.from(
          state.aiField.characterZones,
        )..[0] = null;
        return state.copyWith(
          aiField: state.aiField.copyWith(characterZones: zones),
        );
      },
    );
    final engine = DuelEngine(
      chainEffects: {
        'targeted': targetedEffect,
        'remove': removeTarget,
      },
    );
    final targetedActivation = engine.activateChainEffect(
      state: chainDuel(aiField: aiField),
      link: link(
        id: 'link-1',
        effectKey: 'targeted',
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        target: ChainTarget(cardInstanceId: 'target'),
      ),
    );
    final removalResponse = engine.activateChainEffect(
      state: targetedActivation.state,
      link: link(
        id: 'link-2',
        effectKey: 'remove',
        player: DuelParticipant.ai,
        speed: ChainSpeed.speed2,
      ),
    );

    final resolution = resolveWithTwoPasses(
      engine,
      removalResponse.state,
      firstPassPlayer: DuelParticipant.player,
    );

    expect(targetedActivation.succeeded, isTrue);
    expect(targetedActivation.state.playerLifePoints, 7700);
    expect(resolution.resolvedLinkIds, ['link-2']);
    expect(resolution.fizzledLinkIds, ['link-1']);
    expect(resolutionLog, ['remove']);
    expect(resolution.state.playerLifePoints, 7700);
    expect(containsTarget(resolution.state, 'target'), isFalse);
  });

  test('une cible déjà illégale est refusée avant le paiement du coût', () {
    final targetedEffect = MockChainEffect(
      onTargetLegal: (state, link) =>
          containsTarget(state, link.target!.cardInstanceId),
      onPayCost: (state, link) => state.copyWith(
        playerLifePoints: state.playerLifePoints - 300,
      ),
      onResolve: (state, link) => state,
    );
    final engine = DuelEngine(chainEffects: {'targeted': targetedEffect});

    final activation = engine.activateChainEffect(
      state: chainDuel(),
      link: link(
        id: 'link-invalid-target',
        effectKey: 'targeted',
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
        target: ChainTarget(cardInstanceId: 'missing'),
      ),
    );

    expect(activation.succeeded, isFalse);
    expect(activation.failure, DuelActionFailure.illegalChainTarget);
    expect(activation.state.playerLifePoints, 8000);
    expect(activation.state.chain.isOpen, isFalse);
  });

  test('aucune activation ne peut être ajoutée pendant la résolution', () {
    DuelActionFailure? nestedFailure;
    late DuelEngine engine;
    final nestedEffect = MockChainEffect(onResolve: (state, link) => state);
    final reentrantEffect = MockChainEffect(
      onResolve: (state, resolvingLink) {
        final nestedActivation = engine.activateChainEffect(
          state: state,
          link: link(
            id: 'nested-link',
            effectKey: 'nested',
            player: DuelParticipant.ai,
            speed: ChainSpeed.speed2,
          ),
        );
        nestedFailure = nestedActivation.failure;
        return state;
      },
    );
    engine = DuelEngine(
      chainEffects: {
        'reentrant': reentrantEffect,
        'nested': nestedEffect,
      },
    );
    final activation = engine.activateChainEffect(
      state: chainDuel(),
      link: link(
        id: 'main-link',
        effectKey: 'reentrant',
        player: DuelParticipant.player,
        speed: ChainSpeed.speed1,
      ),
    );

    final resolution = resolveWithTwoPasses(
      engine,
      activation.state,
      firstPassPlayer: DuelParticipant.ai,
    );

    expect(resolution.succeeded, isTrue);
    expect(nestedFailure, DuelActionFailure.chainIsResolving);
    expect(resolution.resolvedLinkIds, ['main-link']);
  });
}
