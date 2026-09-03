import '../../game/battle_state.dart';
import '../../game/card.dart';
import '../../game/duel_types.dart';
import '../../game/player.dart';

abstract final class DuelStateSnapshotBuilder {
  static const int schemaVersion = 1;
  static const String rulesetVersion = 'v2-gdd-1.1';

  static Map<String, Object?> build(DuelState state) => {
        'schemaVersion': schemaVersion,
        'rulesetVersion': rulesetVersion,
        'winner': state.winner?.name ?? 'draw',
        'turn': {
          'number': state.turnNumber,
          'phase': phaseValue(state.currentPhase),
          'activePlayer': state.activePlayer.name,
          'startingPlayer': state.startingPlayer.name,
          'normalSummonUsed': {
            'player': state.normalSummonUsed[DuelParticipant.player] ?? false,
            'ai': state.normalSummonUsed[DuelParticipant.ai] ?? false,
          },
        },
        'players': {
          'player': _player(
            state.playerField,
            state.playerLifePoints,
          ),
          'ai': _player(state.aiField, state.aiLifePoints),
        },
        'chain': {
          'open': state.chain.isOpen,
          'resolving': state.chain.isResolving,
          'links': state.chain.links.map(_chainLink).toList(growable: false),
        },
      };

  static String phaseValue(DuelPhase phase) => switch (phase) {
        DuelPhase.draw => 'draw',
        DuelPhase.preparation => 'preparation',
        DuelPhase.main1 => 'main_1',
        DuelPhase.battle => 'battle',
        DuelPhase.main2 => 'main_2',
        DuelPhase.end => 'end',
      };

  static Map<String, Object?> _player(PlayerFieldState field, int lifePoints) =>
      {
        'lifePoints': lifePoints < 0 ? 0 : lifePoints,
        'zones': {
          'characters': field.characterZones
              .map((card) => card == null ? null : _fieldCard(card))
              .toList(growable: false),
          'actionsAndTraps': field.actionTrapZones
              .map((card) => card == null ? null : _card(card))
              .toList(growable: false),
          'terrain':
              field.terrainZone == null ? null : _card(field.terrainZone!),
        },
        'deck': field.deck.map(_card).toList(growable: false),
        'hand': field.hand.map(_card).toList(growable: false),
        'graveyard': field.graveyard.map(_card).toList(growable: false),
        'banished': field.banished.map(_card).toList(growable: false),
        'mythicReserve': field.mythicReserve.map(_card).toList(growable: false),
      };

  static Map<String, Object?> _fieldCard(FieldCardInstance card) =>
      switch (card) {
        CardInstance value => _card(value),
        TokenInstance value => {
            'kind': 'token',
            'instanceId': value.instanceId,
            'tokenKey': value.tokenKey,
            'owner': value.owner.name,
            'controller': value.controller.name,
            'faceUp': value.faceUp,
            'position': value.position?.name,
            'zoneIndex': value.zoneIndex,
            'atk': value.atk,
            'def': value.def,
            'counters': value.counters,
            'runtimeModifiers':
                value.runtimeModifiers.map(_modifier).toList(growable: false),
          },
      };

  static Map<String, Object?> _card(CardInstance card) => {
        'kind': 'card',
        'instanceId': card.instanceId,
        'cardId': card.cardId,
        'cardCode': card.cardCode,
        'cardRevision': card.cardRevision,
        'category': card.category.name,
        'owner': card.owner.name,
        'controller': card.controller.name,
        'faceUp': card.faceUp,
        'position': card.position?.name,
        'zoneIndex': card.zoneIndex,
        'summonedTurn': card.summonedTurn,
        'attackedThisTurn': card.attackedThisTurn,
        'positionChangedThisTurn': card.positionChangedThisTurn,
        'counters': card.counters,
        'attachedCardInstanceIds': card.attachedCardInstanceIds,
        'runtimeModifiers':
            card.runtimeModifiers.map(_modifier).toList(growable: false),
        'runtimeData': card.runtimeData,
      };

  static Map<String, Object?> _modifier(RuntimeStatModifier modifier) => {
        'modifierId': modifier.modifierId,
        'atkDelta': modifier.atkDelta,
        'defDelta': modifier.defDelta,
        'sourceCardInstanceId': modifier.sourceCardInstanceId,
        'expiresAtTurn': modifier.expiresAtTurn,
        'expiresAfterPhase': modifier.expiresAfterPhase?.name,
        'metadata': modifier.metadata,
      };

  static Map<String, Object?> _chainLink(ChainLink link) => {
        'linkId': link.linkId,
        'effectKey': link.effectKey,
        'activatingPlayer': link.activatingPlayer.name,
        'speed': link.speed.value,
        'sourceCardInstanceId': link.sourceCardInstanceId,
        'sourceCardCode': link.sourceCardCode,
        'targetCardInstanceId': link.target?.cardInstanceId,
      };
}
