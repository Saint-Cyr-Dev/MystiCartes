import '../battle_state.dart';
import '../card.dart';
import '../duel_engine.dart';
import '../duel_types.dart';
import '../mythic_summon.dart';
import '../player.dart';

abstract final class LaguneEffectKeys {
  static const lag001 = 'lag_001_petit_piroguier_des_brumes';
  static const lag002 = 'lag_002_crabe_gardien_des_berges';
  static const lag004 = 'lag_004_plongeuse_aux_perles_bleues';
  static const lag005 = 'lag_005_gardienne_des_paletuviers';
  static const lag006 = 'lag_006_prince_des_courants_croises';
  static const lag007 = 'lag_007_hippopotame_des_eaux_profondes';
  static const lag008 = 'lag_008_courant_inverse';
  static const lag009 = 'lag_009_maree_des_paletuviers';
  static const lag010 = 'lag_010_chant_de_la_lagune_sans_fond';
  static const lag011 = 'lag_011_filet_des_piroguiers';
  static const lag012 = 'lag_012_reflux_absolu';
  static const lag013 = 'lag_013_lagune_aux_reflets_d_argent';
  static const lag014 = 'lag_014_pagaie_des_deux_rives';
  static const lag015 = 'lag_015_reine_des_eaux_d_ebene';
}

abstract interface class LaguneAncestralSummonExtension {
  DuelState summonFromMythicReserve({
    required DuelState state,
    required DuelParticipant participant,
    required String triggerCardCode,
    required String mythicCardCode,
  });
}

final class DefaultLaguneAncestralSummonExtension
    implements LaguneAncestralSummonExtension {
  const DefaultLaguneAncestralSummonExtension();

  @override
  DuelState summonFromMythicReserve({
    required DuelState state,
    required DuelParticipant participant,
    required String triggerCardCode,
    required String mythicCardCode,
  }) =>
      defaultMythicSummonService.summonFromMythicReserve(
        state: state,
        participant: participant,
        triggerCardCode: triggerCardCode,
        mythicCardCode: mythicCardCode,
      );
}

typedef _Predicate = bool Function(DuelState state, ChainLink link);
typedef _Reducer = DuelState Function(DuelState state, ChainLink link);

final class _FunctionalLaguneEffect extends ChainEffectDefinition {
  const _FunctionalLaguneEffect({
    this.onCanActivate,
    this.onPayCost,
    this.onTargetLegal,
    required this.onResolve,
  });

  final _Predicate? onCanActivate;
  final _Reducer? onPayCost;
  final _Predicate? onTargetLegal;
  final _Reducer onResolve;

  @override
  bool canActivate(DuelState state, ChainLink link) =>
      onCanActivate?.call(state, link) ?? true;

  @override
  DuelState payCost(DuelState state, ChainLink link) =>
      onPayCost?.call(state, link) ?? state;

  @override
  bool isTargetLegal(DuelState state, ChainLink link) =>
      onTargetLegal?.call(state, link) ?? link.target == null;

  @override
  DuelState resolve(DuelState state, ChainLink link) => onResolve(state, link);
}

final class LaguneEffectRegistry {
  const LaguneEffectRegistry._();

  static Map<String, ChainEffectDefinition> create({
    LaguneAncestralSummonExtension ancestralSummonExtension =
        const DefaultLaguneAncestralSummonExtension(),
  }) {
    return {
      LaguneEffectKeys.lag001: _lag001(),
      LaguneEffectKeys.lag002: _lag002(),
      LaguneEffectKeys.lag004: _lag004(),
      LaguneEffectKeys.lag005: _lag005(),
      LaguneEffectKeys.lag006: _lag006(),
      LaguneEffectKeys.lag007: _lag007(),
      LaguneEffectKeys.lag008: _lag008(),
      LaguneEffectKeys.lag009: _lag009(),
      LaguneEffectKeys.lag010: _lag010(ancestralSummonExtension),
      LaguneEffectKeys.lag011: _lag011(),
      LaguneEffectKeys.lag012: _lag012(),
      LaguneEffectKeys.lag013: _lag013(),
      LaguneEffectKeys.lag014: _lag014(),
      LaguneEffectKeys.lag015: _lag015(),
    };
  }

