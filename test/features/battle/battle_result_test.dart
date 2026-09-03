import 'package:mysticartes/features/battle/battle_result.dart';
import 'package:mysticartes/features/battle/duel_state_snapshot.dart';
import 'package:mysticartes/game/battle_state.dart';
import 'package:mysticartes/game/card.dart';
import 'package:mysticartes/game/duel_types.dart';
import 'package:mysticartes/game/player.dart';
import 'package:test/test.dart';

CardInstance card(String id, DuelParticipant owner) => CardInstance(
      instanceId: id,
      cardId: 'catalog-$id',
      cardCode: 'BAB-003',
      cardRevision: 1,
      category: CardCategory.character,
      rank: 4,
      owner: owner,
      controller: owner,
      faceUp: true,
      position: BattlePosition.attack,
      atk: 1800,
      def: 1700,
      counters: const {'serment': 2},
    );

DuelState completedState() {
  final playerCard = card('player-card', DuelParticipant.player);
  return DuelState(
    playerField: PlayerFieldState.empty(
      participant: DuelParticipant.player,
      deck: [card('deck-card', DuelParticipant.player)],
    ).copyWith(
      characterZones: [playerCard, null, null, null, null],
    ),
    aiField: PlayerFieldState.empty(participant: DuelParticipant.ai),
    playerLifePoints: 5400,
    aiLifePoints: -300,
    turnNumber: 7,
    startingPlayer: DuelParticipant.player,
    activePlayer: DuelParticipant.player,
    currentPhase: DuelPhase.battle,
    winner: DuelParticipant.player,
    endReason: DuelEndReason.lifePointsDepleted,
  );
}

void main() {
  test('construit le snapshot final complet envoyé à la RPC V2', () {
    final report = BattleReport.fromDuelState(
      state: completedState(),
      deckId: '11111111-1111-4111-8111-111111111111',
      aiKey: 'solo-v2-beginner',
      difficulty: 'beginner',
      startedAt: DateTime.utc(2026, 9, 3, 10),
      completedAt: DateTime.utc(2026, 9, 3, 10, 8),
      clientMatchId: '22222222-2222-4222-8222-222222222222',
    );
    final params = report.toRpcParams();
    final snapshot = params['p_state_snapshot']! as Map<String, Object?>;
    final players = snapshot['players']! as Map<String, Object?>;
    final player = players['player']! as Map<String, Object?>;
    final ai = players['ai']! as Map<String, Object?>;
    final turn = snapshot['turn']! as Map<String, Object?>;

    expect(params['p_client_match_id'], report.clientMatchId);
    expect(params['p_deck_id'], report.deckId);
    expect(params['p_result'], 'win');
    expect(params['p_win_reason'], 'life_points');
    expect(params['p_starting_player'], 'player');
    expect(params['p_turn_number'], 7);
    expect(params['p_current_phase'], 'battle');
    expect(params['p_state_schema_version'],
        DuelStateSnapshotBuilder.schemaVersion);
    expect(snapshot['rulesetVersion'], 'v2-gdd-1.1');
    expect(snapshot['winner'], 'player');
    expect(turn['number'], 7);
    expect(turn['phase'], 'battle');
    expect(player['lifePoints'], 5400);
    expect(ai['lifePoints'], 0);
    expect(player['zones'], isA<Map<String, Object?>>());
    expect(player['deck'], isA<List<Object?>>());
  });

  test('refuse de construire un rapport pour un duel non terminé', () {
    final state = DuelState(
      playerField: PlayerFieldState.empty(
        participant: DuelParticipant.player,
      ),
      aiField: PlayerFieldState.empty(participant: DuelParticipant.ai),
    );
    expect(
      () => BattleReport.fromDuelState(
        state: state,
        deckId: 'deck',
        aiKey: 'ai',
        difficulty: 'beginner',
        startedAt: DateTime.utc(2026),
        completedAt: DateTime.utc(2026),
      ),
      throwsStateError,
    );
  });

  test('lit les récompenses calculées par Supabase V2', () {
    final reward = BattleReward.fromJson({
      'xp': 120,
      'gold': 50,
      'total_xp': 620,
      'total_gold': 90,
      'account_level': 2,
      'already_completed': false,
      'reward_card': {
        'id': 'card-id',
        'name': 'Apprenti du Gbaka',
        'code': 'BAB-001',
        'art_url': null,
      },
    });

    expect(reward.xp, 120);
    expect(reward.gold, 50);
    expect(reward.totalXp, 620);
    expect(reward.accountLevel, 2);
    expect(reward.card?.name, 'Apprenti du Gbaka');
    expect(reward.card?.localArtAsset, 'assets/images/cards/bab-001.png');
  });
}
