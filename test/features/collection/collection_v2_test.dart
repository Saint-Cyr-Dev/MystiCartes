import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysticartes/features/collection/collection_card.dart';
import 'package:mysticartes/features/collection/collection_repository.dart';
import 'package:mysticartes/features/collection/collection_screen.dart';
import 'package:mysticartes/features/collection/widgets/collection_card_tile.dart';

class _FakeSource implements CollectionDataSource {
  _FakeSource(this.cards, [this.owned = const []]);

  final List<Map<String, dynamic>> cards;
  final List<Map<String, dynamic>> owned;

  @override
  Future<List<Map<String, dynamic>>> fetchActiveCards() async => cards;

  @override
  Future<List<Map<String, dynamic>>> fetchOwnedCards() async => owned;
}

class _FakeRepository implements CollectionRepositoryContract {
  _FakeRepository(this.cards);

  final List<CollectionCard> cards;

  @override
  Future<List<CollectionCard>> fetchCollection() async => cards;
}

Map<String, dynamic> _row(int index) => {
      'id': 'id-$index',
      'code': 'TST-${index.toString().padLeft(3, '0')}',
      'name': 'Carte $index',
      'category': 'action',
      'subtype': 'normal',
      'relic_mode': null,
      'rarity': 'commune',
      'rank': null,
      'atk': null,
      'def': null,
      'attribute': 'vent',
      'primary_family': 'babi',
      'secondary_families': <String>[],
      'mythic_summon_condition': null,
      'effect_text': 'Effet de test.',
      'effect_key': 'test_$index',
      'effect_data': <String, dynamic>{},
      'lore_text': null,
      'art_url': null,
      'sort_order': index,
    };

CollectionCard _card({
  required String id,
  String category = 'action',
  int? rank,
}) {
  return CollectionCard(
    id: id,
    code: id,
    name: 'Carte $id',
    category: category,
    rarity: 'commune',
    rank: rank,
    atk: rank == null ? null : 1800,
    def: rank == null ? null : 1600,
    attribute: 'vent',
    primaryFamily: 'babi',
    effectText: 'Effet.',
    quantity: 0,
  );
}

void main() {
  test('charge les 150 cartes et accepte une collection entièrement vide',
      () async {
    final source = _FakeSource(List.generate(150, _row));
    final cards = await CollectionRepository(source: source).fetchCollection();

    expect(cards, hasLength(150));
    expect(cards.every((card) => !card.isOwned), isTrue);
  });

  test('croise les quantités de player_cards avec le catalogue', () async {
    final source = _FakeSource(
      [_row(1), _row(2)],
      [
        {'card_id': 'id-2', 'quantity': 3},
      ],
    );
    final cards = await CollectionRepository(source: source).fetchCollection();

    expect(cards[0].quantity, 0);
    expect(cards[1].quantity, 3);
  });

  testWidgets('affiche le compteur et une grille alimentée par 150 cartes',
      (tester) async {
    final cards = List.generate(150, (index) => _card(id: 'card-$index'));
    await tester.pumpWidget(
      MaterialApp(
        home: CollectionScreen(repository: _FakeRepository(cards)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('150 cartes sur 150'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    final grid = tester
        .widget<SliverGrid>(find.byKey(const ValueKey('collection-grid')));
    final delegate = grid.delegate as SliverChildBuilderDelegate;
    expect(delegate.childCount, 150);
  });

  testWidgets('toute la bibliothèque défile et permet de revenir en haut',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cards = List.generate(40, (index) => _card(id: 'scroll-$index'));
    await tester.pumpWidget(
      MaterialApp(
        home: CollectionScreen(repository: _FakeRepository(cards)),
      ),
    );
    await tester.pumpAndSettle();

    const scrollViewKey = ValueKey('collection-scroll-view');
    const scrollTopKey = ValueKey('collection-scroll-to-top');
    expect(find.byKey(scrollTopKey), findsNothing);

    await tester.drag(
      find.byKey(scrollViewKey),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(scrollTopKey), findsOneWidget);
    await tester.tap(find.byKey(scrollTopKey));
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(scrollViewKey),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(scrollable.position.pixels, closeTo(0, .01));
    expect(find.byKey(scrollTopKey), findsNothing);
  });

  testWidgets('les filtres restent entièrement accessibles sur téléphone',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: CollectionScreen(
          repository: _FakeRepository([_card(id: 'mobile')]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final key in const [
      ValueKey('category-filter'),
      ValueKey('rarity-filter'),
      ValueKey('family-filter'),
    ]) {
      expect(find.byKey(key), findsOneWidget);
      final rect = tester.getRect(find.byKey(key));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(390));
    }
  });

  testWidgets('une carte non combattante ne montre aucune statistique ATK/DEF',
      (tester) async {
    final action = _card(id: 'action');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220,
            height: 360,
            child: CollectionCardTile(card: action, onTap: () {}),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('combat-stats-action')), findsNothing);
    expect(find.textContaining('ATK'), findsNothing);
    expect(find.textContaining('DEF'), findsNothing);
  });

  test('traduit une condition mythique en langage lisible', () {
    final text = describeMythicSummonCondition(
      const {
        'method': 'fusion',
        'trigger_card_code': 'BAB-010',
      },
      cardNamesByCode: const {
        'BAB-010': 'Battement de la Ville',
      },
    );

    expect(text, 'Invocation Fusion via « Battement de la Ville ».');
    expect(text, isNot(contains('{')));
  });
}
