import 'effects/manual_activation_options.dart';
import 'battle_state.dart';
import 'card.dart';
import 'duel_types.dart';
import 'player.dart';

/// Refus métier possibles pour les opérations de l'étape 4.2.
enum DuelActionFailure {
  duelFinished,
  notActivePlayer,
  cardNotInHand,
  cardIsNotCharacter,
  cardIsNotActionOrTrap,
  cardCannotBeActivated,
  notMainPhase,
  mythicNormalSummonForbidden,
  invalidCharacterRank,
  normalSummonAlreadyUsed,
  wrongSacrificeCount,
  invalidSacrifice,
  invalidZoneIndex,
  characterZoneOccupied,
  characterZoneFull,
  actionTrapZoneOccupied,
  actionTrapZoneFull,
  notDrawPhase,
  drawAlreadyResolved,
  notEndPhase,
  handLimitDiscardRequired,
  noHandLimitDiscardRequired,
  invalidDiscardSelection,
  notBattlePhase,
  attackForbiddenOnOpeningTurn,
  attackerNotFound,
  attackerNotControlled,
  attackerNotInAttackPosition,
  attackerAlreadyAttacked,
  attackerCannotAttackByEffect,
  directAttackBlocked,
  targetNotFound,
  invalidAttackTarget,
  missingCombatStats,
  chainWindowOpen,
  chainIsResolving,
  noResponseWindow,
  notPriorityPlayer,
  unknownChainEffect,
  duplicateChainLink,
  illegalChainSpeed,
  illegalChainTarget,
  chainActivationConditionNotMet,
  activationForbiddenDuringCombatCalculation,
}

/// Contrat que les vrais effets de cartes de l'étape 4.5 implémenteront.
///
/// [canActivate] vérifie les conditions autres que vitesse/priorité,
/// [payCost] applique définitivement le coût, [isTargetLegal] est appelée à
/// l'activation puis à la résolution, et [resolve] applique l'effet.
abstract class ChainEffectDefinition {
  const ChainEffectDefinition();

  /// Enumerates optional manual activations. Automatic effects expose none.
  Iterable<ManualActivationOption> buildManualActivations(
          ManualActivationRequest request) =>
      const [];

  ChainLink? createAutomaticTriggerLink({
    required DuelState state,
    required CardInstance source,
    required AutomaticEffectTrigger event,
    required String linkId,
  }) =>
      null;

  ChainLink prepareLink(DuelState state, ChainLink link) => link;

  /// Décrit les conséquences auxquelles l'adversaire peut répondre avant la
  /// résolution. Une nouvelle carte expose ici ses événements rares sans
  /// imposer de modification au contrôleur Flutter.
  Iterable<PendingDuelEvent> pendingEvents(
    DuelState state,
    ChainLink link,
  ) =>
      const [];

  bool canActivate(DuelState state, ChainLink link) => true;

  DuelState payCost(DuelState state, ChainLink link) => state;

  bool isTargetLegal(DuelState state, ChainLink link) => link.target == null;

  DuelState resolve(DuelState state, ChainLink link);
}

final class ChainActivationResult {
  const ChainActivationResult._({
    required this.state,
    this.link,
    this.failure,
  });

  factory ChainActivationResult.success(DuelState state, ChainLink link) {
    return ChainActivationResult._(state: state, link: link);
  }

  factory ChainActivationResult.failure(
    DuelState state,
    DuelActionFailure failure,
  ) {
    return ChainActivationResult._(state: state, failure: failure);
  }

  final DuelState state;
  final ChainLink? link;
  final DuelActionFailure? failure;

  bool get succeeded => failure == null;
}

final class PriorityPassResult {
  PriorityPassResult({
    required this.state,
    this.failure,
    this.resolutionTriggered = false,
    this.interruptedByVictory = false,
    List<String> resolvedLinkIds = const [],
    List<String> fizzledLinkIds = const [],
  })  : resolvedLinkIds = List.unmodifiable(resolvedLinkIds),
        fizzledLinkIds = List.unmodifiable(fizzledLinkIds);

  final DuelState state;
  final DuelActionFailure? failure;
  final bool resolutionTriggered;
  final bool interruptedByVictory;
  final List<String> resolvedLinkIds;
  final List<String> fizzledLinkIds;

  bool get succeeded => failure == null;
}

/// Attaque déclarée, conservée séparément pour permettre une interruption
/// entre sa déclaration et son calcul futur par la Chaîne.
final class AttackDeclaration {
  const AttackDeclaration({
    required this.declarationId,
    required this.attackingPlayer,
    required this.attackerInstanceId,
    required this.targetInstanceId,
    required this.declaredTurn,
  });

  final String declarationId;
  final DuelParticipant attackingPlayer;
  final String attackerInstanceId;
  final String? targetInstanceId;
  final int declaredTurn;

  bool get isDirectAttack => targetInstanceId == null;
}

final class AttackDeclarationResult {
  const AttackDeclarationResult._({
    required this.state,
    this.declaration,
    this.failure,
  });

  factory AttackDeclarationResult.success(
    DuelState state,
    AttackDeclaration declaration,
  ) {
    return AttackDeclarationResult._(
      state: state,
      declaration: declaration,
    );
  }

  factory AttackDeclarationResult.failure(
    DuelState state,
    DuelActionFailure failure,
  ) {
    return AttackDeclarationResult._(state: state, failure: failure);
  }

  final DuelState state;
  final AttackDeclaration? declaration;
  final DuelActionFailure? failure;

  bool get succeeded => failure == null;
}

enum CombatResolutionStatus {
  resolved,
  interruptedTargetMissing,
  interruptedAttackerMissing,
  staleDeclaration,
  responseWindowOpen,
  cancelled,
  invalidCombatStats,
}

enum EffectDestructionStatus { destroyed, prevented, targetNotFound }

final class EffectDestructionResult {
  const EffectDestructionResult({
    required this.state,
    required this.status,
  });

  final DuelState state;
  final EffectDestructionStatus status;
}

/// Bilan brut d'un combat, prêt à être consommé plus tard par les effets.
final class CombatResolutionResult {
  CombatResolutionResult({
    required this.state,
    required this.status,
    this.targetFlippedFaceUp = false,
    List<String> destroyedCardInstanceIds = const [],
    Map<DuelParticipant, int> damageByParticipant = const {},
  })  : destroyedCardInstanceIds = List.unmodifiable(
          destroyedCardInstanceIds,
        ),
        damageByParticipant = Map.unmodifiable(damageByParticipant);

  final DuelState state;
  final CombatResolutionStatus status;

  /// Point d'accroche de l'étape 4.5 : `true` indique qu'un effet de
  /// retournement devrait être proposé après la mécanique brute.
  final bool targetFlippedFaceUp;
  final List<String> destroyedCardInstanceIds;
  final Map<DuelParticipant, int> damageByParticipant;
}

/// Choix demandé à l'appelant lorsque la main dépasse six cartes.
final class HandDiscardRequirement {
  HandDiscardRequirement({
    required this.participant,
    required this.requiredCount,
    required List<CardInstance> candidates,
  }) : candidates = List.unmodifiable(candidates);

  final DuelParticipant participant;
  final int requiredCount;

  /// Toute la main est proposée afin que l'interface ou l'IA puisse choisir
  /// librement les [requiredCount] cartes à défausser.
  final List<CardInstance> candidates;
}

/// Résultat sans exception d'une tentative d'action sur le duel.
final class DuelActionResult {
  const DuelActionResult._({
    required this.state,
    this.failure,
    this.discardRequirement,
  });

  factory DuelActionResult.success(DuelState state) {
    return DuelActionResult._(state: state);
  }

  factory DuelActionResult.failure(
    DuelState state,
    DuelActionFailure failure, {
    HandDiscardRequirement? discardRequirement,
  }) {
    return DuelActionResult._(
      state: state,
      failure: failure,
      discardRequirement: discardRequirement,
    );
  }

  final DuelState state;
  final DuelActionFailure? failure;
  final HandDiscardRequirement? discardRequirement;

  bool get succeeded => failure == null;
}

typedef CombatFlipTriggerLinkFactory = ChainLink? Function({
  required DuelState state,
  required CardInstance flippedCard,
});

/// Règles pures et déterministes de l'étape 4.2.
///
/// Aucune méthode ne modifie l'état reçu. Chaque succès retourne un nouvel
/// instantané [DuelState]. Aucune source aléatoire n'est nécessaire pour les
/// règles de cette étape.
final class DuelEngine {
  DuelEngine({
    Map<String, ChainEffectDefinition> chainEffects = const {},
    CombatFlipTriggerLinkFactory? combatFlipTriggerLinkFactory,
  })  : _chainEffects = Map.unmodifiable(chainEffects),
        _combatFlipTriggerLinkFactory = combatFlipTriggerLinkFactory;

  static const int maximumHandSize = 6;

  final Map<String, ChainEffectDefinition> _chainEffects;

  ChainEffectDefinition? chainEffectDefinition(String effectKey) =>
      _chainEffects[effectKey];
  final CombatFlipTriggerLinkFactory? _combatFlipTriggerLinkFactory;

  /// Événements typés annoncés par le dernier maillon de la Chaîne.
  List<PendingDuelEvent> pendingEventsForCurrentChain(DuelState state) {
    if (!state.chain.isOpen || state.chain.links.isEmpty) return const [];
    final link = state.chain.links.last;
    final definition = _chainEffects[link.effectKey];
    if (definition == null) return const [];
    return List.unmodifiable(definition.pendingEvents(state, link));
  }

