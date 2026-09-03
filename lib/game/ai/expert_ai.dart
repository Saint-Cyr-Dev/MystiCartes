import 'advanced_ai.dart';
import 'beginner_ai.dart';
import '../battle_state.dart';
import '../card.dart';
import '../duel_engine.dart';
import '../duel_types.dart';

enum RiskPosture { prudent, balanced, desperate }

final class ExpertAttackStep {
  const ExpertAttackStep({
    required this.attackerInstanceId,
    this.targetInstanceId,
    required this.purpose,
  });

  final String attackerInstanceId;
  final String? targetInstanceId;
  final String purpose;
}

final class ExpertAttackPlan {
  ExpertAttackPlan(List<ExpertAttackStep> steps)
      : steps = List.unmodifiable(steps);

  final List<ExpertAttackStep> steps;
}

final class ExpertMythicPlan {
  ExpertMythicPlan({
    required this.mythicInstanceId,
    required this.mythicCardCode,
    required this.triggerCardCode,
    required this.method,
    required List<String> requiredMaterialCodes,
    required List<String> missingMaterialCodes,
    required Set<String> requiredFamilies,
    required this.minimumTotalRank,
    required this.currentTotalRank,
    required Set<String> reservedCardInstanceIds,
    required this.ready,
  })  : requiredMaterialCodes = List.unmodifiable(requiredMaterialCodes),
        missingMaterialCodes = List.unmodifiable(missingMaterialCodes),
        requiredFamilies = Set.unmodifiable(requiredFamilies),
        reservedCardInstanceIds = Set.unmodifiable(reservedCardInstanceIds);

  final String mythicInstanceId;
  final String mythicCardCode;
  final String triggerCardCode;
  final String method;
  final List<String> requiredMaterialCodes;
  final List<String> missingMaterialCodes;
  final Set<String> requiredFamilies;
  final int minimumTotalRank;
  final int currentTotalRank;
  final Set<String> reservedCardInstanceIds;
  final bool ready;
}

final class ExpertPriorityDecision {
  const ExpertPriorityDecision({
    required this.state,
    this.activatedLink,
    this.passed = false,
    this.heldImportantEffect = false,
    this.failure,
  });

  final DuelState state;
  final ChainLink? activatedLink;
  final bool passed;
  final bool heldImportantEffect;
  final DuelActionFailure? failure;
}

final class ExpertTurnResult {
  ExpertTurnResult({
    required this.state,
    List<String> actions = const [],
  }) : actions = List.unmodifiable(actions);

  final DuelState state;
  final List<String> actions;
}

/// Couche d'anticipation à profondeur courte au-dessus de [AdvancedAi].
///
/// Les simulations travaillent sur des copies immuables de [DuelState]. Elles
/// ne cherchent pas tout l'arbre : elles projettent une réponse adverse
/// plausible, puis un second coup, ce qui garde le coût adapté à un duel local.
final class ExpertAi {
  ExpertAi({
    required DuelEngine engine,
    AiRandomSource? random,
    AdvancedActivationPlanner? activationPlanner,
  })  : _engine = engine,
        _advanced = AdvancedAi(
          engine: engine,
          random: random,
          activationPlanner: activationPlanner,
        ),
        _activationPlanner = activationPlanner;

  static const participant = DuelParticipant.ai;

  final DuelEngine _engine;
  final AdvancedAi _advanced;
  final AdvancedActivationPlanner? _activationPlanner;
  ExpertMythicPlan? _mythicPlan;

  ExpertMythicPlan? get currentMythicPlan => _mythicPlan;

  BoardEvaluation evaluateBoard(DuelState state) =>
      _advanced.evaluateBoard(state);

  RiskPosture riskPosture(DuelState state) {
    final board = evaluateBoard(state);
    if (board.score >= 1200 && board.ownLifePoints > 2500) {
      return RiskPosture.prudent;
    }
    if (board.score <= -1000 ||
        (board.ownLifePoints <= 2000 && board.isBehind)) {
      return RiskPosture.desperate;
    }
    return RiskPosture.balanced;
  }