  static ChainEffectDefinition _lag001() {
    return _FunctionalLaguneEffect(
      onCanActivate: (state, link) =>
          _sourceHasCode(state, link, 'LAG-001') &&
          link.payload['trigger'] == 'returned_to_own_hand_by_effect' &&
          _canDrawThenDiscard(state, link.activatingPlayer, link),
      onResolve: (state, link) =>
          _drawThenDiscard(state, link.activatingPlayer, link),
    );
  }

  static ChainEffectDefinition _lag002() {
    const usageKey = '${LaguneEffectKeys.lag002}:entered_defense';
    return _FunctionalLaguneEffect(
      onCanActivate: (state, link) {
        final source = _sourceCard(state, link);
        return source?.cardCode == 'LAG-002' &&
            link.payload['trigger'] == 'entered_defense' &&
            source!.position == BattlePosition.defense &&
            !_usedThisTurn(source, usageKey, state.turnNumber);
      },
      onPayCost: (state, link) => _updateFieldCard(
        state,
        link.sourceCardInstanceId!,
        (card) => _markUsed(card, usageKey, state.turnNumber),
      ),
      onResolve: (state, link) => _addModifier(
        state,
        link.sourceCardInstanceId!,
        RuntimeStatModifier(
          modifierId: '${LaguneEffectKeys.lag002}:${link.linkId}',
          defDelta: 300,
          sourceCardInstanceId: link.sourceCardInstanceId,
          expiresAtTurn: state.turnNumber,
        ),
      ),
    );
  }

  static ChainEffectDefinition _lag004() {
    return _FunctionalLaguneEffect(
      onCanActivate: (state, link) =>
          _sourceHasCode(state, link, 'LAG-004') &&
          link.payload['trigger'] == 'on_summon',
      onTargetLegal: (state, link) {
        final card = _graveyardCard(
          state,
          link.activatingPlayer,
          link.target?.cardInstanceId,
        );
        return card != null && card.hasFamily('lagune');
      },
      onResolve: (state, link) {
        var next = _moveGraveyardCardUnderDeck(
          state,
          link.activatingPlayer,
          link.target!.cardInstanceId,
        );
        return _gainLife(next, link.activatingPlayer, 300);
      },
    );
  }

  static ChainEffectDefinition _lag005() {
    const usageKey = '${LaguneEffectKeys.lag005}:return_and_defend';
    return _FunctionalLaguneEffect(
      onCanActivate: (state, link) {
        final source = _sourceCard(state, link);
        final returned = _findFieldCard(
          state,
          link.payload['return_instance_id'] as String?,
        );
        return source?.cardCode == 'LAG-005' &&
            !_usedThisTurn(source!, usageKey, state.turnNumber) &&
            returned != null &&
            returned.card.instanceId != source.instanceId &&
            returned.card.controller == link.activatingPlayer &&
            returned.card.hasFamily('lagune');
      },
      onTargetLegal: (state, link) =>
          _isVisibleOpponentCharacter(state, link, link.target?.cardInstanceId),
      onPayCost: (state, link) {
        var next = _returnFieldCardToOwnerHand(
          state,
          link.payload['return_instance_id']! as String,
          link.activatingPlayer,
        );
        return _updateFieldCard(
          next,
          link.sourceCardInstanceId!,
          (card) => _markUsed(card, usageKey, state.turnNumber),
        );
      },
      onResolve: (state, link) => _updateFieldCard(
        state,
        link.target!.cardInstanceId,
        (card) => card.copyWith(
          position: BattlePosition.defense,
          positionChangedThisTurn: true,
        ),
      ),
    );
  }

