import 'package:mysticartes/features/battle/progression.dart';
import 'package:mysticartes/game/ai/ai_strategy.dart';
import 'package:test/test.dart';

void main() {
  group('courbe XP', () {
    test('gagne un niveau tous les 500 XP à partir du niveau 1', () {
      expect(ProgressionRules.accountLevelForXp(0), 1);
      expect(ProgressionRules.accountLevelForXp(499), 1);
      expect(ProgressionRules.accountLevelForXp(500), 2);
      expect(ProgressionRules.accountLevelForXp(1500), 4);
    });
  });

  group('difficulté proposée', () {
    test('suit les paliers de niveau', () {
      expect(
        ProgressionRules.recommendedDifficulty(
          accountLevel: 2,
          recentResults: const [],
        ),
        AiDifficulty.beginner,
      );
      expect(
        ProgressionRules.recommendedDifficulty(
          accountLevel: 3,
          recentResults: const [],
        ),
        AiDifficulty.intermediate,
      );
      expect(
        ProgressionRules.recommendedDifficulty(
          accountLevel: 6,
          recentResults: const [],
        ),
        AiDifficulty.advanced,
      );
      expect(
        ProgressionRules.recommendedDifficulty(
          accountLevel: 10,
          recentResults: const [],
        ),
        AiDifficulty.expert,
      );
    });

    test('quatre victoires récentes promeuvent exactement un palier', () {
      expect(
        ProgressionRules.recommendedDifficulty(
          accountLevel: 2,
          recentResults: const ['win', 'win', 'loss', 'win', 'win'],
        ),
        AiDifficulty.intermediate,
      );
      expect(
        ProgressionRules.recommendedDifficulty(
          accountLevel: 8,
          recentResults: const ['win', 'win', 'win', 'win', 'win'],
        ),
        AiDifficulty.expert,
      );
    });

    test('une série de défaites ne rétrograde jamais le palier du niveau', () {
      expect(
        ProgressionRules.recommendedDifficulty(
          accountLevel: 7,
          recentResults: const ['loss', 'loss', 'loss', 'loss', 'loss'],
        ),
        AiDifficulty.advanced,
      );
    });
  });
}
