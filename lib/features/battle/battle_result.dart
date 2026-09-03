import 'dart:math';

import '../../game/battle_state.dart';
import '../../game/duel_types.dart';
import 'duel_state_snapshot.dart';

enum PlayerBattleResult { victory, defeat, draw }

class BattleReport {
  const BattleReport({
    required this.clientMatchId,
    required this.deckId,
    required this.result,
    required this.winReason,
    required this.aiKey,
    required this.difficulty,
    required this.startingPlayer,
    required this.turnNumber,
    required this.currentPhase,
    required this.startedAt,
    required this.completedAt,
    required this.stateSchemaVersion,
    required this.stateSnapshot,
  });

  factory BattleReport.fromDuelState({
    required DuelState state,
    required String deckId,
    required String aiKey,
    required String difficulty,
    required DateTime startedAt,
    required DateTime completedAt,
    String? clientMatchId,
  }) {
    final winner = state.winner;
    if (winner == null) {
      throw StateError('Un duel non terminé ne peut pas être sauvegardé.');
    }
    final result = winner == DuelParticipant.player
        ? PlayerBattleResult.victory
        : PlayerBattleResult.defeat;
    return BattleReport(
      clientMatchId: clientMatchId ?? generateClientMatchId(),
      deckId: deckId,
      result: result,
      winReason: switch (state.endReason) {
        DuelEndReason.deckOut => 'deck_out',
        DuelEndReason.cardEffect => 'alternative_effect',
        DuelEndReason.lifePointsDepleted || null => 'life_points',
      },
      aiKey: aiKey,
      difficulty: difficulty,
      startingPlayer: state.startingPlayer.name,
      turnNumber: state.turnNumber,
      currentPhase: DuelStateSnapshotBuilder.phaseValue(state.currentPhase),
      startedAt: startedAt,
      completedAt: completedAt,
      stateSchemaVersion: DuelStateSnapshotBuilder.schemaVersion,
      stateSnapshot: DuelStateSnapshotBuilder.build(state),
    );
  }

  final String clientMatchId;
  final String deckId;
  final PlayerBattleResult result;
  final String winReason;
  final String aiKey;
  final String difficulty;
  final String startingPlayer;
  final int turnNumber;
  final String currentPhase;
  final DateTime startedAt;
  final DateTime completedAt;
  final int stateSchemaVersion;
  final Map<String, Object?> stateSnapshot;

  String get databaseResult => switch (result) {
        PlayerBattleResult.victory => 'win',
        PlayerBattleResult.defeat => 'loss',
        PlayerBattleResult.draw => 'draw',
      };

  Map<String, Object?> toRpcParams() => {
        'p_client_match_id': clientMatchId,
        'p_deck_id': deckId,
        'p_ai_key': aiKey,
        'p_difficulty': difficulty,
        'p_result': databaseResult,
        'p_win_reason': winReason,
        'p_starting_player': startingPlayer,
        'p_turn_number': turnNumber,
        'p_current_phase': currentPhase,
        'p_started_at': startedAt.toUtc().toIso8601String(),
        'p_completed_at': completedAt.toUtc().toIso8601String(),
        'p_state_schema_version': stateSchemaVersion,
        'p_state_snapshot': stateSnapshot,
      };
}

String generateClientMatchId([Random? random]) {
  final source = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => source.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int value) => value.toRadixString(16).padLeft(2, '0');
  final value = bytes.map(hex).join();
  return '${value.substring(0, 8)}-'
      '${value.substring(8, 12)}-'
      '${value.substring(12, 16)}-'
      '${value.substring(16, 20)}-'
      '${value.substring(20)}';
}

class BattleRewardCard {
  const BattleRewardCard({
    required this.id,
    required this.name,
    required this.code,
    this.artUrl,
  });

  factory BattleRewardCard.fromJson(Map<String, dynamic> json) =>
      BattleRewardCard(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Carte mystère',
        code: json['code'] as String? ?? '',
        artUrl: json['art_url'] as String?,
      );

  final String id;
  final String name;
  final String code;
  final String? artUrl;

  String? get localArtAsset =>
      code.isEmpty ? null : 'assets/images/cards/${code.toLowerCase()}.png';
}

class BattleReward {
  const BattleReward({
    required this.xp,
    required this.gold,
    this.totalXp,
    this.totalGold,
    this.accountLevel,
    this.card,
    this.alreadyCompleted = false,
  });

  factory BattleReward.fromJson(Map<String, dynamic> json) {
    final rawCard = json['reward_card'];
    return BattleReward(
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      gold: (json['gold'] as num?)?.toInt() ?? 0,
      totalXp: (json['total_xp'] as num?)?.toInt(),
      totalGold: (json['total_gold'] as num?)?.toInt(),
      accountLevel: (json['account_level'] as num?)?.toInt(),
      card: rawCard is Map
          ? BattleRewardCard.fromJson(Map<String, dynamic>.from(rawCard))
          : null,
      alreadyCompleted: json['already_completed'] as bool? ?? false,
    );
  }

  final int xp;
  final int gold;
  final int? totalXp;
  final int? totalGold;
  final int? accountLevel;
  final BattleRewardCard? card;
  final bool alreadyCompleted;
}

abstract interface class BattleResultDataSource {
  Future<BattleReward> save(BattleReport report);
}
