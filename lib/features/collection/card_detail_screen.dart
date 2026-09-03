import 'package:flutter/material.dart';

import 'collection_card.dart';
import 'widgets/card_artwork.dart';

class CardDetailScreen extends StatelessWidget {
  const CardDetailScreen({
    required this.card,
    this.cardNamesByCode = const {},
    super.key,
  });

  final CollectionCard card;
  final Map<String, String> cardNamesByCode;

  @override
  Widget build(BuildContext context) {
    final summonText = describeMythicSummonCondition(
      card.mythicSummonCondition,
      cardNamesByCode: cardNamesByCode,
    );
    return Scaffold(
      appBar: AppBar(title: Text(card.name)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 2 / 3,
                    child: Hero(
                      tag: 'collection-card-${card.id}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: CardArtwork(
                          card: card,
                          placeholderIconSize: 80,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _Header(card: card),
                  const SizedBox(height: 20),
                  _Section(
                    title: 'Identité',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text(collectionLabel(card.category))),
                        if (card.subtype != null)
                          Chip(label: Text(collectionLabel(card.subtype!))),
                        if (card.relicMode != null)
                          Chip(
                            label: Text(
                              'Mode : ${collectionLabel(card.relicMode!)}',
                            ),
                          ),
                        Chip(
                          label: Text(
                            'Famille : ${collectionLabel(card.primaryFamily)}',
                          ),
                        ),
                        for (final family in card.secondaryFamilies)
                          Chip(
                            label: Text(
                              'Secondaire : ${collectionLabel(family)}',
                            ),
                          ),
                        if (card.attribute != null)
                          Chip(
                            label: Text(
                              'Attribut : ${collectionLabel(card.attribute!)}',
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (card.isCombatCard) ...[
                    const SizedBox(height: 20),
                    _Section(
                      title: 'Combat',
                      child: Wrap(
                        key: ValueKey('detail-combat-stats-${card.id}'),
                        spacing: 8,
                        children: [
                          Chip(label: Text('Rang ${card.rank}')),
                          Chip(label: Text('${card.atk} ATK')),
                          Chip(label: Text('${card.def} DEF')),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _Section(
                    title: 'Effet',
                    child: Text(
                      card.effectText.trim().isEmpty
                          ? 'Aucun effet.'
                          : card.effectText,
                    ),
                  ),
                  if (summonText.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _Section(
                      title: 'Condition d’invocation',
                      child: Text(summonText),
                    ),
                  ],
                  if (card.loreText?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 20),
                    _Section(
                      title: 'Texte culturel',
                      child: Text(
                        card.loreText!,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.card});

  final CollectionCard card;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(card.name,
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text(
                  '${collectionLabel(card.rarity)} · ${card.code}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          ),
          Chip(
            avatar: Icon(
              card.isOwned ? Icons.inventory_2 : Icons.lock_outline,
              size: 18,
            ),
            label: Text(
              card.isOwned ? '${card.quantity} possédée(s)' : 'Non possédée',
            ),
          ),
        ],
      );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          child,
        ],
      );
}
