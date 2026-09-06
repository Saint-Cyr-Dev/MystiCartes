import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysticartes/features/decks/deck_editor_repository.dart';
import 'package:mysticartes/features/decks/deck_editor_screen.dart';
import 'package:mysticartes/features/decks/decks_screen.dart';

class _EmptyDeckRepository implements DeckRepositoryContract {
  @override
  Future<DeckEditorData> load({String? deckId}) async => const DeckEditorData(
        name: '',
        status: 'draft',
        isSelected: false,
        cards: [],
        mainQuantities: {},
        mythicQuantities: {},
      );

  @override
  Future<List<DeckSummary>> listDecks() async => const [];

  @override
  Future<void> markReady(String deckId) async {}

  @override
  Future<String> saveDraft({
    String? deckId,
    required String name,
    required Map<String, int> mainQuantities,
    required Map<String, int> mythicQuantities,
  }) async =>
      'deck-id';

  @override
  Future<void> selectForPlay(String deckId) async {}

  @override
  Future<void> unlockForEditing(String deckId) async {}
}

class _MultipleDeckRepository extends _EmptyDeckRepository {
  String? selectedDeckId;

  @override
  Future<List<DeckSummary>> listDecks() async => const [
        DeckSummary(
          id: 'deck-one',
          name: 'Babi rapide',
          status: 'ready',
          isSelected: true,
        ),
        DeckSummary(
          id: 'deck-two',
          name: 'Forêt mystique',
          status: 'ready',
          isSelected: false,
        ),
        DeckSummary(
          id: 'deck-three',
          name: 'Masques en chantier',
          status: 'draft',
          isSelected: false,
        ),
      ];

  @override
  Future<void> selectForPlay(String deckId) async {
    selectedDeckId = deckId;
  }
}

void main() {
  testWidgets('une collection vide affiche un message clair', (tester) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: DeckEditorScreen(repository: _EmptyDeckRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Votre collection ne contient aucune carte utilisable dans le deck principal.',
      ),
      findsOneWidget,
    );
    final readyButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('mark-ready-button')),
    );
    expect(readyButton.onPressed, isNull);
    expect(find.text('0/40 cartes dans le deck principal.'), findsOneWidget);
  });

  testWidgets('liste plusieurs decks et permet de sélectionner un deck prêt',
      (tester) async {
    final repository = _MultipleDeckRepository();
    await tester.pumpWidget(
      MaterialApp(home: DecksScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Babi rapide'), findsOneWidget);
    expect(find.text('Forêt mystique'), findsOneWidget);
    expect(find.text('Masques en chantier'), findsOneWidget);
    expect(find.text('Actif'), findsOneWidget);
    expect(find.text('À compléter'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.text('Sélectionner'));
    await tester.pumpAndSettle();
    expect(repository.selectedDeckId, 'deck-two');
  });
}
