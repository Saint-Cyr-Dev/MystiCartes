import 'beginner_ai.dart';
import '../battle_state.dart';
import '../card.dart';
import '../duel_engine.dart';
import '../duel_types.dart';
import '../player.dart';

final class IntermediatePriorityDecision {
  const IntermediatePriorityDecision({
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

final class IntermediateTurnResult {
  IntermediateTurnResult({
    required this.state,
    List<String> actions = const [],
  }) : actions = List.unmodifiable(actions);

  final DuelState state;
  final List<String> actions;
}

/// IA V2 intermédiaire fondée sur des heuristiques locales et lisibles.
///
/// Elle ne lit jamais une zone cachée adverse et soumet toutes ses décisions
/// au [DuelEngine]. Les métadonnées optionnelles des réponses de Chaîne sont :
/// `preventsDestruction`, `preventsAttack`, `protectedCardInstanceId` et
/// `incomingDamage`. Elles permettent au planificateur d'effets/UI de décrire
/// l'utilité d'une activation sans introduire la logique des cartes ici.
final class IntermediateAi {
  IntermediateAi({
    required DuelEngine engine,
    AiRandomSource? random,
  })  : _engine = engine,
        _random = random ?? DartAiRandomSource();

  static const participant = DuelParticipant.ai;
  static const int importantMonsterAtk = 1800;
  static const int strongAttackDamage = 1500;

  final DuelEngine _engine;
  final AiRandomSource _random;

  DuelActionResult? playBestMonster(DuelState state) {
    if (!_canActInMainPhase(state) ||
        (state.normalSummonUsed[participant] ?? false)) {
      return null;
    }

    final candidates = legalNormalMonsterCandidates(state);
    if (candidates.isEmpty) return null;

    candidates.sort((left, right) {
      final attack =
          (right.effectiveAtk ?? 0).compareTo(left.effectiveAtk ?? 0);
      if (attack != 0) return attack;
      return (right.effectiveDef ?? 0).compareTo(left.effectiveDef ?? 0);
    });
    final best = candidates.first;
    final required = _engine.requiredSacrificesForNormalPlay(best)!;
    final sacrifices = preferredSacrificeIds(
      state: state,
      count: required,
    );

    final strongestEnemyAttack = state.playerField.characterZones
        .whereType<FieldCardInstance>()
        .where((card) => card.faceUp && card.position == BattlePosition.attack)
        .fold<int>(
            0,
            (value, card) =>
                (card.effectiveAtk ?? 0) > value ? card.effectiveAtk! : value);
    final shouldSet = strongestEnemyAttack > (best.effectiveAtk ?? 0);

    return shouldSet
        ? _engine.normalSet(
            state: state,
            participant: participant,
            cardInstanceId: best.instanceId,
            sacrificeInstanceIds: sacrifices,
          )
        : _engine.normalSummon(
            state: state,
            participant: participant,
            cardInstanceId: best.instanceId,
            sacrificeInstanceIds: sacrifices,
          );
  }

  DuelActionResult? setUsefulActionOrTrap(DuelState state) {
    if (!_canActInMainPhase(state) ||
        state.aiField.actionTrapZones.every((zone) => zone != null)) {
      return null;
    }
    final candidates = preferredBackrowCards(state);
    if (candidates.isEmpty) return null;

    final useful = candidates.where((card) => card.effectKey != null).toList();
    final selected = useful.isNotEmpty ? useful.first : candidates.first;
    return _engine.setActionOrTrap(
      state: state,
      participant: participant,
      cardInstanceId: selected.instanceId,
    );
  }

  /// Retourne `null` lorsque toutes les attaques disponibles constituent un
  /// échange clairement défavorable.
  AttackDeclarationResult? declareBestAttack(DuelState state) {
    if (state.isFinished ||
        state.activePlayer != participant ||
        state.currentPhase != DuelPhase.battle ||
        state.chain.isOpen) {
      return null;
    }

    final attackers = state.aiField.characterZones
        .whereType<FieldCardInstance>()
        .where((card) =>
            card.faceUp &&
            card.position == BattlePosition.attack &&
            !card.attackedThisTurn)
        .toList();
    if (attackers.isEmpty) return null;

    final defenders = state.playerField.characterZones
        .whereType<FieldCardInstance>()
        .toList();
    if (defenders.isEmpty) {
      attackers
          .sort((a, b) => (b.effectiveAtk ?? 0).compareTo(a.effectiveAtk ?? 0));
      for (final attacker in attackers) {
        final result = _engine.declareAttack(
          state: state,
          participant: participant,
          attackerInstanceId: attacker.instanceId,
        );
        if (result.succeeded) return result;
      }
      return null;
    }

    final favorable = <_AttackChoice>[];
    for (final attacker in attackers) {
      final attack = attacker.effectiveAtk ?? -1;
      for (final target in defenders) {
        // Une carte cachée reste une inconnue pour ce niveau : l'IA accepte de
        // la tester, mais la classe après les destructions certaines.
        final targetStat = target.faceUp
            ? target.position == BattlePosition.attack
                ? target.effectiveAtk
                : target.effectiveDef
            : null;
        if (targetStat != null && attack < targetStat) continue;
        final declaration = _engine.declareAttack(
          state: state,
          participant: participant,
          attackerInstanceId: attacker.instanceId,
          targetInstanceId: target.instanceId,
        );
        if (!declaration.succeeded) continue;
        final destroysSafely = targetStat != null && attack > targetStat;
        favorable.add(_AttackChoice(
          declaration: declaration,
          destroysSafely: destroysSafely,
          targetValue: target.faceUp
              ? (target.effectiveAtk ?? target.effectiveDef ?? 0)
              : 0,
          margin: targetStat == null ? 0 : attack - targetStat,
        ));
      }
    }
    if (favorable.isEmpty) return null;
    favorable.sort((left, right) {
      final safe =
          (right.destroysSafely ? 1 : 0).compareTo(left.destroysSafely ? 1 : 0);
      if (safe != 0) return safe;
      final value = right.targetValue.compareTo(left.targetValue);
      if (value != 0) return value;
      return right.margin.compareTo(left.margin);
    });
    return favorable.first.declaration;
  }

  IntermediatePriorityDecision handlePriority({
    required DuelState state,
    List<ChainLink> availableActivations = const [],
  }) {
    if (!state.chain.isOpen || state.chain.priorityPlayer != participant) {
      return IntermediatePriorityDecision(state: state);
    }

    final isOpponentResponseWindow = state.chain.links.isNotEmpty
        ? state.chain.links.last.activatingPlayer != participant
        : state.chain.window == ResponseWindowType.attackDeclaration;
    if (isOpponentResponseWindow) {
      final useful = availableActivations
          .where((link) =>
              link.activatingPlayer == participant &&
              _isOwnedQuickOrTrap(state, link) &&
              _preventsImportantLoss(state, link))
          .toList();
      for (final link in _stableRandomTies(useful)) {
        final activation =
            _engine.activateChainEffect(state: state, link: link);
        if (activation.succeeded) {
          return IntermediatePriorityDecision(
            state: activation.state,
            activatedLink: activation.link,
          );
        }
      }
    }

    final passed = _engine.passPriority(state: state, participant: participant);
    return IntermediatePriorityDecision(
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
    final sacrificeCount = _engine
        .legalNormalSacrificeIds(state: state, participant: participant)
        .length;
    final candidates = List<CardInstance>.from(requirement.candidates)
      ..sort((left, right) {
        final leftScore = _discardPriority(left, sacrificeCount);
        final rightScore = _discardPriority(right, sacrificeCount);
        final score = rightScore.compareTo(leftScore);
        if (score != 0) return score;
        return (right.rank ?? 0).compareTo(left.rank ?? 0);
      });
    return _engine.discardForHandLimit(
      state: state,
      participant: participant,
      cardInstanceIds: candidates
          .take(requirement.requiredCount)
          .map((card) => card.instanceId)
          .toList(growable: false),
    );
  }

  IntermediateTurnResult playUnopposedTurn(DuelState initialState) {
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
            return IntermediateTurnResult(state: state, actions: actions);
          }
          state = advanced.state;
        case DuelPhase.main1:
          if (!mainActionsPlayed) {
            final monster = playBestMonster(state);
            if (monster != null && monster.succeeded) {
              state = _settleUnopposedWindow(monster.state);
              actions.add('normal_monster_play');
            }
            final setCard = setUsefulActionOrTrap(state);
            if (setCard != null && setCard.succeeded) {
              state = _settleUnopposedWindow(setCard.state);
              actions.add('set_action_or_trap');
            }
            mainActionsPlayed = true;
          }
          state = _engine.advancePhase(state).state;
        case DuelPhase.battle:
          final attack = declareBestAttack(state);
          if (attack == null) {
            state = _engine.advancePhase(state).state;
            continue;
          }
          state = _settleUnopposedWindow(attack.state);
          state = _engine
              .resolveAttack(state: state, declaration: attack.declaration!)
              .state;
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
            return IntermediateTurnResult(state: state, actions: actions);
          }
          state = advanced.state;
      }
    }
    return IntermediateTurnResult(state: state, actions: actions);
  }

