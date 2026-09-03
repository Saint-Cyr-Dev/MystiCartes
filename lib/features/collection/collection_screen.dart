import 'package:flutter/material.dart';

import 'card_detail_screen.dart';
import 'collection_card.dart';
import 'collection_filters.dart';
import 'collection_repository.dart';
import 'widgets/collection_card_tile.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({this.repository, super.key});

  final CollectionRepositoryContract? repository;

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  late final CollectionRepositoryContract _repository;
  late Future<List<CollectionCard>> _loadFuture;
  CollectionFilters _filters = const CollectionFilters();

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? CollectionRepository();
    _loadFuture = _repository.fetchCollection();
  }

  void _reload() {
    setState(() => _loadFuture = _repository.fetchCollection());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Bibliothèque'),
          actions: [
            IconButton(
              onPressed: _reload,
              tooltip: 'Actualiser',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: FutureBuilder<List<CollectionCard>>(
          future: _loadFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _LoadError(error: snapshot.error, onRetry: _reload);
            }

            final cards = snapshot.data ?? const <CollectionCard>[];
            final families = cards
                .map((card) => card.primaryFamily)
                .where((family) => family.isNotEmpty)
                .toSet()
                .toList()
              ..sort();
            final visibleCards =
                cards.where(_filters.accepts).toList(growable: false);
            final namesByCode = {
              for (final card in cards) card.code: card.name,
            };

            return Column(
              children: [
                _FilterPanel(
                  filters: _filters,
                  families: families,
                  onChanged: (filters) => setState(() => _filters = filters),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${visibleCards.length} carte${visibleCards.length > 1 ? 's' : ''} sur ${cards.length}',
                      key: const ValueKey('collection-result-count'),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ),
                Expanded(
                  child: visibleCards.isEmpty
                      ? const _EmptyCollection()
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = switch (constraints.maxWidth) {
                              >= 1200 => 6,
                              >= 960 => 5,
                              >= 720 => 4,
                              >= 480 => 3,
                              _ => 2,
                            };
                            return GridView.builder(
                              key: const ValueKey('collection-grid'),
                              padding: const EdgeInsets.all(16),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                childAspectRatio: 0.56,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: visibleCards.length,
                              itemBuilder: (context, index) {
                                final card = visibleCards[index];
                                return CollectionCardTile(
                                  key: ValueKey('collection-card-${card.id}'),
                                  card: card,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => CardDetailScreen(
                                        card: card,
                                        cardNamesByCode: namesByCode,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      );
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.filters,
    required this.families,
    required this.onChanged,
  });

  static const categories = [
    'personnage',
    'action',
    'piège',
    'terrain',
    'relique',
    'mythique',
  ];
  static const rarities = ['commune', 'rare', 'épique', 'légendaire'];

  final CollectionFilters filters;
  final List<String> families;
  final ValueChanged<CollectionFilters> onChanged;

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final ownership in OwnershipFilter.values) ...[
                      FilterChip(
                        key: ValueKey('ownership-${ownership.name}'),
                        selected: filters.ownership == ownership,
                        label: Text(_ownershipLabel(ownership)),
                        onSelected: (_) => onChanged(
                          filters.copyWith(ownership: ownership),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _DropdownFilter(
                      key: const ValueKey('category-filter'),
                      label: 'Catégorie',
                      value: filters.category,
                      values: categories,
                      onChanged: (value) => onChanged(
                        filters.copyWith(
                          category: value,
                          clearCategory: value == null,
                          minimumRank: 1,
                          maximumRank: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _DropdownFilter(
                      key: const ValueKey('rarity-filter'),
                      label: 'Rareté',
                      value: filters.rarity,
                      values: rarities,
                      onChanged: (value) => onChanged(
                        filters.copyWith(
                          rarity: value,
                          clearRarity: value == null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _DropdownFilter(
                      key: const ValueKey('family-filter'),
                      label: 'Famille',
                      value: filters.primaryFamily,
                      values: families,
                      onChanged: (value) => onChanged(
                        filters.copyWith(
                          primaryFamily: value,
                          clearPrimaryFamily: value == null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (filters.rankFilterEnabled) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    SizedBox(
                      width: 88,
                      child: Text(
                        'Rang ${filters.minimumRank}–${filters.maximumRank}',
                      ),
                    ),
                    Expanded(
                      child: RangeSlider(
                        key: const ValueKey('rank-filter'),
                        min: 1,
                        max: 10,
                        divisions: 9,
                        labels: RangeLabels(
                          '${filters.minimumRank}',
                          '${filters.maximumRank}',
                        ),
                        values: RangeValues(
                          filters.minimumRank.toDouble(),
                          filters.maximumRank.toDouble(),
                        ),
                        onChanged: (range) => onChanged(
                          filters.copyWith(
                            minimumRank: range.start.round(),
                            maximumRank: range.end.round(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );

  static String _ownershipLabel(OwnershipFilter value) => switch (value) {
        OwnershipFilter.all => 'Toutes',
        OwnershipFilter.owned => 'Possédées',
        OwnershipFilter.unowned => 'Non possédées',
      };
}

class _DropdownFilter extends StatelessWidget {
  const _DropdownFilter({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
    super.key,
  });

  static const allValue = '__all__';

  final String label;
  final String? value;
  final List<String> values;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 172,
        child: DropdownButtonFormField<String>(
          value: value ?? allValue,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: [
            DropdownMenuItem(
              value: allValue,
              child: Text('$label : toutes'),
            ),
            for (final item in values)
              DropdownMenuItem(
                value: item,
                child: Text(collectionLabel(item)),
              ),
          ],
          onChanged: (selected) =>
              onChanged(selected == allValue ? null : selected),
        ),
      );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48),
              const SizedBox(height: 12),
              const Text('Impossible de charger la bibliothèque.'),
              const SizedBox(height: 8),
              Text('$error', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
}

class _EmptyCollection extends StatelessWidget {
  const _EmptyCollection();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Aucune carte ne correspond à ces filtres.'),
        ),
      );
}