  /// Résout une destruction causée par un effet, après sa fenêtre de réponse.
  ///
  /// Les protections Royaume placent l'identifiant de la carte dans
  /// [DuelState.preventedEffectDestructionInstanceIds]. Cette protection est
  /// consommée ici et ne s'applique volontairement pas au combat, au
  /// sacrifice, au bannissement ou au renvoi dans une autre zone.
  EffectDestructionResult destroyCardByEffect({
    required DuelState state,
    required String cardInstanceId,
  }) {
    if (state.preventedEffectDestructionInstanceIds.contains(cardInstanceId)) {
      final remaining = Set<String>.from(
        state.preventedEffectDestructionInstanceIds,
      )..remove(cardInstanceId);
      return EffectDestructionResult(
        state: state.copyWith(
          preventedEffectDestructionInstanceIds: remaining,
        ),
        status: EffectDestructionStatus.prevented,
      );
    }

    for (final participant in DuelParticipant.values) {
      final field = _fieldFor(state, participant);
      final character = _findCharacter(field, cardInstanceId);
      if (character != null) {
        return EffectDestructionResult(
          state: _destroyCharacter(state, participant, cardInstanceId),
          status: EffectDestructionStatus.destroyed,
        );
      }

      final actionTrapIndex = field.actionTrapZones.indexWhere(
        (card) => card?.instanceId == cardInstanceId,
      );
      if (actionTrapIndex >= 0) {
        final card = field.actionTrapZones[actionTrapIndex]!;
        final zones = List<CardInstance?>.from(field.actionTrapZones)
          ..[actionTrapIndex] = null;
        var nextState = _replaceField(
          state,
          participant,
          field.copyWith(actionTrapZones: zones),
        );
        nextState = _sendCatalogCardToOwnerGraveyard(nextState, card);
        return EffectDestructionResult(
          state: nextState,
          status: EffectDestructionStatus.destroyed,
        );
      }

      if (field.terrainZone?.instanceId == cardInstanceId) {
        final card = field.terrainZone!;
        var nextState = _replaceField(
          state,
          participant,
          field.copyWith(terrainZone: null),
        );
        nextState = _sendCatalogCardToOwnerGraveyard(nextState, card);
        return EffectDestructionResult(
          state: nextState,
          status: EffectDestructionStatus.destroyed,
        );
      }
    }

    return EffectDestructionResult(
      state: state,
      status: EffectDestructionStatus.targetNotFound,
    );
  }

  DuelActionResult normalSummon({
    required DuelState state,
    required DuelParticipant participant,
    required String cardInstanceId,
    List<String> sacrificeInstanceIds = const [],
    int? destinationZoneIndex,
  }) {
    return _normalPlace(
      state: state,
      participant: participant,
      cardInstanceId: cardInstanceId,
      sacrificeInstanceIds: sacrificeInstanceIds,
      destinationZoneIndex: destinationZoneIndex,
      faceUp: true,
      position: BattlePosition.attack,
    );
  }

  /// Nombre de sacrifices exigé par le moteur pour une invocation ou pose
  /// normale. `null` signifie que la carte ne peut pas être jouée ainsi.
  int? requiredSacrificesForNormalPlay(CardInstance card) {
    final rank = card.rank;
    if (card.category != CardCategory.character ||
        rank == null ||
        rank < 1 ||
        rank > 8) {
      return null;
    }
    return switch (rank) {
      <= 4 => 0,
      <= 6 => 1,
      _ => 2,
    };
  }

  /// Identifiants actuellement utilisables comme sacrifices normaux.
  List<String> legalNormalSacrificeIds({
    required DuelState state,
    required DuelParticipant participant,
  }) {
    return _fieldFor(state, participant)
        .characterZones
        .whereType<FieldCardInstance>()
        .where((card) {
          if (card.controller != participant) return false;
          if (card is TokenInstance) {
            return card.runtimeData[CardRuntimeKeys.cannotBeSacrificedTurn] !=
                state.turnNumber;
          }
          return (card as CardInstance).category == CardCategory.character;
        })
        .map((card) => card.instanceId)
        .toList(growable: false);
  }

  DuelActionResult normalSet({
    required DuelState state,
    required DuelParticipant participant,
    required String cardInstanceId,
    List<String> sacrificeInstanceIds = const [],
    int? destinationZoneIndex,
  }) {
    return _normalPlace(
      state: state,
      participant: participant,
      cardInstanceId: cardInstanceId,
      sacrificeInstanceIds: sacrificeInstanceIds,
      destinationZoneIndex: destinationZoneIndex,
      faceUp: false,
      position: BattlePosition.defense,
    );
  }

  /// Pose une Action ou un Piège sans consommer l'invocation normale.
  DuelActionResult setActionOrTrap({
    required DuelState state,
    required DuelParticipant participant,
    required String cardInstanceId,
    int? destinationZoneIndex,
  }) {
    if (state.isFinished) {
      return DuelActionResult.failure(
        state,
        DuelActionFailure.duelFinished,
      );
    }
    if (participant != state.activePlayer) {
      return DuelActionResult.failure(
        state,
        DuelActionFailure.notActivePlayer,
      );
    }
    if (state.chain.isOpen) {
      return DuelActionResult.failure(
        state,
        DuelActionFailure.chainWindowOpen,
      );
    }

    final field = _fieldFor(state, participant);
    final handIndex = field.hand.indexWhere(
      (card) => card.instanceId == cardInstanceId,
    );
    if (handIndex < 0) {
      return DuelActionResult.failure(
        state,
        DuelActionFailure.cardNotInHand,
      );
    }
    final card = field.hand[handIndex];
    if (card.category != CardCategory.action &&
        card.category != CardCategory.trap) {
      return DuelActionResult.failure(
        state,
        DuelActionFailure.cardIsNotActionOrTrap,
      );
    }
    if (destinationZoneIndex != null &&
        (destinationZoneIndex < 0 ||
            destinationZoneIndex >= PlayerFieldState.actionTrapZoneCount)) {
      return DuelActionResult.failure(
        state,
        DuelActionFailure.invalidZoneIndex,
      );
    }

    final zones = List<CardInstance?>.from(field.actionTrapZones);
    final targetIndex = destinationZoneIndex ??
        zones.indexWhere((candidate) => candidate == null);
    if (targetIndex < 0) {
      return DuelActionResult.failure(
        state,
        DuelActionFailure.actionTrapZoneFull,
      );
    }
    if (zones[targetIndex] != null) {
      return DuelActionResult.failure(
        state,
        DuelActionFailure.actionTrapZoneOccupied,
      );
    }

    zones[targetIndex] = card.copyWith(
      controller: participant,
      faceUp: false,
      position: null,
      zoneIndex: targetIndex,
      attackedThisTurn: false,
      positionChangedThisTurn: false,
      runtimeData: {
        ...card.runtimeData,
        CardRuntimeKeys.setOnTurn: state.turnNumber,
      },
    );
    final hand = List<CardInstance>.from(field.hand)..removeAt(handIndex);
    final nextState = _replaceField(
      state,
      participant,
      field.copyWith(actionTrapZones: zones, hand: hand),
    );
    return DuelActionResult.success(
      _openResponseWindow(
        nextState,
        ResponseWindowType.set,
        _opponentOf(participant),
      ),
    );
  }

  AttackDeclarationResult declareAttack({
    required DuelState state,
    required DuelParticipant participant,
    required String attackerInstanceId,
    String? targetInstanceId,
  }) {
    if (state.isFinished) {
      return AttackDeclarationResult.failure(
        state,
        DuelActionFailure.duelFinished,
      );
    }
    if (participant != state.activePlayer) {
      return AttackDeclarationResult.failure(
        state,
        DuelActionFailure.notActivePlayer,
      );
    }
    if (state.chain.isOpen) {
      return AttackDeclarationResult.failure(
        state,
        DuelActionFailure.chainWindowOpen,
      );
    }
    if (state.currentPhase != DuelPhase.battle) {
      return AttackDeclarationResult.failure(
        state,
        DuelActionFailure.notBattlePhase,
      );
    }
    if (state.turnNumber == 1 && participant == state.startingPlayer) {
      return AttackDeclarationResult.failure(
        state,
        DuelActionFailure.attackForbiddenOnOpeningTurn,
      );
    }

    final attackerEntry = _findCharacter(
      _fieldFor(state, participant),
      attackerInstanceId,
    );
    if (attackerEntry == null) {
      return AttackDeclarationResult.failure(
        state,
        DuelActionFailure.attackerNotFound,
      );
    }
    final attacker = attackerEntry.card;
    if (attacker.controller != participant) {
      return AttackDeclarationResult.failure(
        state,
        DuelActionFailure.attackerNotControlled,
      );
    }
    if (attacker.position != BattlePosition.attack) {
      return AttackDeclarationResult.failure(
        state,
        DuelActionFailure.attackerNotInAttackPosition,
      );
    }
    if (attacker.attackedThisTurn) {
      return AttackDeclarationResult.failure(
        state,
        DuelActionFailure.attackerAlreadyAttacked,
      );
    }
    if (_runtimeValue(attacker, CardRuntimeKeys.cannotAttackTurn) ==
        state.turnNumber) {
      return AttackDeclarationResult.failure(
        state,
        DuelActionFailure.attackerCannotAttackByEffect,
      );
    }
    if (attacker.effectiveAtk == null) {
      return AttackDeclarationResult.failure(
        state,
        DuelActionFailure.missingCombatStats,
      );
    }

    final defendingPlayer = _opponentOf(participant);
    final defendingField = _fieldFor(state, defendingPlayer);
    final controlledDefenders = defendingField.characterZones.where(
      (candidate) => candidate?.controller == defendingPlayer,
    );
    if (targetInstanceId == null) {
      if (_runtimeValue(attacker, CardRuntimeKeys.directAttackForbiddenTurn) ==
          state.turnNumber) {
        return AttackDeclarationResult.failure(
          state,
          DuelActionFailure.directAttackBlocked,
        );
      }
      final directAttackAllowedByEffect = attacker is CardInstance &&
          (attacker.runtimeData[CardRuntimeKeys.directAttackAllowedTurn] ==
                  state.turnNumber ||
              (attacker.cardCode == 'FOR-005' &&
                  _controlsSylveToken(
                    _fieldFor(state, participant),
                    participant,
                  )));
      if (controlledDefenders.isNotEmpty && !directAttackAllowedByEffect) {
        return AttackDeclarationResult.failure(
          state,
          DuelActionFailure.directAttackBlocked,
        );
      }
    } else {
      final targetEntry = _findCharacter(defendingField, targetInstanceId);
      if (targetEntry == null) {
        return AttackDeclarationResult.failure(
          state,
          DuelActionFailure.targetNotFound,
        );
      }
      final target = targetEntry.card;
      if (target.controller != defendingPlayer || target.position == null) {
        return AttackDeclarationResult.failure(
          state,
          DuelActionFailure.invalidAttackTarget,
        );
      }
      if (_isProtectedByRoyalGuard(defendingField, target)) {
        return AttackDeclarationResult.failure(
          state,
          DuelActionFailure.invalidAttackTarget,
        );
      }
      if (_mustTargetDozoMythic(defendingField, attacker, target)) {
        return AttackDeclarationResult.failure(
          state,
          DuelActionFailure.invalidAttackTarget,
        );
      }
      final targetStat = target.position == BattlePosition.attack
          ? target.effectiveAtk
          : target.effectiveDef;
      if (targetStat == null) {
        return AttackDeclarationResult.failure(
          state,
          DuelActionFailure.missingCombatStats,
        );
      }
    }

    return AttackDeclarationResult.success(
      _openResponseWindow(
        state,
        ResponseWindowType.attackDeclaration,
        _opponentOf(participant),
      ),
      AttackDeclaration(
        declarationId:
            'attack:${state.turnNumber}:${participant.name}:$attackerInstanceId',
        attackingPlayer: participant,
        attackerInstanceId: attackerInstanceId,
        targetInstanceId: targetInstanceId,
        declaredTurn: state.turnNumber,
      ),
    );
  }

