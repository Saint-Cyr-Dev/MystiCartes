import 'collection_card.dart';

enum OwnershipFilter { all, owned, unowned }

class CollectionFilters {
  const CollectionFilters({
    this.ownership = OwnershipFilter.all,
    this.category,
    this.rarity,
    this.primaryFamily,
    this.minimumRank = 1,
    this.maximumRank = 10,
  });

  final OwnershipFilter ownership;
  final String? category;
  final String? rarity;
  final String? primaryFamily;
  final int minimumRank;
  final int maximumRank;

  bool get rankFilterEnabled =>
      category == 'personnage' || category == 'mythique';

  CollectionFilters copyWith({
    OwnershipFilter? ownership,
    String? category,
    bool clearCategory = false,
    String? rarity,
    bool clearRarity = false,
    String? primaryFamily,
    bool clearPrimaryFamily = false,
    int? minimumRank,
    int? maximumRank,
  }) {
    return CollectionFilters(
      ownership: ownership ?? this.ownership,
      category: clearCategory ? null : category ?? this.category,
      rarity: clearRarity ? null : rarity ?? this.rarity,
      primaryFamily:
          clearPrimaryFamily ? null : primaryFamily ?? this.primaryFamily,
      minimumRank: minimumRank ?? this.minimumRank,
      maximumRank: maximumRank ?? this.maximumRank,
    );
  }

  bool accepts(CollectionCard card) {
    final ownershipMatches = switch (ownership) {
      OwnershipFilter.all => true,
      OwnershipFilter.owned => card.isOwned,
      OwnershipFilter.unowned => !card.isOwned,
    };
    final rankMatches = !rankFilterEnabled ||
        (card.rank != null &&
            card.rank! >= minimumRank &&
            card.rank! <= maximumRank);

    return ownershipMatches &&
        (category == null || card.category == category) &&
        (rarity == null || card.rarity == rarity) &&
        (primaryFamily == null || card.primaryFamily == primaryFamily) &&
        rankMatches;
  }
}
