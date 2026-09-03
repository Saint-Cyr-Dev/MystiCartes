import 'package:mysticartes/features/auth/onboarding_repository.dart';
import 'package:mysticartes/features/battle/local_duel.dart';
import 'package:test/test.dart';

StarterDeckCardData starterCard({
  required int number,
  required int quantity,
  bool mythic = false,
}) {
  final code = 'BAB-${number.toString().padLeft(3, '0')}';
  final category = mythic
      ? 'mythique'
      : switch (number) {
          <= 7 => 'personnage',
          <= 10 => 'action',
          <= 12 => 'piège',
          13 => 'terrain',
          _ => 'relique',
        };
  return StarterDeckCardData(
    cardId: 'id-$code',
    code: code,
    name: 'Carte $code',
    category: category,
    quantity: quantity,
    revision: 1,
  );
}

Map<String, Object?> validStarterResponse({bool alreadyExisted = false}) => {
      'deck_id': 'starter-deck-v2',
      'player_name': 'Amani',
      'family': 'babi',
      'already_existed': alreadyExisted,
      'main_deck': [
        for (var number = 1; number <= 14; number++)
          starterCard(
            number: number,
            quantity: number == 3 ? 1 : 3,
          ).toJson(),
      ],
      'mythic_reserve': [
        starterCard(number: 15, quantity: 1, mythic: true).toJson(),
      ],
    };

void main() {
  group('première expérience V2', () {
    test('un deck ready envoie toujours directement vers l’accueil', () {
      final destination = destinationFor(
        const OnboardingStatus(hasIdentity: false, hasReadyDeck: true),
      );
      expect(destination, OnboardingDestination.home);
    });

    test('un compte sans identité commence par choisir son pseudo', () {
      final destination = destinationFor(
        const OnboardingStatus(hasIdentity: false, hasReadyDeck: false),
      );
      expect(destination, OnboardingDestination.chooseUsername);
    });

    test('un pseudo déjà choisi reprend au tutoriel sans deck ready', () {
      final destination = destinationFor(
        const OnboardingStatus(hasIdentity: true, hasReadyDeck: false),
      );
      expect(destination, OnboardingDestination.tutorial);
    });

    test('le deck Babi contient exactement 40 cartes et une Mythique', () {
      final deck = StarterDeckData.fromJson(validStarterResponse());
      final mainCount =
          deck.mainDeck.fold(0, (sum, card) => sum + card.quantity);
      final mythicCount =
          deck.mythicReserve.fold(0, (sum, card) => sum + card.quantity);

      expect(mainCount, 40);
      expect(mythicCount, 1);
      expect(deck.mainDeck.every((card) => card.quantity <= 3), isTrue);
      expect(
          deck.mainDeck.every((card) => card.category != 'mythique'), isTrue);
      expect(deck.mythicReserve.single.code, 'BAB-015');
    });

    test('le premier duel instancie réellement le deck et sa Réserve', () {
      final starter = StarterDeckData.fromJson(validStarterResponse());
      List<LocalCardPresentation> expand(List<StarterDeckCardData> cards) => [
            for (final card in cards)
              for (var copy = 0; copy < card.quantity; copy++)
                LocalCardPresentation.fromJson(card.toJson()),
          ];
      final duel = LocalDuelController.create(
        seed: 1,
        playerDeck: expand(starter.mainDeck),
        playerMythicReserve: expand(starter.mythicReserve),
      );

      expect(duel.state.playerField.hand, hasLength(5));
      expect(duel.state.playerField.deck, hasLength(35));
      expect(duel.state.playerField.mythicReserve, hasLength(1));
      expect(
        duel.state.playerField.mythicReserve.single.cardCode,
        'BAB-015',
      );
    });

    test('une réponse idempotente réutilise le même deck valide', () {
      final first = StarterDeckData.fromJson(validStarterResponse());
      final repeated = StarterDeckData.fromJson(
        validStarterResponse(alreadyExisted: true),
      );

      expect(repeated.deckId, first.deckId);
      expect(repeated.alreadyExisted, isTrue);
      expect(repeated.mainDeck.length, first.mainDeck.length);
    });

    test('refuse une composition dépassant trois exemplaires', () {
      final invalid = validStarterResponse();
      final cards = List<Map<String, Object?>>.from(
        invalid['main_deck']! as List,
      );
      cards[0] = {...cards[0], 'quantity': 4};
      invalid['main_deck'] = cards;

      expect(() => StarterDeckData.fromJson(invalid), throwsFormatException);
    });
  });
}