  CombatResolutionResult resolveAttack({
    required DuelState state,
    required AttackDeclaration declaration,
  }) {
    if (state.chain.isOpen) {
      return CombatResolutionResult(
        state: state,
        status: CombatResolutionStatus.responseWindowOpen,
      );
    }
    if (state.cancelledAttackDeclarationIds.contains(
      declaration.declarationId,
    )) {
      // Une attaque annulée a tout de même été déclarée et consomme donc
      // l'attaque du Personnage pour ce tour. Sans ce marquage, une IA pouvait
      // redéclarer immédiatement la même attaque (avec le même declarationId),
      // rouvrant indéfiniment la fenêtre de priorité.
      final attackerEntry = _findCharacter(
        _fieldFor(state, declaration.attackingPlayer),
        declaration.attackerInstanceId,
      );
      final cancelledState = attackerEntry == null
          ? state
          : _replaceCharacterAt(
              state,
              declaration.attackingPlayer,
              attackerEntry.index,
              _copyFieldCard(
                attackerEntry.card,
                attackedThisTurn: true,
              ),
            );
      return CombatResolutionResult(
        state: cancelledState,
        status: CombatResolutionStatus.cancelled,
      );
    }
    if (state.isFinished ||
        state.currentPhase != DuelPhase.battle ||
        state.activePlayer != declaration.attackingPlayer ||
        state.turnNumber != declaration.declaredTurn) {
      return CombatResolutionResult(
        state: state,
        status: CombatResolutionStatus.staleDeclaration,
      );
    }

    final attackingPlayer = declaration.attackingPlayer;
    final defendingPlayer = _opponentOf(attackingPlayer);
    final targetInstanceId = state.attackTargetOverrides.containsKey(
      declaration.declarationId,
    )
        ? state.attackTargetOverrides[declaration.declarationId]
        : declaration.targetInstanceId;
    var attackerEntry = _findCharacter(
      _fieldFor(state, attackingPlayer),
      declaration.attackerInstanceId,
    );
    if (attackerEntry == null) {
      return CombatResolutionResult(
        state: state,
        status: CombatResolutionStatus.interruptedAttackerMissing,
      );
    }
    if (attackerEntry.card.attackedThisTurn) {
      return CombatResolutionResult(
        state: state,
        status: CombatResolutionStatus.staleDeclaration,
      );
    }

    var workingState = _replaceCharacterAt(
      state,
      attackingPlayer,
      attackerEntry.index,
      _copyFieldCard(
        attackerEntry.card,
        attackedThisTurn: true,
      ),
    );
    attackerEntry = _findCharacter(
      _fieldFor(workingState, attackingPlayer),
      declaration.attackerInstanceId,
    );
    final attacker = attackerEntry!.card;
    final directAttackerAtk = _combatAttackValue(
      workingState,
      attacker,
      null,
    );
    if (directAttackerAtk == null) {
      return CombatResolutionResult(
        state: workingState,
        status: CombatResolutionStatus.invalidCombatStats,
      );
    }

    if (targetInstanceId == null) {
      var directDamage = directAttackerAtk;
      if (attacker is CardInstance &&
          (attacker.runtimeData[CardRuntimeKeys.directAttackAllowedTurn] ==
                  state.turnNumber ||
              (attacker.cardCode == 'FOR-005' &&
                  _controlsSylveToken(
                    _fieldFor(workingState, attackingPlayer),
                    attackingPlayer,
                  )))) {
        final divisor = attacker
            .runtimeData[CardRuntimeKeys.directAttackDamageDivisor] as int?;
        final effectiveDivisor = attacker.cardCode == 'FOR-005' ? 2 : divisor;
        if (effectiveDivisor != null && effectiveDivisor > 1) {
          directDamage =
              (directDamage + effectiveDivisor - 1) ~/ effectiveDivisor;
        }
      }
      directDamage = _damageDealtByAttacker(
        attacker,
        directDamage,
        state.turnNumber,
      );
      workingState = _applyCombatDamage(
        workingState,
        defendingPlayer,
        directDamage,
      );
      workingState = _clearCombatOnlyModifiers(
        workingState,
        attacker.instanceId,
      );
      return CombatResolutionResult(
        state: workingState,
        status: CombatResolutionStatus.resolved,
        damageByParticipant: {defendingPlayer: directDamage},
      );
    }

    var targetEntry = _findCharacter(
      _fieldFor(workingState, defendingPlayer),
      targetInstanceId,
    );
    if (targetEntry == null) {
      workingState = _clearCombatOnlyModifiers(
        workingState,
        attacker.instanceId,
      );
      return CombatResolutionResult(
        state: workingState,
        status: CombatResolutionStatus.interruptedTargetMissing,
      );
    }

    var targetFlippedFaceUp = false;
    if (!targetEntry.card.faceUp &&
        targetEntry.card.position == BattlePosition.defense) {
      targetFlippedFaceUp = true;
      workingState = _replaceCharacterAt(
        workingState,
        defendingPlayer,
        targetEntry.index,
        targetEntry.card is CardInstance
            ? (targetEntry.card as CardInstance).copyWith(
                faceUp: true,
                runtimeData: {
                  ...(targetEntry.card as CardInstance).runtimeData,
                  CardRuntimeKeys.flippedFaceUpTurn: state.turnNumber,
                },
              )
            : _copyFieldCard(targetEntry.card, faceUp: true),
      );
      targetEntry = _findCharacter(
        _fieldFor(workingState, defendingPlayer),
        targetInstanceId,
      );
    }

    final target = targetEntry!.card;
    final attackerAtk = _combatAttackValue(workingState, attacker, target);
    if (attackerAtk == null) {
      return CombatResolutionResult(
        state: workingState,
        status: CombatResolutionStatus.invalidCombatStats,
        targetFlippedFaceUp: targetFlippedFaceUp,
      );
    }
    final destroyed = <String>[];
    final damage = <DuelParticipant, int>{};
    if (target.position == BattlePosition.attack) {
      final targetAtk = _combatAttackValue(workingState, target, attacker);
      if (targetAtk == null) {
        return CombatResolutionResult(
          state: workingState,
          status: CombatResolutionStatus.invalidCombatStats,
          targetFlippedFaceUp: targetFlippedFaceUp,
        );
      }
      if (attackerAtk > targetAtk) {
        if (!_isBattleDestructionPrevented(target, state.turnNumber)) {
          workingState = _destroyCharacter(
            workingState,
            defendingPlayer,
            target.instanceId,
          );
          destroyed.add(target.instanceId);
        }
        final difference = _damageDealtByAttacker(
          attacker,
          attackerAtk - targetAtk,
          state.turnNumber,
        );
        workingState = _applyCombatDamage(
          workingState,
          defendingPlayer,
          difference,
        );
        damage[defendingPlayer] = difference;
      } else if (attackerAtk < targetAtk) {
        if (!_isBattleDestructionPrevented(attacker, state.turnNumber)) {
          workingState = _destroyCharacter(
            workingState,
            attackingPlayer,
            attacker.instanceId,
          );
          destroyed.add(attacker.instanceId);
        }
        final difference = targetAtk - attackerAtk;
        workingState = _applyCombatDamage(
          workingState,
          attackingPlayer,
          difference,
        );
        damage[attackingPlayer] = difference;
      } else {
        if (!_isBattleDestructionPrevented(attacker, state.turnNumber)) {
          workingState = _destroyCharacter(
            workingState,
            attackingPlayer,
            attacker.instanceId,
          );
          destroyed.add(attacker.instanceId);
        }
        if (!_isBattleDestructionPrevented(target, state.turnNumber)) {
          workingState = _destroyCharacter(
            workingState,
            defendingPlayer,
            target.instanceId,
          );
          destroyed.add(target.instanceId);
        }
      }
    } else if (target.position == BattlePosition.defense) {
      final targetDef = _combatDefenseValue(target);
      if (targetDef == null) {
        return CombatResolutionResult(
          state: workingState,
          status: CombatResolutionStatus.invalidCombatStats,
          targetFlippedFaceUp: targetFlippedFaceUp,
        );
      }
      if (attackerAtk > targetDef) {
        if (!_isBattleDestructionPrevented(target, state.turnNumber)) {
          workingState = _destroyCharacter(
            workingState,
            defendingPlayer,
            target.instanceId,
          );
          destroyed.add(target.instanceId);
        }
        if (attacker is CardInstance && attacker.cardCode == 'SAV-006') {
          final difference = attackerAtk - targetDef;
          final piercingDamage = _damageDealtByAttacker(
            attacker,
            (difference + 1) ~/ 2,
            state.turnNumber,
          );
          workingState = _applyCombatDamage(
            workingState,
            defendingPlayer,
            piercingDamage,
          );
          damage[defendingPlayer] = piercingDamage;
        }
      } else if (attackerAtk < targetDef) {
        final difference = targetDef - attackerAtk;
        workingState = _applyCombatDamage(
          workingState,
          attackingPlayer,
          difference,
        );
        damage[attackingPlayer] = difference;
      }
    } else {
      return CombatResolutionResult(
        state: workingState,
        status: CombatResolutionStatus.invalidCombatStats,
        targetFlippedFaceUp: targetFlippedFaceUp,
      );
    }

    if (targetFlippedFaceUp &&
        target is CardInstance &&
        !workingState.isFinished) {
      workingState = _enqueueAutomaticCombatFlipEffect(
        workingState,
        target,
      );
    }

    workingState = _clearCombatOnlyModifiers(
      workingState,
      attacker.instanceId,
    );
    workingState = _clearCombatOnlyModifiers(
      workingState,
      target.instanceId,
    );

    return CombatResolutionResult(
      state: workingState,
      status: CombatResolutionStatus.resolved,
      targetFlippedFaceUp: targetFlippedFaceUp,
      destroyedCardInstanceIds: destroyed,
      damageByParticipant: damage,
    );
  }

