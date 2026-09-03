import 'package:supabase_flutter/supabase_flutter.dart';

import 'progression.dart';

class ProgressionRepository {
  ProgressionRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<PlayerBattleSetup> prepareBattle() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Un joueur connecté est requis.');

    final currency = await _client
        .from('currencies')
        .select('total_xp, account_level')
        .eq('user_id', userId)
        .maybeSingle();
    final totalXp = (currency?['total_xp'] as num?)?.toInt() ?? 0;
    final accountLevel = (currency?['account_level'] as num?)?.toInt() ??
        ProgressionRules.accountLevelForXp(totalXp);

    final latestAiProgress = await _client
        .from('ai_progress')
        .select('recent_results, last_played_at')
        .eq('user_id', userId)
        .order('last_played_at', ascending: false, nullsFirst: false)
        .limit(1)
        .maybeSingle();
    final recentResults = (latestAiProgress?['recent_results'] as List?)
            ?.whereType<String>()
            .toList(growable: false) ??
        const <String>[];
    final difficulty = ProgressionRules.recommendedDifficulty(
      accountLevel: accountLevel,
      recentResults: recentResults,
    );

    final profile = await _client
        .from('profiles')
        .select('username, display_name')
        .eq('id', userId)
        .maybeSingle();
    final playerName = _firstNonEmpty([
      profile?['display_name'] as String?,
      profile?['username'] as String?,
      'Joueur',
    ]);

    final deck = await _client
        .from('decks')
        .select('id')
        .eq('user_id', userId)
        .eq('status', 'ready')
        .eq('ruleset_version', 'v2-gdd-1.1')
        .order('is_selected', ascending: false)
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (deck == null) {
      throw StateError('Aucun deck prêt à jouer n’a été trouvé.');
    }
    final deckId = deck['id'] as String;
    return PlayerBattleSetup(
      deckId: deckId,
      playerName: playerName,
      accountLevel: accountLevel,
      totalXp: totalXp,
      difficulty: difficulty,
    );
  }

  String _firstNonEmpty(List<String?> values) => values
      .map((value) => value?.trim() ?? '')
      .firstWhere((value) => value.isNotEmpty);
}
