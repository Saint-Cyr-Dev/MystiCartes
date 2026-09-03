import '../../game/ai/ai_strategy.dart';

class ProgressionRules {
  const ProgressionRules._();

  static const int xpPerLevel = 500;

  /// Courbe officielle actuelle: niveau = 1 + floor(XP total / 500).
  static int accountLevelForXp(int totalXp) {
    if (totalXp < 0) throw ArgumentError.value(totalXp, 'totalXp');
    return 1 + totalXp ~/ xpPerLevel;
  }

  /// Difficulté de base par niveau:
  /// 1-2 débutant, 3-5 intermédiaire, 6-9 avancé, 10+ expert.
  /// Quatre victoires sur les cinq derniers résultats du palier courant
  /// accordent une promotion. Les défaites ne provoquent jamais de rétrogradation.
  static AiDifficulty recommendedDifficulty({
    required int accountLevel,
    required List<String> recentResults,
  }) {
    var difficulty = switch (accountLevel) {
      <= 2 => AiDifficulty.beginner,
      <= 5 => AiDifficulty.intermediate,
      <= 9 => AiDifficulty.advanced,
      _ => AiDifficulty.expert,
    };
    final lastFive = recentResults.take(5);
    final wins = lastFive.where((result) => result == 'win').length;
    if (lastFive.length >= 4 && wins >= 4) {
      difficulty = switch (difficulty) {
        AiDifficulty.beginner => AiDifficulty.intermediate,
        AiDifficulty.intermediate => AiDifficulty.advanced,
        AiDifficulty.advanced || AiDifficulty.expert => AiDifficulty.expert,
      };
    }
    return difficulty;
  }
}

class PlayerBattleSetup {
  PlayerBattleSetup({
    required this.deckId,
    required this.playerName,
    required this.accountLevel,
    required this.totalXp,
    required this.difficulty,
  });

  final String deckId;
  final String playerName;
  final int accountLevel;
  final int totalXp;
  final AiDifficulty difficulty;
}