  /// Candidats que le moteur autorise à invoquer ou poser normalement.
  /// Exposé pour permettre aux niveaux supérieurs d'affiner le classement
  /// sans recopier les contrôles de rang, de zone et de sacrifices.
  List<CardInstance> legalNormalMonsterCandidates(DuelState state) {
    if (!_canActInMainPhase(state) ||
        (state.normalSummonUsed[participant] ?? false)) {
      return const [];
    }
    final field = state.aiField;
    final sacrificeIds = _engine.legalNormalSacrificeIds(
      state: state,
      participant: participant,
    );
    return field.hand.where((card) {
      final required = _engine.requiredSacrificesForNormalPlay(card);
      if (required == null || sacrificeIds.length < required) return false;
      return required > 0 || field.characterZones.any((zone) => zone == null);
    }).toList(growable: false);
  }

  /// Classe les cartes de soutien comme l'IA intermédiaire : Piège d'abord
  /// tant qu'aucun Piège n'est déjà posé, puis Action.
  List<CardInstance> preferredBackrowCards(DuelState state) {
    final hand = state.aiField.hand;
    final hasTrapSet = state.aiField.actionTrapZones
        .whereType<CardInstance>()
        .any((card) => card.category == CardCategory.trap);
    final preferredCategory =
        hasTrapSet ? CardCategory.action : CardCategory.trap;
    final preferred = hand
        .where((card) => card.category == preferredCategory)
        .toList(growable: false);
    final fallback = hand
        .where((card) =>
            card.category == CardCategory.action ||
            card.category == CardCategory.trap)
        .toList(growable: false);
    final result = preferred.isNotEmpty ? preferred : fallback;
    return [
      ...result.where((card) => card.effectKey != null),
      ...result.where((card) => card.effectKey == null)
    ];
  }

