import 'package:flutter/material.dart';

import '../collection/collection_card.dart';
import '../collection/widgets/card_artwork.dart';
import 'deck_draft.dart';
import 'deck_editor_repository.dart';

class DeckEditorScreen extends StatefulWidget {
  const DeckEditorScreen({
    this.deckId,
    this.repository,
    super.key,
  });

  final String? deckId;
  final DeckRepositoryContract? repository;

  @override
  State<DeckEditorScreen> createState() => _DeckEditorScreenState();
}

class _DeckEditorScreenState extends State<DeckEditorScreen> {
  late final DeckRepositoryContract _repository;
  final TextEditingController _nameController = TextEditingController();

  DeckDraft? _draft;
  String? _deckId;
  Object? _loadError;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _showNameError = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SupabaseDeckEditorRepository();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final data = await _repository.load(deckId: widget.deckId);
      if (!mounted) return;
      _nameController.text = data.name;
      setState(() {
        _deckId = data.deckId;
        _draft = DeckDraft(
          cards: data.cards,
          initialMainQuantities: data.mainQuantities,
          initialMythicQuantities: data.mythicQuantities,
          status: data.status,
        );
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _isLoading = false;
      });
    }
  }

  Future<void> _save({required bool markReady}) async {
    final draft = _draft;
    if (draft == null || draft.isLocked) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _showNameError = true);
      return;
    }
    if (markReady && !draft.canMarkReady) return;

    setState(() => _isSaving = true);
    try {
      final id = await _repository.saveDraft(
        deckId: _deckId,
        name: name,
        mainQuantities: draft.mainQuantities,
        mythicQuantities: draft.mythicQuantities,
      );
      if (markReady) {
        await _repository.markReady(id);
        draft.markReady();
      }
      if (!mounted) return;
      setState(() => _deckId = id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              markReady ? 'Deck marqué comme prêt.' : 'Brouillon sauvegardé.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de la sauvegarde : $error')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _unlock() async {
    final id = _deckId;
    final draft = _draft;
    if (id == null || draft == null || !draft.isLocked) return;
    setState(() => _isSaving = true);
    try {
      await _repository.unlockForEditing(id);
      if (!mounted) return;
      setState(() => draft.unlockForEditing());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de repasser en brouillon : $error')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF070814),
        appBar: AppBar(
          backgroundColor: const Color(0xFF090A18),
          surfaceTintColor: Colors.transparent,
          title: Text(
              widget.deckId == null ? 'NOUVEAU DECK' : 'ÉDITEUR DE DECK',
              style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -.9),
              radius: 1.5,
              colors: [Color(0xFF251047), Color(0xFF070814)],
            ),
          ),
          child: _buildBody(),
        ),
      );

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return _LoadError(error: _loadError, onRetry: _load);
    }
    final draft = _draft!;

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const _EditorSteps(),
          _DeckSummary(
            draft: draft,
            nameController: _nameController,
            showNameError: _showNameError,
            isSaving: _isSaving,
            onNameChanged: (_) => setState(() => _showNameError = false),
            onSave: () => _save(markReady: false),
            onReady: () => _save(markReady: true),
            onUnlock: _unlock,
          ),
          TabBar(
            tabs: [
              Tab(
                key: const ValueKey('main-zone-tab'),
                text: 'Deck principal ${draft.mainCount}/40',
              ),
              Tab(
                key: const ValueKey('mythic-zone-tab'),
                text: 'Mythiques ${draft.mythicCount}/15',
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _ZoneCollection(
                  draft: draft,
                  zone: DeckZone.main,
                  onChanged: () => setState(() {}),
                ),
                _ZoneCollection(
                  draft: draft,
                  zone: DeckZone.mythic,
                  onChanged: () => setState(() {}),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorSteps extends StatelessWidget {
  const _EditorSteps();
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(14, 12, 14, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xD9121222),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF453052)),
        ),
        child: const Row(children: [
          _StepBadge(number: '1', label: 'INFOS', active: true),
          Expanded(child: Divider()),
          _StepBadge(number: '2', label: 'CARTES', active: true),
          Expanded(child: Divider()),
          _StepBadge(number: '3', label: 'STRATÉGIE'),
          Expanded(child: Divider()),
          _StepBadge(number: '4', label: 'APERÇU'),
        ]),
      );
}

class _StepBadge extends StatelessWidget {
  const _StepBadge(
      {required this.number, required this.label, this.active = false});
  final String number;
  final String label;
  final bool active;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        CircleAvatar(
            radius: 15,
            backgroundColor:
                active ? const Color(0xFF873BD1) : const Color(0xFF222232),
            child: Text(number, style: const TextStyle(fontSize: 12))),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: active
                    ? const Color(0xFFE1B5FF)
                    : const Color(0xFF8F879A))),
      ]);
}

