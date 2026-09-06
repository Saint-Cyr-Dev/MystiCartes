import '../battle_state.dart';
import '../card.dart';
import '../duel_engine.dart';
import '../duel_types.dart';

import 'manual_activation_options.dart';
export 'manual_activation_options.dart';

/// Fabrique commune des activations choisies par un joueur.
///
/// Les effets automatiques (invocation, retournement, auras) sont exclus : ils
/// continuent d'emprunter PendingEffectTrigger/AutomaticEffectTrigger.
final class ManualActivationPlanner {
  const ManualActivationPlanner(this.engine);

  final DuelEngine engine;

  List<ManualActivationOption> legalOptions({
    required DuelState state,
    required DuelParticipant participant,
    ManualActivationContext context = const ManualActivationContext(),
  }) {
    if (state.isFinished) return const [];
    final field = participant == DuelParticipant.player
        ? state.playerField
        : state.aiField;
    final sources = <CardInstance>[
      ...field.actionTrapZones.whereType<CardInstance>(),
      ...field.hand.where((card) => state.chain.isOpen
          ? card.category == CardCategory.action && card.subtype == 'quick'
          : card.category == CardCategory.action ||
              card.category == CardCategory.terrain ||
              card.category == CardCategory.relic),
    ].where((card) => card.effectKey != null).toList(growable: false);
    final options = <ManualActivationOption>[];
    final effectiveContext = context
        .withAdditionalEvents(engine.pendingEventsForCurrentChain(state));
    for (final source in sources) {
      final definition = engine.chainEffectDefinition(source.effectKey!);
      if (definition == null) continue;
      final request = ManualActivationRequest(
          state: state,
          participant: participant,
          source: source,
          context: effectiveContext);
      for (final draft in definition.buildManualActivations(request)) {
        final result = engine.activateCard(
          state: state,
          participant: participant,
          cardInstanceId: source.instanceId,
          link: draft.link,
        );
        if (result.succeeded) options.add(draft);
      }
    }
    return List.unmodifiable(options);
  }
}
