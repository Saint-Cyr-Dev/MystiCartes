import '../battle_state.dart';
import '../card.dart';
import '../duel_engine.dart';
import '../duel_types.dart';
import '../mythic_summon.dart';
import '../player.dart';

/// Clés stables du seed V2. Elles constituent le lien entre Supabase et le
/// moteur Dart et ne doivent pas être dérivées du nom affiché de la carte.
abstract final class RoyaumeEffectKeys {
  static const roy001 = 'roy_001_page_aux_bracelets_d_or';
  static const roy003 = 'roy_003_garde_du_tambour_royal';
  static const roy004 = 'roy_004_stratege_des_sept_cours';
  static const roy005 = 'roy_005_cavalier_au_manteau_pourpre';
  static const roy006 = 'roy_006_reine_des_remparts_solaires';
  static const roy007 = 'roy_007_roi_au_serment_de_fer';
  static const roy008 = 'roy_008_decret_de_mobilisation';
  static const roy009 = 'roy_009_releve_de_la_garde';
  static const roy010 = 'roy_010_couronnement_des_sept_tambours';
  static const roy011 = 'roy_011_herse_de_lumiere';
  static const roy012 = 'roy_012_sceau_inviolable';
  static const roy013 = 'roy_013_cour_des_mille_etendards';
  static const roy014 = 'roy_014_couronne_du_pacte_ancien';
  static const roy015 = 'roy_015_souverain_des_sept_tambours';
}

/// Point d'extension de la Phase 4.6 pour l'Invocation ancestrale.
///
/// ROY-010 valide et paie déjà intégralement les sacrifices. L'implémentation
/// 4.6 remplacera ce port sans modifier la définition de l'effet.
abstract interface class RoyaumeAncestralSummonExtension {
  DuelState summonFromMythicReserve({
    required DuelState state,
    required DuelParticipant participant,
    required String triggerCardCode,
    required String mythicCardCode,
  });
}

final class DefaultRoyaumeAncestralSummonExtension
    implements RoyaumeAncestralSummonExtension {
  const DefaultRoyaumeAncestralSummonExtension();

  @override
  DuelState summonFromMythicReserve({
    required DuelState state,
    required DuelParticipant participant,
    required String triggerCardCode,
    required String mythicCardCode,
  }) {
    return defaultMythicSummonService.summonFromMythicReserve(
      state: state,
      participant: participant,
      triggerCardCode: triggerCardCode,
      mythicCardCode: mythicCardCode,
    );
  }
}

typedef _StateLinkPredicate = bool Function(DuelState state, ChainLink link);
typedef _StateLinkReducer = DuelState Function(
  DuelState state,
  ChainLink link,
);
typedef _PendingEventsCallback = Iterable<PendingDuelEvent> Function(
  DuelState state,
  ChainLink link,
);

final class _FunctionalRoyaumeEffect extends ChainEffectDefinition {
  const _FunctionalRoyaumeEffect({
    this.onCanActivate,
    this.onPayCost,
    this.onTargetLegal,
    this.onPendingEvents,
    required this.onResolve,
  });

  final _StateLinkPredicate? onCanActivate;
  final _StateLinkReducer? onPayCost;
  final _StateLinkPredicate? onTargetLegal;
  final _PendingEventsCallback? onPendingEvents;
  final _StateLinkReducer onResolve;

  @override
  bool canActivate(DuelState state, ChainLink link) {
    return onCanActivate?.call(state, link) ?? true;
  }

  @override
  DuelState payCost(DuelState state, ChainLink link) {
    return onPayCost?.call(state, link) ?? state;
  }

  @override
  bool isTargetLegal(DuelState state, ChainLink link) {
    return onTargetLegal?.call(state, link) ?? link.target == null;
  }

  @override
  Iterable<PendingDuelEvent> pendingEvents(DuelState state, ChainLink link) =>
      onPendingEvents?.call(state, link) ?? const [];

  @override
  DuelState resolve(DuelState state, ChainLink link) {
    return onResolve(state, link);
  }
}

/// Définitions d'effets de la famille Royaume.
final class RoyaumeEffectRegistry {
  const RoyaumeEffectRegistry._();

