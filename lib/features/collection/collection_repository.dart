import 'package:supabase_flutter/supabase_flutter.dart';

import 'collection_card.dart';

abstract interface class CollectionDataSource {
  Future<List<Map<String, dynamic>>> fetchActiveCards();

  Future<List<Map<String, dynamic>>> fetchOwnedCards();
}

class SupabaseCollectionDataSource implements CollectionDataSource {
  SupabaseCollectionDataSource(this.client);

  final SupabaseClient client;

  @override
  Future<List<Map<String, dynamic>>> fetchActiveCards() async {
    final rows = await client
        .from('cards')
        .select(
          'id, code, name, category, subtype, relic_mode, rarity, rank, '
          'atk, def, attribute, primary_family, secondary_families, '
          'mythic_summon_condition, effect_text, effect_key, effect_data, '
          'lore_text, art_url, sort_order',
        )
        .eq('is_active', true)
        .order('sort_order')
        .order('name');
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchOwnedCards() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return const [];
    final rows = await client
        .from('player_cards')
        .select('card_id, quantity')
        .eq('user_id', userId);
    return List<Map<String, dynamic>>.from(rows);
  }
}

abstract interface class CollectionRepositoryContract {
  Future<List<CollectionCard>> fetchCollection();
}

class CollectionRepository implements CollectionRepositoryContract {
  CollectionRepository({SupabaseClient? client, CollectionDataSource? source})
      : _source = source ??
            SupabaseCollectionDataSource(client ?? Supabase.instance.client);

  final CollectionDataSource _source;

  @override
  Future<List<CollectionCard>> fetchCollection() async {
    final results = await Future.wait([
      _source.fetchActiveCards(),
      _source.fetchOwnedCards(),
    ]);
    final cardRows = results[0];
    final ownedRows = results[1];
    final quantitiesByCard = <String, int>{};
    for (final row in ownedRows) {
      final cardId = row['card_id'] as String?;
      if (cardId != null) {
        quantitiesByCard[cardId] = (row['quantity'] as num?)?.toInt() ?? 0;
      }
    }

    return cardRows
        .map(
          (row) => CollectionCard.fromSupabase(
            row,
            quantity: quantitiesByCard[row['id'] as String] ?? 0,
          ),
        )
        .toList(growable: false);
  }
}
