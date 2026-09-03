import 'package:mysticartes/features/collection/collection_card.dart';
import 'package:mysticartes/features/collection/collection_filters.dart';
import 'package:test/test.dart';

CollectionCard makeCard({
  required String id,
  required String category,
  required String rarity,
  required String family,
  required int quantity,
  int? rank,
}) {
  return CollectionCard(
    id: id,
    code: id,
    name: id,
    category: category,
    rarity: rarity,
    primaryFamily: family,
    rank: rank,
    atk: rank == null ? null : 1000,
    def: rank == null ? null : 1000,
    effectText: 'Effet',
    quantity: quantity,
  );
}

void main() {
  final ownedCharacter = makeCard(
    id: 'owned-character',
    category: 'personnage',
    rarity: 'rare',
    family: 'babi',
    quantity: 2,
    rank: 3,
  );
  final unownedMythic = makeCard(
    id: 'unowned-mythic',
    category: 'mythique',
    rarity: 'légendaire',
    family: 'masque',
    quantity: 0,
    rank: 10,
  );
  final unownedAction = makeCard(
    id: 'unowned-action',
    category: 'action',
    rarity: 'commune',
    family: 'babi',
    quantity: 0,
  );

  test('filtre individuellement par possession', () {
    const filters = CollectionFilters(ownership: OwnershipFilter.owned);
    expect(filters.accepts(ownedCharacter), isTrue);
    expect(filters.accepts(unownedMythic), isFalse);
  });

  test('filtre individuellement par catégorie', () {
    const filters = CollectionFilters(category: 'action');
    expect(filters.accepts(unownedAction), isTrue);
    expect(filters.accepts(ownedCharacter), isFalse);
  });

  test('filtre individuellement par rareté', () {
    const filters = CollectionFilters(rarity: 'légendaire');
    expect(filters.accepts(unownedMythic), isTrue);
    expect(filters.accepts(ownedCharacter), isFalse);
  });

  test('filtre individuellement par famille principale', () {
    const filters = CollectionFilters(primaryFamily: 'masque');
    expect(filters.accepts(unownedMythic), isTrue);
    expect(filters.accepts(unownedAction), isFalse);
  });

  test('filtre par plage de rang pour une catégorie combattante', () {
    const filters = CollectionFilters(
      category: 'personnage',
      minimumRank: 2,
      maximumRank: 4,
    );
    expect(filters.accepts(ownedCharacter), isTrue);
    expect(filters.accepts(unownedMythic), isFalse);
  });

  test('ignore le rang pour une catégorie non combattante', () {
    const filters = CollectionFilters(
      category: 'action',
      minimumRank: 8,
      maximumRank: 10,
    );
    expect(filters.rankFilterEnabled, isFalse);
    expect(filters.accepts(unownedAction), isTrue);
  });

  test('combine catégorie, rareté, famille, rang et possession', () {
    const filters = CollectionFilters(
      ownership: OwnershipFilter.owned,
      category: 'personnage',
      rarity: 'rare',
      primaryFamily: 'babi',
      minimumRank: 3,
      maximumRank: 3,
    );
    expect(filters.accepts(ownedCharacter), isTrue);
    expect(filters.accepts(unownedMythic), isFalse);
    expect(filters.accepts(unownedAction), isFalse);
  });
}
