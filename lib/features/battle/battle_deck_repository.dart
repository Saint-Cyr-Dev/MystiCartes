import 'package:supabase_flutter/supabase_flutter.dart';

import 'local_duel.dart';

class BattleDeckData {
  const BattleDeckData({
    required this.deckId,
    required this.mainDeck,
    required this.mythicReserve,
  });

  final String deckId;
  final List<LocalCardPresentation> mainDeck;
  final List<LocalCardPresentation> mythicReserve;
}

abstract interface class BattleDeckDataSource {
  Future<BattleDeckData> load(String deckId);
}

class SupabaseBattleDeckRepository implements BattleDeckDataSource {
  SupabaseBattleDeckRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<BattleDeckData> load(String deckId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Un joueur connecté est requis.');
    final rows = await _client
        .from('deck_cards')
        .select(
          'quantity, zone, cards!inner(id, code, name, category, subtype, '
          'rank, atk, def, attribute, primary_family, secondary_families, '
          'mythic_summon_condition, effect_key, effect_data, revision)',
        )
        .eq('deck_id', deckId)
        .eq('user_id', userId);

    final main = <LocalCardPresentation>[];
    final mythic = <LocalCardPresentation>[];
    for (final row in rows) {
      final rawCard = row['cards'];
      if (rawCard is! Map) continue;
      final definition = LocalCardPresentation.fromJson(
        Map<String, Object?>.from(rawCard),
      );
      final quantity = (row['quantity'] as num).toInt();
      final target = row['zone'] == 'mythic' ? mythic : main;
      for (var copy = 0; copy < quantity; copy++) {
        target.add(definition);
      }
    }
    if (main.length != 40 || mythic.length > 15) {
      throw const FormatException('Composition du deck V2 invalide.');
    }
    return BattleDeckData(
      deckId: deckId,
      mainDeck: List.unmodifiable(main),
      mythicReserve: List.unmodifiable(mythic),
    );
  }
}