  static Map<String, ChainEffectDefinition> create({
    RoyaumeAncestralSummonExtension ancestralSummonExtension =
        const DefaultRoyaumeAncestralSummonExtension(),
  }) {
    return {
      RoyaumeEffectKeys.roy001: _roy001(),
      RoyaumeEffectKeys.roy003: _roy003(),
      RoyaumeEffectKeys.roy004: _roy004(),
      RoyaumeEffectKeys.roy005: _roy005(),
      RoyaumeEffectKeys.roy006: _roy006(),
      RoyaumeEffectKeys.roy007: _roy007(),
      RoyaumeEffectKeys.roy008: _roy008(),
      RoyaumeEffectKeys.roy009: _roy009(),
      RoyaumeEffectKeys.roy010: _roy010(ancestralSummonExtension),
      RoyaumeEffectKeys.roy011: _roy011(),
      RoyaumeEffectKeys.roy012: _roy012(),
      RoyaumeEffectKeys.roy013: _roy013(),
      RoyaumeEffectKeys.roy014: _roy014(),
      RoyaumeEffectKeys.roy015: _roy015(),
    };
  }

  static ChainEffectDefinition _roy001() {
    return _FunctionalRoyaumeEffect(
      onCanActivate: (state, link) =>
          _sourceHasCode(state, link, 'ROY-001') &&
          link.payload['trigger'] == 'sacrificed_for_kingdom_summon',
      onResolve: (state, link) => _drawOne(state, link.activatingPlayer),
    );
  }

  static ChainEffectDefinition _roy003() {
    // La restriction de ciblage est consultée directement par declareAttack.
    // Cette définition conserve l'ancrage effect_key pour les rafraîchissements
    // ou événements futurs sans créer une activation artificielle.
    return _FunctionalRoyaumeEffect(
      onCanActivate: (state, link) =>
          _sourceHasCode(state, link, 'ROY-003') &&
          link.payload['trigger'] == 'continuous_refresh',
      onResolve: (state, link) => state,
    );
  }

  static ChainEffectDefinition _roy004() {
    return _FunctionalRoyaumeEffect(
      onCanActivate: (state, link) =>
          _sourceHasCode(state, link, 'ROY-004') &&
          link.payload['trigger'] == 'on_summon',
      onTargetLegal: _roy004SelectionIsLegal,
      onResolve: (state, link) {
        final participant = link.activatingPlayer;
        final field = _fieldFor(state, participant);
        final topCards = field.deck.take(3).toList();
        final selectedId = link.payload['selected_instance_id'] as String?;
        final orderedIds = _payloadIds(link, 'remaining_order_instance_ids');
        final byId = {for (final card in topCards) card.instanceId: card};
        final selected = selectedId == null ? null : byId[selectedId];
        final remaining = [for (final id in orderedIds) byId[id]!];
        final restOfDeck = field.deck.skip(topCards.length).toList();
        return _replaceField(
          state,
          participant,
          field.copyWith(
            deck: [...restOfDeck, ...remaining],
            hand: selected == null
                ? field.hand
                : [
                    ...field.hand,
                    selected.copyWith(
                      controller: participant,
                      faceUp: false,
                      position: null,
                      zoneIndex: null,
                    ),
                  ],
          ),
        );
      },
    );
  }

  static ChainEffectDefinition _roy005() {
    return _FunctionalRoyaumeEffect(
      onCanActivate: (state, link) =>
          _sourceHasCode(state, link, 'ROY-005') &&
          link.payload['trigger'] == 'on_summon' &&
          link.payload['sacrificed_for_summon'] == true,
      onResolve: (state, link) {
        return _updateFieldCard(
          state,
          link.sourceCardInstanceId!,
          (card) => card.copyWith(
            runtimeModifiers: [
              ...card.runtimeModifiers,
              RuntimeStatModifier(
                modifierId: '${RoyaumeEffectKeys.roy005}:${state.turnNumber}',
                atkDelta: 400,
                sourceCardInstanceId: card.instanceId,
                expiresAtTurn: state.turnNumber,
                expiresAfterPhase: DuelPhase.end,
              ),
            ],
          ),
        );
      },
    );
  }