  /// Active un effet factice ou réel et l'ajoute au sommet de la Chaîne.
  ChainActivationResult activateChainEffect({
    required DuelState state,
    required ChainLink link,
  }) {
    if (state.isFinished) {
      return ChainActivationResult.failure(
        state,
        DuelActionFailure.duelFinished,
      );
    }
    if (state.chain.isResolving) {
      return ChainActivationResult.failure(
        state,
        DuelActionFailure.chainIsResolving,
      );
    }
    if (state.chain.window == ResponseWindowType.combatCalculation &&
        !state.chain.allowActivationDuringCombatCalculation) {
      return ChainActivationResult.failure(
        state,
        DuelActionFailure.activationForbiddenDuringCombatCalculation,
      );
    }

    final definition = _chainEffects[link.effectKey];
    if (definition == null) {
      return ChainActivationResult.failure(
        state,
        DuelActionFailure.unknownChainEffect,
      );
    }
    final preparedLink = definition.prepareLink(state, link);
    final sourceCard = _findFieldCatalogCard(
      state,
      preparedLink.sourceCardInstanceId,
    );
    if (sourceCard?.category == CardCategory.trap &&
        sourceCard?.runtimeData[CardRuntimeKeys.setOnTurn] ==
            state.turnNumber &&
        sourceCard
                ?.runtimeData[CardRuntimeKeys.sameTurnTrapActivationAllowed] !=
            state.turnNumber) {
      return ChainActivationResult.failure(
        state,
        DuelActionFailure.chainActivationConditionNotMet,
      );
    }
    if (sourceCard?.runtimeData[CardRuntimeKeys.effectsNegatedUntilTurn] ==
        state.turnNumber) {
      return ChainActivationResult.failure(
        state,
        DuelActionFailure.chainActivationConditionNotMet,
      );
    }
    if (state.chain.links.any(
      (existing) => existing.linkId == preparedLink.linkId,
    )) {
      return ChainActivationResult.failure(
        state,
        DuelActionFailure.duplicateChainLink,
      );
    }

    if (state.chain.isOpen) {
      if (state.chain.priorityPlayer != preparedLink.activatingPlayer) {
        return ChainActivationResult.failure(
          state,
          DuelActionFailure.notPriorityPlayer,
        );
      }
      if (preparedLink.speed == ChainSpeed.speed1) {
        return ChainActivationResult.failure(
          state,
          DuelActionFailure.illegalChainSpeed,
        );
      }
      if (state.chain.links.isNotEmpty &&
          !preparedLink.speed.canRespondTo(state.chain.links.last.speed)) {
        return ChainActivationResult.failure(
          state,
          DuelActionFailure.illegalChainSpeed,
        );
      }
    } else if (preparedLink.activatingPlayer != state.activePlayer) {
      return ChainActivationResult.failure(
        state,
        DuelActionFailure.notActivePlayer,
      );
    }

    if (!definition.canActivate(state, preparedLink)) {
      return ChainActivationResult.failure(
        state,
        DuelActionFailure.chainActivationConditionNotMet,
      );
    }
    if (_isProtectedFaceDownEffectTarget(state, preparedLink)) {
      return ChainActivationResult.failure(
        state,
        DuelActionFailure.illegalChainTarget,
      );
    }
    if (!definition.isTargetLegal(state, preparedLink)) {
      return ChainActivationResult.failure(
        state,
        DuelActionFailure.illegalChainTarget,
      );
    }

    final stateAfterCost = definition.payCost(state, preparedLink);
    final currentChain = state.chain.isOpen
        ? state.chain
        : ChainState(
            window: ResponseWindowType.effectActivation,
            priorityPlayer: preparedLink.activatingPlayer,
          );
    final nextChain = currentChain.copyWith(
      links: [...currentChain.links, preparedLink],
      priorityPlayer: _opponentOf(preparedLink.activatingPlayer),
      consecutivePasses: 0,
    );
    return ChainActivationResult.success(
      stateAfterCost.copyWith(chain: nextChain),
      preparedLink,
    );
  }

  /// Place ou retourne une carte du catalogue, puis tente son activation.
  ///
  /// Cette primitive garde le déplacement de zone dans le moteur pur. En cas
  /// d'activation illégale, l'état original est retourné : aucune carte n'est
  /// révélée et aucun coût n'est payé.
  ChainActivationResult activateCard({
    required DuelState state,
    required DuelParticipant participant,
    required String cardInstanceId,
    required ChainLink link,
  }) {
    if (state.isFinished) {
      return ChainActivationResult.failure(
        state,
        DuelActionFailure.duelFinished,
      );
    }
    if (link.activatingPlayer != participant ||
        link.sourceCardInstanceId != cardInstanceId) {
      return ChainActivationResult.failure(
        state,
        DuelActionFailure.cardCannotBeActivated,
      );
    }

    final field = _fieldFor(state, participant);
    final handIndex = field.hand.indexWhere(
      (card) => card.instanceId == cardInstanceId,
    );
    var preparedState = state;

    if (handIndex >= 0) {
      final card = field.hand[handIndex];
      if (card.category == CardCategory.mythic ||
          card.category == CardCategory.character) {
        return ChainActivationResult.failure(
          state,
          DuelActionFailure.cardCannotBeActivated,
        );
      }
      final isQuickActionResponse = state.chain.isOpen &&
          card.category == CardCategory.action &&
          card.subtype == 'quick';
      if (!isQuickActionResponse) {
        if (participant != state.activePlayer) {
          return ChainActivationResult.failure(
            state,
            DuelActionFailure.notActivePlayer,
          );
        }
        if (state.currentPhase != DuelPhase.main1 &&
            state.currentPhase != DuelPhase.main2) {
          return ChainActivationResult.failure(
            state,
            DuelActionFailure.notMainPhase,
          );
        }
        if (state.chain.isOpen) {
          return ChainActivationResult.failure(
            state,
            DuelActionFailure.chainWindowOpen,
          );
        }
      }
      final hand = List<CardInstance>.from(field.hand)..removeAt(handIndex);

      if (card.category == CardCategory.terrain) {
        var nextField = field.copyWith(hand: hand);
        final previousTerrain = nextField.terrainZone;
        if (previousTerrain != null) {
          nextField = nextField.copyWith(
            terrainZone: null,
            graveyard: [
              ...nextField.graveyard,
              previousTerrain.copyWith(
                controller: previousTerrain.owner,
                faceUp: true,
                position: null,
                zoneIndex: null,
              ),
            ],
          );
        }
        nextField = nextField.copyWith(
          terrainZone: card.copyWith(
            controller: participant,
            faceUp: true,
            position: null,
            zoneIndex: 0,
          ),
        );
        preparedState = _replaceField(state, participant, nextField);
      } else {
        final zones = List<CardInstance?>.from(field.actionTrapZones);
        final zoneIndex = zones.indexWhere((candidate) => candidate == null);
        if (zoneIndex < 0) {
          return ChainActivationResult.failure(
            state,
            DuelActionFailure.actionTrapZoneFull,
          );
        }
        zones[zoneIndex] = card.copyWith(
          controller: participant,
          faceUp: true,
          position: null,
          zoneIndex: zoneIndex,
          runtimeData: {
            ...card.runtimeData,
            CardRuntimeKeys.pendingOneShotChainLink: link.linkId,
          },
        );
        preparedState = _replaceField(
          state,
          participant,
          field.copyWith(hand: hand, actionTrapZones: zones),
        );
      }
    } else {
      final source = _findFieldCatalogCard(state, cardInstanceId);
      if (source == null || source.controller != participant) {
        return ChainActivationResult.failure(
          state,
          DuelActionFailure.cardCannotBeActivated,
        );
      }
      if (source.category == CardCategory.character ||
          source.category == CardCategory.mythic) {
        // Les effets activés de Personnage utilisent directement la Chaîne :
        // ils n'ont pas besoin d'un changement de zone préalable.
        preparedState = state;
      } else if (!source.faceUp) {
        preparedState = _updateCatalogCard(
          state,
          cardInstanceId,
          (card) => card.copyWith(
            faceUp: true,
            runtimeData: {
              ...card.runtimeData,
              CardRuntimeKeys.pendingOneShotChainLink: link.linkId,
            },
          ),
        );
      }
    }

    final activation = activateChainEffect(state: preparedState, link: link);
    if (!activation.succeeded) {
      return ChainActivationResult.failure(state, activation.failure!);
    }
    return activation;
  }

