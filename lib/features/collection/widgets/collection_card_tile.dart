import 'package:flutter/material.dart';

import '../collection_card.dart';
import 'card_artwork.dart';

class CollectionCardTile extends StatelessWidget {
  const CollectionCardTile({
    required this.card,
    required this.onTap,
    super.key,
  });

  final CollectionCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rarityColor = _rarityColor(card.rarity);
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: rarityColor, width: 2),
      ),
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Hero(
                    tag: 'collection-card-${card.id}',
                    child: CardArtwork(card: card),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: rarityColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              collectionLabel(card.rarity),
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        ],
                      ),
                      if (card.isCombatCard) ...[
                        const SizedBox(height: 5),
                        Text(
                          'Rang ${card.rank}  •  ${card.atk} ATK / ${card.def} DEF',
                          key: ValueKey('combat-stats-${card.id}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Badge(
                backgroundColor: card.isOwned
                    ? colors.primaryContainer
                    : colors.surfaceContainerHighest,
                textColor: card.isOwned
                    ? colors.onPrimaryContainer
                    : colors.onSurfaceVariant,
                label:
                    Text(card.isOwned ? '×${card.quantity}' : 'Non possédée'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _rarityColor(String rarity) => switch (rarity) {
        'légendaire' => const Color(0xFFFFB300),
        'épique' => const Color(0xFF9C5CE5),
        'rare' => const Color(0xFF3887D6),
        _ => const Color(0xFF78909C),
      };
}
