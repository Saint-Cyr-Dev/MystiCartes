class CollectionCard {
  const CollectionCard({
    required this.id,
    required this.code,
    required this.name,
    required this.rarity,
    required this.quantity,
    String? category,
    String? cardType,
    String? effectText,
    String? description,
    this.subtype,
    this.relicMode,
    this.rank,
    this.atk,
    this.def,
    this.attribute,
    this.primaryFamily = '',
    this.secondaryFamilies = const [],
    this.mythicSummonCondition,
    this.effectKey,
    this.effectData = const {},
    this.artUrl,
    this.loreText,
    this.sortOrder = 0,
    int? cost,
  })  : category = category ?? cardType ?? 'action',
        effectText = effectText ?? description ?? '';

  factory CollectionCard.fromSupabase(
    Map<String, dynamic> row, {
    required int quantity,
  }) {
    return CollectionCard(
      id: row['id'] as String,
      code: row['code'] as String? ?? '',
      name: row['name'] as String? ?? 'Carte sans nom',
      category: row['category'] as String? ?? 'action',
      subtype: row['subtype'] as String?,
      relicMode: row['relic_mode'] as String?,
      rarity: row['rarity'] as String? ?? 'commune',
      rank: (row['rank'] as num?)?.toInt(),
      atk: (row['atk'] as num?)?.toInt(),
      def: (row['def'] as num?)?.toInt(),
      attribute: row['attribute'] as String?,
      primaryFamily: row['primary_family'] as String? ?? '',
      secondaryFamilies: List<String>.unmodifiable(
        (row['secondary_families'] as List? ?? const <Object>[])
            .map((value) => value.toString()),
      ),
      mythicSummonCondition: _jsonMap(row['mythic_summon_condition']),
      effectText: row['effect_text'] as String? ?? '',
      effectKey: row['effect_key'] as String?,
      effectData: _jsonMap(row['effect_data']) ?? const {},
      artUrl: row['art_url'] as String?,
      loreText: row['lore_text'] as String?,
      quantity: quantity,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String code;
  final String name;
  final String category;
  final String? subtype;
  final String? relicMode;
  final String rarity;
  final int? rank;
  final int? atk;
  final int? def;
  final String? attribute;
  final String primaryFamily;
  final List<String> secondaryFamilies;
  final Map<String, dynamic>? mythicSummonCondition;
  final String effectText;
  final String? effectKey;
  final Map<String, dynamic> effectData;
  final String? artUrl;
  final String? loreText;
  final int quantity;
  final int sortOrder;

  bool get isOwned => quantity > 0;
  bool get isCombatCard => category == 'personnage' || category == 'mythique';

  /// Chemin conventionnel des futures illustrations V2.
  /// L'UI affiche un placeholder si le fichier n'a pas encore été produit.
  String? get localArtAsset => code.trim().isEmpty
      ? null
      : 'assets/images/cards/${code.toLowerCase()}.png';

  // Compatibilité temporaire avec l'éditeur de deck V1, qui sera reconstruit.
  String get cardType => category;
  String get description => effectText;
  int get cost => rank ?? 0;

  static Map<String, dynamic>? _jsonMap(Object? value) {
    if (value is! Map) return null;
    return Map<String, dynamic>.from(value);
  }
}

String collectionLabel(String value) {
  final text = value.replaceAll('_', ' ').trim();
  if (text.isEmpty) return value;
  return '${text[0].toUpperCase()}${text.substring(1)}';
}

String describeMythicSummonCondition(
  Map<String, dynamic>? condition, {
  Map<String, String> cardNamesByCode = const {},
}) {
  if (condition == null || condition.isEmpty) return '';
  final method = condition['method']?.toString();
  final triggerCode = condition['trigger_card_code']?.toString();
  if (method == null || triggerCode == null || triggerCode.isEmpty) {
    return 'Condition d’invocation spéciale.';
  }

  final methodLabel = switch (method) {
    'fusion' => 'Invocation Fusion',
    'ancestrale' => 'Invocation Ancestrale',
    _ => 'Invocation spéciale',
  };
  final triggerName = cardNamesByCode[triggerCode] ?? triggerCode;
  return '$methodLabel via « $triggerName ».';
}
