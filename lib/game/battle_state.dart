import 'duel_types.dart';
import 'player.dart';

const Object _notProvided = Object();

enum ChainSpeed {
  speed1(1),
  speed2(2),
  speed3(3);

  const ChainSpeed(this.value);

  final int value;

  bool canRespondTo(ChainSpeed previous) {
    if (this == ChainSpeed.speed1) return false;
    if (previous == ChainSpeed.speed3) return this == ChainSpeed.speed3;
    return true;
  }
}

enum ResponseWindowType {
  summon,
  set,
  effectActivation,
  attackDeclaration,
  combatCalculation,
}

enum AutomaticEffectTrigger { flippedFaceUp, specialSummoned }

/// Conséquence annoncée par un effet avant sa résolution.
///
/// Ces événements sont des données moteur pures. Ils permettent aux joueurs,
/// aux IA et à l'interface d'ouvrir la bonne fenêtre de réponse sans analyser
/// le texte, la clé ou le payload privé d'une carte.
sealed class PendingDuelEvent {
  const PendingDuelEvent({required this.sourceLinkId});

  final String sourceLinkId;
}

final class EffectDestructionPending extends PendingDuelEvent {
  const EffectDestructionPending({
    required super.sourceLinkId,
    required this.cardInstanceId,
  });

  final String cardInstanceId;
}

final class BanishmentPending extends PendingDuelEvent {
  const BanishmentPending({
    required super.sourceLinkId,
    required this.cardInstanceId,
    required this.fromGraveyard,
  });

  final String cardInstanceId;
  final bool fromGraveyard;
}

final class LifePointLossPending extends PendingDuelEvent {
  const LifePointLossPending({
    required super.sourceLinkId,
    required this.participant,
    this.amount,
  });

  final DuelParticipant participant;
  final int? amount;
}

final class FaceDownRevealPending extends PendingDuelEvent {
  FaceDownRevealPending({
    required super.sourceLinkId,
    required Iterable<String> cardInstanceIds,
  }) : cardInstanceIds = Set.unmodifiable(cardInstanceIds);

  final Set<String> cardInstanceIds;
}

/// Événement déclenché pendant la résolution d'une Chaîne. Il sera converti
/// en nouveau maillon seulement après la fermeture de la Chaîne courante.
final class PendingEffectTrigger {
  const PendingEffectTrigger({
    required this.triggerId,
    required this.sourceCardInstanceId,
    required this.controller,
    required this.event,
  });

  final String triggerId;
  final String sourceCardInstanceId;
  final DuelParticipant controller;
  final AutomaticEffectTrigger event;
}

/// Référence générique à une cible. La définition d'effet décide de sa
/// légalité exacte à l'activation puis à la résolution.
final class ChainTarget {
  ChainTarget({
    required this.cardInstanceId,
    Map<String, Object?> metadata = const {},
  }) : metadata = Map.unmodifiable(metadata);

  final String cardInstanceId;
  final Map<String, Object?> metadata;
}

/// Données d'une activation, sans fonction ni dépendance UI sérialisée.
final class ChainLink {
  ChainLink({
    required this.linkId,
    required this.effectKey,
    required this.activatingPlayer,
    required this.speed,
    this.sourceCardInstanceId,
    this.sourceCardCode,
    this.protectedFromSpeed2Negation = false,
    this.target,
    Map<String, Object?> payload = const {},
  }) : payload = Map.unmodifiable(payload);

  final String linkId;
  final String effectKey;
  final DuelParticipant activatingPlayer;
  final ChainSpeed speed;
  final String? sourceCardInstanceId;
  final String? sourceCardCode;
  final bool protectedFromSpeed2Negation;
  final ChainTarget? target;
  final Map<String, Object?> payload;

  ChainLink copyWith({
    bool? protectedFromSpeed2Negation,
    Map<String, Object?>? payload,
  }) {
    return ChainLink(
      linkId: linkId,
      effectKey: effectKey,
      activatingPlayer: activatingPlayer,
      speed: speed,
      sourceCardInstanceId: sourceCardInstanceId,
      sourceCardCode: sourceCardCode,
      protectedFromSpeed2Negation:
          protectedFromSpeed2Negation ?? this.protectedFromSpeed2Negation,
      target: target,
      payload: payload ?? this.payload,
    );
  }
}

final class ChainState {
  ChainState({
    List<ChainLink> links = const [],
    this.window,
    this.priorityPlayer,
    this.consecutivePasses = 0,
    this.isResolving = false,
    this.allowActivationDuringCombatCalculation = false,
    Set<String> negatedLinkIds = const {},
  })  : links = List.unmodifiable(links),
        negatedLinkIds = Set.unmodifiable(negatedLinkIds);

  factory ChainState.closed() => ChainState();

  final List<ChainLink> links;
  final ResponseWindowType? window;
  final DuelParticipant? priorityPlayer;
  final int consecutivePasses;
  final bool isResolving;

  /// Point d'extension réservé à une future carte 4.5. Il reste toujours faux
  /// dans les règles génériques actuelles.
  final bool allowActivationDuringCombatCalculation;
  final Set<String> negatedLinkIds;

  bool get isOpen => window != null;

  ChainState copyWith({
    List<ChainLink>? links,
    Object? window = _notProvided,
    Object? priorityPlayer = _notProvided,
    int? consecutivePasses,
    bool? isResolving,
    bool? allowActivationDuringCombatCalculation,
    Set<String>? negatedLinkIds,
  }) {
    return ChainState(
      links: links ?? this.links,
      window: identical(window, _notProvided)
          ? this.window
          : window as ResponseWindowType?,
      priorityPlayer: identical(priorityPlayer, _notProvided)
          ? this.priorityPlayer
          : priorityPlayer as DuelParticipant?,
      consecutivePasses: consecutivePasses ?? this.consecutivePasses,
      isResolving: isResolving ?? this.isResolving,
      allowActivationDuringCombatCalculation:
          allowActivationDuringCombatCalculation ??
              this.allowActivationDuringCombatCalculation,
      negatedLinkIds: negatedLinkIds ?? this.negatedLinkIds,
    );
  }
}

