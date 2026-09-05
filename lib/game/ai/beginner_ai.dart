import 'dart:math';

import '../battle_state.dart';
import '../card.dart';
import '../duel_engine.dart';
import '../duel_types.dart';

abstract interface class AiRandomSource {
  int nextInt(int max);
}

final class DartAiRandomSource implements AiRandomSource {
  DartAiRandomSource([Random? random]) : _random = random ?? Random();

  final Random _random;

  @override
  int nextInt(int max) => _random.nextInt(max);
}

enum BeginnerMonsterPlay { summon, set }

final class BeginnerPriorityDecision {
  const BeginnerPriorityDecision({
    required this.state,
    this.activatedLink,
    this.passed = false,
    this.failure,
  });

  final DuelState state;
  final ChainLink? activatedLink;
  final bool passed;
  final DuelActionFailure? failure;
}

final class BeginnerTurnResult {
  BeginnerTurnResult({
    required this.state,
    List<String> actions = const [],
  }) : actions = List.unmodifiable(actions);

  final DuelState state;
  final List<String> actions;
}

/// IA V2 volontairement simple. Elle ne calcule aucun avantage stratégique :
/// elle choisit seulement au hasard parmi les actions que [DuelEngine] juge
/// légales.
final class BeginnerAi {
  BeginnerAi({
    required DuelEngine engine,
    AiRandomSource? random,
  })  : _engine = engine,
        _random = random ?? DartAiRandomSource();

  static const participant = DuelParticipant.ai;

  final DuelEngine _engine;
  final AiRandomSource _random;

  DuelActionResult? playRandomMonster(DuelState state) {
    if (!_canActInMainPhase(state) ||
        (state.normalSummonUsed[participant] ?? false)) {
      return null;
    }
    final field = state.aiField;
    final sacrifices = _engine.legalNormalSacrificeIds(
      state: state,
      participant: participant,
    );
    final candidates = field.hand.where((card) {
      final required = _engine.requiredSacrificesForNormalPlay(card);
      if (required == null || sacrifices.length < required) return false;
      return required > 0 || field.characterZones.any((zone) => zone == null);
    }).toList();
    if (candidates.isEmpty) return null;

    final card = _choose(candidates);
    final required = _engine.requiredSacrificesForNormalPlay(card)!;
    final sacrificeIds = _randomSubset(sacrifices, required);
    final play = _random.nextInt(2) == 0
        ? BeginnerMonsterPlay.summon
        : BeginnerMonsterPlay.set;
    return play == BeginnerMonsterPlay.summon
        ? _engine.normalSummon(
            state: state,
            participant: participant,
            cardInstanceId: card.instanceId,
            sacrificeInstanceIds: sacrificeIds,
          )
        : _engine.normalSet(
            state: state,
            participant: participant,
            cardInstanceId: card.instanceId,
            sacrificeInstanceIds: sacrificeIds,
          );
  }

  DuelActionResult? setRandomActionOrTrap(DuelState state) {
    if (!_canActInMainPhase(state) ||
        state.aiField.actionTrapZones.every((zone) => zone != null)) {
      return null;
    }
    final candidates = state.aiField.hand
        .where(
          (card) =>
              card.category == CardCategory.action ||
              card.category == CardCategory.trap,
        )
        .toList();
    if (candidates.isEmpty) return null;
    return _engine.setActionOrTrap(
      state: state,
      participant: participant,
      cardInstanceId: _choose(candidates).instanceId,
    );
  }

  AttackDeclarationResult? declareRandomAttack(DuelState state) {
    if (state.isFinished ||
        state.activePlayer != participant ||
        state.currentPhase != DuelPhase.battle ||
        state.chain.isOpen) {
      return null;
    }
    final defenders = state.playerField.characterZones
        .whereType<FieldCardInstance>()
        .map((card) => card.instanceId)
        .toList();
    final legal = <AttackDeclarationResult>[];
    for (final attacker
        in state.aiField.characterZones.whereType<FieldCardInstance>()) {
      final targetIds = defenders.isEmpty ? <String?>[null] : defenders;
      for (final targetId in targetIds) {
        final result = _engine.declareAttack(
          state: state,
          participant: participant,
          attackerInstanceId: attacker.instanceId,
          targetInstanceId: targetId,
        );
        if (result.succeeded) legal.add(result);
      }
    }
    return legal.isEmpty ? null : _choose(legal);
  }

  /// Passe toujours si le dernier maillon vient de l'adversaire. Dans une
  /// autre fenêtre, l'appelant peut fournir les activations rapides déjà
  /// préparées avec leurs cibles et coûts propres.
  BeginnerPriorityDecision handlePriority({
    required DuelState state,
    List<ChainLink> availableActivations = const [],
  }) {
    if (!state.chain.isOpen || state.chain.priorityPlayer != participant) {
      return BeginnerPriorityDecision(state: state);
    }
    final respondsToOpponent = state.chain.links.isNotEmpty &&
        state.chain.links.last.activatingPlayer != participant;
    if (!respondsToOpponent) {
      final candidates = availableActivations.where(
        (link) =>
            link.activatingPlayer == participant &&
            _isOwnedQuickOrTrap(state, link),
      );
      for (final link in _shuffled(candidates.toList())) {
        final activation =
            _engine.activateChainEffect(state: state, link: link);
        if (activation.succeeded) {
          return BeginnerPriorityDecision(
            state: activation.state,
            activatedLink: activation.link,
          );
        }
      }
    }

    final passed = _engine.passPriority(state: state, participant: participant);
    return BeginnerPriorityDecision(
      state: passed.state,
      passed: passed.succeeded,
      failure: passed.failure,
    );
  }

