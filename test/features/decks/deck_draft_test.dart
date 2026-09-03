import 'package:mysticartes/features/collection/collection_card.dart';
import 'package:mysticartes/features/decks/deck_draft.dart';
import 'package:test/test.dart';

CollectionCard card({
  required String id,
  required String category,
  int owned = 3,
  String? name,
}) {
  return CollectionCard(
    id: id,
    code: id,
    name: name ?? id,
    category: category,
    rarity: 'commune',
    primaryFamily: 'babi',
    effectText: '',
    quantity: owned,
  );
}

List<CollectionCard> fortyCardPool() => List.generate(
      14,
      (index) => card(id: 'main-$index', category: 'personnage'),
    );

Map<String, int> validMainComposition(List<CollectionCard> cards) => {
      for (var index = 0; index < cards.length; index++)
        cards[index].id: index < 13 ? 3 : 1,
    };

void main() {
  test('ajout et retrait respectent trois exemplaires par nom combinés', () {
    final main = card(id: 'main-copy', category: 'action', name: 'Même nom');
    final mythic = card(
      id: 'mythic-copy',
      category: 'mythique',
      name: 'Même nom',
    );
    final draft = DeckDraft(cards: [main, mythic]);

    expect(draft.add(main, DeckZone.main), isTrue);
    expect(draft.add(main, DeckZone.main), isTrue);
    expect(draft.add(mythic, DeckZone.mythic), isTrue);
    expect(draft.totalSelectedForName('Même nom'), 3);
    expect(draft.add(mythic, DeckZone.mythic), isFalse);
    expect(draft.remove(main, DeckZone.main), isTrue);
    expect(draft.totalSelectedForName('Même nom'), 2);
    expect(draft.add(mythic, DeckZone.mythic), isTrue);
  });

  test('refuse une Mythique dans le main et une non-Mythique en réserve', () {
    final character = card(id: 'character', category: 'personnage');
    final mythic = card(id: 'mythic', category: 'mythique');
    final draft = DeckDraft(cards: [character, mythic]);

    expect(draft.add(mythic, DeckZone.main), isFalse);
    expect(draft.add(character, DeckZone.mythic), isFalse);
    expect(draft.add(character, DeckZone.main), isTrue);
    expect(draft.add(mythic, DeckZone.mythic), isTrue);
  });

  test('refuse le passage ready sans quarante cartes principales', () {
    final character = card(id: 'one', category: 'personnage');
    final draft = DeckDraft(cards: [character]);
    draft.add(character, DeckZone.main);

    expect(draft.canMarkReady, isFalse);
    expect(draft.markReady(), isFalse);
    expect(draft.validationMessages,
        contains('1/40 cartes dans le deck principal.'));
  });

  test('valide un main de quarante cartes avec une réserve optionnelle valide',
      () {
    final cards = fortyCardPool();
    final mythic = card(id: 'mythic', category: 'mythique');
    final draft = DeckDraft(
      cards: [...cards, mythic],
      initialMainQuantities: validMainComposition(cards),
      initialMythicQuantities: {mythic.id: 2},
    );

    expect(draft.mainCount, 40);
    expect(draft.mythicCount, 2);
    expect(draft.canMarkReady, isTrue);
    expect(draft.markReady(), isTrue);
    expect(draft.status, 'ready');
  });

  test('un deck ready reste verrouillé jusqu’au retour explicite en draft', () {
    final character = card(id: 'locked', category: 'personnage');
    final draft = DeckDraft(
      cards: [character],
      initialMainQuantities: {character.id: 1},
      status: 'ready',
    );

    expect(draft.isLocked, isTrue);
    expect(draft.add(character, DeckZone.main), isFalse);
    expect(draft.remove(character, DeckZone.main), isFalse);
    expect(draft.unlockForEditing(), isTrue);
    expect(draft.remove(character, DeckZone.main), isTrue);
  });

  test('détecte une quantité non couverte par la collection', () {
    final character = card(id: 'scarce', category: 'personnage', owned: 1);
    final draft = DeckDraft(
      cards: [character],
      initialMainQuantities: {character.id: 2},
    );

    expect(draft.exceedsOwnedCards, isTrue);
    expect(draft.canMarkReady, isFalse);
  });
}
