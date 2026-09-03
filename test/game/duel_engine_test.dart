import 'package:mysticartes/game/battle_state.dart';
import 'package:mysticartes/game/card.dart';
import 'package:mysticartes/game/duel_engine.dart';
import 'package:mysticartes/game/duel_types.dart';
import 'package:mysticartes/game/player.dart';
import 'package:test/test.dart';

final engine = DuelEngine();

CardInstance card(
  String instanceId, {
  int? rank = 1,
  CardCategory category = CardCategory.character,
  DuelParticipant owner = DuelParticipant.player,
  int? atk = 1000,
  int? def = 1000,
  bool faceUp = false,
  BattlePosition? position,
  int? zoneIndex,
  bool attackedThisTurn = false,
  bool positionChangedThisTurn = false,
}) {
  return CardInstance(
    instanceId: instanceId,
    cardId: 'catalog-$instanceId',
    cardCode: instanceId.toUpperCase(),
    cardRevision: 1,
    category: category,
    rank: rank,
    atk: atk,
    def: def,
    owner: owner,
    controller: owner,
    faceUp: faceUp,
    position: position,
    zoneIndex: zoneIndex,
    attackedThisTurn: attackedThisTurn,
    positionChangedThisTurn: positionChangedThisTurn,
  );
}

PlayerFieldState field({
  required DuelParticipant participant,
  List<FieldCardInstance?>? characterZones,
  List<CardInstance?>? actionTrapZones,
  List<CardInstance> deck = const [],
  List<CardInstance> hand = const [],
  List<CardInstance> graveyard = const [],
}) {
  return PlayerFieldState(
    participant: participant,
    characterZones: characterZones ??
        List<FieldCardInstance?>.filled(
          PlayerFieldState.characterZoneCount,
          null,
        ),
    actionTrapZones: actionTrapZones ??
        List<CardInstance?>.filled(
          PlayerFieldState.actionTrapZoneCount,
          null,
        ),
    terrainZone: null,
    deck: deck,
    hand: hand,
    graveyard: graveyard,
    banished: const [],
    mythicReserve: const [],
  );
}

DuelState duel({
  PlayerFieldState? playerField,
  PlayerFieldState? aiField,
  int turnNumber = 1,
  DuelParticipant startingPlayer = DuelParticipant.player,
  DuelParticipant activePlayer = DuelParticipant.player,
  DuelPhase currentPhase = DuelPhase.main1,
  bool drawPhaseResolved = false,
  Map<DuelParticipant, bool>? normalSummonUsed,
}) {
  return DuelState(
    playerField: playerField ?? field(participant: DuelParticipant.player),
    aiField: aiField ?? field(participant: DuelParticipant.ai),
    turnNumber: turnNumber,
    startingPlayer: startingPlayer,
    activePlayer: activePlayer,
    currentPhase: currentPhase,
    drawPhaseResolved: drawPhaseResolved,
    normalSummonUsed: normalSummonUsed,
  );
}