  static ChainEffectDefinition _lag006() {
    const turnKey = 'lag_006_return_trigger_turn';
    const countKey = 'lag_006_return_trigger_count';
    return _FunctionalLaguneEffect(
      onCanActivate: (state, link) {
        final source = _sourceCard(state, link);
        if (source?.cardCode != 'LAG-006' ||
            link.payload['trigger'] != 'card_returned_to_hand') {
          return false;
        }
        final sameTurn = source!.runtimeData[turnKey] == state.turnNumber;
        final count = sameTurn ? source.runtimeData[countKey] as int? ?? 0 : 0;
        return count < 2;
      },
      onPayCost: (state, link) => _updateFieldCard(
        state,
        link.sourceCardInstanceId!,
        (card) {
          final sameTurn = card.runtimeData[turnKey] == state.turnNumber;
          final count = sameTurn ? card.runtimeData[countKey] as int? ?? 0 : 0;
          return card.copyWith(runtimeData: {
            ...card.runtimeData,
            turnKey: state.turnNumber,
            countKey: count + 1,
          });
        },
      ),
      onResolve: (state, link) => _addModifier(
        state,
        link.sourceCardInstanceId!,
        RuntimeStatModifier(
          modifierId: '${LaguneEffectKeys.lag006}:${link.linkId}',
          atkDelta: 300,
          sourceCardInstanceId: link.sourceCardInstanceId,
          expiresAtTurn: state.turnNumber,
        ),
      ),
    );
  }

  static ChainEffectDefinition _lag007() {
    const usageKey = '${LaguneEffectKeys.lag007}:return_destroy';
    return _FunctionalLaguneEffect(
      onCanActivate: (state, link) {
        final source = _sourceCard(state, link);
        final returned = _findFieldCard(
          state,
          link.payload['return_instance_id'] as String?,
        );
        return source?.cardCode == 'LAG-007' &&
            !_usedThisTurn(source!, usageKey, state.turnNumber) &&
            returned != null &&
            returned.card.instanceId != source.instanceId &&
            returned.card.controller == link.activatingPlayer;
      },
      onTargetLegal: (state, link) {
        final target = _findFieldCard(state, link.target?.cardInstanceId);
        return target != null &&
            target.kind == _ZoneKind.actionTrap &&
            target.card.controller != link.activatingPlayer &&
            target.card.faceUp;
      },
      onPayCost: (state, link) {
        var next = _returnFieldCardToOwnerHand(
          state,
          link.payload['return_instance_id']! as String,
          link.activatingPlayer,
        );
        return _updateFieldCard(
          next,
          link.sourceCardInstanceId!,
          (card) => _markUsed(card, usageKey, state.turnNumber),
        );
      },
      onResolve: (state, link) => resolveCardDestructionByEffect(
        state: state,
        cardInstanceId: link.target!.cardInstanceId,
      ).state,
    );
  }

  static ChainEffectDefinition _lag008() {
    return _FunctionalLaguneEffect(
      onCanActivate: (state, link) => _sourceHasCode(state, link, 'LAG-008'),
      onTargetLegal: (state, link) {
        final own = _findFieldCard(state, link.target?.cardInstanceId);
        final enemy = _findFieldCard(
          state,
          link.payload['opponent_instance_id'] as String?,
        );
        return own != null &&
            own.kind == _ZoneKind.character &&
            own.card.controller == link.activatingPlayer &&
            own.card.hasFamily('lagune') &&
            enemy != null &&
            enemy.kind == _ZoneKind.character &&
            enemy.card.controller != link.activatingPlayer &&
            (enemy.card.rank ?? 99) <= (own.card.rank ?? -1) &&
            _canBeReturnedBy(state, enemy, link.activatingPlayer);
      },
      onResolve: (state, link) {
        var next = _returnFieldCardToOwnerHand(
          state,
          link.target!.cardInstanceId,
          link.activatingPlayer,
        );
        return _returnFieldCardToOwnerHand(
          next,
          link.payload['opponent_instance_id']! as String,
          link.activatingPlayer,
        );
      },
    );
  }

  static ChainEffectDefinition _lag009() {
    const usageKey = '${LaguneEffectKeys.lag009}:lagoon_returned';
    return _FunctionalLaguneEffect(
      onCanActivate: (state, link) {
        final source = _sourceCard(state, link);
        return source?.cardCode == 'LAG-009' &&
            link.payload['trigger'] == 'own_lagoon_returned_to_hand' &&
            !_usedThisTurn(source!, usageKey, state.turnNumber);
      },
      onTargetLegal: (state, link) =>
          link.target == null ||
          _findFieldCard(state, link.target?.cardInstanceId)?.kind ==
              _ZoneKind.character,
      onPayCost: (state, link) => _updateFieldCard(
        state,
        link.sourceCardInstanceId!,
        (card) => _markUsed(card, usageKey, state.turnNumber),
      ),
      onResolve: (state, link) {
        var next = _gainLife(state, link.activatingPlayer, 400);
        final targetId = link.target?.cardInstanceId;
        if (targetId == null) return next;
        return _updateFieldCard(next, targetId, (card) {
          final position = card.position == BattlePosition.attack
              ? BattlePosition.defense
              : BattlePosition.attack;
          return card.copyWith(
            position: position,
            positionChangedThisTurn: true,
          );
        });
      },
    );
  }