  static ChainEffectDefinition _roy006() {
    const usageKey = '${RoyaumeEffectKeys.roy006}:destruction_guard';
    return _FunctionalRoyaumeEffect(
      onCanActivate: (state, link) {
        final source = _sourceCard(state, link);
        final discardId = link.payload['discard_instance_id'] as String?;
        return source?.cardCode == 'ROY-006' &&
            link.payload['trigger'] == 'effect_destruction_pending' &&
            !_usedThisTurn(source!, usageKey, state.turnNumber) &&
            discardId != null &&
            _fieldFor(state, link.activatingPlayer)
                .hand
                .any((card) => card.instanceId == discardId);
      },
      onTargetLegal: (state, link) {
        final target = _findFieldCard(state, link.target?.cardInstanceId);
        return target != null &&
            target.card.controller == link.activatingPlayer &&
            target.card.hasFamily('royaume');
      },
      onPayCost: (state, link) {
        var nextState = _discardFromHand(
          state,
          link.activatingPlayer,
          link.payload['discard_instance_id']! as String,
        );
        nextState = _updateFieldCard(
          nextState,
          link.sourceCardInstanceId!,
          (card) => _markUsed(card, usageKey, state.turnNumber),
        );
        return nextState;
      },
      onResolve: (state, link) => state.copyWith(
        preventedEffectDestructionInstanceIds: {
          ...state.preventedEffectDestructionInstanceIds,
          link.target!.cardInstanceId,
        },
      ),
    );
  }

  static ChainEffectDefinition _roy007() {
    return _FunctionalRoyaumeEffect(
      onCanActivate: (state, link) {
        if (!_sourceHasCode(state, link, 'ROY-007') ||
            link.payload['trigger'] != 'tribute_summon') {
          return false;
        }
        return _validRoyalRevivalSelection(
          state,
          link.activatingPlayer,
          _payloadIds(link, 'target_instance_ids'),
          maximumRank: 4,
        );
      },
      onResolve: (state, link) => _reviveRoyalCharacters(
        state,
        link.activatingPlayer,
        _payloadIds(link, 'target_instance_ids'),
        effectsNegatedThisTurn: true,
        maximumRank: 4,
      ),
    );
  }

  static ChainEffectDefinition _roy008() {
    return _FunctionalRoyaumeEffect(
      onCanActivate: (state, link) {
        if (!_sourceHasCode(state, link, 'ROY-008')) return false;
        final selectedId = link.payload['selected_instance_id'] as String?;
        return selectedId != null &&
            _fieldFor(state, link.activatingPlayer).deck.any(
                  (card) =>
                      card.instanceId == selectedId &&
                      _isLowRankRoyalCharacter(card),
                );
      },
      onResolve: (state, link) {
        final participant = link.activatingPlayer;
        final field = _fieldFor(state, participant);
        final selectedId = link.payload['selected_instance_id']! as String;
        final index = field.deck.indexWhere(
          (card) =>
              card.instanceId == selectedId && _isLowRankRoyalCharacter(card),
        );
        if (index < 0) return state;
        final deck = List<CardInstance>.from(field.deck);
        final selected = deck.removeAt(index).copyWith(
              controller: participant,
              faceUp: false,
              position: null,
              zoneIndex: null,
            );
        return _replaceField(
          state,
          participant,
          field.copyWith(deck: deck, hand: [...field.hand, selected]),
        );
      },
    );
  }

  static ChainEffectDefinition _roy009() {
    return _FunctionalRoyaumeEffect(
      onCanActivate: (state, link) {
        if (!_sourceHasCode(state, link, 'ROY-009') ||
            link.payload['trigger'] != 'destruction_pending') {
          return false;
        }
        final sacrificeId = link.payload['sacrifice_instance_id'] as String?;
        final sacrifice = _findFieldCard(state, sacrificeId);
        return sacrifice != null &&
            sacrifice.kind == _ZoneKind.character &&
            sacrifice.card.controller == link.activatingPlayer &&
            sacrifice.card.instanceId != link.target?.cardInstanceId;
      },
      onTargetLegal: (state, link) {
        final target = _findFieldCard(state, link.target?.cardInstanceId);
        return target != null &&
            target.kind == _ZoneKind.character &&
            target.card.controller == link.activatingPlayer &&
            target.card.hasFamily('royaume');
      },
      onPayCost: (state, link) => _sacrificeCharacter(
        state,
        link.activatingPlayer,
        link.payload['sacrifice_instance_id']! as String,
      ),
      onResolve: (state, link) => state.copyWith(
        preventedEffectDestructionInstanceIds: {
          ...state.preventedEffectDestructionInstanceIds,
          link.target!.cardInstanceId,
        },
      ),
    );
  }

