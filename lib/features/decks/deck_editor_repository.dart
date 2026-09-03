import 'package:supabase_flutter/supabase_flutter.dart';

import '../collection/collection_card.dart';
import '../collection/collection_repository.dart';
import 'deck_draft.dart';

class DeckSummary {
  const DeckSummary({
    required this.id,
    required this.name,
    required this.status,
    required this.isSelected,
  });

  final String id;
  final String name;
  final String status;
  final bool isSelected;

  bool get isReady => status == 'ready';
}

class DeckEditorData {
  const DeckEditorData({
    this.deckId,
    required this.name,
    required this.status,
    required this.isSelected,
    required this.cards,
    required this.mainQuantities,
    required this.mythicQuantities,
  });

  final String? deckId;
  final String name;
  final String status;
  final bool isSelected;
  final List<CollectionCard> cards;
  final Map<String, int> mainQuantities;
  final Map<String, int> mythicQuantities;
}

abstract interface class DeckRepositoryContract {
  Future<List<DeckSummary>> listDecks();

  Future<DeckEditorData> load({String? deckId});

  Future<String> saveDraft({
    String? deckId,
    required String name,
    required Map<String, int> mainQuantities,
    required Map<String, int> mythicQuantities,
  });

  Future<void> markReady(String deckId);

  Future<void> unlockForEditing(String deckId);

  Future<void> selectForPlay(String deckId);
}

typedef DeckEditorDataSource = DeckRepositoryContract;

class SupabaseDeckEditorRepository implements DeckRepositoryContract {
  SupabaseDeckEditorRepository({
    SupabaseClient? client,
    CollectionRepositoryContract? collectionRepository,
  })  : _client = client ?? Supabase.instance.client,
        _collectionRepository = collectionRepository ??
            CollectionRepository(client: client ?? Supabase.instance.client);

  static const rulesetVersion = 'v2-gdd-1.1';

  final SupabaseClient _client;
  final CollectionRepositoryContract _collectionRepository;