/// Instantané complet des données globales d'un duel V2.
///
/// Cette classe ne fait avancer ni les phases ni les tours et n'applique
/// aucune règle. Elle ne fait que transporter un état copiable.
final class DuelState {
  DuelState({
    required this.playerField,
    required this.aiField,
    this.playerLifePoints = initialLifePoints,
    this.aiLifePoints = initialLifePoints,
    this.turnNumber = 1,
    this.startingPlayer = DuelParticipant.player,
    this.activePlayer = DuelParticipant.player,
    this.currentPhase = DuelPhase.draw,
    this.drawPhaseResolved = false,
    Map<DuelParticipant, bool>? normalSummonUsed,
    ChainState? chain,
    this.winner,
    this.endReason,
    Set<String> cancelledAttackDeclarationIds = const {},
    Set<String> preventedEffectDestructionInstanceIds = const {},
    Map<String, String?> attackTargetOverrides = const {},
    List<PendingEffectTrigger> pendingEffectTriggers = const [],
  })  : assert(playerField.participant == DuelParticipant.player),
        assert(aiField.participant == DuelParticipant.ai),
        normalSummonUsed = Map.unmodifiable({
          for (final participant in DuelParticipant.values)
            participant: normalSummonUsed?[participant] ?? false,
        }),
        chain = chain ?? ChainState.closed(),
        cancelledAttackDeclarationIds =
            Set.unmodifiable(cancelledAttackDeclarationIds),
        preventedEffectDestructionInstanceIds =
            Set.unmodifiable(preventedEffectDestructionInstanceIds),
        attackTargetOverrides = Map.unmodifiable(attackTargetOverrides),
        pendingEffectTriggers = List.unmodifiable(pendingEffectTriggers);

  static const int initialLifePoints = 8000;

  final PlayerFieldState playerField;
  final PlayerFieldState aiField;
  final int playerLifePoints;
  final int aiLifePoints;
  final int turnNumber;
  final DuelParticipant startingPlayer;
  final DuelParticipant activePlayer;
  final DuelPhase currentPhase;
  final bool drawPhaseResolved;

  /// Indique séparément, pour chaque participant, si son invocation normale a
  /// déjà été utilisée pendant le tour courant.
  final Map<DuelParticipant, bool> normalSummonUsed;

  final ChainState chain;
  final DuelParticipant? winner;
  final DuelEndReason? endReason;
  final Set<String> cancelledAttackDeclarationIds;

  /// Protections ponctuelles créées en réponse à une destruction par effet.
  /// L'identifiant est consommé par la prochaine tentative de destruction de
  /// cette instance et n'affecte jamais une destruction au combat.
  final Set<String> preventedEffectDestructionInstanceIds;

  /// Nouvelle cible choisie par un effet entre la déclaration et le calcul.
  /// La présence de la clé distingue une redirection vers une attaque directe
  /// d'une déclaration qui n'a jamais été modifiée.
  final Map<String, String?> attackTargetOverrides;
  final List<PendingEffectTrigger> pendingEffectTriggers;

  bool get isFinished => winner != null;

  DuelState copyWith({
    PlayerFieldState? playerField,
    PlayerFieldState? aiField,
    int? playerLifePoints,
    int? aiLifePoints,
    int? turnNumber,
    DuelParticipant? startingPlayer,
    DuelParticipant? activePlayer,
    DuelPhase? currentPhase,
    bool? drawPhaseResolved,
    Map<DuelParticipant, bool>? normalSummonUsed,
    ChainState? chain,
    Object? winner = _notProvided,
    Object? endReason = _notProvided,
    Set<String>? cancelledAttackDeclarationIds,
    Set<String>? preventedEffectDestructionInstanceIds,
    Map<String, String?>? attackTargetOverrides,
    List<PendingEffectTrigger>? pendingEffectTriggers,
  }) {
    return DuelState(
      playerField: playerField ?? this.playerField,
      aiField: aiField ?? this.aiField,
      playerLifePoints: playerLifePoints ?? this.playerLifePoints,
      aiLifePoints: aiLifePoints ?? this.aiLifePoints,
      turnNumber: turnNumber ?? this.turnNumber,
      startingPlayer: startingPlayer ?? this.startingPlayer,
      activePlayer: activePlayer ?? this.activePlayer,
      currentPhase: currentPhase ?? this.currentPhase,
      drawPhaseResolved: drawPhaseResolved ?? this.drawPhaseResolved,
      normalSummonUsed: normalSummonUsed ?? this.normalSummonUsed,
      chain: chain ?? this.chain,
      winner: identical(winner, _notProvided)
          ? this.winner
          : winner as DuelParticipant?,
      endReason: identical(endReason, _notProvided)
          ? this.endReason
          : endReason as DuelEndReason?,
      cancelledAttackDeclarationIds:
          cancelledAttackDeclarationIds ?? this.cancelledAttackDeclarationIds,
      preventedEffectDestructionInstanceIds:
          preventedEffectDestructionInstanceIds ??
              this.preventedEffectDestructionInstanceIds,
      attackTargetOverrides:
          attackTargetOverrides ?? this.attackTargetOverrides,
      pendingEffectTriggers:
          pendingEffectTriggers ?? this.pendingEffectTriggers,
    );
  }
}
