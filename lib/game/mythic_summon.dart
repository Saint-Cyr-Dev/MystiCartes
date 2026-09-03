import 'battle_state.dart';
import 'card.dart';
import 'duel_types.dart';
import 'player.dart';

enum MythicSummonFailure {
  mythicNotInReserve,
  invalidMythicCard,
  invalidSummonCondition,
  triggerMismatch,
  noFreeCharacterZone,
}

final class MythicSummonResult {
  const MythicSummonResult._({
    required this.state,
    this.summonedCard,
    this.failure,
  });

  factory MythicSummonResult.success(
    DuelState state,
    CardInstance summonedCard,
  ) {
    return MythicSummonResult._(
      state: state,
      summonedCard: summonedCard,
    );
  }

  factory MythicSummonResult.failure(
    DuelState state,
    MythicSummonFailure failure,
  ) {
    return MythicSummonResult._(state: state, failure: failure);
  }

  final DuelState state;
  final CardInstance? summonedCard;
  final MythicSummonFailure? failure;

  bool get succeeded => failure == null;
}

/// Invocation commune aux dix familles. Les coûts restent la responsabilité
/// des effets déclencheurs : ce service ne les rembourse jamais.
final class MythicSummonService {
  const MythicSummonService();

  MythicSummonResult trySummonFromReserve({
    required DuelState state,
    required DuelParticipant participant,
    required String triggerCardCode,
    required String mythicCardCode,
  }) {
    final field = _fieldFor(state, participant);
    final reserveIndex = field.mythicReserve.indexWhere(
      (card) => card.cardCode == mythicCardCode,
    );
    if (reserveIndex < 0) {
      return MythicSummonResult.failure(
        state,
        MythicSummonFailure.mythicNotInReserve,
      );
    }

    final mythic = field.mythicReserve[reserveIndex];
    if (mythic.category != CardCategory.mythic) {
      return MythicSummonResult.failure(
        state,
        MythicSummonFailure.invalidMythicCard,
      );
    }
    final condition = mythic.mythicSummonCondition;
    final method = condition['method'];
    if ((method != 'fusion' && method != 'ancestrale') || condition.isEmpty) {
      return MythicSummonResult.failure(
        state,
        MythicSummonFailure.invalidSummonCondition,
      );
    }
    if (condition['trigger_card_code'] != triggerCardCode) {
      return MythicSummonResult.failure(
        state,
        MythicSummonFailure.triggerMismatch,
      );
    }

    final destinationIndex = field.characterZones.indexWhere(
      (card) => card == null,
    );
    if (destinationIndex < 0) {
      return MythicSummonResult.failure(
        state,
        MythicSummonFailure.noFreeCharacterZone,
      );
    }

    final reserve = List<CardInstance>.from(field.mythicReserve)
      ..removeAt(reserveIndex);
    final summoned = mythic.copyWith(
      controller: participant,
      faceUp: true,
      position: BattlePosition.attack,
      zoneIndex: destinationIndex,
      summonedTurn: state.turnNumber,
      attackedThisTurn: false,
      positionChangedThisTurn: false,
      counters: const {},
      runtimeModifiers: const [],
      runtimeData: const {},
    );
    final zones = List<FieldCardInstance?>.from(field.characterZones)
      ..[destinationIndex] = summoned;
    var nextState = _replaceField(
      state,
      participant,
      field.copyWith(characterZones: zones, mythicReserve: reserve),
    );
    if (summoned.effectKey != null) {
      nextState = nextState.copyWith(
        pendingEffectTriggers: [
          ...nextState.pendingEffectTriggers,
          PendingEffectTrigger(
            triggerId:
                'special-summon:${summoned.instanceId}:${state.turnNumber}',
            sourceCardInstanceId: summoned.instanceId,
            controller: participant,
            event: AutomaticEffectTrigger.specialSummoned,
          ),
        ],
      );
    }
    return MythicSummonResult.success(nextState, summoned);
  }

  DuelState summonFromMythicReserve({
    required DuelState state,
    required DuelParticipant participant,
    required String triggerCardCode,
    required String mythicCardCode,
  }) {
    return trySummonFromReserve(
      state: state,
      participant: participant,
      triggerCardCode: triggerCardCode,
      mythicCardCode: mythicCardCode,
    ).state;
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
}

const defaultMythicSummonService = MythicSummonService();
