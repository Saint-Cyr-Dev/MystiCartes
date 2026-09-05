import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysticartes/features/battle/battle_screen.dart';
import 'package:mysticartes/features/battle/local_duel.dart';
import 'package:mysticartes/game/ai/ai_strategy.dart';
import 'package:mysticartes/game/ai/beginner_ai.dart';
import 'package:mysticartes/game/battle_state.dart';
import 'package:mysticartes/game/card.dart';
import 'package:mysticartes/game/duel_engine.dart';
import 'package:mysticartes/game/duel_types.dart';
import 'package:mysticartes/game/effects/effect_registry.dart';
import 'package:mysticartes/game/effects/foret_effects.dart';
import 'package:mysticartes/game/player.dart';

final class _ZeroRandom implements AiRandomSource {
  const _ZeroRandom();

  @override
  int nextInt(int max) => 0;
}

LocalDuelController _chainController() {
  final engine = DuelEngine(chainEffects: V2EffectRegistry.create());
  final quick = CardInstance(
    instanceId: 'quick-forest',
    cardId: 'card-for-008',
    cardCode: 'FOR-008',
    cardRevision: 1,
    category: CardCategory.action,
    rank: null,
    subtype: 'quick',
    primaryFamily: 'forêt',
    effectKey: ForetEffectKeys.for008,
    owner: DuelParticipant.player,
    controller: DuelParticipant.player,
    faceUp: false,
    position: null,
  );
  final state = DuelState(
    turnNumber: 2,
    activePlayer: DuelParticipant.ai,
    currentPhase: DuelPhase.main1,
    chain: ChainState(
      links: [
        ChainLink(
          linkId: 'enemy-action',
          effectKey: 'dummy',
          activatingPlayer: DuelParticipant.ai,
          speed: ChainSpeed.speed1,
        ),
      ],
      window: ResponseWindowType.effectActivation,
      priorityPlayer: DuelParticipant.player,
    ),
    playerField: PlayerFieldState.empty(
      participant: DuelParticipant.player,
      deck: const [],
    ).copyWith(hand: [quick]),
    aiField: PlayerFieldState.empty(
      participant: DuelParticipant.ai,
      deck: const [],
    ),
  );
  return LocalDuelController.forTesting(
    engine: engine,
    ai: createDuelAi(
      difficulty: AiDifficulty.beginner,
      engine: engine,
      random: const _ZeroRandom(),
    ),
    presentations: const {
      'FOR-008': LocalCardPresentation(
        code: 'FOR-008',
        name: 'Souffle de Germination',
        category: CardCategory.action,
        family: 'Forêt',
        attribute: 'Nature',
        subtype: 'quick',
        effectKey: ForetEffectKeys.for008,
      ),
    },
    state: state,
  );
}

void main() {
  Future<void> pumpBattle(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: BattleScreen.local(),
      ),
    );
    await tester.pump();
  }

  testWidgets('le changement de tour utilise une bannière animée temporaire',
      (tester) async {
    await pumpBattle(tester);

    expect(find.byKey(const Key('battle-moment-banner')), findsOneWidget);
    expect(find.text('TON TOUR'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('TON TOUR'), findsNothing);
  });

  testWidgets('un changement de phase montre son identité visuelle',
      (tester) async {
    await pumpBattle(tester);
    await tester.pump(const Duration(milliseconds: 1300));

    await tester.tap(find.byTooltip('Phase suivante'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('PHASE DE PRÉPARATION'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets(
      'une carte jouée au mauvais moment tremble et affiche une erreur locale',
      (tester) async {
    await pumpBattle(tester);
    final card = find.text('Gardien du Carrefour').first;
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byKey(const Key('battle-card-feedback')), findsOneWidget);
    expect(find.text('Attends une Phase Principale'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.byKey(const Key('battle-card-feedback')), findsNothing);
  });

  testWidgets(
      'la priorité fait pulser la carte et affiche Passer sans dialogue',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: BattleScreen.local(controller: _chainController()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 80));

    expect(
      find.byKey(const Key('battle-activatable-quick-forest')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('battle-chain-pass')), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(
      find.byKey(const Key('battle-activatable-quick-forest')),
    );
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byKey(const Key('battle-chain-pass')), findsOneWidget);
  });
}
