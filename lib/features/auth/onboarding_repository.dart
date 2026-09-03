import 'package:supabase_flutter/supabase_flutter.dart';

class OnboardingStatus {
  const OnboardingStatus({
    required this.hasIdentity,
    required this.hasReadyDeck,
  });

  final bool hasIdentity;
  final bool hasReadyDeck;
}

enum OnboardingDestination { chooseUsername, tutorial, home }

OnboardingDestination destinationFor(OnboardingStatus status) {
  if (status.hasReadyDeck) return OnboardingDestination.home;
  return status.hasIdentity
      ? OnboardingDestination.tutorial
      : OnboardingDestination.chooseUsername;
}

class StarterDeckCardData {
  StarterDeckCardData({
    required this.cardId,
    required this.code,
    required this.name,
    required this.category,
    required this.quantity,
    required this.revision,
    this.subtype,
    this.rank,
    this.atk,
    this.def,
    this.attribute,
    this.primaryFamily,
    this.secondaryFamilies = const [],
    this.mythicSummonCondition = const {},
    this.effectKey,
    this.effectData = const {},
  }) {
    if (quantity < 1 || quantity > 3) {
      throw const FormatException(
          'Quantité invalide dans le deck de départ V2.');
    }
  }

  factory StarterDeckCardData.fromJson(Map<String, dynamic> json) {
    return StarterDeckCardData(
      cardId: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      quantity: (json['quantity'] as num).toInt(),
      revision: (json['revision'] as num?)?.toInt() ?? 1,
      subtype: json['subtype'] as String?,
      rank: (json['rank'] as num?)?.toInt(),
      atk: (json['atk'] as num?)?.toInt(),
      def: (json['def'] as num?)?.toInt(),
      attribute: json['attribute'] as String?,
      primaryFamily: json['primary_family'] as String?,
      secondaryFamilies: (json['secondary_families'] as List? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
      mythicSummonCondition: _jsonMap(json['mythic_summon_condition']),
      effectKey: json['effect_key'] as String?,
      effectData: _jsonMap(json['effect_data']),
    );
  }

  final String cardId;
  final String code;
  final String name;
  final String category;
  final int quantity;
  final int revision;
  final String? subtype;
  final int? rank;
  final int? atk;
  final int? def;
  final String? attribute;
  final String? primaryFamily;
  final List<String> secondaryFamilies;
  final Map<String, Object?> mythicSummonCondition;
  final String? effectKey;
  final Map<String, Object?> effectData;

  Map<String, Object?> toJson() => {
        'id': cardId,
        'code': code,
        'name': name,
        'category': category,
        'quantity': quantity,
        'revision': revision,
        'subtype': subtype,
        'rank': rank,
        'atk': atk,
        'def': def,
        'attribute': attribute,
        'primary_family': primaryFamily,
        'secondary_families': secondaryFamilies,
        'mythic_summon_condition': mythicSummonCondition,
        'effect_key': effectKey,
        'effect_data': effectData,
      };

  static Map<String, Object?> _jsonMap(Object? value) =>
      value is Map ? Map<String, Object?>.from(value) : const {};
}

class StarterDeckData {
  StarterDeckData({
    required this.deckId,
    required this.playerName,
    required this.family,
    required this.mainDeck,
    required this.mythicReserve,
    required this.alreadyExisted,
  }) {
    final mainCount = mainDeck.fold(0, (sum, card) => sum + card.quantity);
    final mythicCount =
        mythicReserve.fold(0, (sum, card) => sum + card.quantity);
    if (mainCount != 40 || mythicCount != 1) {
      throw const FormatException(
        'Le deck de départ V2 doit contenir 40 cartes et une Mythique.',
      );
    }
    if (mainDeck.any((card) => card.category == 'mythique') ||
        mythicReserve.any((card) => card.category != 'mythique')) {
      throw const FormatException(
          'Une carte du deck de départ est mal placée.');
    }
    final copiesByName = <String, int>{};
    for (final card in [...mainDeck, ...mythicReserve]) {
      copiesByName.update(
        card.name.trim().toLowerCase(),
        (value) => value + card.quantity,
        ifAbsent: () => card.quantity,
      );
    }
    if (copiesByName.values.any((quantity) => quantity > 3)) {
      throw const FormatException(
        'Le deck de départ dépasse trois exemplaires par nom.',
      );
    }
  }

  factory StarterDeckData.fromJson(Map<String, dynamic> json) {
    List<StarterDeckCardData> parseCards(String key) {
      final raw = json[key];
      if (raw is! List) {
        throw FormatException('Composition $key absente.');
      }
      return raw
          .map(
            (value) => StarterDeckCardData.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList(growable: false);
    }

    return StarterDeckData(
      deckId: json['deck_id'] as String,
      playerName: json['player_name'] as String? ?? 'Joueur',
      family: json['family'] as String? ?? 'babi',
      mainDeck: parseCards('main_deck'),
      mythicReserve: parseCards('mythic_reserve'),
      alreadyExisted: json['already_existed'] as bool? ?? false,
    );
  }

  final String deckId;
  final String playerName;
  final String family;
  final List<StarterDeckCardData> mainDeck;
  final List<StarterDeckCardData> mythicReserve;
  final bool alreadyExisted;
}

class OnboardingRepository {
  OnboardingRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Un joueur connecté est requis.');
    return id;
  }

  Future<OnboardingStatus> fetchStatus() async {
    final userId = _userId;
    var profile = await _client
        .from('profiles')
        .select('username, display_name')
        .eq('id', userId)
        .maybeSingle();
    profile ??= await _client
        .from('profiles')
        .insert({'id': userId})
        .select('username, display_name')
        .single();

    final readyDeck = await _client
        .from('decks')
        .select('id')
        .eq('user_id', userId)
        .eq('status', 'ready')
        .eq('ruleset_version', 'v2-gdd-1.1')
        .limit(1)
        .maybeSingle();
    final username = (profile['username'] as String?)?.trim() ?? '';
    final displayName = (profile['display_name'] as String?)?.trim() ?? '';
    return OnboardingStatus(
      hasIdentity: username.isNotEmpty && displayName.isNotEmpty,
      hasReadyDeck: readyDeck != null,
    );
  }

  Future<void> saveIdentity(String username) async {
    final normalized = username.trim();
    if (!RegExp(r'^[A-Za-z0-9_]{3,24}$').hasMatch(normalized)) {
      throw const FormatException(
        'Le pseudo doit contenir 3 à 24 lettres, chiffres ou underscores.',
      );
    }
    await _client.from('profiles').update({
      'username': normalized,
      'display_name': normalized,
    }).eq('id', _userId);
  }

  Future<StarterDeckData> createStarterDeck() async {
    final response = await _client.rpc('create_starter_deck_v2');
    if (response is! Map) {
      throw const FormatException(
          'Réponse invalide pour le deck de départ V2.');
    }
    return StarterDeckData.fromJson(Map<String, dynamic>.from(response));
  }
}