  /// Passe la priorité. La seconde passe consécutive résout la Chaîne en LIFO.
  PriorityPassResult passPriority({
    required DuelState state,
    required DuelParticipant participant,
  }) {
    if (state.chain.isResolving) {
      return PriorityPassResult(
        state: state,
        failure: DuelActionFailure.chainIsResolving,
      );
    }
    if (!state.chain.isOpen) {
      return PriorityPassResult(
        state: state,
        failure: DuelActionFailure.noResponseWindow,
      );
    }
    if (state.chain.priorityPlayer != participant) {
      return PriorityPassResult(
        state: state,
        failure: DuelActionFailure.notPriorityPlayer,
      );
    }

    final passCount = state.chain.consecutivePasses + 1;
    if (passCount < 2) {
      return PriorityPassResult(
        state: state.copyWith(
          chain: state.chain.copyWith(
            priorityPlayer: _opponentOf(participant),
            consecutivePasses: passCount,
          ),
        ),
      );
    }

    if (state.chain.links.isEmpty) {
      return PriorityPassResult(
          state: state.copyWith(chain: ChainState.closed()));
    }

    var workingState = state.copyWith(
      chain: state.chain.copyWith(
        priorityPlayer: null,
        consecutivePasses: 2,
        isResolving: true,
      ),
    );
    final resolvedLinkIds = <String>[];
    final fizzledLinkIds = <String>[];
    var interruptedByVictory = false;

    for (final link in state.chain.links.reversed) {
      final definition = _chainEffects[link.effectKey]!;
      if (workingState.chain.negatedLinkIds.contains(link.linkId)) {
        fizzledLinkIds.add(link.linkId);
      } else if (!definition.isTargetLegal(workingState, link)) {
        fizzledLinkIds.add(link.linkId);
      } else {
        final resolvingChain = workingState.chain;
        final resolvedState = definition.resolve(workingState, link);
        workingState = resolvedState.copyWith(
          chain: resolvingChain.copyWith(
            negatedLinkIds: {
              ...resolvingChain.negatedLinkIds,
              ...resolvedState.chain.negatedLinkIds,
            },
          ),
        );
        resolvedLinkIds.add(link.linkId);
      }

      workingState = _sendResolvedOneShotSourceToGraveyard(
        workingState,
        link,
      );

      workingState = _determineWinnerFromLifePoints(workingState);
      if (workingState.isFinished) {
        interruptedByVictory = true;
        break;
      }
    }

    var finalState = workingState.copyWith(chain: ChainState.closed());
    if (!finalState.isFinished) {
      finalState = _openNextPendingEffectTrigger(finalState);
    }
    return PriorityPassResult(
      state: finalState,
      resolutionTriggered: true,
      interruptedByVictory: interruptedByVictory,
      resolvedLinkIds: resolvedLinkIds,
      fizzledLinkIds: fizzledLinkIds,
    );
  }

  DuelActionResult _normalPlace({
    required DuelState state,
    required DuelParticipant participant,
    required String cardInstanceId,
    required List<String> sacrificeInstanceIds,
    required int? destinationZoneIndex,
    required bool faceUp,
    required BattlePosition position,
  }) {
    if (state.isFinished) {
      return DuelActionResult.failure(
        state,
        DuelActionFailure.duelFinished,
      );
    }
    if (participant != state.activePlayer) {
      return DuelActionResult.failure(
        state,
        DuelActionFailure.notActivePlayer,
      );
    }
    if (state.chain.isOpen) {
      return DuelActionResult.failure(
        state,
        DuelActionFailure.chainWindowOpen,
      );
    }
    if (state.normalSummonUsed[participant] ?? false) {
      return DuelActionResult.failure(
        state,
        DuelActionFailure.normalSummonAlreadyUsed,
      );
    }

    final field = _fieldFor(state, participant);
    final handIndex = field.hand.indexWhere(
      (card) => card.instanceId == cardInstanceId,
    );
    if (handIndex < 0) {
      return DuelActionResult.failure(
        state,
        DuelActionFailure.cardNotInHand,
      );
    }

    final card = field.hand[handIndex];
    final rank = card.rank;
    if (card.category == CardCategory.mythic || (rank != null && rank >= 9)) {
      return DuelActionResult.failure(
        state,
        DuelActionFailure.mythicNormalSummonForbidden,
      );
    }
    if (card.category != CardCategory.character) {
      return DuelActionResult.failure(
        state,
        DuelActionFailure.cardIsNotCharacter,
      );
    }
    if (rank == null || rank < 1 || rank > 8) {
      return DuelActionResult.failure(
        state,
        DuelActionFailure.invalidCharacterRank,
      );
    }

    final requiredSacrifices = requiredSacrificesForNormalPlay(card)!;
    if (sacrificeInstanceIds.length != requiredSacrifices ||
        sacrificeInstanceIds.toSet().length != requiredSacrifices) {
      return DuelActionResult.failure(
        state,
        DuelActionFailure.wrongSacrificeCount,
      );
    }

    if (destinationZoneIndex != null &&
        (destinationZoneIndex < 0 ||
            destinationZoneIndex >= PlayerFieldState.characterZoneCount)) {
      return DuelActionResult.failure(
        state,
        DuelActionFailure.invalidZoneIndex,
      );
    }

    final characterZones = List<FieldCardInstance?>.from(
      field.characterZones,
    );
    final sacrifices = <FieldCardInstance>[];
    for (final sacrificeId in sacrificeInstanceIds) {
      final sacrificeIndex = characterZones.indexWhere(
        (candidate) =>
            candidate?.instanceId == sacrificeId &&
            candidate?.controller == participant,
      );
      if (sacrificeIndex < 0) {
        return DuelActionResult.failure(
          state,
          DuelActionFailure.invalidSacrifice,
        );
      }
      final sacrifice = characterZones[sacrificeIndex]!;
      if (sacrifice is TokenInstance &&
          sacrifice.runtimeData[CardRuntimeKeys.cannotBeSacrificedTurn] ==
              state.turnNumber) {
        return DuelActionResult.failure(
          state,
          DuelActionFailure.invalidSacrifice,
        );
      }
      if (sacrifice is CardInstance &&
          sacrifice.category != CardCategory.character) {
        return DuelActionResult.failure(
          state,
          DuelActionFailure.invalidSacrifice,
        );
      }
      sacrifices.add(sacrifice);
      characterZones[sacrificeIndex] = null;
    }

    final targetIndex = destinationZoneIndex ??
        characterZones.indexWhere((candidate) => candidate == null);
    if (targetIndex < 0) {
      return DuelActionResult.failure(
        state,
        DuelActionFailure.characterZoneFull,
      );
    }
    if (characterZones[targetIndex] != null) {
      return DuelActionResult.failure(
        state,
        DuelActionFailure.characterZoneOccupied,
      );
    }

    final summonedCard = card.copyWith(
      controller: participant,
      faceUp: faceUp,
      position: position,
      zoneIndex: targetIndex,
      summonedTurn: state.turnNumber,
      attackedThisTurn: false,
      positionChangedThisTurn: false,
    );
    characterZones[targetIndex] = summonedCard;

    final hand = List<CardInstance>.from(field.hand)..removeAt(handIndex);
    var nextState = _replaceField(
      state,
      participant,
      field.copyWith(
        characterZones: characterZones,
        hand: hand,
      ),
    );

    for (final sacrifice in sacrifices) {
      if (sacrifice is TokenInstance) {
        continue;
      }
      final sacrificedCard = (sacrifice as CardInstance).copyWith(
        controller: sacrifice.owner,
        faceUp: true,
        position: null,
        zoneIndex: null,
        attackedThisTurn: false,
        positionChangedThisTurn: false,
      );
      final ownerField = _fieldFor(nextState, sacrifice.owner);
      nextState = _replaceField(
        nextState,
        sacrifice.owner,
        ownerField.copyWith(
          graveyard: [...ownerField.graveyard, sacrificedCard],
        ),
      );
    }

    final summonUsage = Map<DuelParticipant, bool>.from(
      nextState.normalSummonUsed,
    )..[participant] = true;
    final placedState = nextState.copyWith(normalSummonUsed: summonUsage);
    return DuelActionResult.success(
      _openResponseWindow(
        placedState,
        faceUp ? ResponseWindowType.summon : ResponseWindowType.set,
        _opponentOf(participant),
      ),
    );
  }

  /// Résout l'unique pioche due pendant la Phase de Pioche courante.
  ///
  /// L'index 0 de [PlayerFieldState.deck] représente le dessus du deck.
  DuelActionResult resolveDrawPhase(DuelState state) {
    if (state.isFinished) {
      return DuelActionResult.failure(
        state,
        DuelActionFailure.duelFinished,
      );
    }
    if (state.currentPhase != DuelPhase.draw) {
      return DuelActionResult.failure(
        state,
        DuelActionFailure.notDrawPhase,
      );
    }
    if (state.drawPhaseResolved) {
      return DuelActionResult.failure(
        state,
        DuelActionFailure.drawAlreadyResolved,
      );
    }

    final skipsOpeningDraw =
        state.turnNumber == 1 && state.activePlayer == state.startingPlayer;
    if (skipsOpeningDraw) {
      return DuelActionResult.success(
        state.copyWith(drawPhaseResolved: true),
      );
    }

    final participant = state.activePlayer;
    final field = _fieldFor(state, participant);
    if (field.deck.isEmpty) {
      return DuelActionResult.success(
        state.copyWith(
          drawPhaseResolved: true,
          winner: _opponentOf(participant),
          endReason: DuelEndReason.deckOut,
        ),
      );
    }

    final deck = List<CardInstance>.from(field.deck);
    final drawnCard = deck.removeAt(0).copyWith(
          controller: participant,
          faceUp: false,
          position: null,
          zoneIndex: null,
          attackedThisTurn: false,
          positionChangedThisTurn: false,
        );
    final nextField = field.copyWith(
      deck: deck,
      hand: [...field.hand, drawnCard],
    );
    return DuelActionResult.success(
      _replaceField(state, participant, nextField).copyWith(
        drawPhaseResolved: true,
      ),
    );
  }

  HandDiscardRequirement? handDiscardRequirement(
    DuelState state,
    DuelParticipant participant,
  ) {
    final hand = _fieldFor(state, participant).hand;
    final excess = hand.length - maximumHandSize;
    if (excess <= 0) return null;
    return HandDiscardRequirement(
      participant: participant,
      requiredCount: excess,
      candidates: hand,
    );
  }