  /// Met à jour le même objectif Mythique au fil des tours tant que la carte
  /// reste dans la Réserve. Les matériaux identifiés sont marqués à préserver.
  ExpertMythicPlan? updateMythicPlan(DuelState state) {
    final reserve = state.aiField.mythicReserve;
    if (reserve.isEmpty) {
      _mythicPlan = null;
      return null;
    }
    final candidates = reserve.where((card) {
      final condition = card.mythicSummonCondition;
      return condition['trigger_card_code'] is String &&
          (condition['method'] == 'fusion' ||
              condition['method'] == 'ancestrale');
    }).toList();
    if (candidates.isEmpty) {
      _mythicPlan = null;
      return null;
    }
    candidates.sort((left, right) {
      final leftValue =
          (left.effectiveAtk ?? 0) + (left.effectiveDef ?? 0) ~/ 2;
      final rightValue =
          (right.effectiveAtk ?? 0) + (right.effectiveDef ?? 0) ~/ 2;
      return rightValue.compareTo(leftValue);
    });
    final previousId = _mythicPlan?.mythicInstanceId;
    final mythic =
        candidates.where((card) => card.instanceId == previousId).firstOrNull ??
            candidates.first;
    final condition = mythic.mythicSummonCondition;
    final requiredCodes = <String>[];
    final families = <String>{};
    var minimumRank = 0;
    var rankSource = 'field';

    void readRequirement(Object? value) {
      if (value is List) {
        for (final item in value) {
          readRequirement(item);
        }
        return;
      }
      if (value is! Map) return;
      final code = value['card_code'];
      final quantity = _integer(value['quantity'], fallback: 1);
      if (code is String) {
        for (var index = 0; index < quantity; index++) {
          requiredCodes.add(code);
        }
      }
      final rawFamilies = value['families'];
      if (rawFamilies is List) families.addAll(rawFamilies.whereType<String>());
      final rank = _integer(value['minimum_total_rank']);
      if (rank > minimumRank) {
        minimumRank = rank;
        rankSource = value['source'] as String? ?? 'field';
      }
      readRequirement(value['materials']);
      readRequirement(value['requirements']);
      readRequirement(value['all']);
    }

    readRequirement(condition);
    final accessibleCharacters = <CardInstance>[
      ...state.aiField.characterZones.whereType<CardInstance>(),
      ...state.aiField.hand
          .where((card) => card.category == CardCategory.character),
      ...state.aiField.graveyard
          .where((card) => card.category == CardCategory.character),
    ];
    final materialSource = condition['source'] as String? ?? 'field';
    final positionedMaterials = materialSource == 'graveyard'
        ? state.aiField.graveyard
        : state.aiField.characterZones.whereType<CardInstance>();
    final availableByCode = <String, int>{};
    for (final card in positionedMaterials) {
      availableByCode.update(card.cardCode, (count) => count + 1,
          ifAbsent: () => 1);
    }
    final missing = <String>[];
    final consumed = <String, int>{};
    for (final code in requiredCodes) {
      final used = consumed[code] ?? 0;
      if (used >= (availableByCode[code] ?? 0)) missing.add(code);
      consumed[code] = used + 1;
    }
    final rankCandidates = rankSource == 'graveyard'
        ? state.aiField.graveyard
        : state.aiField.characterZones.whereType<CardInstance>();
    final familyCards = rankCandidates.where(
      (card) => families.isEmpty || families.any(card.hasFamily),
    );
    final currentRank = familyCards.fold<int>(
      0,
      (sum, card) => sum + (card.rank ?? 0),
    );
    final reserved = accessibleCharacters
        .where((card) =>
            requiredCodes.contains(card.cardCode) ||
            families.any(card.hasFamily))
        .map((card) => card.instanceId)
        .toSet();
    final triggerAvailable = <CardInstance>[
      ...state.aiField.hand,
      ...state.aiField.actionTrapZones.whereType<CardInstance>(),
    ].any((card) => card.cardCode == condition['trigger_card_code']);
    final exactReady = missing.isEmpty;
    final rankReady = minimumRank == 0 || currentRank >= minimumRank;
    _mythicPlan = ExpertMythicPlan(
      mythicInstanceId: mythic.instanceId,
      mythicCardCode: mythic.cardCode,
      triggerCardCode: condition['trigger_card_code']! as String,
      method: condition['method']! as String,
      requiredMaterialCodes: requiredCodes,
      missingMaterialCodes: missing,
      requiredFamilies: families,
      minimumTotalRank: minimumRank,
      currentTotalRank: currentRank,
      reservedCardInstanceIds: reserved,
      ready: exactReady && rankReady && triggerAvailable,
    );
    return _mythicPlan;
  }