  @override
  Future<List<DeckSummary>> listDecks() async {
    final userId = _requireUserId();
    final rows = await _client
        .from('decks')
        .select('id, name, status, is_selected')
        .eq('user_id', userId)
        .eq('ruleset_version', rulesetVersion)
        .neq('status', 'archived')
        .order('is_selected', ascending: false)
        .order('updated_at', ascending: false);
    return rows
        .map(
          (row) => DeckSummary(
            id: row['id'] as String,
            name: row['name'] as String,
            status: row['status'] as String,
            isSelected: row['is_selected'] as bool? ?? false,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<DeckEditorData> load({String? deckId}) async {
    final cards = await _collectionRepository.fetchCollection();
    if (deckId == null) {
      return DeckEditorData(
        name: '',
        status: 'draft',
        isSelected: false,
        cards: cards,
        mainQuantities: const {},
        mythicQuantities: const {},
      );
    }

    final userId = _requireUserId();
    final deckRow = await _client
        .from('decks')
        .select('id, name, status, is_selected')
        .eq('id', deckId)
        .eq('user_id', userId)
        .eq('ruleset_version', rulesetVersion)
        .single();
    final compositionRows = await _client
        .from('deck_cards')
        .select('card_id, quantity, zone')
        .eq('deck_id', deckId)
        .eq('user_id', userId);

    final main = <String, int>{};
    final mythic = <String, int>{};
    for (final row in compositionRows) {
      final destination = row['zone'] == 'mythic' ? mythic : main;
      destination[row['card_id'] as String] = (row['quantity'] as num).toInt();
    }
    return DeckEditorData(
      deckId: deckRow['id'] as String,
      name: deckRow['name'] as String,
      status: deckRow['status'] as String,
      isSelected: deckRow['is_selected'] as bool? ?? false,
      cards: cards,
      mainQuantities: main,
      mythicQuantities: mythic,
    );
  }

  @override
  Future<String> saveDraft({
    String? deckId,
    required String name,
    required Map<String, int> mainQuantities,
    required Map<String, int> mythicQuantities,
  }) async {
    final userId = _requireUserId();
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError.value(
          name, 'name', 'Le nom du deck est obligatoire.');
    }

    if (deckId != null) {
      final existing = await _client
          .from('decks')
          .select('status')
          .eq('id', deckId)
          .eq('user_id', userId)
          .single();
      if (existing['status'] == 'ready') {
        throw StateError(
            'Passez explicitement le deck en brouillon avant de le modifier.');
      }
    }

    final cards = await _collectionRepository.fetchCollection();
    final draft = DeckDraft(
      cards: cards,
      initialMainQuantities: mainQuantities,
      initialMythicQuantities: mythicQuantities,
    );
    if (draft.exceedsCopyLimit ||
        draft.exceedsOwnedCards ||
        draft.hasInvalidZones ||
        draft.mainCount > DeckDraft.mainDeckSize ||
        draft.mythicCount > DeckDraft.mythicReserveLimit) {
      throw StateError('La composition du deck est invalide.');
    }

    final String savedDeckId;
    if (deckId == null) {
      final row = await _client
          .from('decks')
          .insert({
            'user_id': userId,
            'name': cleanName,
            'status': 'draft',
            'is_selected': false,
            'ruleset_version': rulesetVersion,
          })
          .select('id')
          .single();
      savedDeckId = row['id'] as String;
    } else {
      await _client
          .from('decks')
          .update({'name': cleanName})
          .eq('id', deckId)
          .eq('user_id', userId);
      savedDeckId = deckId;
    }

    await _client
        .from('deck_cards')
        .delete()
        .eq('deck_id', savedDeckId)
        .eq('user_id', userId);

    final rows = <Map<String, Object>>[
      ..._compositionRows(
        deckId: savedDeckId,
        userId: userId,
        zone: DeckZone.main,
        quantities: mainQuantities,
      ),
      ..._compositionRows(
        deckId: savedDeckId,
        userId: userId,
        zone: DeckZone.mythic,
        quantities: mythicQuantities,
      ),
    ];
    if (rows.isNotEmpty) await _client.from('deck_cards').insert(rows);
    return savedDeckId;
  }

  @override
  Future<void> markReady(String deckId) async {
    final userId = _requireUserId();
    await _client
        .from('decks')
        .update({'status': 'ready'})
        .eq('id', deckId)
        .eq('user_id', userId);
  }

  @override
  Future<void> unlockForEditing(String deckId) async {
    final userId = _requireUserId();
    await _client
        .from('decks')
        .update({'status': 'draft', 'is_selected': false})
        .eq('id', deckId)
        .eq('user_id', userId)
        .eq('status', 'ready');
  }

  @override
  Future<void> selectForPlay(String deckId) async {
    final userId = _requireUserId();
    final target = await _client
        .from('decks')
        .select('id')
        .eq('id', deckId)
        .eq('user_id', userId)
        .eq('status', 'ready')
        .maybeSingle();
    if (target == null) {
      throw StateError('Seul un deck prêt peut être sélectionné pour jouer.');
    }
    await _client
        .from('decks')
        .update({'is_selected': false})
        .eq('user_id', userId)
        .eq('is_selected', true);
    await _client
        .from('decks')
        .update({'is_selected': true})
        .eq('id', deckId)
        .eq('user_id', userId)
        .eq('status', 'ready');
  }

  Iterable<Map<String, Object>> _compositionRows({
    required String deckId,
    required String userId,
    required DeckZone zone,
    required Map<String, int> quantities,
  }) sync* {
    for (final entry in quantities.entries) {
      if (entry.value <= 0) continue;
      yield {
        'deck_id': deckId,
        'user_id': userId,
        'card_id': entry.key,
        'quantity': entry.value,
        'zone': zone.databaseValue,
      };
    }
  }

  String _requireUserId() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Un joueur connecté est requis pour gérer les decks.');
    }
    return userId;
  }
}
