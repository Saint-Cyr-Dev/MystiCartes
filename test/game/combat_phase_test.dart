import 'package:mysticartes/game/battle_state.dart';
import 'package:mysticartes/game/card.dart';
import 'package:mysticartes/game/duel_engine.dart';
import 'package:mysticartes/game/duel_types.dart';
import 'package:mysticartes/game/player.dart';
import 'package:test/test.dart';

final engine = DuelEngine();

CardInstance combatCard(
  String instanceId, {
  required DuelParticipant owner,
  required int atk,
  required int def,
  required BattlePosition position,
  bool faceUp = true,
  int? zoneIndex,
  int? summonedTurn,
  bool attackedThisTurn = false,
}) {
  return CardInstance(
    instanceId: instanceId,
    cardId: 'catalog-$instanceId',
    cardCode: instanceId.toUpperCase(),
    cardRevision: 1,
    category: CardCategory.character,
    rank: 4,
    atk: atk,
    def: def,
    owner: owner,
    controller: owner,
    faceUp: faceUp,
    position: position,
    zoneIndex: zoneIndex,
    summonedTurn: summonedTurn,
    attackedThisTurn: attackedThisTurn,
  );
}

PlayerFieldState combatField({
  required DuelParticipant participant,
  List<FieldCardInstance?>? characterZones,
  List<CardInstance> graveyard = const [],
}) {
  return PlayerFieldState(
    participant: participant,
    characterZones: characterZones ?? const [null, null, null, null, null],
    actionTrapZones: const [null, null, null, null, null],
    terrainZone: null,
    deck: const [],
    hand: const [],
    graveyard: graveyard,
    banished: const [],
    mythicReserve: const [],
  );
}

DuelState combatDuel({
  required List<FieldCardInstance?> playerCharacters,
  required List<FieldCardInstance?> aiCharacters,
  int playerLifePoints = 8000,
  int aiLifePoints = 8000,
  int turnNumber = 2,
  DuelParticipant startingPlayer = DuelParticipant.player,
}) {
  return DuelState(
    playerField: combatField(
      participant: DuelParticipant.player,
      characterZones: playerCharacters,
    ),
    aiField: combatField(
      participant: DuelParticipant.ai,
      characterZones: aiCharacters,
    ),
    playerLifePoints: playerLifePoints,
    aiLifePoints: aiLifePoints,
    turnNumber: turnNumber,
    startingPlayer: startingPlayer,
    activePlayer: DuelParticipant.player,
    currentPhase: DuelPhase.battle,
  );
}

CombatResolutionResult resolveCombat(
  DuelState state, {
  required String attackerId,
  String? targetId,
}) {
  final declaration = engine.declareAttack(
    state: state,
    participant: DuelParticipant.player,
    attackerInstanceId: attackerId,
    targetInstanceId: targetId,
  );
  expect(declaration.succeeded, isTrue);
  final firstPass = engine.passPriority(
    state: declaration.state,
    participant: DuelParticipant.ai,
  );
  final secondPass = engine.passPriority(
    state: firstPass.state,
    participant: DuelParticipant.player,
  );
  return engine.resolveAttack(
    state: secondPass.state,
    declaration: declaration.declaration!,
  );
}