  static ChainEffectDefinition _roy010(
    RoyaumeAncestralSummonExtension ancestralSummonExtension,
  ) {
    return _FunctionalRoyaumeEffect(
      onCanActivate: _hasAncestralSacrifices,
      onPayCost: (state, link) {
        var nextState = state;
        for (final id in _payloadIds(link, 'sacrifice_instance_ids')) {
          nextState = _sacrificeCharacter(
            nextState,
            link.activatingPlayer,
            id,
          );
        }
        return nextState;
      },
      onResolve: (state, link) {
        return ancestralSummonExtension.summonFromMythicReserve(
          state: state,
          participant: link.activatingPlayer,
          triggerCardCode: 'ROY-010',
          mythicCardCode: 'ROY-015',
        );
      },
    );
  }

  static ChainEffectDefinition _roy011() {
    return _FunctionalRoyaumeEffect(
      onCanActivate: (state, link) =>
          _sourceHasCode(state, link, 'ROY-011') &&
          link.payload['trigger'] == 'attack_declared' &&
          link.payload['attack_declaration_id'] is String,
      onTargetLegal: (state, link) {
        final attacker = _findFieldCard(state, link.target?.cardInstanceId);
        return attacker != null &&
            attacker.kind == _ZoneKind.character &&
            attacker.card.controller != link.activatingPlayer;
      },
      onResolve: (state, link) {
        final attackerId = link.target!.cardInstanceId;
        var nextState = _updateFieldCard(state, attackerId, (card) {
          return card.copyWith(
            runtimeModifiers: [
              ...card.runtimeModifiers,
              RuntimeStatModifier(
                modifierId:
                    '${RoyaumeEffectKeys.roy011}:${link.linkId}:${state.turnNumber}',
                atkDelta: -800,
                sourceCardInstanceId: link.sourceCardInstanceId,
                expiresAtTurn: state.turnNumber,
                expiresAfterPhase: DuelPhase.end,
              ),
            ],
          );
        });
        final attacker = _findFieldCard(nextState, attackerId)?.card;
        final attackedId = link.payload['attack_target_instance_id'] as String?;
        final attacked = _findFieldCard(nextState, attackedId)?.card;
        if (attacker?.effectiveAtk != null &&
            attacked?.effectiveAtk != null &&
            attacker!.effectiveAtk! < attacked!.effectiveAtk!) {
          nextState = nextState.copyWith(
            cancelledAttackDeclarationIds: {
              ...nextState.cancelledAttackDeclarationIds,
              link.payload['attack_declaration_id']! as String,
            },
          );
        }
        return nextState;
      },
    );
  }

  static ChainEffectDefinition _roy012() {
    return _FunctionalRoyaumeEffect(
      onPendingEvents: (state, link) {
        final id = _targetedChainLink(state, link)?.sourceCardInstanceId;
        return id == null
            ? const []
            : [
                EffectDestructionPending(
                  sourceLinkId: link.linkId,
                  cardInstanceId: id,
                ),
              ];
      },
      onCanActivate: (state, link) {
        final targetLink = _targetedChainLink(state, link);
        if (!_sourceHasCode(state, link, 'ROY-012') ||
            link.speed != ChainSpeed.speed3 ||
            targetLink == null) {
          return false;
        }
        final target = _findFieldCard(
          state,
          targetLink.target?.cardInstanceId,
        );
        return target != null &&
            target.card.controller == link.activatingPlayer &&
            target.card.hasFamily('royaume');
      },
      onResolve: (state, link) => _negateAndDestroySource(
        state,
        _targetedChainLink(state, link)!,
      ),
    );
  }

  static ChainEffectDefinition _roy013() {
    return _FunctionalRoyaumeEffect(
      onCanActivate: (state, link) {
        if (!_sourceHasCode(state, link, 'ROY-013')) return false;
        final trigger = link.payload['trigger'];
        return trigger == 'continuous_refresh' ||
            (trigger == 'character_sacrificed' &&
                (link.payload['sacrifice_count'] as int? ?? 0) > 0);
      },
      onResolve: (state, link) {
        var nextState = state;
        if (link.payload['trigger'] == 'character_sacrificed') {
          final count = link.payload['sacrifice_count']! as int;
          nextState = _updateFieldCard(
            nextState,
            link.sourceCardInstanceId!,
            (card) => card.copyWith(
              counters: {
                ...card.counters,
                'serment': (card.counters['serment'] ?? 0) + count,
              },
            ),
          );
        }
        return _refreshRoyalCourtAura(
          nextState,
          link.sourceCardInstanceId!,
          link.activatingPlayer,
        );
      },
    );
  }