  DuelActionResult? discardExcessHand(DuelState state) {
    if (state.activePlayer != participant ||
        state.currentPhase != DuelPhase.end ||
        state.isFinished) {
      return null;
    }
    final requirement = _engine.handDiscardRequirement(state, participant);
    if (requirement == null) return null;
    final selected = _randomSubset(
      requirement.candidates.map((card) => card.instanceId).toList(),
      requirement.requiredCount,
    );
    return _engine.discardForHandLimit(
      state: state,
      participant: participant,
      cardInstanceIds: selected,
    );
  }

  /// Simulation pratique pour le solo local quand aucune réponse du joueur
  /// n'est fournie. Les APIs unitaires ci-dessus restent utilisables par l'UI
  /// pour laisser au joueur chaque véritable fenêtre de priorité.
  BeginnerTurnResult playUnopposedTurn(DuelState initialState) {
    var state = initialState;
    final actions = <String>[];
    var safety = 0;
    var mainActionsPlayed = false;
    while (!state.isFinished &&
        state.activePlayer == participant &&
        safety++ < 100) {
      if (state.chain.isOpen) {
        state = _settleUnopposedWindow(state);
        continue;
      }
      switch (state.currentPhase) {
        case DuelPhase.draw:
        case DuelPhase.preparation:
          final advanced = _engine.advancePhase(state);
          if (!advanced.succeeded) {
            return BeginnerTurnResult(state: state, actions: actions);
          }
          state = advanced.state;
        case DuelPhase.main1:
          if (!mainActionsPlayed) {
            final monster = playRandomMonster(state);
            if (monster != null && monster.succeeded) {
              state = monster.state;
              actions.add('normal_monster_play');
              state = _settleUnopposedWindow(state);
            }
            final setCard = setRandomActionOrTrap(state);
            if (setCard != null && setCard.succeeded) {
              state = setCard.state;
              actions.add('set_action_or_trap');
              state = _settleUnopposedWindow(state);
            }
            mainActionsPlayed = true;
          }
          state = _engine.advancePhase(state).state;
        case DuelPhase.battle:
          final attack = declareRandomAttack(state);
          if (attack == null) {
            state = _engine.advancePhase(state).state;
            continue;
          }
          state = _settleUnopposedWindow(attack.state);
          final combat = _engine.resolveAttack(
            state: state,
            declaration: attack.declaration!,
          );
          state = combat.state;
          actions.add('attack');
          if (state.chain.isOpen) state = _settleUnopposedWindow(state);
        case DuelPhase.main2:
          state = _engine.advancePhase(state).state;
        case DuelPhase.end:
          final discard = discardExcessHand(state);
          if (discard != null && discard.succeeded) {
            state = discard.state;
            actions.add('discard_for_hand_limit');
          }
          final advanced = _engine.advancePhase(state);
          if (!advanced.succeeded) {
            return BeginnerTurnResult(state: state, actions: actions);
          }
          state = advanced.state;
      }
    }
    return BeginnerTurnResult(state: state, actions: actions);
  }

  bool _canActInMainPhase(DuelState state) {
    return !state.isFinished &&
        state.activePlayer == participant &&
        (state.currentPhase == DuelPhase.main1 ||
            state.currentPhase == DuelPhase.main2) &&
        !state.chain.isOpen;
  }

  bool _isOwnedQuickOrTrap(DuelState state, ChainLink link) {
    final sourceId = link.sourceCardInstanceId;
    if (sourceId == null) return false;
    for (final card
        in state.aiField.actionTrapZones.whereType<CardInstance>()) {
      if (card.instanceId != sourceId || card.controller != participant) {
        continue;
      }
      return card.category == CardCategory.trap ||
          (card.category == CardCategory.action && card.subtype == 'quick');
    }
    for (final card in state.aiField.hand) {
      if (card.instanceId == sourceId &&
          card.controller == participant &&
          card.category == CardCategory.action &&
          card.subtype == 'quick') {
        return true;
      }
    }
    return false;
  }

  DuelState _settleUnopposedWindow(DuelState initialState) {
    var state = initialState;
    var safety = 0;
    while (state.chain.isOpen && safety++ < 10) {
      final priority = state.chain.priorityPlayer;
      if (priority == null) break;
      final passed = _engine.passPriority(state: state, participant: priority);
      if (!passed.succeeded) break;
      state = passed.state;
    }
    return state;
  }

  T _choose<T>(List<T> values) => values[_random.nextInt(values.length)];

  List<T> _randomSubset<T>(List<T> values, int count) {
    return _shuffled(values).take(count).toList(growable: false);
  }

  List<T> _shuffled<T>(List<T> values) {
    final result = List<T>.from(values);
    for (var index = result.length - 1; index > 0; index--) {
      final other = _random.nextInt(index + 1);
      final current = result[index];
      result[index] = result[other];
      result[other] = current;
    }
    return result;
  }
}
