import 'beginner_ai.dart';
import 'intermediate_ai.dart';
import '../battle_state.dart';
import '../card.dart';
import '../duel_engine.dart';
import '../duel_types.dart';

typedef AdvancedActivationPlanner = List<ChainLink> Function(DuelState state);

final class BoardEvaluation {
  const BoardEvaluation({
    required this.ownLifePoints,
    required this.opponentLifePoints,
    required this.ownMonsterCount,
    required this.opponentMonsterCount,
    required this.ownCombatPower,
    required this.opponentCombatPower,
    required this.ownHandCount,
    required this.opponentHandCount,
    required this.knownOpponentHandCount,
    required this.ownCounterCount,
    required this.opponentCounterCount,
    required this.hiddenOpponentBackrowCount,
    required this.score,
  });

  final int ownLifePoints;
  final int opponentLifePoints;
  final int ownMonsterCount;
  final int opponentMonsterCount;
  final int ownCombatPower;
  final int opponentCombatPower;
  final int ownHandCount;
  final int opponentHandCount;
  final int knownOpponentHandCount;
  final int ownCounterCount;
  final int opponentCounterCount;
  final int hiddenOpponentBackrowCount;
  final int score;

  bool get isBehind => score < 0;
  bool get isLowOnLife => ownLifePoints <= 2500;
  bool get opponentHasProbableTrap =>
      opponentHandCount > 0 && hiddenOpponentBackrowCount > 0;
}