  DuelActionResult? playBestMonster(DuelState state) {
    final plan = updateMythicPlan(state);
    final candidates = _advanced.legalNormalMonsterCandidates(state);
    if (candidates.isEmpty) return null;
    CardInstance? plannedMaterial;
    if (plan != null && !plan.ready) {
      final planned = candidates.where((card) =>
          plan.missingMaterialCodes.contains(card.cardCode) ||
          plan.requiredFamilies.any(card.hasFamily));
      if (planned.isNotEmpty) {
        plannedMaterial = planned.reduce((left, right) =>
            (left.rank ?? 0) >= (right.rank ?? 0) ? left : right);
      }
    }
    if (plannedMaterial == null) return _advanced.playBestMonster(state);

    final required =
        _engine.requiredSacrificesForNormalPlay(plannedMaterial) ?? 0;
    final preferred = _advanced.preferredSacrificeIds(
      state: state,
      count: required,
    );
    final safeSacrifices = preferred
        .where((id) => !(plan?.reservedCardInstanceIds.contains(id) ?? false))
        .toList();
    if (safeSacrifices.length < required) {
      return _advanced.playBestMonster(state);
    }
    final board = evaluateBoard(state);
    final shouldSet = board.opponentHasProbableTrap &&
        _advanced.evaluateMonsterCandidate(state, plannedMaterial) >= 2500;
    return shouldSet
        ? _engine.normalSet(
            state: state,
            participant: participant,
            cardInstanceId: plannedMaterial.instanceId,
            sacrificeInstanceIds: safeSacrifices.take(required).toList(),
          )
        : _engine.normalSummon(
            state: state,
            participant: participant,
            cardInstanceId: plannedMaterial.instanceId,
            sacrificeInstanceIds: safeSacrifices.take(required).toList(),
          );
  }

  /// Expose les choix de support de la couche avancée au pilote de tour
  /// interactif. La légalité reste entièrement vérifiée par le moteur.
  DuelActionResult? setStrategicBackrow(DuelState state) =>
      _advanced.setStrategicBackrow(state);

  DuelActionResult? discardExcessHand(DuelState state) =>
      _advanced.discardExcessHand(state);