  static ChainEffectDefinition _lag010(
    LaguneAncestralSummonExtension extension,
  ) {
    return _FunctionalLaguneEffect(
      onCanActivate: _validAncestralCost,
      onPayCost: (state, link) {
        var next = state;
        for (final id in _payloadIds(link, 'sacrifice_instance_ids')) {
          next = _sendCharacterToGraveyard(next, id);
        }
        return _returnFieldCardToOwnerHand(
          next,
          link.payload['return_instance_id']! as String,
          link.activatingPlayer,
        );
      },
      onResolve: (state, link) => extension.summonFromMythicReserve(
        state: state,
        participant: link.activatingPlayer,
        triggerCardCode: 'LAG-010',
        mythicCardCode: 'LAG-015',
      ),
    );
  }

  static ChainEffectDefinition _lag011() {
    return _FunctionalLaguneEffect(
      onCanActivate: (state, link) =>
          _sourceHasCode(state, link, 'LAG-011') &&
          link.payload['trigger'] == 'opponent_character_summoned',
      onTargetLegal: (state, link) {
        final target = _findFieldCard(state, link.target?.cardInstanceId);
        return target != null &&
            target.kind == _ZoneKind.character &&
            target.card.controller != link.activatingPlayer &&
            (target.card.rank ?? 99) <= 5;
      },
      onResolve: (state, link) => _updateFieldCard(
        state,
        link.target!.cardInstanceId,
        (card) => card.copyWith(
          position: BattlePosition.defense,
          positionChangedThisTurn: true,
          runtimeData: {
            ...card.runtimeData,
            CardRuntimeKeys.effectsNegatedUntilTurn: state.turnNumber,
          },
        ),
      ),
    );
  }

  static ChainEffectDefinition _lag012() {
    return _FunctionalLaguneEffect(
      onCanActivate: (state, link) {
        if (!_sourceHasCode(state, link, 'LAG-012')) return false;
        final protected = _findFieldCard(state, link.target?.cardInstanceId);
        final targeted = _targetedChainLink(state, link);
        return protected != null &&
            protected.card.controller == link.activatingPlayer &&
            protected.card.hasFamily('lagune') &&
            targeted != null &&
            targeted.activatingPlayer != link.activatingPlayer &&
            targeted.target?.cardInstanceId == protected.card.instanceId &&
            _canBeReturnedBy(state, protected, link.activatingPlayer);
      },
      onTargetLegal: (state, link) =>
          _findFieldCard(state, link.target?.cardInstanceId) != null &&
          _targetedChainLink(state, link) != null,
      onResolve: (state, link) {
        final targeted = _targetedChainLink(state, link)!;
        var next = _returnFieldCardToOwnerHand(
          state,
          link.target!.cardInstanceId,
          link.activatingPlayer,
        );
        return next.copyWith(
          chain: next.chain.copyWith(
            negatedLinkIds: {...next.chain.negatedLinkIds, targeted.linkId},
          ),
        );
      },
    );
  }

  static ChainEffectDefinition _lag013() {
    const usageKey = '${LaguneEffectKeys.lag013}:first_return';
    return _FunctionalLaguneEffect(
      onCanActivate: (state, link) {
        final source = _sourceCard(state, link);
        if (source?.cardCode != 'LAG-013') return false;
        if (link.payload['mode'] == 'continuous_refresh') return true;
        final owner = _participantFromPayload(link.payload['returned_owner']);
        return link.payload['mode'] == 'card_returned_to_hand' &&
            owner != null &&
            !_usedThisTurn(source!, usageKey, state.turnNumber) &&
            _canDrawThenDiscard(state, owner, link);
      },
      onPayCost: (state, link) {
        if (link.payload['mode'] == 'continuous_refresh') return state;
        return _updateFieldCard(
          state,
          link.sourceCardInstanceId!,
          (card) => _markUsed(card, usageKey, state.turnNumber),
        );
      },
      onResolve: (state, link) {
        var next = _refreshLagoonAura(state, link.sourceCardInstanceId!);
        if (link.payload['mode'] == 'continuous_refresh') return next;
        return _drawThenDiscard(
          next,
          _participantFromPayload(link.payload['returned_owner'])!,
          link,
        );
      },
    );
  }

