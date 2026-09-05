import 'advanced_ai.dart';
import 'beginner_ai.dart';
import 'expert_ai.dart';
import 'intermediate_ai.dart';
import '../battle_state.dart';
import '../duel_engine.dart';

enum AiDifficulty { beginner, intermediate, advanced, expert }

final class DuelAiTurnResult {
  DuelAiTurnResult({
    required this.state,
    List<String> actions = const [],
  }) : actions = List.unmodifiable(actions);

  final DuelState state;
  final List<String> actions;
}

abstract interface class DuelAiStrategy {
  AiDifficulty get difficulty;

  DuelAiTurnResult playTurn(DuelState state);

  DuelActionResult? playMainMonster(DuelState state);

  DuelActionResult? setBackrow(DuelState state);

  AttackDeclarationResult? declareAttack(DuelState state);

  /// Choisit une activation déjà préparée par le planificateur générique.
  /// La mutation réelle reste effectuée une seule fois par le contrôleur.
  ChainLink? chooseChainActivation({
    required DuelState state,
    required List<ChainLink> availableActivations,
  });

  DuelActionResult? discardExcessHand(DuelState state);
}

/// Point d'entrée unique utilisé par l'écran de combat pour les quatre
/// niveaux. Le générateur aléatoire et le planificateur restent injectables.
DuelAiStrategy createDuelAi({
  required AiDifficulty difficulty,
  required DuelEngine engine,
  AiRandomSource? random,
  AdvancedActivationPlanner? activationPlanner,
}) {
  return switch (difficulty) {
    AiDifficulty.beginner => _BeginnerStrategy(
        BeginnerAi(engine: engine, random: random),
      ),
    AiDifficulty.intermediate => _IntermediateStrategy(
        IntermediateAi(engine: engine, random: random),
      ),
    AiDifficulty.advanced => _AdvancedStrategy(
        AdvancedAi(
          engine: engine,
          random: random,
          activationPlanner: activationPlanner,
        ),
      ),
    AiDifficulty.expert => _ExpertStrategy(
        ExpertAi(
          engine: engine,
          random: random,
          activationPlanner: activationPlanner,
        ),
      ),
  };
}

final class _BeginnerStrategy implements DuelAiStrategy {
  const _BeginnerStrategy(this.ai);
  final BeginnerAi ai;

  @override
  AiDifficulty get difficulty => AiDifficulty.beginner;

  @override
  DuelAiTurnResult playTurn(DuelState state) {
    final result = ai.playUnopposedTurn(state);
    return DuelAiTurnResult(state: result.state, actions: result.actions);
  }

  @override
  DuelActionResult? playMainMonster(DuelState state) =>
      ai.playRandomMonster(state);

  @override
  DuelActionResult? setBackrow(DuelState state) =>
      ai.setRandomActionOrTrap(state);

  @override
  AttackDeclarationResult? declareAttack(DuelState state) =>
      ai.declareRandomAttack(state);

  @override
  ChainLink? chooseChainActivation({
    required DuelState state,
    required List<ChainLink> availableActivations,
  }) =>
      ai
          .handlePriority(
            state: state,
            availableActivations: availableActivations,
          )
          .activatedLink;

  @override
  DuelActionResult? discardExcessHand(DuelState state) =>
      ai.discardExcessHand(state);
}

final class _IntermediateStrategy implements DuelAiStrategy {
  const _IntermediateStrategy(this.ai);
  final IntermediateAi ai;

  @override
  AiDifficulty get difficulty => AiDifficulty.intermediate;

  @override
  DuelAiTurnResult playTurn(DuelState state) {
    final result = ai.playUnopposedTurn(state);
    return DuelAiTurnResult(state: result.state, actions: result.actions);
  }

  @override
  DuelActionResult? playMainMonster(DuelState state) =>
      ai.playBestMonster(state);

  @override
  DuelActionResult? setBackrow(DuelState state) =>
      ai.setUsefulActionOrTrap(state);

  @override
  AttackDeclarationResult? declareAttack(DuelState state) =>
      ai.declareBestAttack(state);

  @override
  ChainLink? chooseChainActivation({
    required DuelState state,
    required List<ChainLink> availableActivations,
  }) =>
      ai
          .handlePriority(
            state: state,
            availableActivations: availableActivations,
          )
          .activatedLink;

  @override
  DuelActionResult? discardExcessHand(DuelState state) =>
      ai.discardExcessHand(state);
}

final class _AdvancedStrategy implements DuelAiStrategy {
  const _AdvancedStrategy(this.ai);
  final AdvancedAi ai;

  @override
  AiDifficulty get difficulty => AiDifficulty.advanced;

  @override
  DuelAiTurnResult playTurn(DuelState state) {
    final result = ai.playUnopposedTurn(state);
    return DuelAiTurnResult(state: result.state, actions: result.actions);
  }

  @override
  DuelActionResult? playMainMonster(DuelState state) =>
      ai.playBestMonster(state);

  @override
  DuelActionResult? setBackrow(DuelState state) =>
      ai.setStrategicBackrow(state);

  @override
  AttackDeclarationResult? declareAttack(DuelState state) =>
      ai.declareBestAttack(state);

  @override
  ChainLink? chooseChainActivation({
    required DuelState state,
    required List<ChainLink> availableActivations,
  }) =>
      ai
          .handlePriority(
            state: state,
            availableActivations: availableActivations,
          )
          .activatedLink;

  @override
  DuelActionResult? discardExcessHand(DuelState state) =>
      ai.discardExcessHand(state);
}

final class _ExpertStrategy implements DuelAiStrategy {
  const _ExpertStrategy(this.ai);
  final ExpertAi ai;

  @override
  AiDifficulty get difficulty => AiDifficulty.expert;

  @override
  DuelAiTurnResult playTurn(DuelState state) {
    final result = ai.playUnopposedTurn(state);
    return DuelAiTurnResult(state: result.state, actions: result.actions);
  }

  @override
  DuelActionResult? playMainMonster(DuelState state) =>
      ai.playBestMonster(state);

  @override
  DuelActionResult? setBackrow(DuelState state) =>
      ai.setStrategicBackrow(state);

  @override
  AttackDeclarationResult? declareAttack(DuelState state) =>
      ai.declareNextAttack(state);

  @override
  ChainLink? chooseChainActivation({
    required DuelState state,
    required List<ChainLink> availableActivations,
  }) =>
      ai
          .handlePriority(
            state: state,
            availableActivations: availableActivations,
          )
          .activatedLink;

  @override
  DuelActionResult? discardExcessHand(DuelState state) =>
      ai.discardExcessHand(state);
}
