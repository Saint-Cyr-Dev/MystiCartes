import 'package:flutter/material.dart';

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
        appBar: AppBar(
          title: const Text('Mes decks'),
          actions: [
            IconButton(
              onPressed: _reload,
              tooltip: 'Actualiser',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          key: const ValueKey('create-deck-button'),
          onPressed: _openEditor,
          icon: const Icon(Icons.add),
          label: const Text('Nouveau deck'),
        ),
        body: FutureBuilder<List<DeckSummary>>(
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
            if (decks.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Vous n’avez encore aucun deck V2. Créez un brouillon pour commencer.',
                    key: ValueKey('empty-deck-list'),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: decks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final deck = decks[index];
                return Card(
                  child: ListTile(
                    leading: Icon(
                      deck.isReady ? Icons.style : Icons.edit_note,
                      color: deck.isSelected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    title: Text(deck.name),
                    subtitle: Text(
                      deck.isReady ? 'Prêt à jouer' : 'Brouillon',
                    ),
                    onTap: () => _openEditor(deck.id),
                    trailing: deck.isSelected
                        ? const Chip(
                            avatar: Icon(Icons.check, size: 18),
                            label: Text('Actif'),
                          )
                        : deck.isReady
                            ? FilledButton.tonal(
                                onPressed: () => _select(deck),
                                child: const Text('Sélectionner'),
                              )
                            : const Chip(label: Text('À compléter')),
                  ),
                );
              },
            );
          },
        ),
      );
}