  static ChainEffectDefinition _lag014() {
    const usageKey = '${LaguneEffectKeys.lag014}:return_protect';
    return _FunctionalLaguneEffect(
      onCanActivate: (state, link) {
        final source = _sourceCard(state, link);
        if (source?.cardCode != 'LAG-014') return false;
        if (link.payload['mode'] == 'equip') return true;
        final equippedId = source!
            .runtimeData[CardRuntimeKeys.equippedToInstanceId] as String?;
        return link.payload['mode'] == 'return_and_protect' &&
            !_usedThisTurn(source, usageKey, state.turnNumber) &&
            _findFieldCard(state, equippedId) != null;
      },
      onTargetLegal: (state, link) {
        if (link.payload['mode'] != 'equip') return link.target == null;
        final target = _findFieldCard(state, link.target?.cardInstanceId);
        return target != null &&
            target.kind == _ZoneKind.character &&
            target.card.controller == link.activatingPlayer &&
            target.card.hasFamily('lagune');
      },
      onPayCost: (state, link) {
        if (link.payload['mode'] == 'equip') return state;
        return _updateFieldCard(
          state,
          link.sourceCardInstanceId!,
          (card) => _markUsed(card, usageKey, state.turnNumber),
        );
      },
      onResolve: (state, link) {
        if (link.payload['mode'] == 'equip') {
          return _equipPaddle(state, link);
        }
        final source = _sourceCard(state, link)!;
        final equippedId =
            source.runtimeData[CardRuntimeKeys.equippedToInstanceId]! as String;
        var next = _updateFieldCard(state, equippedId, (card) {
          return card.copyWith(
            attachedCardInstanceIds: card.attachedCardInstanceIds
                .where((id) => id != source.instanceId)
                .toList(),
            runtimeModifiers: card.runtimeModifiers
                .where((modifier) =>
                    modifier.sourceCardInstanceId != source.instanceId)
                .toList(),
            runtimeData: {
              ...card.runtimeData,
              CardRuntimeKeys.cannotBeDestroyedInBattleTurn: state.turnNumber,
            },
          );
        });
        return _returnFieldCardToOwnerHand(
          next,
          source.instanceId,
          link.activatingPlayer,
        );
      },
    );
  }

  static ChainEffectDefinition _lag015() {
    const usageKey = '${LaguneEffectKeys.lag015}:lock_return';
    return _FunctionalLaguneEffect(
      onCanActivate: (state, link) {
        final source = _sourceCard(state, link);
        if (source?.cardCode != 'LAG-015') return false;
        if (link.payload['mode'] == 'on_summon') {
          return _payloadIds(link, 'target_instance_ids').length <= 2;
        }
        return link.payload['mode'] == 'card_returned_to_hand' &&
            !_usedThisTurn(source!, usageKey, state.turnNumber);
      },
      onTargetLegal: (state, link) {
        if (link.payload['mode'] == 'on_summon') {
          return _payloadIds(link, 'target_instance_ids').every((id) {
            final target = _findFieldCard(state, id);
            return target != null &&
                target.card.controller != link.activatingPlayer &&
                target.card.faceUp &&
                _canBeReturnedBy(state, target, link.activatingPlayer);
          });
        }
        return _findFieldCard(state, link.target?.cardInstanceId) != null;
      },
      onPayCost: (state, link) {
        if (link.payload['mode'] == 'on_summon') return state;
        return _updateFieldCard(
          state,
          link.sourceCardInstanceId!,
          (card) => _markUsed(card, usageKey, state.turnNumber),
        );
      },
      onResolve: (state, link) {
        if (link.payload['mode'] == 'on_summon') {
          var next = state;
          for (final id in _payloadIds(link, 'target_instance_ids')) {
            next = _returnFieldCardToOwnerHand(
              next,
              id,
              link.activatingPlayer,
            );
          }
          return next;
        }
        return _updateFieldCard(
          state,
          link.target!.cardInstanceId,
          (card) => card.copyWith(runtimeData: {
            ...card.runtimeData,
            CardRuntimeKeys.cannotAttackTurn: state.turnNumber,
            CardRuntimeKeys.effectsNegatedUntilTurn: state.turnNumber,
          }),
        );
      },
    );
  }
}