  DuelActionResult discardForHandLimit({
    required DuelState state,
    required DuelParticipant participant,
    required List<String> cardInstanceIds,
  }) {
    if (state.isFinished) {
      return DuelActionResult.failure(
        state,
        DuelActionFailure.duelFinished,
      );
    }
    if (participant != state.activePlayer) {
      return DuelActionResult.failure(
        state,
        DuelActionFailure.notActivePlayer,
      );
    }
    if (state.currentPhase != DuelPhase.end) {
      return DuelActionResult.failure(
        state,
        DuelActionFailure.notEndPhase,
      );
    }

    final requirement = handDiscardRequirement(state, participant);
    if (requirement == null) {
      return DuelActionResult.failure(
        state,
        DuelActionFailure.noHandLimitDiscardRequired,
      );
    }
    final selectedIds = cardInstanceIds.toSet();
    if (cardInstanceIds.length != requirement.requiredCount ||
        selectedIds.length != requirement.requiredCount) {
      return DuelActionResult.failure(
        state,
        DuelActionFailure.invalidDiscardSelection,
      );
    }

    final field = _fieldFor(state, participant);
    if (selectedIds.any(
      (id) => field.hand.every((card) => card.instanceId != id),
    )) {
      return DuelActionResult.failure(
        state,
        DuelActionFailure.invalidDiscardSelection,
      );
    }

    final discarded = <CardInstance>[];
    final hand = <CardInstance>[];
    for (final card in field.hand) {
      if (selectedIds.contains(card.instanceId)) {
        discarded.add(
          card.copyWith(
            controller: card.owner,
            faceUp: true,
            position: null,
            zoneIndex: null,
            attackedThisTurn: false,
            positionChangedThisTurn: false,
          ),
        );
      } else {
        hand.add(card);
      }
    }

    return DuelActionResult.success(
      _replaceField(
        state,
        participant,
        field.copyWith(
          hand: hand,
          graveyard: [...field.graveyard, ...discarded],
        ),
      ),
    );
  }

  /// Passe à la phase suivante sans résoudre de combat ni de Chaîne.
  DuelActionResult advancePhase(DuelState state) {
    if (state.isFinished) {
      return DuelActionResult.failure(
        state,
        DuelActionFailure.duelFinished,
      );
    }
    if (state.chain.isOpen) {
      return DuelActionResult.failure(
        state,
        DuelActionFailure.chainWindowOpen,
      );
    }

    var workingState = state;
    if (workingState.currentPhase == DuelPhase.draw &&
        !workingState.drawPhaseResolved) {
      final drawResult = resolveDrawPhase(workingState);
      if (!drawResult.succeeded || drawResult.state.isFinished) {
        return drawResult;
      }
      workingState = drawResult.state;
    }

    switch (workingState.currentPhase) {
      case DuelPhase.draw:
        final preparationState = workingState.copyWith(
          currentPhase: DuelPhase.preparation,
        );
        return DuelActionResult.success(
          _determinePreparationAlternativeWinner(preparationState),
        );
      case DuelPhase.preparation:
        return DuelActionResult.success(
          workingState.copyWith(currentPhase: DuelPhase.main1),
        );
      case DuelPhase.main1:
        return DuelActionResult.success(
          workingState.copyWith(currentPhase: DuelPhase.battle),
        );
      case DuelPhase.battle:
        return DuelActionResult.success(
          workingState.copyWith(currentPhase: DuelPhase.main2),
        );
      case DuelPhase.main2:
        return DuelActionResult.success(
          workingState.copyWith(currentPhase: DuelPhase.end),
        );
      case DuelPhase.end:
        final requirement = handDiscardRequirement(
          workingState,
          workingState.activePlayer,
        );
        if (requirement != null) {
          return DuelActionResult.failure(
            workingState,
            DuelActionFailure.handLimitDiscardRequired,
            discardRequirement: requirement,
          );
        }

        final endingTurn = workingState.turnNumber;
        var cleanedState = workingState;
        for (final participant in DuelParticipant.values) {
          cleanedState = _replaceField(
            cleanedState,
            participant,
            _expireEndOfTurnState(
              _fieldFor(cleanedState, participant),
              endingTurn,
            ),
          );
        }

        final nextPlayer = _opponentOf(workingState.activePlayer);
        final resetField = _resetTurnFlags(
          _fieldFor(cleanedState, nextPlayer),
        );
        final nextState = _replaceField(
          cleanedState,
          nextPlayer,
          resetField,
        );
        return DuelActionResult.success(
          nextState.copyWith(
            turnNumber: workingState.turnNumber + 1,
            activePlayer: nextPlayer,
            currentPhase: DuelPhase.draw,
            drawPhaseResolved: false,
            normalSummonUsed: const {
              DuelParticipant.player: false,
              DuelParticipant.ai: false,
            },
            preventedEffectDestructionInstanceIds: const {},
          ),
        );
    }
  }

  PlayerFieldState _resetTurnFlags(PlayerFieldState field) {
    CardInstance resetCard(CardInstance card) => card.copyWith(
          attackedThisTurn: false,
          positionChangedThisTurn: false,
        );

    FieldCardInstance? resetFieldCard(FieldCardInstance? card) {
      if (card == null) return null;
      if (card is CardInstance) return resetCard(card);
      return (card as TokenInstance).copyWith(
        attackedThisTurn: false,
        positionChangedThisTurn: false,
      );
    }

    return PlayerFieldState(
      participant: field.participant,
      characterZones: field.characterZones.map(resetFieldCard).toList(),
      actionTrapZones: field.actionTrapZones
          .map((card) => card == null ? null : resetCard(card))
          .toList(),
      terrainZone:
          field.terrainZone == null ? null : resetCard(field.terrainZone!),
      deck: field.deck.map(resetCard).toList(),
      hand: field.hand.map(resetCard).toList(),
      graveyard: field.graveyard.map(resetCard).toList(),
      banished: field.banished.map(resetCard).toList(),
      mythicReserve: field.mythicReserve.map(resetCard).toList(),
      revealedCardInstanceIds: field.revealedCardInstanceIds,
    );
  }

  PlayerFieldState _expireEndOfTurnState(
    PlayerFieldState field,
    int endingTurn,
  ) {
    List<RuntimeStatModifier> activeModifiers(FieldCardInstance card) {
      return card.runtimeModifiers.where((modifier) {
        final expiryTurn = modifier.expiresAtTurn;
        return expiryTurn == null || expiryTurn > endingTurn;
      }).toList();
    }

    CardInstance cleanCard(CardInstance card) {
      final runtimeData = Map<String, Object?>.from(card.runtimeData);
      final allowedTurn = runtimeData[CardRuntimeKeys.directAttackAllowedTurn];
      if (allowedTurn is int && allowedTurn <= endingTurn) {
        runtimeData
          ..remove(CardRuntimeKeys.directAttackAllowedTurn)
          ..remove(CardRuntimeKeys.directAttackDamageDivisor);
      }
      final negatedUntilTurn =
          runtimeData[CardRuntimeKeys.effectsNegatedUntilTurn];
      if (negatedUntilTurn is int && negatedUntilTurn <= endingTurn) {
        runtimeData.remove(CardRuntimeKeys.effectsNegatedUntilTurn);
      }
      final flippedTurn = runtimeData[CardRuntimeKeys.flippedFaceUpTurn];
      if (flippedTurn is int && flippedTurn <= endingTurn) {
        runtimeData.remove(CardRuntimeKeys.flippedFaceUpTurn);
      }
      final cannotAttackTurn = runtimeData[CardRuntimeKeys.cannotAttackTurn];
      if (cannotAttackTurn is int && cannotAttackTurn <= endingTurn) {
        runtimeData.remove(CardRuntimeKeys.cannotAttackTurn);
      }
      final sameTurnTrapActivation =
          runtimeData[CardRuntimeKeys.sameTurnTrapActivationAllowed];
      if (sameTurnTrapActivation is int &&
          sameTurnTrapActivation <= endingTurn) {
        runtimeData.remove(CardRuntimeKeys.sameTurnTrapActivationAllowed);
      }
      final battleProtection =
          runtimeData[CardRuntimeKeys.cannotBeDestroyedInBattleTurn];
      if (battleProtection is int && battleProtection <= endingTurn) {
        runtimeData.remove(CardRuntimeKeys.cannotBeDestroyedInBattleTurn);
      }
      return card.copyWith(
        runtimeModifiers: activeModifiers(card),
        runtimeData: runtimeData,
      );
    }

    FieldCardInstance? cleanFieldCard(FieldCardInstance? card) {
      if (card == null) return null;
      if (card is CardInstance) return cleanCard(card);
      return (card as TokenInstance).copyWith(
        runtimeModifiers: activeModifiers(card),
        runtimeData: {
          for (final entry in card.runtimeData.entries)
            if (!(entry.key == CardRuntimeKeys.cannotBeSacrificedTurn &&
                entry.value is int &&
                (entry.value! as int) <= endingTurn))
              entry.key: entry.value,
        },
      );
    }

    return PlayerFieldState(
      participant: field.participant,
      characterZones: field.characterZones.map(cleanFieldCard).toList(),
      actionTrapZones: field.actionTrapZones
          .map((card) => card == null ? null : cleanCard(card))
          .toList(),
      terrainZone:
          field.terrainZone == null ? null : cleanCard(field.terrainZone!),
      deck: field.deck.map(cleanCard).toList(),
      hand: field.hand.map(cleanCard).toList(),
      graveyard: field.graveyard.map(cleanCard).toList(),
      banished: field.banished.map(cleanCard).toList(),
      mythicReserve: field.mythicReserve.map(cleanCard).toList(),
      revealedCardInstanceIds: field.revealedCardInstanceIds,
    );
  }

  ({int index, FieldCardInstance card})? _findCharacter(
    PlayerFieldState field,
    String instanceId,
  ) {
    final index = field.characterZones.indexWhere(
      (candidate) => candidate?.instanceId == instanceId,
    );
    if (index < 0) return null;
    return (index: index, card: field.characterZones[index]!);
  }

  CardInstance? _findFieldCatalogCard(
    DuelState state,
    String? instanceId,
  ) {
    if (instanceId == null) return null;
    for (final participant in DuelParticipant.values) {
      final field = _fieldFor(state, participant);
      for (final card in field.characterZones) {
        if (card is CardInstance && card.instanceId == instanceId) return card;
      }
      for (final card in field.actionTrapZones) {
        if (card?.instanceId == instanceId) return card;
      }
      if (field.terrainZone?.instanceId == instanceId) {
        return field.terrainZone;
      }
    }
    return null;
  }

