import 'package:supabase_flutter/supabase_flutter.dart';

import 'battle_result.dart';

export 'battle_result.dart';

class SupabaseBattleResultRepository implements BattleResultDataSource {
  SupabaseBattleResultRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<BattleReward> save(BattleReport report) async {
    if (_client.auth.currentUser == null) {
      throw StateError(
          'Un joueur connecté est requis pour sauvegarder le combat.');
    }

    final response = await _client.rpc(
      'complete_solo_match_v2',
      params: report.toRpcParams(),
    );

    final json = switch (response) {
      final Map value => Map<String, dynamic>.from(value),
      final List value when value.isNotEmpty =>
        Map<String, dynamic>.from(value.first as Map),
      _ => throw const FormatException(
          'La sauvegarde Supabase n’a renvoyé aucune récompense.',
        ),
    };
    final cardId = json['card_id'];
    if (cardId is String) {
      final card = await _client
          .from('cards')
          .select('id, name, code, art_url')
          .eq('id', cardId)
          .maybeSingle();
      if (card != null) json['reward_card'] = card;
    }
    return BattleReward.fromJson(json);
  }
}