enum _ZoneKind { character, actionTrap, terrain }

final class _Location {
  const _Location(this.participant, this.kind, this.index, this.card);

  final DuelParticipant participant;
  final _ZoneKind kind;
  final int? index;
  final CardInstance card;
}

PlayerFieldState _fieldFor(DuelState state, DuelParticipant participant) =>
    participant == DuelParticipant.player ? state.playerField : state.aiField;

DuelState _replaceField(
  DuelState state,
  DuelParticipant participant,
  PlayerFieldState field,
) =>
    participant == DuelParticipant.player
        ? state.copyWith(playerField: field)
        : state.copyWith(aiField: field);

_Location? _findFieldCard(DuelState state, String? id) {
  if (id == null) return null;
  for (final participant in DuelParticipant.values) {
    final field = _fieldFor(state, participant);
    for (var index = 0; index < field.characterZones.length; index++) {
      final card = field.characterZones[index];
      if (card is CardInstance && card.instanceId == id) {
        return _Location(participant, _ZoneKind.character, index, card);
      }
    }
    for (var index = 0; index < field.actionTrapZones.length; index++) {
      final card = field.actionTrapZones[index];
      if (card?.instanceId == id) {
        return _Location(participant, _ZoneKind.actionTrap, index, card!);
      }
    }
    if (field.terrainZone?.instanceId == id) {
      return _Location(
        participant,
        _ZoneKind.terrain,
        null,
        field.terrainZone!,
      );
    }
  }
  return null;
}

CardInstance? _sourceCard(DuelState state, ChainLink link) =>
    _findFieldCard(state, link.sourceCardInstanceId)?.card;

bool _sourceHasCode(DuelState state, ChainLink link, String code) {
  if (link.sourceCardCode == code ||
      _sourceCard(state, link)?.cardCode == code) {
    return true;
  }
  final field = _fieldFor(state, link.activatingPlayer);
  return [...field.hand, ...field.graveyard].any(
    (card) =>
        card.instanceId == link.sourceCardInstanceId && card.cardCode == code,
  );
}

DuelState _updateFieldCard(
  DuelState state,
  String id,
  CardInstance Function(CardInstance card) update,
) {
  final location = _findFieldCard(state, id);
  if (location == null) return state;
  final field = _fieldFor(state, location.participant);
  switch (location.kind) {
    case _ZoneKind.character:
      final zones = List<FieldCardInstance?>.from(field.characterZones)
        ..[location.index!] = update(location.card);
      return _replaceField(
        state,
        location.participant,
        field.copyWith(characterZones: zones),
      );
    case _ZoneKind.actionTrap:
      final zones = List<CardInstance?>.from(field.actionTrapZones)
        ..[location.index!] = update(location.card);
      return _replaceField(
        state,
        location.participant,
        field.copyWith(actionTrapZones: zones),
      );
    case _ZoneKind.terrain:
      return _replaceField(
        state,
        location.participant,
        field.copyWith(terrainZone: update(location.card)),
      );
  }
}

bool _usedThisTurn(CardInstance card, String key, int turn) =>
    card.effectUsageTurns[key] == turn;

CardInstance _markUsed(CardInstance card, String key, int turn) =>
    card.copyWith(
      effectUsageTurns: {...card.effectUsageTurns, key: turn},
    );

DuelState _addModifier(
  DuelState state,
  String id,
  RuntimeStatModifier modifier,
) =>
    _updateFieldCard(
      state,
      id,
      (card) => card.copyWith(
        runtimeModifiers: [...card.runtimeModifiers, modifier],
      ),
    );

CardInstance? _graveyardCard(
  DuelState state,
  DuelParticipant participant,
  String? id,
) {
  if (id == null) return null;
  for (final card in _fieldFor(state, participant).graveyard) {
    if (card.instanceId == id) return card;
  }
  return null;
}