  static ChainEffectDefinition _roy014() {
    return _FunctionalRoyaumeEffect(
      onCanActivate: (state, link) {
        final source = _sourceCard(state, link);
        if (source?.cardCode != 'ROY-014') return false;
        final mode = link.payload['mode'];
        if (mode == 'equip') return true;
        if (mode != 'equipped_character_left') return false;
        final equippedId = source!
            .runtimeData[CardRuntimeKeys.equippedToInstanceId] as String?;
        return equippedId != null && _findFieldCard(state, equippedId) == null;
      },
      onTargetLegal: (state, link) {
        if (link.payload['mode'] == 'equipped_character_left') {
          return link.target == null;
        }
        final target = _findFieldCard(state, link.target?.cardInstanceId);
        return target != null &&
            target.kind == _ZoneKind.character &&
            target.card.controller == link.activatingPlayer &&
            target.card.hasFamily('royaume') &&
            (target.card.rank ?? 0) >= 5;
      },
      onResolve: (state, link) {
        if (link.payload['mode'] == 'equipped_character_left') {
          return _moveFieldCardToHand(state, link.sourceCardInstanceId!);
        }
        final targetId = link.target!.cardInstanceId;
        var nextState = _updateFieldCard(state, targetId, (card) {
          return card.copyWith(
            attachedCardInstanceIds: {
              ...card.attachedCardInstanceIds,
              link.sourceCardInstanceId!,
            }.toList(),
            runtimeModifiers: [
              ...card.runtimeModifiers,
              RuntimeStatModifier(
                modifierId:
                    '${RoyaumeEffectKeys.roy014}:${link.sourceCardInstanceId}',
                atkDelta: 400,
                defDelta: 400,
                sourceCardInstanceId: link.sourceCardInstanceId,
              ),
            ],
          );
        });
        nextState = _updateFieldCard(
          nextState,
          link.sourceCardInstanceId!,
          (card) => card.copyWith(
            faceUp: true,
            runtimeData: {
              ...card.runtimeData,
              CardRuntimeKeys.equippedToInstanceId: targetId,
            },
          ),
        );
        return nextState;
      },
    );
  }

  static ChainEffectDefinition _roy015() {
    const usageKey = '${RoyaumeEffectKeys.roy015}:negate_speed2';
    return _FunctionalRoyaumeEffect(
      onPendingEvents: (state, link) {
        if (link.payload['trigger'] == 'on_summon') return const [];
        final id = _targetedChainLink(state, link)?.sourceCardInstanceId;
        return id == null
            ? const []
            : [
                EffectDestructionPending(
                  sourceLinkId: link.linkId,
                  cardInstanceId: id,
                ),
              ];
      },
      onCanActivate: (state, link) {
        final source = _sourceCard(state, link);
        if (source?.cardCode != 'ROY-015') return false;
        if (link.payload['trigger'] == 'on_summon') {
          return _validRoyalRevivalSelection(
            state,
            link.activatingPlayer,
            _payloadIds(link, 'target_instance_ids'),
          );
        }
        final targetLink = _targetedChainLink(state, link);
        final sacrificeId = link.payload['sacrifice_instance_id'] as String?;
        final sacrifice = _findFieldCard(state, sacrificeId);
        return link.payload['trigger'] == 'speed2_effect_activated' &&
            link.speed == ChainSpeed.speed2 &&
            targetLink?.speed == ChainSpeed.speed2 &&
            !_usedThisTurn(source!, usageKey, state.turnNumber) &&
            sacrifice != null &&
            sacrifice.kind == _ZoneKind.character &&
            sacrifice.card.controller == link.activatingPlayer &&
            sacrifice.card.instanceId != source.instanceId;
      },
      onPayCost: (state, link) {
        if (link.payload['trigger'] == 'on_summon') return state;
        var nextState = _sacrificeCharacter(
          state,
          link.activatingPlayer,
          link.payload['sacrifice_instance_id']! as String,
        );
        nextState = _updateFieldCard(
          nextState,
          link.sourceCardInstanceId!,
          (card) => _markUsed(card, usageKey, state.turnNumber),
        );
        return nextState;
      },
      onResolve: (state, link) {
        if (link.payload['trigger'] == 'on_summon') {
          return _reviveRoyalCharacters(
            state,
            link.activatingPlayer,
            _payloadIds(link, 'target_instance_ids'),
            effectsNegatedThisTurn: false,
          );
        }
        return _negateAndDestroySource(
          state,
          _targetedChainLink(state, link)!,
        );
      },
    );
  }
}