  DuelState _updateCatalogCard(
    DuelState state,
    String instanceId,
    CardInstance Function(CardInstance card) update,
  ) {
    for (final participant in DuelParticipant.values) {
      final field = _fieldFor(state, participant);
      final characterIndex = field.characterZones.indexWhere(
        (card) => card is CardInstance && card.instanceId == instanceId,
      );
      if (characterIndex >= 0) {
        final zones = List<FieldCardInstance?>.from(field.characterZones);
        zones[characterIndex] = update(zones[characterIndex]! as CardInstance);
        return _replaceField(
          state,
          participant,
          field.copyWith(characterZones: zones),
        );
      }
      final actionIndex = field.actionTrapZones.indexWhere(
        (card) => card?.instanceId == instanceId,
      );
      if (actionIndex >= 0) {
        final zones = List<CardInstance?>.from(field.actionTrapZones);
        zones[actionIndex] = update(zones[actionIndex]!);
        return _replaceField(
          state,
          participant,
          field.copyWith(actionTrapZones: zones),
        );
      }
      if (field.terrainZone?.instanceId == instanceId) {
        return _replaceField(
          state,
          participant,
          field.copyWith(terrainZone: update(field.terrainZone!)),
        );
      }
    }
    return state;
  }

  DuelState _sendResolvedOneShotSourceToGraveyard(
    DuelState state,
    ChainLink link,
  ) {
    final sourceId = link.sourceCardInstanceId;
    if (sourceId == null) return state;
    final source = _findFieldCatalogCard(state, sourceId);
    if (source == null) return state;
    if (source.runtimeData[CardRuntimeKeys.pendingOneShotChainLink] !=
        link.linkId) {
      return state;
    }
    final isOneShotAction = source.category == CardCategory.action &&
        source.subtype != 'continuous';
    final isOneShotTrap =
        source.category == CardCategory.trap && source.subtype != 'continuous';
    if (!isOneShotAction && !isOneShotTrap) {
      return _updateCatalogCard(state, sourceId, (card) {
        final runtimeData = Map<String, Object?>.from(card.runtimeData)
          ..remove(CardRuntimeKeys.pendingOneShotChainLink);
        return card.copyWith(runtimeData: runtimeData);
      });
    }
    return _sendCatalogCardToOwnerGraveyard(
      _removeCatalogCardFromField(state, sourceId),
      source,
    );
  }

  DuelState _removeCatalogCardFromField(DuelState state, String instanceId) {
    for (final participant in DuelParticipant.values) {
      final field = _fieldFor(state, participant);
      final actionIndex = field.actionTrapZones.indexWhere(
        (card) => card?.instanceId == instanceId,
      );
      if (actionIndex >= 0) {
        final zones = List<CardInstance?>.from(field.actionTrapZones)
          ..[actionIndex] = null;
        return _replaceField(
          state,
          participant,
          field.copyWith(actionTrapZones: zones),
        );
      }
    }
    return state;
  }

  DuelState _enqueueAutomaticCombatFlipEffect(
    DuelState state,
    CardInstance flippedCard,
  ) {
    final factory = _combatFlipTriggerLinkFactory;
    final effectKey = flippedCard.effectKey;
    if (effectKey == null || state.chain.isOpen) {
      return state;
    }
    final definition = _chainEffects[effectKey];
    if (definition == null) return state;
    final link = factory?.call(state: state, flippedCard: flippedCard) ??
        definition.createAutomaticTriggerLink(
          state: state,
          source: flippedCard,
          event: AutomaticEffectTrigger.flippedFaceUp,
          linkId: 'combat-flip:${flippedCard.instanceId}:${state.turnNumber}',
        );
    if (link == null ||
        link.effectKey != effectKey ||
        link.sourceCardInstanceId != flippedCard.instanceId ||
        link.activatingPlayer != flippedCard.controller) {
      return state;
    }
    final prepared = definition.prepareLink(state, link);
    if (!definition.canActivate(state, prepared) ||
        !definition.isTargetLegal(state, prepared)) {
      return state;
    }
    final afterCost = definition.payCost(state, prepared);
    return afterCost.copyWith(
      chain: ChainState(
        links: [prepared],
        window: ResponseWindowType.effectActivation,
        priorityPlayer: _opponentOf(prepared.activatingPlayer),
      ),
    );
  }

  DuelState _openNextPendingEffectTrigger(DuelState state) {
    var workingState = state;
    while (workingState.pendingEffectTriggers.isNotEmpty) {
      final pending = workingState.pendingEffectTriggers.first;
      workingState = workingState.copyWith(
        pendingEffectTriggers:
            workingState.pendingEffectTriggers.skip(1).toList(),
      );
      final source = _findFieldCatalogCard(
        workingState,
        pending.sourceCardInstanceId,
      );
      if (source == null || source.controller != pending.controller) continue;
      final effectKey = source.effectKey;
      if (effectKey == null) continue;
      final definition = _chainEffects[effectKey];
      if (definition == null) continue;
      final link = definition.createAutomaticTriggerLink(
            state: workingState,
            source: source,
            event: pending.event,
            linkId: pending.triggerId,
          ) ??
          _buildAutomaticMythicSummonTriggerLink(
            workingState,
            source,
            pending.event,
            pending.triggerId,
          );
      if (link == null) continue;
      final prepared = definition.prepareLink(workingState, link);
      if (!definition.canActivate(workingState, prepared) ||
          !definition.isTargetLegal(workingState, prepared)) {
        continue;
      }
      final afterCost = definition.payCost(workingState, prepared);
      return afterCost.copyWith(
        chain: ChainState(
          links: [prepared],
          window: ResponseWindowType.effectActivation,
          priorityPlayer: _opponentOf(prepared.activatingPlayer),
        ),
      );
    }
    return workingState;
  }

  ChainLink? _buildAutomaticMythicSummonTriggerLink(
    DuelState state,
    CardInstance source,
    AutomaticEffectTrigger event,
    String linkId,
  ) {
    final effectKey = source.effectKey;
    if (effectKey == null) return null;
    if (event != AutomaticEffectTrigger.specialSummoned) return null;
    final ownField = _fieldFor(state, source.controller);
    final opponentField = _fieldFor(state, _opponentOf(source.controller));
    var payload = <String, Object?>{};
    switch (source.cardCode) {
      case 'BAB-015':
        payload = {
          'trigger': 'on_summon',
          'target_instance_ids': opponentField.actionTrapZones
              .whereType<CardInstance>()
              .where((card) => !card.faceUp)
              .take(2)
              .map((card) => card.instanceId)
              .toList(),
        };
      case 'ROY-015':
        final freeZones =
            ownField.characterZones.where((card) => card == null).length;
        payload = {
          'trigger': 'on_summon',
          'target_instance_ids': ownField.graveyard
              .where(
                (card) =>
                    card.category == CardCategory.character &&
                    card.hasFamily('royaume'),
              )
              .take(freeZones < 2 ? freeZones : 2)
              .map((card) => card.instanceId)
              .toList(),
        };
      case 'ANC-015':
        payload = {
          'trigger': 'on_summon',
          'target_instance_ids': ownField.graveyard
              .take(5)
              .map((card) => card.instanceId)
              .toList(),
        };
      case 'MAS-015':
        payload = {
          'trigger': 'on_summon',
          'target_instance_ids': opponentField.characterZones
              .whereType<CardInstance>()
              .take(2)
              .map((card) => card.instanceId)
              .toList(),
        };
      case 'FOR-015':
        final freeZones =
            ownField.characterZones.where((card) => card == null).length;
        payload = {
          'mode': 'on_summon',
          'token_count': freeZones < 3 ? freeZones : 3,
        };
      case 'LAG-015':
        final candidates = <CardInstance>[
          ...opponentField.characterZones.whereType<CardInstance>(),
          ...opponentField.actionTrapZones.whereType<CardInstance>(),
          if (opponentField.terrainZone != null) opponentField.terrainZone!,
        ].where((card) => card.faceUp).take(2);
        payload = {
          'mode': 'on_summon',
          'target_instance_ids':
              candidates.map((card) => card.instanceId).toList(),
        };
      case 'VIL-015':
        final freeZones =
            ownField.actionTrapZones.where((card) => card == null).length;
        final selectionLimit = freeZones < 2 ? freeZones : 2;
        final selected = <CardInstance>[];
        final selectedCodes = <String>{};
        if (selectionLimit > 0) {
          for (final card in ownField.graveyard) {
            final isEquipment = card.subtype == 'equipment' &&
                (card.category == CardCategory.action ||
                    card.category == CardCategory.relic);
            if (isEquipment && selectedCodes.add(card.cardCode)) {
              selected.add(card);
              if (selected.length == selectionLimit) break;
            }
          }
        }
        payload = {
          'trigger': 'on_summon',
          'equipment_instance_ids':
              selected.map((card) => card.instanceId).toList(),
        };
      case 'MAQ-015':
        CardInstance? action;
        for (final card in ownField.graveyard) {
          if (card.category == CardCategory.action &&
              card.hasFamily('maquis')) {
            action = card;
            break;
          }
        }
        payload = {
          'mode': 'on_summon',
          if (action != null) 'recover_action_instance_id': action.instanceId,
        };
      case 'DOZ-015':
      case 'SAV-015':
        return null;
      default:
        return null;
    }

    return ChainLink(
      linkId: linkId,
      effectKey: effectKey,
      activatingPlayer: source.controller,
      speed: ChainSpeed.speed1,
      sourceCardInstanceId: source.instanceId,
      sourceCardCode: source.cardCode,
      payload: payload,
    );
  }

  bool _isProtectedFaceDownEffectTarget(DuelState state, ChainLink link) {
    final target = _findFieldCatalogCard(state, link.target?.cardInstanceId);
    if (target == null ||
        target.faceUp ||
        target.controller == link.activatingPlayer) {
      return false;
    }
    final field = _fieldFor(state, target.controller);
    return field.characterZones.any(
      (card) =>
          card is CardInstance &&
          card.cardCode == 'MAS-006' &&
          card.controller == target.controller &&
          card.faceUp,
    );
  }

  FieldCardInstance _copyFieldCard(
    FieldCardInstance card, {
    bool? faceUp,
    bool? attackedThisTurn,
  }) {
    if (card is CardInstance) {
      return card.copyWith(
        faceUp: faceUp,
        attackedThisTurn: attackedThisTurn,
      );
    }
    return (card as TokenInstance).copyWith(
      faceUp: faceUp,
      attackedThisTurn: attackedThisTurn,
    );
  }