bool _isVisibleOpponentCharacter(
  DuelState state,
  ChainLink link,
  String? id,
) {
  final target = _findFieldCard(state, id);
  return target != null &&
      target.kind == _ZoneKind.character &&
      target.card.controller != link.activatingPlayer &&
      target.card.faceUp;
}

bool _canBeReturnedBy(
  DuelState state,
  _Location location,
  DuelParticipant actor,
) {
  return !(location.card.cardCode == 'LAG-007' &&
      location.card.controller != actor);
}

DuelState _returnFieldCardToOwnerHand(
  DuelState state,
  String id,
  DuelParticipant actor,
) {
  final location = _findFieldCard(state, id);
  if (location == null || !_canBeReturnedBy(state, location, actor)) {
    return state;
  }
  final field = _fieldFor(state, location.participant);
  late PlayerFieldState removed;
  switch (location.kind) {
    case _ZoneKind.character:
      final zones = List<FieldCardInstance?>.from(field.characterZones)
        ..[location.index!] = null;
      removed = field.copyWith(characterZones: zones);
    case _ZoneKind.actionTrap:
      final zones = List<CardInstance?>.from(field.actionTrapZones)
        ..[location.index!] = null;
      removed = field.copyWith(actionTrapZones: zones);
    case _ZoneKind.terrain:
      removed = field.copyWith(terrainZone: null);
  }
  var next = _replaceField(state, location.participant, removed);
  final ownerField = _fieldFor(next, location.card.owner);
  return _replaceField(
    next,
    location.card.owner,
    ownerField.copyWith(
      hand: [...ownerField.hand, _asHandCard(location.card)],
    ),
  );
}

DuelState _moveGraveyardCardUnderDeck(
  DuelState state,
  DuelParticipant participant,
  String id,
) {
  final field = _fieldFor(state, participant);
  final index = field.graveyard.indexWhere((card) => card.instanceId == id);
  if (index < 0) return state;
  final graveyard = List<CardInstance>.from(field.graveyard);
  final card = _asDeckCard(graveyard.removeAt(index));
  return _replaceField(
    state,
    participant,
    field.copyWith(graveyard: graveyard, deck: [...field.deck, card]),
  );
}

bool _validAncestralCost(DuelState state, ChainLink link) {
  if (!_sourceHasCode(state, link, 'LAG-010')) return false;
  final ids = _payloadIds(link, 'sacrifice_instance_ids');
  final returned = _findFieldCard(
    state,
    link.payload['return_instance_id'] as String?,
  );
  if (ids.isEmpty ||
      ids.toSet().length != ids.length ||
      returned == null ||
      returned.card.controller != link.activatingPlayer ||
      returned.card.instanceId == link.sourceCardInstanceId ||
      ids.contains(returned.card.instanceId)) {
    return false;
  }
  var ranks = 0;
  for (final id in ids) {
    final card = _findFieldCard(state, id);
    if (card == null ||
        card.kind != _ZoneKind.character ||
        card.card.controller != link.activatingPlayer ||
        card.card.attribute != 'eau' ||
        card.card.rank == null) {
      return false;
    }
    ranks += card.card.rank!;
  }
  return ranks >= 9;
}

DuelState _sendCharacterToGraveyard(DuelState state, String id) {
  final location = _findFieldCard(state, id)!;
  final field = _fieldFor(state, location.participant);
  final zones = List<FieldCardInstance?>.from(field.characterZones)
    ..[location.index!] = null;
  var next = _replaceField(
    state,
    location.participant,
    field.copyWith(characterZones: zones),
  );
  final ownerField = _fieldFor(next, location.card.owner);
  return _replaceField(
    next,
    location.card.owner,
    ownerField.copyWith(
      graveyard: [...ownerField.graveyard, _asGraveyardCard(location.card)],
    ),
  );
}