class _DeckSummary extends StatelessWidget {
  const _DeckSummary({
    required this.draft,
    required this.nameController,
    required this.showNameError,
    required this.isSaving,
    required this.onNameChanged,
    required this.onSave,
    required this.onReady,
    required this.onUnlock,
  });

  final DeckDraft draft;
  final TextEditingController nameController;
  final bool showNameError;
  final bool isSaving;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onSave;
  final VoidCallback onReady;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final distribution = draft.categoryDistribution.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xE8111220),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF493258)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: nameController,
              enabled: !draft.isLocked && !isSaving,
              maxLength: 50,
              onChanged: onNameChanged,
              decoration: InputDecoration(
                labelText: 'Nom du deck',
                prefixIcon:
                    const Icon(Icons.auto_awesome, color: Color(0xFFBC62F6)),
                errorText: showNameError ? 'Donnez un nom au deck.' : null,
                border: const OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _CountCard(
                  label: 'Deck principal',
                  value: draft.mainCount,
                  maximum: DeckDraft.mainDeckSize,
                ),
                const SizedBox(width: 10),
                _CountCard(
                  label: 'Réserve Mythique',
                  value: draft.mythicCount,
                  maximum: DeckDraft.mythicReserveLimit,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (distribution.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final entry in distribution)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('${_label(entry.key)} : ${entry.value}'),
                    ),
                ],
              ),
            if (draft.isLocked)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Ce deck est prêt et verrouillé. Repassez-le en brouillon pour le modifier.',
                  key: ValueKey('ready-deck-locked-message'),
                ),
              )
            else if (draft.validationMessages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  draft.validationMessages.join(' '),
                  key: const ValueKey('deck-validation-message'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                if (draft.isLocked)
                  OutlinedButton.icon(
                    onPressed: isSaving ? null : onUnlock,
                    icon: const Icon(Icons.edit),
                    label: const Text('Repasser en brouillon'),
                  )
                else ...[
                  OutlinedButton.icon(
                    onPressed: isSaving ? null : onSave,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Sauvegarder le brouillon'),
                  ),
                  FilledButton.icon(
                    key: const ValueKey('mark-ready-button'),
                    onPressed: !isSaving && draft.canMarkReady ? onReady : null,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Marquer comme prêt'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _label(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.label,
    required this.value,
    required this.maximum,
  });

  final String label;
  final int value;
  final int maximum;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border:
                Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              Text('$value/$maximum',
                  style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ),
      );
}

class _ZoneCollection extends StatelessWidget {
  const _ZoneCollection({
    required this.draft,
    required this.zone,
    required this.onChanged,
  });

  final DeckDraft draft;
  final DeckZone zone;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final cards = draft.cards.where((card) {
      return draft.isCompatible(card, zone) &&
          (card.isOwned || draft.quantityFor(card, zone) > 0);
    }).toList(growable: false);
    if (cards.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            zone == DeckZone.main
                ? 'Votre collection ne contient aucune carte utilisable dans le deck principal.'
                : 'Vous ne possédez encore aucune carte Mythique pour la Réserve.',
            key: ValueKey('empty-${zone.name}-collection'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: cards.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final card = cards[index];
        return _CardSelector(
          card: card,
          selectedQuantity: draft.quantityFor(card, zone),
          combinedQuantity: draft.totalSelectedForName(card.name),
          locked: draft.isLocked,
          canAdd: draft.canAdd(card, zone),
          onAdd: () {
            draft.add(card, zone);
            onChanged();
          },
          onRemove: () {
            draft.remove(card, zone);
            onChanged();
          },
        );
      },
    );
  }
}

class _CardSelector extends StatelessWidget {
  const _CardSelector({
    required this.card,
    required this.selectedQuantity,
    required this.combinedQuantity,
    required this.locked,
    required this.canAdd,
    required this.onAdd,
    required this.onRemove,
  });

  final CollectionCard card;
  final int selectedQuantity;
  final int combinedQuantity;
  final bool locked;
  final bool canAdd;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: SizedBox(
            width: 48,
            height: 66,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CardArtwork(card: card, placeholderIconSize: 22),
            ),
          ),
          title: Text(card.name),
          subtitle: Text(
            '${_label(card.category)} · $combinedQuantity/3 exemplaires · ${card.quantity} possédée(s)',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: !locked && selectedQuantity > 0 ? onRemove : null,
                tooltip: 'Retirer',
                icon: const Icon(Icons.remove_circle_outline),
              ),
              SizedBox(
                width: 24,
                child: Text('$selectedQuantity', textAlign: TextAlign.center),
              ),
              IconButton(
                onPressed: canAdd ? onAdd : null,
                tooltip: 'Ajouter',
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ),
      );

  static String _label(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
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
              const Text('Impossible de charger l’éditeur de deck.'),
              const SizedBox(height: 12),
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
