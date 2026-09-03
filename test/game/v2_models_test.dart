import 'package:mysticartes/game/battle_state.dart';
import 'package:mysticartes/game/card.dart';
import 'package:mysticartes/game/duel_types.dart';
import 'package:mysticartes/game/player.dart';
import 'package:test/test.dart';

CardInstance catalogCard({
  String instanceId = 'instance-1',
  String cardCode = 'BAB-001',
  DuelParticipant owner = DuelParticipant.player,
  CardCategory category = CardCategory.character,
  int? rank = 1,
  int? atk = 1000,
  int? def = 1000,
  BattlePosition? position,
  int? zoneIndex,
}) {
  return CardInstance(
    instanceId: instanceId,
    cardId: 'card-$cardCode',
    cardCode: cardCode,
    cardRevision: 1,
    category: category,
    rank: rank,
    atk: atk,
    def: def,
    owner: owner,
    controller: owner,
    faceUp: true,
    position: position,
    zoneIndex: zoneIndex,
  );
}

void main() {
  group('CardInstance', () {
    test('conserve son identité catalogue et son état d’exécution', () {
      final modifier = RuntimeStatModifier(
        modifierId: 'boost-1',
        atkDelta: 500,
        defDelta: -200,
        sourceCardInstanceId: 'source-1',
        expiresAtTurn: 3,
        expiresAfterPhase: DuelPhase.end,
      );
      final card = CardInstance(
        instanceId: 'instance-1',
        cardId: 'catalog-uuid',
        cardCode: 'DOZ-005',
        cardRevision: 2,
        category: CardCategory.character,
        rank: 5,
        atk: 2100,
        def: 1800,
        owner: DuelParticipant.player,
        controller: DuelParticipant.ai,
        faceUp: true,
        position: BattlePosition.attack,
        zoneIndex: 2,
        summonedTurn: 4,
        attackedThisTurn: true,
        positionChangedThisTurn: true,
        counters: const {'proie': 2, 'mémoire': 1},
        attachedCardInstanceIds: const ['equipment-1'],
        runtimeModifiers: [modifier],
      );

      expect(card.cardId, 'catalog-uuid');
      expect(card.cardCode, 'DOZ-005');
      expect(card.cardRevision, 2);
      expect(card.counters, {'proie': 2, 'mémoire': 1});
      expect(card.runtimeModifiers.single.atkDelta, 500);
      expect(card.effectiveAtk, 2600);
      expect(card.effectiveDef, 1600);
      expect(card.attachedCardInstanceIds, ['equipment-1']);
    });

    test('copyWith produit une copie indépendante et accepte les nullables',
        () {
      final original = catalogCard(
        position: BattlePosition.attack,
        zoneIndex: 1,
      );
      final copy = original.copyWith(
        controller: DuelParticipant.ai,
        position: BattlePosition.defense,
        atk: 500,
        def: 500,
        zoneIndex: null,
        counters: const {'serment': 3},
        attackedThisTurn: true,
      );

      expect(copy, isNot(same(original)));
      expect(copy.controller, DuelParticipant.ai);
      expect(copy.position, BattlePosition.defense);
      expect(copy.zoneIndex, isNull);
      expect(copy.counters, {'serment': 3});
      expect(original.controller, DuelParticipant.player);
      expect(original.position, BattlePosition.attack);
      expect(original.zoneIndex, 1);
      expect(original.counters, isEmpty);
      expect(() => copy.counters['outil'] = 1, throwsUnsupportedError);
    });

    test('les modificateurs temporaires sont copiables et immuables', () {
      final modifier = RuntimeStatModifier(
        modifierId: 'temporary-boost',
        atkDelta: 300,
        metadata: const {'reason': 'action rapide'},
      );
      final copy = modifier.copyWith(
        atkDelta: 700,
        expiresAtTurn: 5,
      );

      expect(modifier.atkDelta, 300);
      expect(copy.atkDelta, 700);
      expect(copy.expiresAtTurn, 5);
      expect(
        () => copy.metadata['other'] = true,
        throwsUnsupportedError,
      );
    });
  });

  group('PlayerFieldState', () {
    test('construit les zones V2 avec les capacités attendues', () {
      final field = PlayerFieldState.empty(
        participant: DuelParticipant.player,
        deck: [catalogCard()],
        mythicReserve: [catalogCard(cardCode: 'BAB-015')],
      );

      expect(field.characterZones, hasLength(5));
      expect(field.actionTrapZones, hasLength(5));
      expect(field.characterZones, everyElement(isNull));
      expect(field.actionTrapZones, everyElement(isNull));
      expect(field.terrainZone, isNull);
      expect(field.deck.single.cardCode, 'BAB-001');
      expect(field.hand, isEmpty);
      expect(field.graveyard, isEmpty);
      expect(field.banished, isEmpty);
      expect(field.mythicReserve.single.cardCode, 'BAB-015');
    });

    test('copyWith remplace des zones sans modifier l’état source', () {
      final original = PlayerFieldState.empty(
        participant: DuelParticipant.player,
      );
      final character = catalogCard(
        position: BattlePosition.attack,
        zoneIndex: 0,
      );
      final terrain = catalogCard(cardCode: 'BAB-013');
      final zones = List<FieldCardInstance?>.from(original.characterZones)
        ..[0] = character;

      final copy = original.copyWith(
        characterZones: zones,
        terrainZone: terrain,
        hand: [catalogCard(cardCode: 'BAB-008')],
      );

      expect(copy.characterZones.first, same(character));
      expect(copy.terrainZone, same(terrain));
      expect(copy.hand.single.cardCode, 'BAB-008');
      expect(original.characterZones.first, isNull);
      expect(original.terrainZone, isNull);
      expect(original.hand, isEmpty);
      expect(() => copy.characterZones[1] = character, throwsUnsupportedError);
    });

    test('un TokenInstance utilise tokenKey et reste limité au terrain', () {
      final token = TokenInstance(
        instanceId: 'token-instance-1',
        tokenKey: 'sylve',
        owner: DuelParticipant.player,
        controller: DuelParticipant.player,
        position: BattlePosition.defense,
        zoneIndex: 3,
        summonedTurn: 2,
        counters: const {'graine': 1},
      );
      final field = PlayerFieldState(
        participant: DuelParticipant.player,
        characterZones: [null, null, null, token, null],
        actionTrapZones: const [null, null, null, null, null],
        terrainZone: null,
        deck: const [],
        hand: const [],
        graveyard: const [],
        banished: const [],
        mythicReserve: const [],
      );
      final copy = token.copyWith(
        position: BattlePosition.attack,
        zoneIndex: 1,
      );

      expect(field.characterZones[3], same(token));
      expect(token.tokenKey, 'sylve');
      expect(copy.position, BattlePosition.attack);
      expect(copy.zoneIndex, 1);
      expect(field.deck, isA<List<CardInstance>>());
      expect(field.hand, isA<List<CardInstance>>());
      expect(field.graveyard, isA<List<CardInstance>>());
      expect(field.banished, isA<List<CardInstance>>());
    });
  });

  group('DuelState', () {
    test('démarre avec 8000 PV, la phase de pioche et les usages libres', () {
      final state = DuelState(
        playerField: PlayerFieldState.empty(
          participant: DuelParticipant.player,
        ),
        aiField: PlayerFieldState.empty(
          participant: DuelParticipant.ai,
        ),
      );

      expect(state.playerLifePoints, 8000);
      expect(state.aiLifePoints, 8000);
      expect(state.turnNumber, 1);
      expect(state.activePlayer, DuelParticipant.player);
      expect(state.currentPhase, DuelPhase.draw);
      expect(state.normalSummonUsed[DuelParticipant.player], isFalse);
      expect(state.normalSummonUsed[DuelParticipant.ai], isFalse);
      expect(state.chain, isA<ChainState>());
    });

    test('copyWith crée un nouvel instantané sans appliquer de règle', () {
      final original = DuelState(
        playerField: PlayerFieldState.empty(
          participant: DuelParticipant.player,
        ),
        aiField: PlayerFieldState.empty(
          participant: DuelParticipant.ai,
        ),
      );
      final copy = original.copyWith(
        playerLifePoints: 7250,
        turnNumber: 3,
        activePlayer: DuelParticipant.ai,
        currentPhase: DuelPhase.main1,
        normalSummonUsed: const {
          DuelParticipant.player: false,
          DuelParticipant.ai: true,
        },
      );

      expect(copy.playerLifePoints, 7250);
      expect(copy.turnNumber, 3);
      expect(copy.activePlayer, DuelParticipant.ai);
      expect(copy.currentPhase, DuelPhase.main1);
      expect(copy.normalSummonUsed[DuelParticipant.ai], isTrue);
      expect(original.playerLifePoints, 8000);
      expect(original.turnNumber, 1);
      expect(original.currentPhase, DuelPhase.draw);
      expect(
        () => copy.normalSummonUsed[DuelParticipant.player] = true,
        throwsUnsupportedError,
      );
    });
  });
}