void main() {
  test('une attaque directe inflige l’ATK et consomme l’attaque', () {
    final attacker = combatCard(
      'attacker',
      owner: DuelParticipant.player,
      atk: 2400,
      def: 1800,
      position: BattlePosition.attack,
      zoneIndex: 0,
      summonedTurn: 2,
    );
    final state = combatDuel(
      playerCharacters: [attacker, null, null, null, null],
      aiCharacters: const [null, null, null, null, null],
    );

    final result = resolveCombat(state, attackerId: 'attacker');

    expect(result.status, CombatResolutionStatus.resolved);
    expect(result.state.aiLifePoints, 5600);
    expect(result.damageByParticipant[DuelParticipant.ai], 2400);
    expect(
      result.state.playerField.characterZones.first!.attackedThisTurn,
      isTrue,
    );
  });

  test('ATK supérieure à ATK détruit la cible et inflige la différence', () {
    final attacker = combatCard(
      'attacker',
      owner: DuelParticipant.player,
      atk: 2500,
      def: 1800,
      position: BattlePosition.attack,
      zoneIndex: 0,
    );
    final target = combatCard(
      'target',
      owner: DuelParticipant.ai,
      atk: 1800,
      def: 1600,
      position: BattlePosition.attack,
      zoneIndex: 0,
    );

    final result = resolveCombat(
      combatDuel(
        playerCharacters: [attacker, null, null, null, null],
        aiCharacters: [target, null, null, null, null],
      ),
      attackerId: 'attacker',
      targetId: 'target',
    );

    expect(result.state.aiLifePoints, 7300);
    expect(result.state.aiField.characterZones.first, isNull);
    expect(result.state.aiField.graveyard.single.instanceId, 'target');
    expect(result.destroyedCardInstanceIds, ['target']);
  });

  test('ATK inférieure à ATK détruit l’attaquant et lui inflige la différence',
      () {
    final attacker = combatCard(
      'attacker',
      owner: DuelParticipant.player,
      atk: 1500,
      def: 1200,
      position: BattlePosition.attack,
      zoneIndex: 0,
    );
    final target = combatCard(
      'target',
      owner: DuelParticipant.ai,
      atk: 2200,
      def: 1700,
      position: BattlePosition.attack,
      zoneIndex: 0,
    );

    final result = resolveCombat(
      combatDuel(
        playerCharacters: [attacker, null, null, null, null],
        aiCharacters: [target, null, null, null, null],
      ),
      attackerId: 'attacker',
      targetId: 'target',
    );

    expect(result.state.playerLifePoints, 7300);
    expect(result.state.playerField.characterZones.first, isNull);
    expect(result.state.playerField.graveyard.single.instanceId, 'attacker');
    expect(result.state.aiField.characterZones.first, same(target));
  });

  test('ATK égales détruisent les deux Personnages sans dégâts', () {
    final attacker = combatCard(
      'attacker',
      owner: DuelParticipant.player,
      atk: 2000,
      def: 1500,
      position: BattlePosition.attack,
      zoneIndex: 0,
    );
    final target = combatCard(
      'target',
      owner: DuelParticipant.ai,
      atk: 2000,
      def: 1900,
      position: BattlePosition.attack,
      zoneIndex: 0,
    );

    final result = resolveCombat(
      combatDuel(
        playerCharacters: [attacker, null, null, null, null],
        aiCharacters: [target, null, null, null, null],
      ),
      attackerId: 'attacker',
      targetId: 'target',
    );

    expect(result.state.playerLifePoints, 8000);
    expect(result.state.aiLifePoints, 8000);
    expect(result.state.playerField.characterZones.first, isNull);
    expect(result.state.aiField.characterZones.first, isNull);
    expect(
        result.destroyedCardInstanceIds, containsAll(['attacker', 'target']));
  });

  test('ATK supérieure à DEF détruit le défenseur sans dégâts aux PV', () {
    final attacker = combatCard(
      'attacker',
      owner: DuelParticipant.player,
      atk: 2200,
      def: 1600,
      position: BattlePosition.attack,
      zoneIndex: 0,
    );
    final target = combatCard(
      'target',
      owner: DuelParticipant.ai,
      atk: 1000,
      def: 1800,
      position: BattlePosition.defense,
      zoneIndex: 0,
    );

    final result = resolveCombat(
      combatDuel(
        playerCharacters: [attacker, null, null, null, null],
        aiCharacters: [target, null, null, null, null],
      ),
      attackerId: 'attacker',
      targetId: 'target',
    );

    expect(result.state.aiField.characterZones.first, isNull);
    expect(result.state.aiLifePoints, 8000);
    expect(result.damageByParticipant, isEmpty);
  });

  test('ATK inférieure à DEF ne détruit rien et blesse l’attaquant', () {
    final attacker = combatCard(
      'attacker',
      owner: DuelParticipant.player,
      atk: 1500,
      def: 1400,
      position: BattlePosition.attack,
      zoneIndex: 0,
    );
    final target = combatCard(
      'target',
      owner: DuelParticipant.ai,
      atk: 900,
      def: 2100,
      position: BattlePosition.defense,
      zoneIndex: 0,
    );

    final result = resolveCombat(
      combatDuel(
        playerCharacters: [attacker, null, null, null, null],
        aiCharacters: [target, null, null, null, null],
      ),
      attackerId: 'attacker',
      targetId: 'target',
    );

    expect(result.state.playerLifePoints, 7400);
    expect(result.state.playerField.characterZones.first, isNotNull);
    expect(result.state.aiField.characterZones.first, isNotNull);
    expect(result.destroyedCardInstanceIds, isEmpty);
  });

  test('ATK égale à DEF ne détruit rien et ne cause aucun dégât', () {
    final attacker = combatCard(
      'attacker',
      owner: DuelParticipant.player,
      atk: 1900,
      def: 1400,
      position: BattlePosition.attack,
      zoneIndex: 0,
    );
    final target = combatCard(
      'target',
      owner: DuelParticipant.ai,
      atk: 1200,
      def: 1900,
      position: BattlePosition.defense,
      zoneIndex: 0,
    );

    final result = resolveCombat(
      combatDuel(
        playerCharacters: [attacker, null, null, null, null],
        aiCharacters: [target, null, null, null, null],
      ),
      attackerId: 'attacker',
      targetId: 'target',
    );

    expect(result.state.playerLifePoints, 8000);
    expect(result.state.aiLifePoints, 8000);
    expect(result.destroyedCardInstanceIds, isEmpty);
  });

  test('un défenseur face cachée est retourné avant le calcul', () {
    final attacker = combatCard(
      'attacker',
      owner: DuelParticipant.player,
      atk: 1500,
      def: 1300,
      position: BattlePosition.attack,
      zoneIndex: 0,
    );
    final hiddenTarget = combatCard(
      'hidden-target',
      owner: DuelParticipant.ai,
      atk: 800,
      def: 2000,
      position: BattlePosition.defense,
      faceUp: false,
      zoneIndex: 0,
    );

    final result = resolveCombat(
      combatDuel(
        playerCharacters: [attacker, null, null, null, null],
        aiCharacters: [hiddenTarget, null, null, null, null],
      ),
      attackerId: 'attacker',
      targetId: 'hidden-target',
    );

    expect(result.targetFlippedFaceUp, isTrue);
    expect(result.state.aiField.characterZones.first!.faceUp, isTrue);
    expect(result.state.playerLifePoints, 7500);
  });

  test('le joueur initial ne peut pas attaquer pendant le premier tour', () {
    final attacker = combatCard(
      'attacker',
      owner: DuelParticipant.player,
      atk: 1800,
      def: 1500,
      position: BattlePosition.attack,
      zoneIndex: 0,
      summonedTurn: 1,
    );
    final state = combatDuel(
      playerCharacters: [attacker, null, null, null, null],
      aiCharacters: const [null, null, null, null, null],
      turnNumber: 1,
    );

    final declaration = engine.declareAttack(
      state: state,
      participant: DuelParticipant.player,
      attackerInstanceId: 'attacker',
    );

    expect(declaration.succeeded, isFalse);
    expect(
      declaration.failure,
      DuelActionFailure.attackForbiddenOnOpeningTurn,
    );
  });

  test('un Personnage ne peut pas effectuer deux attaques dans le même tour',
      () {
    final attacker = combatCard(
      'attacker',
      owner: DuelParticipant.player,
      atk: 1200,
      def: 1000,
      position: BattlePosition.attack,
      zoneIndex: 0,
    );
    final state = combatDuel(
      playerCharacters: [attacker, null, null, null, null],
      aiCharacters: const [null, null, null, null, null],
    );
    final first = resolveCombat(state, attackerId: 'attacker');

    final secondDeclaration = engine.declareAttack(
      state: first.state,
      participant: DuelParticipant.player,
      attackerInstanceId: 'attacker',
    );

    expect(secondDeclaration.succeeded, isFalse);
    expect(
      secondDeclaration.failure,
      DuelActionFailure.attackerAlreadyAttacked,
    );
  });

  test('les dégâts qui réduisent les PV à zéro terminent immédiatement le duel',
      () {
    final attacker = combatCard(
      'attacker',
      owner: DuelParticipant.player,
      atk: 2500,
      def: 1800,
      position: BattlePosition.attack,
      zoneIndex: 0,
    );
    final state = combatDuel(
      playerCharacters: [attacker, null, null, null, null],
      aiCharacters: const [null, null, null, null, null],
      aiLifePoints: 2500,
    );

    final result = resolveCombat(state, attackerId: 'attacker');

    expect(result.state.aiLifePoints, 0);
    expect(result.state.isFinished, isTrue);
    expect(result.state.winner, DuelParticipant.player);
    expect(result.state.endReason, DuelEndReason.lifePointsDepleted);
  });

  test('une cible disparue interrompt le calcul sans attaque directe', () {
    final attacker = combatCard(
      'attacker',
      owner: DuelParticipant.player,
      atk: 2400,
      def: 1700,
      position: BattlePosition.attack,
      zoneIndex: 0,
    );
    final target = combatCard(
      'target',
      owner: DuelParticipant.ai,
      atk: 1000,
      def: 1000,
      position: BattlePosition.attack,
      zoneIndex: 0,
    );
    final state = combatDuel(
      playerCharacters: [attacker, null, null, null, null],
      aiCharacters: [target, null, null, null, null],
    );
    final declaration = engine.declareAttack(
      state: state,
      participant: DuelParticipant.player,
      attackerInstanceId: 'attacker',
      targetInstanceId: 'target',
    );
    final stateAfterInterruption = declaration.state.copyWith(
      aiField: declaration.state.aiField.copyWith(
        characterZones: const [null, null, null, null, null],
        graveyard: [target.copyWith(position: null, zoneIndex: null)],
      ),
    );
    final firstPass = engine.passPriority(
      state: stateAfterInterruption,
      participant: DuelParticipant.ai,
    );
    final secondPass = engine.passPriority(
      state: firstPass.state,
      participant: DuelParticipant.player,
    );

    final result = engine.resolveAttack(
      state: secondPass.state,
      declaration: declaration.declaration!,
    );

    expect(result.status, CombatResolutionStatus.interruptedTargetMissing);
    expect(result.state.aiLifePoints, 8000);
    expect(
      result.state.playerField.characterZones.first!.attackedThisTurn,
      isTrue,
    );
  });

  test('un Personnage déjà détruit ne peut plus être ciblé', () {
    final firstAttacker = combatCard(
      'attacker-1',
      owner: DuelParticipant.player,
      atk: 2200,
      def: 1700,
      position: BattlePosition.attack,
      zoneIndex: 0,
    );
    final secondAttacker = combatCard(
      'attacker-2',
      owner: DuelParticipant.player,
      atk: 1800,
      def: 1500,
      position: BattlePosition.attack,
      zoneIndex: 1,
    );
    final target = combatCard(
      'target',
      owner: DuelParticipant.ai,
      atk: 1000,
      def: 900,
      position: BattlePosition.attack,
      zoneIndex: 0,
    );
    final firstResult = resolveCombat(
      combatDuel(
        playerCharacters: [firstAttacker, secondAttacker, null, null, null],
        aiCharacters: [target, null, null, null, null],
      ),
      attackerId: 'attacker-1',
      targetId: 'target',
    );

    final secondDeclaration = engine.declareAttack(
      state: firstResult.state,
      participant: DuelParticipant.player,
      attackerInstanceId: 'attacker-2',
      targetInstanceId: 'target',
    );

    expect(secondDeclaration.succeeded, isFalse);
    expect(secondDeclaration.failure, DuelActionFailure.targetNotFound);
  });
}