enum _ZoneKind { character, actionTrap, terrain }

final class _FieldLocation {
  const _FieldLocation({
    required this.participant,
    required this.kind,
    required this.index,
    required this.card,
  });

  final DuelParticipant participant;
  final _ZoneKind kind;
  final int? index;
  final CardInstance card;
}

PlayerFieldState _fieldFor(DuelState state, DuelParticipant participant) {
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

_FieldLocation? _findFieldCard(DuelState state, String? instanceId) {
  if (instanceId == null) return null;
  for (final participant in DuelParticipant.values) {
    final field = _fieldFor(state, participant);
    for (var index = 0; index < field.characterZones.length; index++) {
      final entry = field.characterZones[index];
      if (entry is CardInstance && entry.instanceId == instanceId) {
        return _FieldLocation(
          participant: participant,
          kind: _ZoneKind.character,
          index: index,
          card: entry,
        );
      }
    }
    for (var index = 0; index < field.actionTrapZones.length; index++) {
      final entry = field.actionTrapZones[index];
      if (entry != null && entry.instanceId == instanceId) {
        return _FieldLocation(
          participant: participant,
          kind: _ZoneKind.actionTrap,
          index: index,
          card: entry,
        );
      }
    }
    final terrain = field.terrainZone;
    if (terrain?.instanceId == instanceId) {
      return _FieldLocation(
        participant: participant,
        kind: _ZoneKind.terrain,
        index: null,
        card: terrain!,
      );
    }
  }
  return null;
}

CardInstance? _sourceCard(DuelState state, ChainLink link) {
  return _findFieldCard(state, link.sourceCardInstanceId)?.card;
}

bool _sourceHasCode(DuelState state, ChainLink link, String code) {
  if (link.sourceCardCode == code) return true;
  if (_sourceCard(state, link)?.cardCode == code) return true;
  return _fieldFor(state, link.activatingPlayer).graveyard.any(
        (card) =>
            card.instanceId == link.sourceCardInstanceId &&
            card.cardCode == code,
      );
}

DuelState _updateFieldCard(
  DuelState state,
  String instanceId,
  CardInstance Function(CardInstance card) update,
) {
  final location = _findFieldCard(state, instanceId);
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

DuelState _removeFieldCard(DuelState state, _FieldLocation location) {
  final field = _fieldFor(state, location.participant);
  switch (location.kind) {
    case _ZoneKind.character:
      final zones = List<FieldCardInstance?>.from(field.characterZones)
        ..[location.index!] = null;
      return _replaceField(
        state,
        location.participant,
        field.copyWith(characterZones: zones),
      );
    case _ZoneKind.actionTrap:
      final zones = List<CardInstance?>.from(field.actionTrapZones)
        ..[location.index!] = null;
      return _replaceField(
        state,
        location.participant,
        field.copyWith(actionTrapZones: zones),
      );
    case _ZoneKind.terrain:
      return _replaceField(
        state,
        location.participant,
        field.copyWith(terrainZone: null),
      );
  }
}

DuelState _moveFieldCardToHand(DuelState state, String instanceId) {
  final location = _findFieldCard(state, instanceId);
  if (location == null) return state;
  var nextState = _removeFieldCard(state, location);
  final ownerField = _fieldFor(nextState, location.card.owner);
  final handCard = location.card.copyWith(
    controller: location.card.owner,
    faceUp: false,
    position: null,
    zoneIndex: null,
    attachedCardInstanceIds: const [],
    counters: const {},
    runtimeModifiers: const [],
    runtimeData: const {},
  );
  return _replaceField(
    nextState,
    location.card.owner,
    ownerField.copyWith(hand: [...ownerField.hand, handCard]),
  );
}

DuelState _discardFromHand(
  DuelState state,
  DuelParticipant participant,
  String instanceId,
) {
  final field = _fieldFor(state, participant);
  final index = field.hand.indexWhere((card) => card.instanceId == instanceId);
  if (index < 0) return state;
  final hand = List<CardInstance>.from(field.hand);
  final removed = hand.removeAt(index);
  final graveyardCard = removed.copyWith(
    controller: removed.owner,
    faceUp: true,
    position: null,
    zoneIndex: null,
  );
  final ownerField = removed.owner == participant
      ? field.copyWith(hand: hand)
      : _fieldFor(state, removed.owner);
  var nextState = _replaceField(
    state,
    participant,
    field.copyWith(hand: hand),
  );
  final latestOwnerField = _fieldFor(nextState, removed.owner);
  return _replaceField(
    nextState,
    removed.owner,
    latestOwnerField.copyWith(
      graveyard: [...ownerField.graveyard, graveyardCard],
    ),
  );
}

DuelState _drawOne(DuelState state, DuelParticipant participant) {
  final field = _fieldFor(state, participant);
  if (field.deck.isEmpty) {
    return state.copyWith(
      winner: participant == DuelParticipant.player
          ? DuelParticipant.ai
          : DuelParticipant.player,
      endReason: DuelEndReason.deckOut,
    );
  }
  final deck = List<CardInstance>.from(field.deck);
  final drawn = deck.removeAt(0).copyWith(
        controller: participant,
        faceUp: false,
        position: null,
        zoneIndex: null,
      );
  return _replaceField(
    state,
    participant,
    field.copyWith(deck: deck, hand: [...field.hand, drawn]),
  );
}

DuelState _sacrificeCharacter(
  DuelState state,
  DuelParticipant participant,
  String instanceId,
) {
  final field = _fieldFor(state, participant);
  final index = field.characterZones.indexWhere(
    (card) => card?.instanceId == instanceId && card?.controller == participant,
  );
  if (index < 0) return state;
  final sacrificed = field.characterZones[index]!;
  final zones = List<FieldCardInstance?>.from(field.characterZones)
    ..[index] = null;
  var nextState = _replaceField(
    state,
    participant,
    field.copyWith(characterZones: zones),
  );
  if (sacrificed is TokenInstance) return nextState;
  final card = sacrificed as CardInstance;
  final ownerField = _fieldFor(nextState, card.owner);
  final graveyardCard = card.copyWith(
    controller: card.owner,
    faceUp: true,
    position: null,
    zoneIndex: null,
    attachedCardInstanceIds: const [],
    counters: const {},
  );
  return _replaceField(
    nextState,
    card.owner,
    ownerField.copyWith(graveyard: [...ownerField.graveyard, graveyardCard]),
  );
}

bool _roy004SelectionIsLegal(DuelState state, ChainLink link) {
  final field = _fieldFor(state, link.activatingPlayer);
  if (field.deck.isEmpty) return false;
  final topCards = field.deck.take(3).toList();
  final selectedId = link.payload['selected_instance_id'] as String?;
  final eligible = topCards.where(_isRoyalCard).toList();
  if (eligible.isNotEmpty &&
      !eligible.any((card) => card.instanceId == selectedId)) {
    return false;
  }
  if (eligible.isEmpty && selectedId != null) return false;
  final expectedRemaining = topCards
      .where((card) => card.instanceId != selectedId)
      .map((card) => card.instanceId)
      .toSet();
  final order = _payloadIds(link, 'remaining_order_instance_ids');
  return order.length == expectedRemaining.length &&
      order.toSet().length == order.length &&
      order.toSet().containsAll(expectedRemaining);
}

bool _isRoyalCard(CardInstance card) => card.hasFamily('royaume');

bool _isLowRankRoyalCharacter(CardInstance card) {
  return card.category == CardCategory.character &&
      card.hasFamily('royaume') &&
      (card.rank ?? 99) <= 4;
}

bool _validRoyalRevivalSelection(
  DuelState state,
  DuelParticipant participant,
  List<String> ids, {
  int? maximumRank,
}) {
  if (ids.length > 2 || ids.toSet().length != ids.length) return false;
  final field = _fieldFor(state, participant);
  final freeZones = field.characterZones.where((card) => card == null).length;
  if (ids.length > freeZones) return false;
  return ids.every((id) {
    return field.graveyard.any(
      (card) =>
          card.instanceId == id &&
          card.category == CardCategory.character &&
          card.hasFamily('royaume') &&
          (maximumRank == null || (card.rank ?? 99) <= maximumRank),
    );
  });
}

DuelState _reviveRoyalCharacters(
  DuelState state,
  DuelParticipant participant,
  List<String> ids, {
  required bool effectsNegatedThisTurn,
  int? maximumRank,
}) {
  var nextState = state;
  for (final id in ids) {
    final field = _fieldFor(nextState, participant);
    final graveyardIndex = field.graveyard.indexWhere(
      (card) =>
          card.instanceId == id &&
          card.category == CardCategory.character &&
          card.hasFamily('royaume') &&
          (maximumRank == null || (card.rank ?? 99) <= maximumRank),
    );
    final zoneIndex = field.characterZones.indexWhere((card) => card == null);
    if (graveyardIndex < 0 || zoneIndex < 0) continue;
    final graveyard = List<CardInstance>.from(field.graveyard);
    final card = graveyard.removeAt(graveyardIndex);
    final runtimeData = Map<String, Object?>.from(card.runtimeData);
    if (effectsNegatedThisTurn) {
      runtimeData[CardRuntimeKeys.effectsNegatedUntilTurn] =
          nextState.turnNumber;
    }
    final revived = card.copyWith(
      controller: participant,
      faceUp: true,
      position: BattlePosition.defense,
      zoneIndex: zoneIndex,
      summonedTurn: nextState.turnNumber,
      attackedThisTurn: false,
      positionChangedThisTurn: false,
      counters: const {},
      runtimeModifiers: const [],
      runtimeData: runtimeData,
    );
    final zones = List<FieldCardInstance?>.from(field.characterZones)
      ..[zoneIndex] = revived;
    nextState = _replaceField(
      nextState,
      participant,
      field.copyWith(characterZones: zones, graveyard: graveyard),
    );
  }
  return nextState;
}

bool _hasAncestralSacrifices(DuelState state, ChainLink link) {
  if (!_sourceHasCode(state, link, 'ROY-010')) return false;
  final ids = _payloadIds(link, 'sacrifice_instance_ids');
  if (ids.isEmpty || ids.toSet().length != ids.length) return false;
  var totalRank = 0;
  for (final id in ids) {
    final location = _findFieldCard(state, id);
    if (location == null ||
        location.kind != _ZoneKind.character ||
        location.card.controller != link.activatingPlayer ||
        location.card.rank == null) {
      return false;
    }
    totalRank += location.card.rank!;
  }
  return totalRank >= 9;
}

ChainLink? _targetedChainLink(DuelState state, ChainLink link) {
  final targetId = link.payload['target_link_id'] as String?;
  if (targetId == null) return null;
  for (final candidate in state.chain.links) {
    if (candidate.linkId == targetId) return candidate;
  }
  return null;
}

DuelState _negateAndDestroySource(DuelState state, ChainLink targetLink) {
  var nextState = state.copyWith(
    chain: state.chain.copyWith(
      negatedLinkIds: {...state.chain.negatedLinkIds, targetLink.linkId},
    ),
  );
  final sourceId = targetLink.sourceCardInstanceId;
  if (sourceId != null) {
    nextState = resolveCardDestructionByEffect(
      state: nextState,
      cardInstanceId: sourceId,
    ).state;
  }
  return nextState;
}

DuelState _refreshRoyalCourtAura(
  DuelState state,
  String terrainInstanceId,
  DuelParticipant controller,
) {
  final terrain = _findFieldCard(state, terrainInstanceId)?.card;
  if (terrain == null) return state;
  final hasOathBonus = (terrain.counters['serment'] ?? 0) >= 3;
  final modifierId = '${RoyaumeEffectKeys.roy013}:$terrainInstanceId';
  var nextState = state;
  for (final participant in DuelParticipant.values) {
    final field = _fieldFor(nextState, participant);
    final zones = field.characterZones.map((entry) {
      if (entry is! CardInstance) return entry;
      final withoutAura = entry.runtimeModifiers
          .where((modifier) => modifier.modifierId != modifierId)
          .toList();
      if (!entry.hasFamily('royaume')) {
        return entry.copyWith(runtimeModifiers: withoutAura);
      }
      return entry.copyWith(
        runtimeModifiers: [
          ...withoutAura,
          RuntimeStatModifier(
            modifierId: modifierId,
            atkDelta: entry.controller == controller && hasOathBonus ? 300 : 0,
            defDelta: 200,
            sourceCardInstanceId: terrainInstanceId,
          ),
        ],
      );
    }).toList();
    nextState = _replaceField(
      nextState,
      participant,
      field.copyWith(characterZones: zones),
    );
  }
  return nextState;
}

bool _usedThisTurn(CardInstance card, String key, int turnNumber) {
  return card.effectUsageTurns[key] == turnNumber;
}

CardInstance _markUsed(CardInstance card, String key, int turnNumber) {
  return card.copyWith(
    effectUsageTurns: {...card.effectUsageTurns, key: turnNumber},
  );
}

List<String> _payloadIds(ChainLink link, String key) {
  final value = link.payload[key];
  if (value is! List) return const [];
  return value.whereType<String>().toList(growable: false);
}