  /// Même politique de sacrifice que le niveau intermédiaire, réutilisable
  /// par les IA plus fortes.
  List<String> preferredSacrificeIds({
    required DuelState state,
    required int count,
  }) {
    final legalIds = _engine.legalNormalSacrificeIds(
      state: state,
      participant: participant,
    );
    return _chooseSacrifices(
      field: state.aiField,
      legalIds: legalIds,
      count: count,
    );
  }

  List<String> _chooseSacrifices({
    required PlayerFieldState field,
    required List<String> legalIds,
    required int count,
  }) {
    if (count == 0) return const [];
    final cards = field.characterZones
        .whereType<CardInstance>()
        .where((card) => legalIds.contains(card.instanceId))
        .toList()
      ..sort((left, right) {
        final group = _sacrificeGroup(left).compareTo(_sacrificeGroup(right));
        if (group != 0) return group;
        return (left.effectiveAtk ?? 0).compareTo(right.effectiveAtk ?? 0);
      });
    return cards.take(count).map((card) => card.instanceId).toList();
  }

  int _sacrificeGroup(CardInstance card) {
    if (card.effectKey == null || card.cardCode.endsWith('-003')) return 0;
    final continuous = card.subtype == 'continuous' ||
        card.effectData['continuous'] == true ||
        card.runtimeData['continuous_effect_active'] == true;
    return continuous ? 2 : 1;
  }

  bool _preventsImportantLoss(DuelState state, ChainLink link) {
    final preventsDestruction = link.payload['preventsDestruction'] == true;
    final preventsAttack = link.payload['preventsAttack'] == true;
    final incomingDamage = link.payload['incomingDamage'];
    if (preventsAttack &&
        incomingDamage is num &&
        incomingDamage.toInt() >= strongAttackDamage) {
      return true;
    }
    if (!preventsDestruction) return false;
    final protectedId = link.payload['protectedCardInstanceId'];
    if (protectedId is! String) return false;
    final protected = state.aiField.characterZones
        .whereType<FieldCardInstance>()
        .where((card) => card.instanceId == protectedId)
        .firstOrNull;
    return protected != null &&
        ((protected.effectiveAtk ?? 0) >= importantMonsterAtk ||
            protected is CardInstance && protected.effectKey != null);
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
    return false;
  }

  int _discardPriority(CardInstance card, int sacrifices) {
    final required = _engine.requiredSacrificesForNormalPlay(card);
    if (required != null && required > sacrifices) return 100 + required;
    if (card.category == CardCategory.mythic) return 1000;
    if (card.category == CardCategory.character) return card.rank ?? 0;
    return card.effectKey == null ? 20 : 0;
  }

  bool _canActInMainPhase(DuelState state) =>
      !state.isFinished &&
      state.activePlayer == participant &&
      (state.currentPhase == DuelPhase.main1 ||
          state.currentPhase == DuelPhase.main2) &&
      !state.chain.isOpen;

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

  List<ChainLink> _stableRandomTies(List<ChainLink> values) {
    if (values.length < 2) return values;
    final result = List<ChainLink>.from(values);
    final offset = _random.nextInt(result.length);
    return [...result.skip(offset), ...result.take(offset)];
  }
}

final class _AttackChoice {
  const _AttackChoice({
    required this.declaration,
    required this.destroysSafely,
    required this.targetValue,
    required this.margin,
  });

  final AttackDeclarationResult declaration;
  final bool destroysSafely;
  final int targetValue;
  final int margin;
}
