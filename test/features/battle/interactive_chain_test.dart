import 'package:flutter_test/flutter_test.dart';
import 'package:mysticartes/features/battle/local_duel.dart';
import 'package:mysticartes/game/ai/ai_strategy.dart';
import 'package:mysticartes/game/ai/beginner_ai.dart';
import 'package:mysticartes/game/battle_state.dart';
import 'package:mysticartes/game/card.dart';
import 'package:mysticartes/game/duel_engine.dart';
import 'package:mysticartes/game/duel_types.dart';
import 'package:mysticartes/game/effects/babi_effects.dart';
import 'package:mysticartes/game/effects/effect_registry.dart';
import 'package:mysticartes/game/player.dart';

final class _ZeroRandom implements AiRandomSource {
  const _ZeroRandom();

  @override
  int nextInt(int max) => 0;
}

CardInstance _card({
  required String id,
  required String code,
  required DuelParticipant owner,
  required CardCategory category,
  String? effectKey,
  String? subtype,
  int? atk,
  int? def,
  BattlePosition? position,
  bool faceUp = true,
  int? zoneIndex,
}) =>
    CardInstance(
      instanceId: id,
      cardId: 'card-$code',
      cardCode: code,
      cardRevision: 1,
      category: category,
      rank: category == CardCategory.character ? 4 : null,
      subtype: subtype,
      primaryFamily: 'babi',
      effectKey: effectKey,
      owner: owner,
      controller: owner,
      faceUp: faceUp,
      position: position,
      zoneIndex: zoneIndex,
      atk: atk,
      def: def,
    );

void main() {
  test('BAB-011 interrompt réellement une attaque IA via la priorité UI', () {
    final engine = DuelEngine(chainEffects: V2EffectRegistry.create());
    final attacker = _card(
      id: 'ai-attacker',
      code: 'BAB-003',
      owner: DuelParticipant.ai,
      category: CardCategory.character,
      atk: 1800,
      def: 1700,
      position: BattlePosition.attack,
      zoneIndex: 0,
    );
    final trap = _card(
      id: 'player-trap',
      code: 'BAB-011',
      owner: DuelParticipant.player,
      category: CardCategory.trap,
      subtype: 'normal',
      effectKey: BabiEffectKeys.bab011,
      faceUp: false,
      zoneIndex: 0,
    );
    final state = DuelState(
      turnNumber: 2,
      activePlayer: DuelParticipant.ai,
      currentPhase: DuelPhase.battle,
      playerField: PlayerFieldState.empty(
        participant: DuelParticipant.player,
        deck: const [],
      ).copyWith(actionTrapZones: [trap, null, null, null, null]),
      aiField: PlayerFieldState.empty(
        participant: DuelParticipant.ai,
        deck: const [],
      ).copyWith(characterZones: [attacker, null, null, null, null]),
    );
    final ai = createDuelAi(
      difficulty: AiDifficulty.beginner,
      engine: engine,
      random: const _ZeroRandom(),
    );
    final controller = LocalDuelController.forTesting(
      engine: engine,
      ai: ai,
      presentations: const {
        'BAB-003': LocalCardPresentation(
          code: 'BAB-003',
          name: 'Gardien du Carrefour',
          category: CardCategory.character,
          family: 'Babi',
          attribute: 'Terre',
          rank: 4,
          atk: 1800,
          def: 1700,
        ),
        'BAB-011': LocalCardPresentation(
          code: 'BAB-011',
          name: 'Feu Rouge Mystique',
          category: CardCategory.trap,
          family: 'Babi',
          attribute: 'Feu',
          subtype: 'normal',
          effectKey: BabiEffectKeys.bab011,
        ),
      },
      state: state,
    );

    controller.playAiUntilPlayerDecision();
    expect(controller.awaitingPlayerPriority, isTrue);
    expect(controller.pendingAiAttack, isNotNull);
    final option = controller.availablePlayerResponses().single;
    expect(option.card.cardCode, 'BAB-011');

    expect(controller.activatePlayerResponse(option: option).succeeded, isTrue);
    expect(controller.awaitingPlayerPriority, isTrue);
    expect(controller.passPlayerPriority().succeeded, isTrue);
    controller.playAiUntilPlayerDecision();

    expect(controller.state.playerLifePoints, 8000);
    final resolvedAttacker = controller.state.aiField.characterZones.first!;
    expect(resolvedAttacker.position, BattlePosition.defense);
    expect(resolvedAttacker.attackedThisTurn, isTrue);
    expect(controller.lastChainEvents.join(' '), contains('Résolu'));
  });
}