  DuelState _replaceCharacterAt(
    DuelState state,
    DuelParticipant participant,
    int index,
    FieldCardInstance? card,
  ) {
    final field = _fieldFor(state, participant);
    final zones = List<FieldCardInstance?>.from(field.characterZones)
      ..[index] = card;
    return _replaceField(
      state,
      participant,
      field.copyWith(characterZones: zones),
    );
  }

  DuelState _destroyCharacter(
    DuelState state,
    DuelParticipant fieldOwner,
    String instanceId,
  ) {
    final field = _fieldFor(state, fieldOwner);
    final entry = _findCharacter(field, instanceId);
    if (entry == null) return state;

    var nextState = _replaceCharacterAt(
      state,
      fieldOwner,
      entry.index,
      null,
    );
    final destroyed = entry.card;
    if (destroyed is TokenInstance) {
      return nextState;
    }

    return _sendCatalogCardToOwnerGraveyard(
      nextState,
      destroyed as CardInstance,
    );
  }

  DuelState _sendCatalogCardToOwnerGraveyard(
    DuelState state,
    CardInstance catalogCard,
  ) {
    final graveyardCard = catalogCard.copyWith(
      controller: catalogCard.owner,
      faceUp: true,
      position: null,
      zoneIndex: null,
      counters: const {},
      attachedCardInstanceIds: const [],
      runtimeModifiers: const [],
      runtimeData: const {},
    );
    final ownerField = _fieldFor(state, catalogCard.owner);
    return _replaceField(
      state,
      catalogCard.owner,
      ownerField.copyWith(
        graveyard: [...ownerField.graveyard, graveyardCard],
      ),
    );
  }

  bool _isProtectedByRoyalGuard(
    PlayerFieldState defendingField,
    FieldCardInstance target,
  ) {
    if (target is! CardInstance || !target.hasFamily('royaume')) return false;
    return defendingField.characterZones.any((candidate) {
      return candidate is CardInstance &&
          candidate.instanceId != target.instanceId &&
          candidate.controller == target.controller &&
          candidate.cardCode == 'ROY-003' &&
          candidate.faceUp &&
          candidate.position == BattlePosition.attack;
    });
  }

  bool _mustTargetDozoMythic(
    PlayerFieldState defendingField,
    FieldCardInstance attacker,
    FieldCardInstance selectedTarget,
  ) {
    if ((attacker.counters['proie'] ?? 0) <= 0) return false;
    for (final card
        in defendingField.characterZones.whereType<CardInstance>()) {
      if (card.controller == selectedTarget.controller &&
          card.faceUp &&
          card.cardCode == 'DOZ-015') {
        return selectedTarget.instanceId != card.instanceId;
      }
    }
    return false;
  }

  bool _controlsSylveToken(
    PlayerFieldState field,
    DuelParticipant participant,
  ) {
    return field.characterZones.any(
      (card) =>
          card is TokenInstance &&
          card.controller == participant &&
          card.tokenKey == 'sylve',
    );
  }

  int? _combatAttackValue(
    DuelState state,
    FieldCardInstance combatant,
    FieldCardInstance? opponent,
  ) {
    final base = combatant.effectiveAtk;
    if (base == null) return null;
    if (combatant is! CardInstance) return base;
    var bonus = 0;
    if (combatant.cardCode == 'SAV-002' && opponent == null) {
      bonus += 300;
    }
    if (combatant.cardCode == 'DOZ-002' &&
        opponent?.position == BattlePosition.defense) {
      bonus += 300;
    }
    if (combatant.cardCode == 'DOZ-005' &&
        (opponent?.counters['proie'] ?? 0) > 0) {
      bonus += 300;
    }
    if (combatant.hasFamily('savane') &&
        state.currentPhase == DuelPhase.battle &&
        state.activePlayer == combatant.controller) {
      final ownField = _fieldFor(state, combatant.controller);
      if (ownField.characterZones.any(
        (card) =>
            card is CardInstance &&
            card.instanceId != combatant.instanceId &&
            card.faceUp &&
            card.cardCode == 'SAV-007',
      )) {
        bonus += 300;
      }
      if (DuelParticipant.values.any(
        (owner) =>
            _fieldFor(state, owner).terrainZone?.cardCode == 'SAV-013' &&
            _fieldFor(state, owner).terrainZone?.faceUp == true,
      )) {
        bonus += 300;
      }
    }
    if (opponent is CardInstance &&
        combatant.runtimeData[CardRuntimeKeys.savaneSpearEquipped] == true &&
        (opponent.rank ?? 0) > (combatant.rank ?? 0)) {
      bonus += 500;
    }
    bonus +=
        combatant.runtimeData[CardRuntimeKeys.combatOnlyAtkDelta] as int? ?? 0;
    return base + bonus;
  }

  Object? _runtimeValue(FieldCardInstance card, String key) {
    return card is CardInstance
        ? card.runtimeData[key]
        : (card as TokenInstance).runtimeData[key];
  }

  bool _isBattleDestructionPrevented(
    FieldCardInstance card,
    int turnNumber,
  ) {
    return _runtimeValue(
          card,
          CardRuntimeKeys.cannotBeDestroyedInBattleTurn,
        ) ==
        turnNumber;
  }

  int? _combatDefenseValue(FieldCardInstance combatant) {
    final base = combatant.effectiveDef;
    if (base == null) return null;
    final delta =
        _runtimeValue(combatant, CardRuntimeKeys.combatOnlyDefDelta) as int? ??
            0;
    return base + delta;
  }

  int _damageDealtByAttacker(
    FieldCardInstance attacker,
    int rawDamage,
    int turnNumber,
  ) {
    if (rawDamage <= 0 ||
        _runtimeValue(attacker, CardRuntimeKeys.combatDamageDivisorTurn) !=
            turnNumber) {
      return rawDamage;
    }
    final divisor =
        _runtimeValue(attacker, CardRuntimeKeys.combatDamageDivisor) as int?;
    if (divisor == null || divisor <= 1) return rawDamage;
    return (rawDamage + divisor - 1) ~/ divisor;
  }

  DuelState _clearCombatOnlyModifiers(
    DuelState state,
    String instanceId,
  ) {
    for (final participant in DuelParticipant.values) {
      final field = _fieldFor(state, participant);
      final entry = _findCharacter(field, instanceId);
      if (entry == null || entry.card is! CardInstance) continue;
      final card = entry.card as CardInstance;
      if (!card.runtimeData.containsKey(CardRuntimeKeys.combatOnlyAtkDelta) &&
          !card.runtimeData.containsKey(CardRuntimeKeys.combatOnlyDefDelta) &&
          !card.runtimeData.containsKey(CardRuntimeKeys.combatDamageDivisor) &&
          !card.runtimeData.containsKey(
            CardRuntimeKeys.combatDamageDivisorTurn,
          )) {
        return state;
      }
      final runtimeData = Map<String, Object?>.from(card.runtimeData)
        ..remove(CardRuntimeKeys.combatOnlyAtkDelta)
        ..remove(CardRuntimeKeys.combatOnlyDefDelta)
        ..remove(CardRuntimeKeys.combatDamageDivisor)
        ..remove(CardRuntimeKeys.combatDamageDivisorTurn);
      return _replaceCharacterAt(
        state,
        participant,
        entry.index,
        card.copyWith(runtimeData: runtimeData),
      );
    }
    return state;
  }

  DuelState _applyCombatDamage(
    DuelState state,
    DuelParticipant damagedPlayer,
    int amount,
  ) {
    if (amount <= 0) return state;
    final remainingLifePoints = damagedPlayer == DuelParticipant.player
        ? state.playerLifePoints - amount
        : state.aiLifePoints - amount;
    var nextState = damagedPlayer == DuelParticipant.player
        ? state.copyWith(playerLifePoints: remainingLifePoints)
        : state.copyWith(aiLifePoints: remainingLifePoints);
    if (remainingLifePoints <= 0) {
      nextState = nextState.copyWith(
        winner: _opponentOf(damagedPlayer),
        endReason: DuelEndReason.lifePointsDepleted,
      );
    }
    return nextState;
  }

  DuelState _openResponseWindow(
    DuelState state,
    ResponseWindowType window,
    DuelParticipant firstPriority,
  ) {
    return state.copyWith(
      chain: ChainState(
        window: window,
        priorityPlayer: firstPriority,
      ),
    );
  }

  DuelState _determineWinnerFromLifePoints(DuelState state) {
    if (state.isFinished) return state;
    if (state.playerLifePoints <= 0) {
      return state.copyWith(
        winner: DuelParticipant.ai,
        endReason: DuelEndReason.lifePointsDepleted,
      );
    }
    if (state.aiLifePoints <= 0) {
      return state.copyWith(
        winner: DuelParticipant.player,
        endReason: DuelEndReason.lifePointsDepleted,
      );
    }
    return state;
  }

  DuelState _determinePreparationAlternativeWinner(DuelState state) {
    if (state.isFinished || state.currentPhase != DuelPhase.preparation) {
      return state;
    }
    final field = _fieldFor(state, state.activePlayer);
    final calabashReady = field.actionTrapZones.any(
      (card) =>
          card?.cardCode == 'ANC-014' &&
          card!.faceUp &&
          (card.counters['nom'] ?? 0) >= 8,
    );
    if (!calabashReady) return state;
    return state.copyWith(
      winner: state.activePlayer,
      endReason: DuelEndReason.cardEffect,
    );
  }

  PlayerFieldState _fieldFor(
    DuelState state,
    DuelParticipant participant,
  ) {
    return participant == DuelParticipant.player
        ? state.playerField
        : state.aiField;
  }

  DuelState _replaceField(
    DuelState state,
    DuelParticipant participant,
    PlayerFieldState field,
  ) {
    return participant == DuelParticipant.player
        ? state.copyWith(playerField: field)
        : state.copyWith(aiField: field);
  }

  DuelParticipant _opponentOf(DuelParticipant participant) {
    return participant == DuelParticipant.player
        ? DuelParticipant.ai
        : DuelParticipant.player;
  }
}

/// Point d'entrée pur réutilisable par les définitions d'effets qui doivent
/// détruire une carte pendant la résolution d'une Chaîne.
EffectDestructionResult resolveCardDestructionByEffect({
  required DuelState state,
  required String cardInstanceId,
}) {
  return DuelEngine().destroyCardByEffect(
    state: state,
    cardInstanceId: cardInstanceId,
  );
}