  ExpertAttackPlan planAttackSequence(DuelState initialState) {
    if (initialState.isFinished ||
        initialState.activePlayer != participant ||
        initialState.currentPhase != DuelPhase.battle ||
        initialState.chain.isOpen) {
      return ExpertAttackPlan(const []);
    }
    var simulation = initialState;
    final steps = <ExpertAttackStep>[];
    var probableResponseConsumed = false;
    var depth = 0;
    while (!simulation.isFinished && depth++ < 2) {
      final attackers = simulation.aiField.characterZones
          .whereType<FieldCardInstance>()
          .where((card) =>
              card.faceUp &&
              card.position == BattlePosition.attack &&
              !card.attackedThisTurn)
          .toList();
      if (attackers.isEmpty) break;
      final targets = simulation.playerField.characterZones
          .whereType<FieldCardInstance>()
          .toList();
      final board = evaluateBoard(simulation);
      final probableResponse = board.opponentHasProbableTrap;
      AttackDeclarationResult? declaration;
      var purpose = 'value';

      final protector = targets.where(_protectsOtherCards).firstOrNull;
      if (protector != null) {
        final targetStat = _visibleBattleStat(protector) ?? 0;
        final breakers = attackers
            .where((card) => (card.effectiveAtk ?? 0) > targetStat)
            .toList()
          ..sort((left, right) =>
              (left.effectiveAtk ?? 0).compareTo(right.effectiveAtk ?? 0));
        for (final breaker in breakers) {
          final candidate = _engine.declareAttack(
            state: simulation,
            participant: participant,
            attackerInstanceId: breaker.instanceId,
            targetInstanceId: protector.instanceId,
          );
          if (candidate.succeeded) {
            declaration = candidate;
            purpose = 'remove_protection';
            break;
          }
        }
      }

      if (declaration == null &&
          probableResponse &&
          !probableResponseConsumed &&
          attackers.length > 1) {
        final expendable = List<FieldCardInstance>.from(attackers)
          ..sort((left, right) =>
              (left.effectiveAtk ?? 0).compareTo(right.effectiveAtk ?? 0));
        for (final attacker in expendable) {
          final targetId = targets.isEmpty ? null : targets.first.instanceId;
          final candidate = _engine.declareAttack(
            state: simulation,
            participant: participant,
            attackerInstanceId: attacker.instanceId,
            targetInstanceId: targetId,
          );
          if (candidate.succeeded) {
            declaration = candidate;
            purpose = 'probe_response';
            probableResponseConsumed = true;
            break;
          }
        }
      }

      declaration ??= _advanced.declareBestAttack(simulation);
      if (declaration == null &&
          riskPosture(simulation) == RiskPosture.desperate) {
        declaration = _firstLegalRiskAttack(simulation, attackers, targets);
        purpose = 'desperation';
      }
      if (declaration == null) break;

      final attacker = attackers
          .where((card) =>
              card.instanceId == declaration!.declaration!.attackerInstanceId)
          .first;
      final directLethal = declaration.declaration!.targetInstanceId == null &&
          (attacker.effectiveAtk ?? 0) >= simulation.playerLifePoints;
      if (!directLethal &&
          probableResponse &&
          !probableResponseConsumed &&
          attackers.length == 1 &&
          (attacker.effectiveAtk ?? 0) >= 2500 &&
          riskPosture(simulation) == RiskPosture.prudent) {
        break;
      }

      final attack = declaration.declaration!;
      steps.add(ExpertAttackStep(
        attackerInstanceId: attack.attackerInstanceId,
        targetInstanceId: attack.targetInstanceId,
        purpose: purpose,
      ));
      simulation = _settleUnopposedWindow(declaration.state);
      final combat = _engine.resolveAttack(
        state: simulation,
        declaration: attack,
      );
      simulation = _settleUnopposedWindow(combat.state);
    }
    return ExpertAttackPlan(steps);
  }

  AttackDeclarationResult? declareNextAttack(DuelState state) {
    final plan = planAttackSequence(state);
    if (plan.steps.isEmpty) return null;
    final step = plan.steps.first;
    return _engine.declareAttack(
      state: state,
      participant: participant,
      attackerInstanceId: step.attackerInstanceId,
      targetInstanceId: step.targetInstanceId,
    );
  }

  /// Devant une réponse probable, une activation marquée `bait` est jouée
  /// avant l'effet `highValue`. Sans appât, l'effet important est conservé.
  ExpertPriorityDecision activateWithForesight({
    required DuelState state,
    required List<ChainLink> availableActivations,
  }) {
    final board = evaluateBoard(state);
    final probableResponse = board.opponentHasProbableTrap;
    final highValue = availableActivations.where(_isHighValueEffect).toList();
    if (probableResponse && highValue.isNotEmpty) {
      final baits = availableActivations
          .where((link) => link.payload['bait'] == true)
          .toList();
      if (baits.isEmpty) {
        return ExpertPriorityDecision(
          state: state,
          heldImportantEffect: true,
        );
      }
      final bait = _advanced.activateProactively(
        state: state,
        availableActivations: baits,
      );
      if (bait.activatedLink != null) {
        return ExpertPriorityDecision(
          state: bait.state,
          activatedLink: bait.activatedLink,
        );
      }
    }
    final result = _advanced.activateProactively(
      state: state,
      availableActivations: availableActivations,
    );
    return ExpertPriorityDecision(
      state: result.state,
      activatedLink: result.activatedLink,
      passed: result.passed,
      failure: result.failure,
    );
  }

