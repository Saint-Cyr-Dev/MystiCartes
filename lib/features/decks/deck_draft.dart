import '../collection/collection_card.dart';

enum DeckZone { main, mythic }

extension DeckZoneValue on DeckZone {
  String get databaseValue => name;
}

class DeckDraft {
  DeckDraft({
    required this.cards,
    Map<String, int>? initialMainQuantities,
    Map<String, int>? initialMythicQuantities,
    Map<String, int>? initialQuantities,
    String status = 'draft',
  })  : _mainQuantities = Map<String, int>.from(
          initialMainQuantities ?? initialQuantities ?? const {},
        ),
        _mythicQuantities = Map<String, int>.from(
          initialMythicQuantities ?? const {},
        ),
        _status = status;

  static const int mainDeckSize = 40;
  static const int mythicReserveLimit = 15;
  static const int maximumCopiesPerName = 3;

  // Alias temporaire pour les anciens appelants.
  static const int targetCardCount = mainDeckSize;
  static const int maximumCopiesPerCard = maximumCopiesPerName;

  final List<CollectionCard> cards;
  final Map<String, int> _mainQuantities;
  final Map<String, int> _mythicQuantities;
  String _status;

  String get status => _status;
  bool get isLocked => _status == 'ready';
  bool get isComplete => isReadyComposition;
  int get mainCount => _sum(_mainQuantities.values);
  int get mythicCount => _sum(_mythicQuantities.values);
  int get totalCards => mainCount + mythicCount;
  int get totalOwned => cards.fold(0, (sum, card) => sum + card.quantity);

  Map<String, int> get mainQuantities => Map.unmodifiable(_mainQuantities);
  Map<String, int> get mythicQuantities => Map.unmodifiable(_mythicQuantities);

  /// Compatibilité temporaire : l'ancien éditeur ne connaissait que le main.
  Map<String, int> get quantities => mainQuantities;

  int quantityFor(CollectionCard card, DeckZone zone) =>
      _quantities(zone)[card.id] ?? 0;

  int totalSelectedForCard(CollectionCard card) =>
      quantityFor(card, DeckZone.main) + quantityFor(card, DeckZone.mythic);

  int totalSelectedForName(String name) {
    final normalized = _normalizeName(name);
    return cards
        .where((card) => _normalizeName(card.name) == normalized)
        .fold(0, (sum, card) => sum + totalSelectedForCard(card));
  }

  bool isCompatible(CollectionCard card, DeckZone zone) => switch (zone) {
        DeckZone.main => const {
            'personnage',
            'action',
            'piège',
            'terrain',
            'relique',
          }.contains(card.category),
        DeckZone.mythic => card.category == 'mythique',
      };

  bool canAdd(CollectionCard card, DeckZone zone) {
    if (isLocked || !card.isOwned || !isCompatible(card, zone)) return false;
    if (zone == DeckZone.main && mainCount >= mainDeckSize) return false;
    if (zone == DeckZone.mythic && mythicCount >= mythicReserveLimit) {
      return false;
    }
    if (totalSelectedForName(card.name) >= maximumCopiesPerName) return false;
    return totalSelectedForCard(card) < card.quantity;
  }

  bool add(CollectionCard card, DeckZone zone) {
    if (!canAdd(card, zone)) return false;
    final quantities = _quantities(zone);
    quantities[card.id] = quantityFor(card, zone) + 1;
    return true;
  }

  bool remove(CollectionCard card, DeckZone zone) {
    if (isLocked) return false;
    final quantities = _quantities(zone);
    final current = quantityFor(card, zone);
    if (current <= 0) return false;
    if (current == 1) {
      quantities.remove(card.id);
    } else {
      quantities[card.id] = current - 1;
    }
    return true;
  }

  bool get exceedsOwnedCards {
    return cards.any((card) => totalSelectedForCard(card) > card.quantity);
  }

  bool get exceedsCopyLimit {
    final names = cards.map((card) => _normalizeName(card.name)).toSet();
    return names.any((name) {
      final sample = cards.firstWhere(
        (card) => _normalizeName(card.name) == name,
      );
      return totalSelectedForName(sample.name) > maximumCopiesPerName;
    });
  }

  bool get hasInvalidZones {
    final cardsById = {for (final card in cards) card.id: card};
    return _mainQuantities.keys.any(
          (id) =>
              cardsById[id] == null ||
              !isCompatible(cardsById[id]!, DeckZone.main),
        ) ||
        _mythicQuantities.keys.any(
          (id) =>
              cardsById[id] == null ||
              !isCompatible(cardsById[id]!, DeckZone.mythic),
        );
  }

  bool get isReadyComposition =>
      mainCount == mainDeckSize &&
      mythicCount <= mythicReserveLimit &&
      !exceedsOwnedCards &&
      !exceedsCopyLimit &&
      !hasInvalidZones;

  bool get canMarkReady => !isLocked && isReadyComposition;

  List<String> get validationMessages {
    final messages = <String>[];
    if (mainCount != mainDeckSize) {
      messages.add('$mainCount/$mainDeckSize cartes dans le deck principal.');
    }
    if (mythicCount > mythicReserveLimit) {
      messages.add(
        '$mythicCount/$mythicReserveLimit cartes dans la Réserve des Mythiques.',
      );
    }
    if (exceedsCopyLimit) {
      messages.add('Trois exemplaires maximum sont autorisés par nom.');
    }
    if (exceedsOwnedCards) {
      messages.add('Certaines quantités dépassent votre collection.');
    }
    if (hasInvalidZones) {
      messages.add('Certaines cartes sont placées dans une zone incompatible.');
    }
    return List.unmodifiable(messages);
  }

  bool markReady() {
    if (!canMarkReady) return false;
    _status = 'ready';
    return true;
  }

  bool unlockForEditing() {
    if (!isLocked) return false;
    _status = 'draft';
    return true;
  }

  Map<String, int> get categoryDistribution {
    final result = <String, int>{};
    for (final card in cards) {
      final selected = quantityFor(card, DeckZone.main);
      if (selected > 0) {
        result.update(
          card.category,
          (value) => value + selected,
          ifAbsent: () => selected,
        );
      }
    }
    return Map.unmodifiable(result);
  }

  Map<String, int> get typeDistribution => categoryDistribution;

  Map<String, int> _quantities(DeckZone zone) =>
      zone == DeckZone.main ? _mainQuantities : _mythicQuantities;

  static int _sum(Iterable<int> values) =>
      values.fold(0, (sum, value) => sum + value);

  static String _normalizeName(String name) => name.trim().toLowerCase();
}