final class AdvancedPriorityDecision {
  const AdvancedPriorityDecision({
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

final class AdvancedTurnResult {
  AdvancedTurnResult({
    required this.state,
    List<String> actions = const [],
  }) : actions = List.unmodifiable(actions);

  final DuelState state;
  final List<String> actions;
}

/// Évolution de [IntermediateAi] qui raisonne sur l'avantage global du
/// plateau. Les décisions finales restent toutes validées par [DuelEngine].
final class AdvancedAi {
  AdvancedAi({
    required DuelEngine engine,
    AiRandomSource? random,
    AdvancedActivationPlanner? activationPlanner,
  })  : _engine = engine,
        _intermediate = IntermediateAi(engine: engine, random: random),
        _activationPlanner = activationPlanner;

  static const participant = DuelParticipant.ai;

  final DuelEngine _engine;
  final IntermediateAi _intermediate;
  final AdvancedActivationPlanner? _activationPlanner;

  BoardEvaluation evaluateBoard(DuelState state) {
    final ownMonsters =
        state.aiField.characterZones.whereType<FieldCardInstance>().toList();
    final opponentMonsters = state.playerField.characterZones
        .whereType<FieldCardInstance>()
        .toList();
    final ownPower = ownMonsters.fold<int>(0, _combatPowerSum);
    // Seules les statistiques révélées sont utilisées : aucune lecture
    // stratégique d'une carte adverse face cachée.
    final opponentPower = opponentMonsters
        .where((card) => card.faceUp)
        .fold<int>(0, _combatPowerSum);
    final ownCounters = ownMonsters.fold<int>(0, _counterSum) +
        state.aiField.actionTrapZones
            .whereType<CardInstance>()
            .fold<int>(0, _counterSum);
    final opponentCounters = opponentMonsters.fold<int>(0, _counterSum) +
        state.playerField.actionTrapZones
            .whereType<CardInstance>()
            .fold<int>(0, _counterSum);
    final knownOpponentHand = state.playerField.hand
        .where((card) =>
            state.aiField.revealedCardInstanceIds.contains(card.instanceId))
        .length;
    final hiddenBackrow = state.playerField.actionTrapZones
        .whereType<CardInstance>()
        .where((card) => !card.faceUp)
        .length;
    final score = (state.aiLifePoints - state.playerLifePoints) ~/ 5 +
        ownPower -
        opponentPower +
        (ownMonsters.length - opponentMonsters.length) * 450 +
        (state.aiField.hand.length - state.playerField.hand.length) * 160 +
        (ownCounters - opponentCounters) * 40;
    return BoardEvaluation(
      ownLifePoints: state.aiLifePoints,
      opponentLifePoints: state.playerLifePoints,
      ownMonsterCount: ownMonsters.length,
      opponentMonsterCount: opponentMonsters.length,
      ownCombatPower: ownPower,
      opponentCombatPower: opponentPower,
      ownHandCount: state.aiField.hand.length,
      opponentHandCount: state.playerField.hand.length,
      knownOpponentHandCount: knownOpponentHand,
      ownCounterCount: ownCounters,
      opponentCounterCount: opponentCounters,
      hiddenOpponentBackrowCount: hiddenBackrow,
      score: score,
    );
  }

  DuelActionResult? playBestMonster(DuelState state) {
    final candidates = _intermediate.legalNormalMonsterCandidates(state);
    if (candidates.isEmpty) return null;
    final board = evaluateBoard(state);
    final ranked = candidates
        .map((card) => _MonsterChoice(
              card: card,
              score: _monsterBoardValue(state, board, card),
            ))
        .toList()
      ..sort((left, right) => right.score.compareTo(left.score));
    final selected = ranked.first;
    final required =
        _engine.requiredSacrificesForNormalPlay(selected.card) ?? 0;
    final sacrifices = _intermediate.preferredSacrificeIds(
      state: state,
      count: required,
    );

    final strongestEnemy = state.playerField.characterZones
        .whereType<FieldCardInstance>()
        .where((card) => card.faceUp && card.position == BattlePosition.attack)
        .fold<int>(0, (value, card) {
      final attack = card.effectiveAtk ?? 0;
      return attack > value ? attack : value;
    });
    final valuable = selected.score >= 2600 ||
        selected.card.effectData['ai_value'] is num &&
            (selected.card.effectData['ai_value'] as num).toInt() >= 500;
    final cautiousOfTrap = board.opponentHasProbableTrap && valuable;
    final outmatched = strongestEnemy > (selected.card.effectiveAtk ?? 0);
    final shouldSet = cautiousOfTrap || outmatched;

    return shouldSet
        ? _engine.normalSet(
            state: state,
            participant: participant,
            cardInstanceId: selected.card.instanceId,
            sacrificeInstanceIds: sacrifices,
          )
        : _engine.normalSummon(
            state: state,
            participant: participant,
            cardInstanceId: selected.card.instanceId,
            sacrificeInstanceIds: sacrifices,
          );
  }

  DuelActionResult? setStrategicBackrow(DuelState state) {
    if (state.isFinished ||
        state.activePlayer != participant ||
        state.chain.isOpen ||
        (state.currentPhase != DuelPhase.main1 &&
            state.currentPhase != DuelPhase.main2) ||
        state.aiField.actionTrapZones.every((zone) => zone != null)) {
      return null;
    }
    final board = evaluateBoard(state);
    final candidates = _intermediate
        .preferredBackrowCards(state)
        .where((card) => !_shouldKeepForLater(state, board, card))
        .toList();
    if (candidates.isEmpty) return null;
    return _engine.setActionOrTrap(
      state: state,
      participant: participant,
      cardInstanceId: candidates.first.instanceId,
    );
  }

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
    final targets = state.playerField.characterZones
        .whereType<FieldCardInstance>()
        .toList();
    if (targets.isEmpty) return _intermediate.declareBestAttack(state);

    final choices = <_AdvancedAttackChoice>[];
    for (final attacker in attackers) {
      final attackValue = attacker.effectiveAtk ?? -1;
      for (final target in targets) {
        final targetStat = target.faceUp
            ? target.position == BattlePosition.attack
                ? target.effectiveAtk
                : target.effectiveDef
            : null;
        if (targetStat != null && attackValue < targetStat) continue;
        final declaration = _engine.declareAttack(
          state: state,
          participant: participant,
          attackerInstanceId: attacker.instanceId,
          targetInstanceId: target.instanceId,
        );
        if (!declaration.succeeded) continue;
        final immediateDamage = target.faceUp &&
                target.position == BattlePosition.attack &&
                targetStat != null
            ? attackValue - targetStat
            : 0;
        final winsNow = immediateDamage >= state.playerLifePoints;
        if (!winsNow &&
            _counterattackCouldBeLethal(
              state: state,
              attacker: attacker,
              destroyedTarget: targetStat != null && attackValue > targetStat
                  ? target
                  : null,
            )) {
          continue;
        }
        choices.add(_AdvancedAttackChoice(
          declaration: declaration,
          strategicValue: _targetThreat(target) +
              _attackComboValue(attacker) +
              (targetStat != null && attackValue > targetStat ? 500 : 0),
        ));
      }
    }
    if (choices.isEmpty) return null;
    choices.sort(
      (left, right) => right.strategicValue.compareTo(left.strategicValue),
    );
    return choices.first.declaration;
  }

  /// Essaie une activation de tempo/ressources, y compris les dix cartes
  /// déclencheuses `*-010` d'invocation Mythique.
  AdvancedPriorityDecision activateProactively({
    required DuelState state,
    required List<ChainLink> availableActivations,
  }) {
    if (state.isFinished || state.activePlayer != participant) {
      return AdvancedPriorityDecision(state: state);
    }
    final candidates = availableActivations
        .where((link) => link.activatingPlayer == participant)
        .map((link) => _EffectChoice(
              link: link,
              score: _proactiveEffectValue(state, link),
            ))
        .where((choice) => choice.score > 0)
        .toList()
      ..sort((left, right) => right.score.compareTo(left.score));
    for (final candidate in candidates) {
      final activation =
          _engine.activateChainEffect(state: state, link: candidate.link);
      if (activation.succeeded) {
        return AdvancedPriorityDecision(
          state: activation.state,
          activatedLink: activation.link,
        );
      }
    }
    return AdvancedPriorityDecision(state: state);
  }

  AdvancedPriorityDecision handlePriority({
    required DuelState state,
    List<ChainLink> availableActivations = const [],
  }) {
    final proactive = activateProactively(
      state: state,
      availableActivations: availableActivations,
    );
    if (proactive.activatedLink != null) return proactive;
    final fallback = _intermediate.handlePriority(
      state: state,
      availableActivations: availableActivations,
    );
    return AdvancedPriorityDecision(
      state: fallback.state,
      activatedLink: fallback.activatedLink,
      passed: fallback.passed,
      failure: fallback.failure,
    );
  }

  DuelActionResult? discardExcessHand(DuelState state) =>
      _intermediate.discardExcessHand(state);

  /// Points d'extension utilisés par l'IA experte pour ajouter une recherche
  /// à faible profondeur sans recopier la légalité ni les sacrifices.
  List<CardInstance> legalNormalMonsterCandidates(DuelState state) =>
      _intermediate.legalNormalMonsterCandidates(state);

  List<String> preferredSacrificeIds({
    required DuelState state,
    required int count,
  }) =>
      _intermediate.preferredSacrificeIds(state: state, count: count);

  int evaluateMonsterCandidate(DuelState state, CardInstance card) =>
      _monsterBoardValue(state, evaluateBoard(state), card);

  AdvancedTurnResult playUnopposedTurn(DuelState initialState) {
    var state = initialState;
    final actions = <String>[];
    var safety = 0;
    var mainActionsPlayed = false;
    while (!state.isFinished &&
        state.activePlayer == participant &&
        safety++ < 120) {
      if (state.chain.isOpen) {
        state = _settleUnopposedWindow(state);
        continue;
      }
      switch (state.currentPhase) {
        case DuelPhase.draw:
        case DuelPhase.preparation:
          final advanced = _engine.advancePhase(state);
          if (!advanced.succeeded) {
            return AdvancedTurnResult(state: state, actions: actions);
          }
          state = advanced.state;
        case DuelPhase.main1:
          if (!mainActionsPlayed) {
            final planned = _activationPlanner?.call(state) ?? const [];
            final proactive = activateProactively(
              state: state,
              availableActivations: planned,
            );
            if (proactive.activatedLink != null) {
              state = _settleUnopposedWindow(proactive.state);
              actions.add('proactive_effect');
            }
            final monster = playBestMonster(state);
            if (monster != null && monster.succeeded) {
              state = _settleUnopposedWindow(monster.state);
              actions.add('normal_monster_play');
            }
            final support = setStrategicBackrow(state);
            if (support != null && support.succeeded) {
              state = _settleUnopposedWindow(support.state);
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
            return AdvancedTurnResult(state: state, actions: actions);
          }
          state = advanced.state;
      }
    }
    return AdvancedTurnResult(state: state, actions: actions);
  }

  int _monsterBoardValue(
    DuelState state,
    BoardEvaluation board,
    CardInstance card,
  ) {
    final required = _engine.requiredSacrificesForNormalPlay(card) ?? 0;
    var score = (card.effectiveAtk ?? 0) + (card.effectiveDef ?? 0) ~/ 4;
    if (card.effectKey != null && !card.cardCode.endsWith('-003')) score += 180;
    score += _numeric(card.effectData['ai_value']);
    score += _numeric(card.effectData['on_summon_draw']) * 350;
    score += _numeric(card.effectData['on_summon_destroy']) * 650;
    score += _numeric(card.effectData['on_summon_buff']);
    if (card.effectData['on_summon_draw'] == true) score += 350;
    if (card.effectData['on_summon_destroy'] == true) score += 650;
    if (card.effectData['on_summon_buff'] == true) score += 300;
    score += _catalogSummonValue(state, board, card);
    if (required > 0) {
      final sacrifices = _intermediate.preferredSacrificeIds(
        state: state,
        count: required,
      );
      score -= sacrifices.fold<int>(0, (total, id) {
        final material = state.aiField.characterZones
            .whereType<FieldCardInstance>()
            .where((entry) => entry.instanceId == id)
            .firstOrNull;
        return total + (material?.effectiveAtk ?? 0) ~/ 2;
      });
      final remainingPresence = board.ownMonsterCount - required + 1;
      if (remainingPresence <= 1 && board.opponentMonsterCount >= 2) {
        score -= 900;
      }
    }
    return score;
  }

  /// Valeur contextuelle des effets d'invocation du catalogue V2. Les clés
  /// `effect_data` restent prioritaires au-dessus ; cette table garantit que
  /// le seed actuel, encore peu annoté, est déjà compris par l'IA.
  int _catalogSummonValue(
    DuelState state,
    BoardEvaluation board,
    CardInstance card,
  ) {
    final ownCards = state.aiField.characterZones.whereType<CardInstance>();
    final ownFamilyCount = ownCards
        .where((entry) => entry.hasFamily(card.primaryFamily ?? ''))
        .length;
    final matchingGraveyard = state.aiField.graveyard
        .where((entry) => entry.hasFamily(card.primaryFamily ?? ''))
        .length;
    final freeZones =
        state.aiField.characterZones.where((entry) => entry == null).length;
    return switch (card.cardCode) {
      'BAB-001' => 180,
      'BAB-002' => board.ownMonsterCount > 0 ? 180 : 0,
      'BAB-005' => board.hiddenOpponentBackrowCount * 350,
      'ROY-004' => 350,
      'ROY-005' => 400,
      'ROY-007' => (matchingGraveyard > 2 ? 2 : matchingGraveyard) * 550,
      'ANC-002' => matchingGraveyard > 0 ? 180 : 0,
      'ANC-004' => 240,
      'ANC-007' => (matchingGraveyard > 3 ? 3 : matchingGraveyard) * 170,
      'MAS-005' => freeZones > 1 && state.aiField.hand.length > 1 ? 450 : 0,
      'DOZ-001' => 80,
      'DOZ-004' => 320,
      'DOZ-007' => board.opponentMonsterCount * 140,
      'FOR-004' => board.isLowOnLife ? 500 : 250,
      'FOR-007' => (freeZones > 2 ? 2 : freeZones) * 300,
      'LAG-004' => matchingGraveyard > 0 ? 300 : 0,
      'SAV-001' => 140,
      'SAV-005' => ownFamilyCount * 180,
      'VIL-002' => ownFamilyCount > 0 ? 180 : 0,
      'VIL-004' => 300,
      'MAQ-001' => ownFamilyCount > 0 ? 180 : 100,
      'MAQ-005' => 350,
      _ => 0,
    };
  }

  bool _shouldKeepForLater(
    DuelState state,
    BoardEvaluation board,
    CardInstance card,
  ) {
    final requiredResources = _numeric(card.effectData['requires_resources']);
    final availableResources = board.ownMonsterCount + board.ownCounterCount;
    if (requiredResources > availableResources) return true;
    final isMythicTrigger = card.cardCode.endsWith('-010');
    if (isMythicTrigger && !_hasMatchingMythic(state, card.cardCode)) {
      return true;
    }
    return card.effectData['future_value'] == true && !board.isBehind;
  }

  int _proactiveEffectValue(DuelState state, ChainLink link) {
    var score = _numeric(link.payload['tempoGain']) * 300 +
        _numeric(link.payload['resourceGain']) * 250;
    if (link.payload['createsAdvantage'] == true) score += 400;
    final triggerCode = link.sourceCardCode ?? '';
    final summonsMythic =
        link.payload['summonsMythic'] == true || triggerCode.endsWith('-010');
    if (summonsMythic && _hasMatchingMythic(state, triggerCode)) {
      final reserveMythic = state.aiField.mythicReserve
          .where((card) =>
              card.mythicSummonCondition['trigger_card_code'] == triggerCode)
          .firstOrNull;
      final mythicValue = reserveMythic == null
          ? 0
          : (reserveMythic.effectiveAtk ?? 0) +
              (reserveMythic.effectiveDef ?? 0) ~/ 3;
      score += mythicValue + 1000;
    }
    return score;
  }

  bool _hasMatchingMythic(DuelState state, String triggerCode) =>
      state.aiField.mythicReserve.any((card) =>
          card.mythicSummonCondition['trigger_card_code'] == triggerCode &&
          state.aiField.characterZones.any((zone) => zone == null));

  bool _counterattackCouldBeLethal({
    required DuelState state,
    required FieldCardInstance attacker,
    FieldCardInstance? destroyedTarget,
  }) {
    if (state.aiLifePoints > 2500) return false;
    final nextAttackers = state.playerField.characterZones
        .whereType<FieldCardInstance>()
        .where((card) => card.instanceId != destroyedTarget?.instanceId)
        .where((card) => card.faceUp && card.position == BattlePosition.attack);
    for (final enemy in nextAttackers) {
      final damage = (enemy.effectiveAtk ?? 0) - (attacker.effectiveAtk ?? 0);
      if (damage >= state.aiLifePoints) return true;
    }
    return false;
  }

  int _targetThreat(FieldCardInstance target) {
    var score = target.effectiveAtk ?? target.effectiveDef ?? 0;
    score +=
        target.counters.values.fold<int>(0, (sum, value) => sum + value) * 80;
    if (target is CardInstance) {
      if (target.effectKey != null && !target.cardCode.endsWith('-003')) {
        score += 600;
      }
      if (target.subtype == 'continuous' ||
          target.effectData['continuous'] == true ||
          target.runtimeData['continuous_effect_active'] == true) {
        score += 900;
      }
      score += _numeric(target.effectData['ai_threat']);
    }
    return score;
  }

  int _attackComboValue(FieldCardInstance attacker) {
    if (attacker is! CardInstance) return 0;
    var score = _numeric(attacker.effectData['on_battle_destroy_value']);
    if (attacker.effectData['combo_after_attack'] == true) score += 500;
    return score;
  }

  DuelState _settleUnopposedWindow(DuelState initialState) {
    var state = initialState;
    var safety = 0;
    while (state.chain.isOpen && safety++ < 16) {
      final priority = state.chain.priorityPlayer;
      if (priority == null) break;
      final passed = _engine.passPriority(state: state, participant: priority);
      if (!passed.succeeded) break;
      state = passed.state;
    }
    return state;
  }

  static int _combatPowerSum(int total, FieldCardInstance card) =>
      total + (card.effectiveAtk ?? 0) + (card.effectiveDef ?? 0) ~/ 2;

  static int _counterSum(int total, FieldCardInstance card) =>
      total + card.counters.values.fold<int>(0, (sum, value) => sum + value);

  static int _numeric(Object? value) => value is num ? value.toInt() : 0;
}

final class _MonsterChoice {
  const _MonsterChoice({required this.card, required this.score});

  final CardInstance card;
  final int score;
}

final class _AdvancedAttackChoice {
  const _AdvancedAttackChoice({
    required this.declaration,
    required this.strategicValue,
  });

  final AttackDeclarationResult declaration;
  final int strategicValue;
}

final class _EffectChoice {
  const _EffectChoice({required this.link, required this.score});

  final ChainLink link;
  final int score;
}
