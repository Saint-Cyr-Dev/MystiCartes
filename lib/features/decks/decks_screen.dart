import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../app/mystic_navigation.dart';
import 'deck_editor_repository.dart';
import 'deck_editor_screen.dart';

class DecksScreen extends StatefulWidget {
  const DecksScreen({this.repository, super.key});

  final DeckRepositoryContract? repository;

  @override
  State<DecksScreen> createState() => _DecksScreenState();
}

class _DecksScreenState extends State<DecksScreen> {
  late final DeckRepositoryContract _repository;
  late Future<List<DeckSummary>> _loadFuture;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SupabaseDeckEditorRepository();
    _loadFuture = _repository.listDecks();
  }

  void _reload() {
    setState(() => _loadFuture = _repository.listDecks());
  }

  Future<void> _openEditor([String? deckId]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DeckEditorScreen(
          deckId: deckId,
          repository: _repository,
        ),
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _select(DeckSummary deck) async {
    try {
      await _repository.selectForPlay(deck.id);
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('« ${deck.name} » est maintenant le deck actif.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de sélectionner ce deck : $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF070814),
        appBar: AppBar(
          backgroundColor: const Color(0xFF090A18),
          surfaceTintColor: Colors.transparent,
          title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MES DECKS',
                    style: TextStyle(fontWeight: FontWeight.w900)),
                Text('Créez, gérez et personnalisez vos decks.',
                    style: TextStyle(fontSize: 12, color: Color(0xFFBBA9CE))),
              ]),
          actions: [
            IconButton(
              onPressed: _reload,
              tooltip: 'Actualiser',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        bottomNavigationBar: const MysticBottomNavigation(
          currentRoute: AppRoutes.decks,
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-.8, -.9),
              radius: 1.5,
              colors: [Color(0xFF23103F), Color(0xFF070814)],
            ),
          ),
          child: FutureBuilder<List<DeckSummary>>(
            future: _loadFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Impossible de charger vos decks.'),
                        const SizedBox(height: 12),
                        Text('${snapshot.error}', textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                            onPressed: _reload, child: const Text('Réessayer')),
                      ],
                    ),
                  ),
                );
              }
              final decks = snapshot.data ?? const <DeckSummary>[];
              return LayoutBuilder(builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900
                    ? 3
                    : constraints.maxWidth >= 560
                        ? 2
                        : 1;
                final items = decks.length + 1;
                return GridView.builder(
                  padding: const EdgeInsets.all(18),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisExtent: 220,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: items,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _CreateDeckCard(
                          onTap: _openEditor, empty: decks.isEmpty);
                    }
                    final deck = decks[index - 1];
                    return _DeckCard(
                        deck: deck,
                        onOpen: () => _openEditor(deck.id),
                        onSelect: () => _select(deck));
                  },
                );
              });
            },
          ),
        ),
      );
}

class _CreateDeckCard extends StatelessWidget {
  const _CreateDeckCard({required this.onTap, required this.empty});
  final VoidCallback onTap;
  final bool empty;
  @override
  Widget build(BuildContext context) => InkWell(
        key: const ValueKey('create-deck-button'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xAA111121),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF8E3ED1), width: 1.4),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.add_circle_outline,
                size: 66, color: Color(0xFFC66CFF)),
            const SizedBox(height: 12),
            const Text('NOUVEAU DECK',
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: Color(0xFFD996FF))),
            const SizedBox(height: 6),
            Text(
                empty
                    ? 'Vous n’avez encore aucun deck V2. Créez un brouillon pour commencer.'
                    : 'Créez un deck personnalisé',
                key: empty ? const ValueKey('empty-deck-list') : null,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFBAA9CA))),
          ]),
        ),
      );
}

class _DeckCard extends StatelessWidget {
  const _DeckCard(
      {required this.deck, required this.onOpen, required this.onSelect});
  final DeckSummary deck;
  final VoidCallback onOpen;
  final VoidCallback onSelect;
  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xE8111220),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
              color: deck.isSelected
                  ? const Color(0xFFB650F0)
                  : const Color(0xFF3B304C)),
        ),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF2A1645),
                        border: Border.all(color: const Color(0xFF8F45CA))),
                    child: Icon(deck.isReady ? Icons.style : Icons.edit_note,
                        color: const Color(0xFFC875FF))),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(deck.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800))),
              ]),
              const Spacer(),
              Text(
                  deck.isReady
                      ? '40/40 cartes · Réserve Mythique'
                      : 'Deck en construction',
                  style: const TextStyle(color: Color(0xFFC9B8D9))),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                  value: deck.isReady ? 1 : .35,
                  color: const Color(0xFFB14EF2),
                  backgroundColor: const Color(0xFF292536)),
              const SizedBox(height: 12),
              Align(
                  alignment: Alignment.centerRight,
                  child: deck.isSelected
                      ? const Chip(
                          avatar: Icon(Icons.check, size: 18),
                          label: Text('Actif'))
                      : deck.isReady
                          ? FilledButton.tonal(
                              onPressed: onSelect,
                              child: const Text('Sélectionner'))
                          : const Chip(label: Text('À compléter'))),
            ]),
          ),
        ),
      );
}
