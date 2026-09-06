import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../app/mystic_navigation.dart';
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
  late final ScrollController _scrollController;
  late Future<List<CollectionCard>> _loadFuture;
  CollectionFilters _filters = const CollectionFilters();
  String _query = '';
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? CollectionRepository();
    _scrollController = ScrollController()..addListener(_onScroll);
    _loadFuture = _repository.fetchCollection();
  }

  void _onScroll() {
    final shouldShow =
        _scrollController.hasClients && _scrollController.offset > 280;
    if (shouldShow != _showScrollToTop) {
      setState(() => _showScrollToTop = shouldShow);
    }
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _reload() {
    setState(() => _loadFuture = _repository.fetchCollection());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF070814),
        appBar: AppBar(
          backgroundColor: const Color(0xFF090A18),
          surfaceTintColor: Colors.transparent,
          leading: const Padding(
            padding: EdgeInsets.all(9),
            child: _HeaderIcon(icon: Icons.menu_book_rounded),
          ),
          title: const Text('BIBLIOTHÈQUE',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .4)),
          actions: [
            IconButton(
              onPressed: _reload,
              tooltip: 'Actualiser',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        bottomNavigationBar: const MysticBottomNavigation(
          currentRoute: AppRoutes.collection,
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-.7, -.8),
              radius: 1.4,
              colors: [Color(0xFF241047), Color(0xFF080915)],
            ),
          ),
          child: FutureBuilder<List<CollectionCard>>(
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
              final needle = _query.trim().toLowerCase();
              final visibleCards = cards
                  .where(_filters.accepts)
                  .where((card) =>
                      needle.isEmpty ||
                      card.name.toLowerCase().contains(needle) ||
                      card.code.toLowerCase().contains(needle))
                  .toList(growable: false);
              final namesByCode = {
                for (final card in cards) card.code: card.name,
              };

              final owned = cards.where((card) => card.isOwned).toList();
              return LayoutBuilder(
                builder: (context, constraints) {
                  final columns = switch (constraints.maxWidth) {
                    >= 1200 => 6,
                    >= 960 => 5,
                    >= 720 => 4,
                    >= 480 => 3,
                    _ => 2,
                  };
                  return Stack(
                    children: [
                      CustomScrollView(
                        key: const ValueKey('collection-scroll-view'),
                        controller: _scrollController,
                        slivers: [
                          SliverToBoxAdapter(
                            child: _FilterPanel(
                              filters: _filters,
                              families: families,
                              onChanged: (filters) =>
                                  setState(() => _filters = filters),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: _CollectionSummary(
                              cards: cards,
                              owned: owned,
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                              child: TextField(
                                onChanged: (value) =>
                                    setState(() => _query = value),
                                decoration: InputDecoration(
                                  hintText: 'Rechercher une carte…',
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Text(
                                      '${visibleCards.length} carte${visibleCards.length > 1 ? 's' : ''} sur ${cards.length}',
                                      key: const ValueKey(
                                        'collection-result-count',
                                      ),
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xD9121222),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF4C3268),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (visibleCards.isEmpty)
                            const SliverFillRemaining(
                              hasScrollBody: false,
                              child: _EmptyCollection(),
                            )
                          else
                            SliverPadding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 16, 16, 88),
                              sliver: SliverGrid(
                                key: const ValueKey('collection-grid'),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  childAspectRatio: 0.56,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final card = visibleCards[index];
                                    return CollectionCardTile(
                                      key: ValueKey(
                                        'collection-card-${card.id}',
                                      ),
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
                                  childCount: visibleCards.length,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(
                            scale: animation,
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          ),
                          child: _showScrollToTop
                              ? FloatingActionButton.small(
                                  key: const ValueKey(
                                    'collection-scroll-to-top',
                                  ),
                                  heroTag: 'collection-scroll-to-top',
                                  tooltip: 'Revenir en haut',
                                  onPressed: _scrollToTop,
                                  backgroundColor: const Color(0xFF6E2AAA),
                                  foregroundColor: Colors.white,
                                  child: const Icon(Icons.keyboard_arrow_up),
                                )
                              : const SizedBox.shrink(
                                  key: ValueKey(
                                    'collection-scroll-to-top-hidden',
                                  ),
                                ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      );
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF171126),
          border: Border.all(color: const Color(0xFF65408C)),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, color: const Color(0xFFC275FF)),
      );
}

class _CollectionSummary extends StatelessWidget {
  const _CollectionSummary({required this.cards, required this.owned});
  final List<CollectionCard> cards;
  final List<CollectionCard> owned;

  @override
  Widget build(BuildContext context) {
    final copies = owned.fold<int>(0, (sum, card) => sum + card.quantity);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xD9131323),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF453052)),
      ),
      child: Row(children: [
        const _HeaderIcon(icon: Icons.auto_stories_rounded),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Ma collection',
              style: TextStyle(color: Color(0xFFD9C8EB))),
          Text('${owned.length} / ${cards.length}',
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          Text('$copies exemplaire${copies > 1 ? 's' : ''}',
              style: const TextStyle(color: Color(0xFFAD9DBD))),
        ])),
        const SizedBox(height: 48, child: VerticalDivider()),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Cartes utilisables',
              style: TextStyle(color: Color(0xFFD9C8EB))),
          Text('$copies cartes',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const Text('Construisez vos decks',
              style: TextStyle(color: Color(0xFFC275FF))),
        ])),
      ]),
    );
  }
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
        color: const Color(0xE0101020),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (final ownership in OwnershipFilter.values)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: FilterChip(
                          key: ValueKey('ownership-${ownership.name}'),
                          selected: filters.ownership == ownership,
                          showCheckmark: false,
                          label: SizedBox(
                            width: double.infinity,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(_ownershipLabel(ownership)),
                            ),
                          ),
                          onSelected: (_) => onChanged(
                            filters.copyWith(ownership: ownership),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              LayoutBuilder(builder: (context, constraints) {
                final narrow = constraints.maxWidth < 560;
                final fieldWidth = narrow
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 24) / 3;
                return Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: fieldWidth,
                      child: _DropdownFilter(
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
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: _DropdownFilter(
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
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: _DropdownFilter(
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
                    ),
                  ],
                );
              }),
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
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
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