DuelState _equipPaddle(DuelState state, ChainLink link) {
  final targetId = link.target!.cardInstanceId;
  var next = _updateFieldCard(state, targetId, (card) {
    return card.copyWith(
      attachedCardInstanceIds: [
        ...card.attachedCardInstanceIds,
        link.sourceCardInstanceId!,
      ],
      runtimeModifiers: [
        ...card.runtimeModifiers,
        RuntimeStatModifier(
          modifierId: '${LaguneEffectKeys.lag014}:${link.sourceCardInstanceId}',
          atkDelta: 300,
          defDelta: 300,
          sourceCardInstanceId: link.sourceCardInstanceId,
        ),
      ],
    );
  });
  return _updateFieldCard(
    next,
    link.sourceCardInstanceId!,
    (card) => card.copyWith(
      faceUp: true,
      runtimeData: {
        ...card.runtimeData,
        CardRuntimeKeys.equippedToInstanceId: targetId,
      },
    ),
  );
}

DuelState _refreshLagoonAura(DuelState state, String sourceId) {
  final source = _findFieldCard(state, sourceId);
  if (source == null ||
      source.kind != _ZoneKind.terrain ||
      !source.card.faceUp) {
    return state;
  }
  var next = state;
  for (final participant in DuelParticipant.values) {
    final field = _fieldFor(next, participant);
    for (final card in field.characterZones.whereType<CardInstance>()) {
      final modifiers = card.runtimeModifiers
          .where((modifier) => modifier.sourceCardInstanceId != sourceId)
          .toList();
      if (card.hasFamily('lagune')) {
        modifiers.add(RuntimeStatModifier(
          modifierId: '${LaguneEffectKeys.lag013}:$sourceId',
          defDelta: 200,
          sourceCardInstanceId: sourceId,
        ));
      }
      next = _updateFieldCard(
        next,
        card.instanceId,
        (current) => current.copyWith(runtimeModifiers: modifiers),
      );
    }
  }
  return next;
}

bool _canDrawThenDiscard(
  DuelState state,
  DuelParticipant participant,
  ChainLink link,
) {
  final field = _fieldFor(state, participant);
  final discardId = link.payload['discard_instance_id'] as String?;
  return field.deck.isNotEmpty &&
      discardId != null &&
      (field.hand.any((card) => card.instanceId == discardId) ||
          field.deck.first.instanceId == discardId);
}

DuelState _drawThenDiscard(
  DuelState state,
  DuelParticipant participant,
  ChainLink link,
) {
  final field = _fieldFor(state, participant);
  final deck = List<CardInstance>.from(field.deck);
  final hand = [...field.hand, _asHandCard(deck.removeAt(0))];
  final discardId = link.payload['discard_instance_id']! as String;
  final discardIndex = hand.indexWhere((card) => card.instanceId == discardId);
  final discarded = _asGraveyardCard(hand.removeAt(discardIndex));
  return _replaceField(
    state,
    participant,
    field.copyWith(
      deck: deck,
      hand: hand,
      graveyard: [...field.graveyard, discarded],
    ),
  );
}

DuelState _gainLife(
  DuelState state,
  DuelParticipant participant,
  int amount,
) =>
    participant == DuelParticipant.player
        ? state.copyWith(playerLifePoints: state.playerLifePoints + amount)
        : state.copyWith(aiLifePoints: state.aiLifePoints + amount);

ChainLink? _targetedChainLink(DuelState state, ChainLink link) {
  final id = link.payload['target_link_id'] as String?;
  if (id == null) return null;
  for (final candidate in state.chain.links) {
    if (candidate.linkId == id) return candidate;
  }
  return null;
}

DuelParticipant? _participantFromPayload(Object? value) {
  if (value == 'player') return DuelParticipant.player;
  if (value == 'ai') return DuelParticipant.ai;
  return null;
}

List<String> _payloadIds(ChainLink link, String key) {
  final value = link.payload[key];
  return value is List ? value.whereType<String>().toList() : const [];
}

CardInstance _asDeckCard(CardInstance card) => card.copyWith(
      controller: card.owner,
      faceUp: false,
      position: null,
      zoneIndex: null,
      counters: const {},
      attachedCardInstanceIds: const [],
      runtimeModifiers: const [],
      runtimeData: const {},
    );

CardInstance _asHandCard(CardInstance card) => _asDeckCard(card);

CardInstance _asGraveyardCard(CardInstance card) => card.copyWith(
      controller: card.owner,
      faceUp: true,
      position: null,
      zoneIndex: null,
      counters: const {},
      attachedCardInstanceIds: const [],
      runtimeModifiers: const [],
      runtimeData: const {},
    );