void main() {
  group('Invocation normale et pose', () {
    test('un Personnage de rang 1 à 4 ne demande aucun sacrifice', () {
      final state = duel(
        playerField: field(
          participant: DuelParticipant.player,
          hand: [card('bab-001', rank: 4)],
        ),
      );

      final result = engine.normalSummon(
        state: state,
        participant: DuelParticipant.player,
        cardInstanceId: 'bab-001',
      );

      expect(result.succeeded, isTrue);
      final summoned = result.state.playerField.characterZones.first;
      expect(summoned, isA<CardInstance>());
      expect(summoned!.faceUp, isTrue);
      expect(summoned.position, BattlePosition.attack);
      expect(summoned.zoneIndex, 0);
      expect(summoned.summonedTurn, 1);
      expect(result.state.playerField.hand, isEmpty);
      expect(
        result.state.normalSummonUsed[DuelParticipant.player],
        isTrue,
      );
    });

    test('la pose normale place le Personnage face cachée en Défense', () {
      final state = duel(
        playerField: field(
          participant: DuelParticipant.player,
          hand: [card('mas-001', rank: 2)],
        ),
      );

      final result = engine.normalSet(
        state: state,
        participant: DuelParticipant.player,
        cardInstanceId: 'mas-001',
        destinationZoneIndex: 3,
      );

      final summoned = result.state.playerField.characterZones[3];
      expect(result.succeeded, isTrue);
      expect(summoned!.faceUp, isFalse);
      expect(summoned.position, BattlePosition.defense);
      expect(result.state.normalSummonUsed[DuelParticipant.player], isTrue);
    });

    test('un rang 5 à 6 exige exactement un sacrifice', () {
      final tribute = card(
        'tribute-1',
        rank: 3,
        faceUp: true,
        position: BattlePosition.attack,
        zoneIndex: 0,
      );
      final state = duel(
        playerField: field(
          participant: DuelParticipant.player,
          characterZones: [tribute, null, null, null, null],
          hand: [card('roy-006', rank: 6)],
        ),
      );

      final result = engine.normalSummon(
        state: state,
        participant: DuelParticipant.player,
        cardInstanceId: 'roy-006',
        sacrificeInstanceIds: const ['tribute-1'],
      );

      expect(result.succeeded, isTrue);
      expect(
        result.state.playerField.characterZones.first!.instanceId,
        'roy-006',
      );
      expect(
        result.state.playerField.graveyard.single.instanceId,
        'tribute-1',
      );
    });

    test('un rang 7 à 8 exige exactement deux sacrifices', () {
      final tribute1 = card(
        'tribute-1',
        rank: 2,
        faceUp: true,
        position: BattlePosition.attack,
        zoneIndex: 0,
      );
      final tribute2 = card(
        'tribute-2',
        rank: 4,
        faceUp: true,
        position: BattlePosition.defense,
        zoneIndex: 1,
      );
      final state = duel(
        playerField: field(
          participant: DuelParticipant.player,
          characterZones: [tribute1, tribute2, null, null, null],
          hand: [card('roy-007', rank: 8)],
        ),
      );

      final result = engine.normalSummon(
        state: state,
        participant: DuelParticipant.player,
        cardInstanceId: 'roy-007',
        sacrificeInstanceIds: const ['tribute-1', 'tribute-2'],
        destinationZoneIndex: 1,
      );

      expect(result.succeeded, isTrue);
      expect(result.state.playerField.graveyard, hasLength(2));
      expect(
        result.state.playerField.characterZones[1]!.instanceId,
        'roy-007',
      );
      expect(result.state.playerField.characterZones[0], isNull);
    });

    test('une Mythique de rang 9 à 10 refuse l’invocation normale', () {
      final state = duel(
        playerField: field(
          participant: DuelParticipant.player,
          hand: [
            card(
              'bab-015',
              rank: 9,
              category: CardCategory.mythic,
            ),
          ],
        ),
      );

      final result = engine.normalSummon(
        state: state,
        participant: DuelParticipant.player,
        cardInstanceId: 'bab-015',
      );

      expect(result.succeeded, isFalse);
      expect(
        result.failure,
        DuelActionFailure.mythicNormalSummonForbidden,
      );
      expect(result.state, same(state));
      expect(state.normalSummonUsed[DuelParticipant.player], isFalse);
    });

    test('une invocation sans sacrifice échoue si les cinq zones sont pleines',
        () {
      final occupiedZones = List<FieldCardInstance?>.generate(
        5,
        (index) => card(
          'field-$index',
          rank: 1,
          faceUp: true,
          position: BattlePosition.attack,
          zoneIndex: index,
        ),
      );
      final state = duel(
        playerField: field(
          participant: DuelParticipant.player,
          characterZones: occupiedZones,
          hand: [card('new-character', rank: 4)],
        ),
      );

      final result = engine.normalSummon(
        state: state,
        participant: DuelParticipant.player,
        cardInstanceId: 'new-character',
      );

      expect(result.succeeded, isFalse);
      expect(result.failure, DuelActionFailure.characterZoneFull);
      expect(result.state.playerField.hand, hasLength(1));
      expect(result.state.normalSummonUsed[DuelParticipant.player], isFalse);
    });

    test('poser une Action ou un Piège ne consomme pas l’invocation normale',
        () {
      final state = duel(
        playerField: field(
          participant: DuelParticipant.player,
          hand: [
            card(
              'action-1',
              rank: null,
              category: CardCategory.action,
              atk: null,
              def: null,
            ),
            card('character-1', rank: 3),
          ],
        ),
      );

      final setResult = engine.setActionOrTrap(
        state: state,
        participant: DuelParticipant.player,
        cardInstanceId: 'action-1',
      );
      final opponentPass = engine.passPriority(
        state: setResult.state,
        participant: DuelParticipant.ai,
      );
      final playerPass = engine.passPriority(
        state: opponentPass.state,
        participant: DuelParticipant.player,
      );
      final summonResult = engine.normalSummon(
        state: playerPass.state,
        participant: DuelParticipant.player,
        cardInstanceId: 'character-1',
      );

      expect(setResult.succeeded, isTrue);
      expect(
        setResult.state.normalSummonUsed[DuelParticipant.player],
        isFalse,
      );
      expect(
          setResult.state.playerField.actionTrapZones.first!.faceUp, isFalse);
      expect(summonResult.succeeded, isTrue);
      expect(
        summonResult.state.normalSummonUsed[DuelParticipant.player],
        isTrue,
      );
    });

    test('une deuxième invocation normale est refusée pendant le même tour',
        () {
      final state = duel(
        playerField: field(
          participant: DuelParticipant.player,
          hand: [card('character-1'), card('character-2')],
        ),
      );
      final first = engine.normalSummon(
        state: state,
        participant: DuelParticipant.player,
        cardInstanceId: 'character-1',
      );
      final opponentPass = engine.passPriority(
        state: first.state,
        participant: DuelParticipant.ai,
      );
      final playerPass = engine.passPriority(
        state: opponentPass.state,
        participant: DuelParticipant.player,
      );

      final second = engine.normalSummon(
        state: playerPass.state,
        participant: DuelParticipant.player,
        cardInstanceId: 'character-2',
      );

      expect(first.succeeded, isTrue);
      expect(second.succeeded, isFalse);
      expect(second.failure, DuelActionFailure.normalSummonAlreadyUsed);
      expect(second.state.playerField.hand.single.instanceId, 'character-2');
    });
  });

  group('Pioche et limite de main', () {
    test('le joueur qui commence ne pioche pas pendant son premier tour', () {
      final state = duel(
        currentPhase: DuelPhase.draw,
        playerField: field(
          participant: DuelParticipant.player,
          deck: [card('opening-top-card')],
        ),
      );

      final result = engine.resolveDrawPhase(state);

      expect(result.succeeded, isTrue);
      expect(result.state.drawPhaseResolved, isTrue);
      expect(
          result.state.playerField.deck.single.instanceId, 'opening-top-card');
      expect(result.state.playerField.hand, isEmpty);
    });

    test('la pioche prend exactement la première carte du deck', () {
      final state = duel(
        turnNumber: 2,
        activePlayer: DuelParticipant.ai,
        currentPhase: DuelPhase.draw,
        aiField: field(
          participant: DuelParticipant.ai,
          deck: [
            card('top-card', owner: DuelParticipant.ai),
            card('next-card', owner: DuelParticipant.ai),
          ],
        ),
      );

      final result = engine.resolveDrawPhase(state);

      expect(result.succeeded, isTrue);
      expect(result.state.aiField.hand.single.instanceId, 'top-card');
      expect(result.state.aiField.deck.single.instanceId, 'next-card');
      expect(result.state.drawPhaseResolved, isTrue);
      expect(
        engine.resolveDrawPhase(result.state).failure,
        DuelActionFailure.drawAlreadyResolved,
      );
    });

    test('un deck vide au moment de la pioche donne la victoire adverse', () {
      final state = duel(
        turnNumber: 2,
        activePlayer: DuelParticipant.ai,
        currentPhase: DuelPhase.draw,
        aiField: field(participant: DuelParticipant.ai),
      );

      final result = engine.resolveDrawPhase(state);

      expect(result.succeeded, isTrue);
      expect(result.state.isFinished, isTrue);
      expect(result.state.winner, DuelParticipant.player);
      expect(result.state.endReason, DuelEndReason.deckOut);
    });

    test('l’excédent au-delà de six est choisi puis envoyé au Cimetière', () {
      final hand = List<CardInstance>.generate(
        8,
        (index) => card('hand-$index'),
      );
      final state = duel(
        currentPhase: DuelPhase.end,
        playerField: field(
          participant: DuelParticipant.player,
          hand: hand,
        ),
      );

      final blockedTransition = engine.advancePhase(state);
      final requirement = blockedTransition.discardRequirement!;
      final discardResult = engine.discardForHandLimit(
        state: blockedTransition.state,
        participant: DuelParticipant.player,
        cardInstanceIds: const ['hand-1', 'hand-6'],
      );

      expect(
        blockedTransition.failure,
        DuelActionFailure.handLimitDiscardRequired,
      );
      expect(requirement.requiredCount, 2);
      expect(requirement.candidates, hasLength(8));
      expect(discardResult.succeeded, isTrue);
      expect(discardResult.state.playerField.hand, hasLength(6));
      expect(
        discardResult.state.playerField.graveyard
            .map((discarded) => discarded.instanceId),
        containsAll(['hand-1', 'hand-6']),
      );
    });
  });

  test('un tour parcourt toutes les phases puis prépare le joueur suivant', () {
    final aiCharacter = card(
      'ai-character',
      owner: DuelParticipant.ai,
      faceUp: true,
      position: BattlePosition.attack,
      zoneIndex: 0,
      attackedThisTurn: true,
      positionChangedThisTurn: true,
    );
    var state = duel(
      currentPhase: DuelPhase.draw,
      aiField: field(
        participant: DuelParticipant.ai,
        characterZones: [aiCharacter, null, null, null, null],
        deck: [card('ai-draw', owner: DuelParticipant.ai)],
      ),
      normalSummonUsed: const {
        DuelParticipant.player: true,
        DuelParticipant.ai: true,
      },
    );

    final expectedPhases = [
      DuelPhase.preparation,
      DuelPhase.main1,
      DuelPhase.battle,
      DuelPhase.main2,
      DuelPhase.end,
      DuelPhase.draw,
    ];
    for (final expectedPhase in expectedPhases) {
      final result = engine.advancePhase(state);
      expect(result.succeeded, isTrue);
      state = result.state;
      expect(state.currentPhase, expectedPhase);
    }

    expect(state.turnNumber, 2);
    expect(state.activePlayer, DuelParticipant.ai);
    expect(state.drawPhaseResolved, isFalse);
    expect(state.normalSummonUsed[DuelParticipant.player], isFalse);
    expect(state.normalSummonUsed[DuelParticipant.ai], isFalse);
    final resetCharacter = state.aiField.characterZones.first!;
    expect(resetCharacter.attackedThisTurn, isFalse);
    expect(resetCharacter.positionChangedThisTurn, isFalse);
  });
}