  ExpertPriorityDecision handlePriority({
    required DuelState state,
    List<ChainLink> availableActivations = const [],
  }) {
    final foresight = activateWithForesight(
      state: state,
      availableActivations: availableActivations,
    );
    if (foresight.activatedLink != null || foresight.heldImportantEffect) {
      return foresight;
    }
    final fallback = _advanced.handlePriority(
      state: state,
      availableActivations: availableActivations,
    );
    return ExpertPriorityDecision(
      state: fallback.state,
      activatedLink: fallback.activatedLink,
      passed: fallback.passed,
      failure: fallback.failure,
    );
  }

  ExpertTurnResult playUnopposedTurn(DuelState initialState) {
    var state = initialState;
    final actions = <String>[];
    var safety = 0;
    var mainActionsPlayed = false;
    while (!state.isFinished &&
        state.activePlayer == participant &&
        safety++ < 140) {
      if (state.chain.isOpen) {
        state = _settleUnopposedWindow(state);
        continue;
      }
      switch (state.currentPhase) {
        case DuelPhase.draw:
        case DuelPhase.preparation:
          final advanced = _engine.advancePhase(state);
          if (!advanced.succeeded) {
            return ExpertTurnResult(state: state, actions: actions);
          }
          state = advanced.state;
        case DuelPhase.main1:
          if (!mainActionsPlayed) {
            updateMythicPlan(state);
            final planned = _activationPlanner?.call(state) ?? const [];
            final activation = activateWithForesight(
              state: state,
              availableActivations: planned,
            );
            if (activation.activatedLink != null) {
              state = _settleUnopposedWindow(activation.state);
              actions.add('planned_effect');
            }
            final monster = playBestMonster(state);
            if (monster != null && monster.succeeded) {
              state = _settleUnopposedWindow(monster.state);
              actions.add('normal_monster_play');
            }
            final support = _advanced.setStrategicBackrow(state);
            if (support != null && support.succeeded) {
              state = _settleUnopposedWindow(support.state);
              actions.add('set_action_or_trap');
            }
            mainActionsPlayed = true;
          }
          state = _engine.advancePhase(state).state;
        case DuelPhase.battle:
          final attack = declareNextAttack(state);
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
          final discard = _advanced.discardExcessHand(state);
          if (discard != null && discard.succeeded) {
            state = discard.state;
            actions.add('discard_for_hand_limit');
          }
          final advanced = _engine.advancePhase(state);
          if (!advanced.succeeded) {
            return ExpertTurnResult(state: state, actions: actions);
          }
          state = advanced.state;
      }
    }
    return ExpertTurnResult(state: state, actions: actions);
  }

  AttackDeclarationResult? _firstLegalRiskAttack(
    DuelState state,
    List<FieldCardInstance> attackers,
    List<FieldCardInstance> targets,
  ) {
    for (final attacker in attackers) {
      final targetIds = targets.isEmpty
          ? const <String?>[null]
          : targets.map<String?>((target) => target.instanceId);
      for (final targetId in targetIds) {
        final result = _engine.declareAttack(
          state: state,
          participant: participant,
          attackerInstanceId: attacker.instanceId,
          targetInstanceId: targetId,
        );
        if (result.succeeded) return result;
      }
    }
    return null;
  }

  bool _protectsOtherCards(FieldCardInstance card) {
    if (card is! CardInstance) return false;
    return card.cardCode == 'ROY-003' ||
        card.runtimeData['protects_others'] == true ||
        card.effectData['must_be_attacked_first'] == true;
  }

  int? _visibleBattleStat(FieldCardInstance card) {
    if (!card.faceUp) return null;
    return card.position == BattlePosition.attack
        ? card.effectiveAtk
        : card.effectiveDef;
  }

  bool _isHighValueEffect(ChainLink link) =>
      link.payload['highValue'] == true ||
      link.payload['summonsMythic'] == true ||
      (link.sourceCardCode?.endsWith('-010') ?? false);

  DuelState _settleUnopposedWindow(DuelState initialState) {
    var state = initialState;
    var safety = 0;
    while (state.chain.isOpen && safety++ < 18) {
      final priority = state.chain.priorityPlayer;
      if (priority == null) break;
      final passed = _engine.passPriority(state: state, participant: priority);
      if (!passed.succeeded) break;
      state = passed.state;
    }
    return state;
  }

  static int _integer(Object? value, {int fallback = 0}) =>
      value is num ? value.toInt() : fallback;
}
