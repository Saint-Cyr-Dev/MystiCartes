import 'manual_activation_options.dart';
import '../battle_state.dart';
import '../card.dart';
import '../duel_engine.dart';
import '../duel_types.dart';
import '../mythic_summon.dart';
import '../player.dart';

abstract final class VillageEffectKeys {
  static const vil001 = 'vil_001_apprenti_potier';
  static const vil002 = 'vil_002_tisserande_aux_fils_de_vent';
  static const vil004 = 'vil_004_forgeronne_des_etincelles_bleues';
  static const vil005 = 'vil_005_doyenne_du_grenier_commun';
  static const vil006 = 'vil_006_maitre_artisan_des_trois_metaux';
  static const vil007 = 'vil_007_gardien_du_grenier_d_argile';
  static const vil008 = 'vil_008_atelier_partage';
  static const vil009 = 'vil_009_tablier_aux_cent_poches';
  static const vil010 = 'vil_010_etincelle_de_la_forge_ancestrale';
  static const vil011 = 'vil_011_mur_de_banco_renforce';
  static const vil012 = 'vil_012_travail_bien_fait';
  static const vil013 = 'vil_013_grand_village_des_artisans';
  static const vil014 = 'vil_014_marteau_des_trois_metaux';
  static const vil015 = 'vil_015_forge_ancetre_main_du_peuple';
}

abstract interface class VillageFusionSummonExtension {
  DuelState summonFromMythicReserve({
    required DuelState state,
    required DuelParticipant participant,
    required String triggerCardCode,
    required String mythicCardCode,
  });
}

final class DefaultVillageFusionSummonExtension
    implements VillageFusionSummonExtension {
  const DefaultVillageFusionSummonExtension();
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

typedef _Predicate = bool Function(DuelState, ChainLink);
typedef _Reducer = DuelState Function(DuelState, ChainLink);
typedef _PendingEvents = Iterable<PendingDuelEvent> Function(
  DuelState state,
  ChainLink link,
);

final class _Effect extends ChainEffectDefinition {
  const _Effect({
    this.onManualActivations,
    this.can,
    this.cost,
    this.legal,
    this.events,
    required this.effect,
  });
  final _Predicate? can;
  final _Reducer? cost;
  final _Predicate? legal;
  final _PendingEvents? events;
  final _Reducer effect;
  final ManualActivationBuilder? onManualActivations;
  @override
  Iterable<ManualActivationOption> buildManualActivations(
          ManualActivationRequest request) =>
      onManualActivations?.call(request) ?? const [];

  @override
  bool canActivate(DuelState state, ChainLink link) =>
      can?.call(state, link) ?? true;
  @override
  DuelState payCost(DuelState state, ChainLink link) =>
      cost?.call(state, link) ?? state;
  @override
  bool isTargetLegal(DuelState state, ChainLink link) =>
      legal?.call(state, link) ?? link.target == null;
  @override
  Iterable<PendingDuelEvent> pendingEvents(DuelState state, ChainLink link) =>
      events?.call(state, link) ?? const [];
  @override
  DuelState resolve(DuelState state, ChainLink link) => effect(state, link);
}

final class VillageEffectRegistry {
  const VillageEffectRegistry._();

  static Map<String, ChainEffectDefinition> create({
    VillageFusionSummonExtension fusionSummonExtension =
        const DefaultVillageFusionSummonExtension(),
  }) =>
      {
        VillageEffectKeys.vil001: _vil001(),
        VillageEffectKeys.vil002: _vil002(),
        VillageEffectKeys.vil004: _vil004(),
        VillageEffectKeys.vil005: _vil005(),
        VillageEffectKeys.vil006: _vil006(),
        VillageEffectKeys.vil007: _vil007(),
        VillageEffectKeys.vil008: _vil008(),
        VillageEffectKeys.vil009: _vil009(),
        VillageEffectKeys.vil010: _vil010(fusionSummonExtension),
        VillageEffectKeys.vil011: _vil011(),
        VillageEffectKeys.vil012: _vil012(),
        VillageEffectKeys.vil013: _vil013(),
        VillageEffectKeys.vil014: _vil014(),
        VillageEffectKeys.vil015: _vil015(),
      };

  static ChainEffectDefinition _vil001() => _Effect(
        can: (state, link) =>
            _sourceCode(state, link, 'VIL-001') &&
            link.payload['trigger'] == 'sent_from_field_to_graveyard',
        legal: (state, link) {
          final target = _graveCard(
              state, link.activatingPlayer, link.target?.cardInstanceId);
          return target != null && _isEquipment(target);
        },
        effect: (state, link) => _graveToDeckBottom(
            state, link.activatingPlayer, link.target!.cardInstanceId),
      );

  static ChainEffectDefinition _vil002() => _Effect(
        can: (state, link) =>
            _sourceCode(state, link, 'VIL-002') &&
            link.payload['trigger'] == 'on_summon',
        legal: (state, link) => _controlledVillageCharacter(
            state, link, link.target?.cardInstanceId),
        effect: (state, link) => _modify(
          state,
          link.target!.cardInstanceId,
          RuntimeStatModifier(
            modifierId: '${VillageEffectKeys.vil002}:${link.linkId}',
            defDelta: 300,
            sourceCardInstanceId: link.sourceCardInstanceId,
            expiresAtTurn: state.turnNumber + 1,
          ),
        ),
      );

  static ChainEffectDefinition _vil004() => _Effect(
        can: (state, link) {
          if (!_sourceCode(state, link, 'VIL-004') ||
              link.payload['trigger'] != 'on_summon') {
            return false;
          }
          final field = _field(state, link.activatingPlayer);
          final equipmentId = link.payload['equipment_instance_id'] as String?;
          final discardId = link.payload['discard_instance_id'] as String?;
          final equipment = _listCard(field.deck, equipmentId);
          return equipment != null &&
              _isEquipment(equipment) &&
              discardId != null &&
              (discardId == equipmentId ||
                  field.hand.any((card) => card.instanceId == discardId));
        },
        effect: (state, link) {
          final participant = link.activatingPlayer;
          final field = _field(state, participant);
          final deck = [...field.deck];
          final equipmentId = link.payload['equipment_instance_id']! as String;
          final equipmentIndex =
              deck.indexWhere((card) => card.instanceId == equipmentId);
          final hand = [...field.hand, _asHand(deck.removeAt(equipmentIndex))];
          final discardId = link.payload['discard_instance_id']! as String;
          final discardIndex =
              hand.indexWhere((card) => card.instanceId == discardId);
          final discarded = _asGrave(hand.removeAt(discardIndex));
          return _replaceField(
              state,
              participant,
              field.copyWith(
                deck: deck,
                hand: hand,
                graveyard: [...field.graveyard, discarded],
              ));
        },
      );

  static ChainEffectDefinition _vil005() {
    const usage = '${VillageEffectKeys.vil005}:equipped_left';
    return _Effect(
      can: (state, link) {
        final source = _source(state, link);
        final field = _field(state, link.activatingPlayer);
        final discardId = link.payload['discard_instance_id'] as String?;
        return source?.cardCode == 'VIL-005' &&
            link.payload['trigger'] == 'equipped_card_left_field' &&
            !_used(source!, usage, state.turnNumber) &&
            field.deck.isNotEmpty &&
            discardId != null &&
            (field.hand.any((card) => card.instanceId == discardId) ||
                field.deck.first.instanceId == discardId);
      },
      cost: (state, link) => _markUsage(
          state, link.sourceCardInstanceId!, usage, state.turnNumber),
      effect: (state, link) {
        var next = _gainLife(state, link.activatingPlayer, 500);
        return _drawDiscard(next, link.activatingPlayer,
            link.payload['discard_instance_id']! as String);
      },
    );
  }

  static ChainEffectDefinition _vil006() {
    const usage = '${VillageEffectKeys.vil006}:reequip';
    return _Effect(
      can: (state, link) {
        final source = _source(state, link);
        return source?.cardCode == 'VIL-006' &&
            link.payload['mode'] == 'reequip' &&
            !_used(source!, usage, state.turnNumber);
      },
      legal: (state, link) {
        final equipmentId = link.payload['equipment_instance_id'] as String?;
        final equipment = _graveCard(state, link.activatingPlayer, equipmentId);
        return equipment != null &&
            _isEquipment(equipment) &&
            _controlledCharacter(state, link, link.target?.cardInstanceId) &&
            _field(state, link.activatingPlayer)
                .actionTrapZones
                .any((zone) => zone == null);
      },
      cost: (state, link) => _markUsage(
          state, link.sourceCardInstanceId!, usage, state.turnNumber),
      effect: (state, link) => _equipFromGrave(
        state,
        link.activatingPlayer,
        link.payload['equipment_instance_id']! as String,
        link.target!.cardInstanceId,
        banishWhenLeaves: true,
      ),
    );
  }

  static ChainEffectDefinition _vil007() {
    const usage = '${VillageEffectKeys.vil007}:protection';
    return _Effect(
      can: (state, link) {
        final source = _source(state, link);
        final target = _locate(state, link.target?.cardInstanceId);
        return source?.cardCode == 'VIL-007' &&
            link.payload['trigger'] ==
                'other_village_would_be_destroyed_by_opponent_effect' &&
            !_used(source!, usage, state.turnNumber) &&
            target != null &&
            target.card.instanceId != source.instanceId &&
            target.card.controller == link.activatingPlayer &&
            target.card.hasFamily('village');
      },
      legal: (state, link) =>
          _locate(state, link.target?.cardInstanceId) != null,
      cost: (state, link) => _markUsage(
          state, link.sourceCardInstanceId!, usage, state.turnNumber),
      effect: (state, link) => state.copyWith(
        preventedEffectDestructionInstanceIds: {
          ...state.preventedEffectDestructionInstanceIds,
          link.target!.cardInstanceId,
        },
      ),
    );
  }

  static ChainEffectDefinition _vil008() {
    const usage = '${VillageEffectKeys.vil008}:tool';
    return _Effect(
      can: (state, link) {
        final source = _source(state, link);
        if (source?.cardCode != 'VIL-008') return false;
        if (link.payload['mode'] == 'equipment_attached') {
          return !_used(source!, usage, state.turnNumber);
        }
        if (link.payload['mode'] == 'spend_tools') {
          final field = _field(state, link.activatingPlayer);
          final discardId = link.payload['discard_instance_id'] as String?;
          return (source!.counters['outil'] ?? 0) >= 2 &&
              field.deck.isNotEmpty &&
              discardId != null &&
              (field.hand.any((c) => c.instanceId == discardId) ||
                  field.deck.first.instanceId == discardId);
        }
        return false;
      },
      cost: (state, link) {
        if (link.payload['mode'] == 'equipment_attached') {
          return _markUsage(
              state, link.sourceCardInstanceId!, usage, state.turnNumber);
        }
        return _update(
            state,
            link.sourceCardInstanceId!,
            (card) => card.copyWith(
                  counters: {
                    ...card.counters,
                    'outil': card.counters['outil']! - 2
                  },
                ));
      },
      effect: (state, link) {
        if (link.payload['mode'] == 'equipment_attached') {
          return _update(
              state,
              link.sourceCardInstanceId!,
              (card) => card.copyWith(
                    counters: {
                      ...card.counters,
                      'outil': (card.counters['outil'] ?? 0) + 1,
                    },
                  ));
        }
        return _drawDiscard(state, link.activatingPlayer,
            link.payload['discard_instance_id']! as String);
      },
    );
  }

  static ChainEffectDefinition _vil009() {
    const usage = '${VillageEffectKeys.vil009}:peek';
    return _Effect(
      onManualActivations: (request) sync* {
        final ownCharacters = request.ownCharacters;
        final option = request.option;
        for (final target
            in ownCharacters.where((c) => c.hasFamily('village'))) {
          yield option(
              target: ChainTarget(cardInstanceId: target.instanceId),
              payload: {'mode': 'equip'},
              description: 'Équiper ${target.cardCode}',
              suffix: target.instanceId);
        }
      },
      can: (state, link) {
        final source = _source(state, link);
        if (source?.cardCode != 'VIL-009') return false;
        if (link.payload['mode'] == 'equip') return true;
        if (link.payload['mode'] != 'peek' ||
            _used(source!, usage, state.turnNumber)) {
          return false;
        }
        final field = _field(state, link.activatingPlayer);
        if (field.deck.isEmpty) return false;
        final take = link.payload['take'] == true;
        if (!take) return true;
        final bottomId = link.payload['bottom_instance_id'] as String?;
        return _isEquipment(field.deck.first) &&
            bottomId != null &&
            (bottomId == field.deck.first.instanceId ||
                field.hand.any((c) => c.instanceId == bottomId));
      },
      legal: (state, link) =>
          link.payload['mode'] != 'equip' ||
          _controlledVillageCharacter(state, link, link.target?.cardInstanceId),
      cost: (state, link) => link.payload['mode'] == 'peek'
          ? _markUsage(
              state, link.sourceCardInstanceId!, usage, state.turnNumber)
          : state,
      effect: (state, link) {
        if (link.payload['mode'] == 'equip') {
          return _equipExisting(
              state, link.sourceCardInstanceId!, link.target!.cardInstanceId,
              defDelta: 400);
        }
        if (link.payload['take'] != true) return state;
        final participant = link.activatingPlayer;
        final field = _field(state, participant);
        final deck = [...field.deck];
        final hand = [...field.hand, _asHand(deck.removeAt(0))];
        final bottomId = link.payload['bottom_instance_id']! as String;
        final index = hand.indexWhere((c) => c.instanceId == bottomId);
        deck.add(_asDeck(hand.removeAt(index)));
        return _replaceField(
            state, participant, field.copyWith(deck: deck, hand: hand));
      },
    );
  }

  static ChainEffectDefinition _vil010(
          VillageFusionSummonExtension extension) =>
      _Effect(
        can: (state, link) {
          if (!_sourceCode(state, link, 'VIL-010') ||
              link.payload['mode'] != 'fusion_cost') {
            return false;
          }
          final ids = _ids(link, 'material_instance_ids');
          if (ids.length != 3 || ids.toSet().length != 3) return false;
          final cards = ids.map((id) => _locate(state, id)).toList();
          return cards.every((entry) =>
                  entry != null &&
                  entry.card.controller == link.activatingPlayer) &&
              cards.any((e) => e!.card.cardCode == 'VIL-004') &&
              cards.any((e) => e!.card.cardCode == 'VIL-006') &&
              cards.any((e) => _isEquipment(e!.card));
        },
        cost: (state, link) {
          var next = state;
          for (final id in _ids(link, 'material_instance_ids')) {
            next = _sendFieldCardToGrave(next, id);
          }
          return next;
        },
        effect: (state, link) => extension.summonFromMythicReserve(
          state: state,
          participant: link.activatingPlayer,
          triggerCardCode: 'VIL-010',
          mythicCardCode: 'VIL-015',
        ),
      );

  static ChainEffectDefinition _vil011() => _Effect(
        onManualActivations: (request) sync* {
          final ownCharacters = request.ownCharacters;
          final attack = request.attack;
          final option = request.option;
          if (attack != null) {
            final target = ownCharacters
                .where((c) =>
                    c.instanceId == attack.targetInstanceId &&
                    c.hasFamily('village') &&
                    c.position == BattlePosition.defense)
                .firstOrNull;
            if (target != null) {
              yield option(
                  target: ChainTarget(cardInstanceId: target.instanceId),
                  payload: {'trigger': 'village_defender_attacked'},
                  description: 'Renforcer ${target.cardCode}',
                  suffix: target.instanceId);
            }
          }
        },
        can: (state, link) =>
            _sourceCode(state, link, 'VIL-011') &&
            link.payload['trigger'] == 'village_defender_attacked',
        legal: (state, link) {
          final target = _locate(state, link.target?.cardInstanceId);
          return target != null &&
              target.card.controller == link.activatingPlayer &&
              target.card.position == BattlePosition.defense &&
              target.card.hasFamily('village');
        },
        effect: (state, link) => _update(
            state,
            link.target!.cardInstanceId,
            (card) => card.copyWith(runtimeData: {
                  ...card.runtimeData,
                  CardRuntimeKeys.combatOnlyDefDelta:
                      (card.runtimeData[CardRuntimeKeys.combatOnlyDefDelta]
                                  as int? ??
                              0) +
                          1000,
                })),
      );

  static ChainEffectDefinition _vil012() => _Effect(
        onManualActivations: (request) sync* {
          final effectiveContext = request.context;
          final last = request.last;
          final option = request.option;
          if (last != null) {
            final destruction =
                effectiveContext.firstEvent<EffectDestructionPending>();
            final banishment = effectiveContext.firstEvent<BanishmentPending>();
            final equipmentId = destruction?.cardInstanceId ??
                banishment?.cardInstanceId ??
                last.target?.cardInstanceId ??
                last.payload['equipment_instance_id'] as String?;
            if (equipmentId != null) {
              yield option(payload: {
                'trigger': 'equipment_would_be_destroyed_or_banished',
                'target_link_id': last.linkId,
                'equipment_instance_id': equipmentId
              }, description: 'Protéger l’Équipement', suffix: last.linkId);
            }
          }
        },
        events: (state, link) {
          final id = _targetLink(state, link)?.sourceCardInstanceId;
          return id == null
              ? const []
              : [
                  EffectDestructionPending(
                    sourceLinkId: link.linkId,
                    cardInstanceId: id,
                  ),
                ];
        },
        can: (state, link) {
          final source = _source(state, link);
          final targeted = _targetLink(state, link);
          final equipmentId = link.payload['equipment_instance_id'] as String?;
          final equipment = _locate(state, equipmentId);
          return source?.cardCode == 'VIL-012' &&
              link.payload['trigger'] ==
                  'equipment_would_be_destroyed_or_banished' &&
              targeted != null &&
              equipment != null &&
              equipment.card.controller == link.activatingPlayer &&
              _isEquipment(equipment.card);
        },
        effect: (state, link) =>
            _negateAndDestroy(state, _targetLink(state, link)!),
      );

  static ChainEffectDefinition _vil013() {
    const usage = '${VillageEffectKeys.vil013}:grave_equip';
    return _Effect(
      can: (state, link) {
        final source = _source(state, link);
        if (source?.cardCode != 'VIL-013') return false;
        if (link.payload['mode'] == 'continuous_refresh') return true;
        final equipment =
            _locate(state, link.payload['equipment_instance_id'] as String?);
        return link.payload['mode'] == 'equip_village_from_grave' &&
            !_used(source!, usage, state.turnNumber) &&
            equipment != null &&
            equipment.card.controller == link.activatingPlayer &&
            _isEquipment(equipment.card);
      },
      legal: (state, link) {
        if (link.payload['mode'] == 'continuous_refresh') return true;
        final target = _graveCard(
            state, link.activatingPlayer, link.target?.cardInstanceId);
        return target != null &&
            target.hasFamily('village') &&
            target.category == CardCategory.character &&
            _field(state, link.activatingPlayer)
                .characterZones
                .any((zone) => zone == null);
      },
      cost: (state, link) => link.payload['mode'] == 'continuous_refresh'
          ? state
          : _markUsage(
              state, link.sourceCardInstanceId!, usage, state.turnNumber),
      effect: (state, link) {
        if (link.payload['mode'] == 'continuous_refresh') {
          return _refreshVillageAura(state, link.sourceCardInstanceId!);
        }
        final equipmentId = link.payload['equipment_instance_id']! as String;
        var next = _reviveFromGrave(
            state, link.activatingPlayer, link.target!.cardInstanceId,
            negateEffects: true);
        return _equipExisting(next, equipmentId, link.target!.cardInstanceId);
      },
    );
  }

  static ChainEffectDefinition _vil014() {
    return _Effect(
      can: (state, link) {
        final source = _source(state, link);
        if (source?.cardCode != 'VIL-014') return false;
        if (link.payload['mode'] == 'equip' ||
            link.payload['mode'] == 'refresh_bonus') {
          return true;
        }
        final substitute =
            _locate(state, link.payload['substitute_instance_id'] as String?);
        return link.payload['mode'] == 'substitute_destruction' &&
            substitute != null &&
            substitute.card.controller == link.activatingPlayer &&
            substitute.card.instanceId != source!.instanceId &&
            _isEquipment(substitute.card);
      },
      legal: (state, link) =>
          link.payload['mode'] != 'equip' ||
          _controlledVillageCharacter(state, link, link.target?.cardInstanceId),
      cost: (state, link) {
        if (link.payload['mode'] != 'substitute_destruction') return state;
        return resolveCardDestructionByEffect(
          state: state,
          cardInstanceId: link.payload['substitute_instance_id']! as String,
        ).state;
      },
      effect: (state, link) {
        if (link.payload['mode'] == 'equip') {
          return _equipExisting(
              state, link.sourceCardInstanceId!, link.target!.cardInstanceId);
        }
        if (link.payload['mode'] == 'substitute_destruction') {
          return state.copyWith(preventedEffectDestructionInstanceIds: {
            ...state.preventedEffectDestructionInstanceIds,
            link.sourceCardInstanceId!,
          });
        }
        return _refreshHammerBonus(
            state, link.sourceCardInstanceId!, link.activatingPlayer);
      },
    );
  }

  static ChainEffectDefinition _vil015() {
    const usage = '${VillageEffectKeys.vil015}:prevent';
    return _Effect(
      can: (state, link) {
        final source = _source(state, link);
        if (source?.cardCode != 'VIL-015') return false;
        if (link.payload['trigger'] == 'on_summon') {
          final ids = _ids(link, 'equipment_instance_ids');
          final cards = ids
              .map((id) => _graveCard(state, link.activatingPlayer, id))
              .toList();
          return ids.length <= 2 &&
              ids.toSet().length == ids.length &&
              _field(state, link.activatingPlayer)
                      .actionTrapZones
                      .where((zone) => zone == null)
                      .length >=
                  ids.length &&
              cards.every((card) => card != null && _isEquipment(card)) &&
              cards.map((card) => card!.cardCode).toSet().length ==
                  cards.length;
        }
        final equipmentId = link.payload['equipment_instance_id'] as String?;
        final target = _locate(state, link.target?.cardInstanceId);
        return link.payload['trigger'] ==
                'controlled_card_would_be_destroyed' &&
            !_used(source!, usage, state.turnNumber) &&
            source.attachedCardInstanceIds.contains(equipmentId) &&
            target != null &&
            target.card.controller == link.activatingPlayer;
      },
      legal: (state, link) =>
          link.payload['trigger'] == 'on_summon' ||
          _locate(state, link.target?.cardInstanceId) != null,
      cost: (state, link) {
        if (link.payload['trigger'] == 'on_summon') return state;
        var next = _markUsage(
            state, link.sourceCardInstanceId!, usage, state.turnNumber);
        return _sendFieldCardToGrave(
            next, link.payload['equipment_instance_id']! as String);
      },
      effect: (state, link) {
        if (link.payload['trigger'] == 'on_summon') {
          var next = state;
          for (final id in _ids(link, 'equipment_instance_ids')) {
            next = _equipFromGrave(
                next, link.activatingPlayer, id, link.sourceCardInstanceId!);
          }
          return next;
        }
        return state.copyWith(preventedEffectDestructionInstanceIds: {
          ...state.preventedEffectDestructionInstanceIds,
          link.target!.cardInstanceId,
        });
      },
    );
  }
}

enum _Kind { character, action, terrain }

final class _Location {
  const _Location(this.participant, this.kind, this.card, [this.index]);
  final DuelParticipant participant;
  final _Kind kind;
  final CardInstance card;
  final int? index;
}

PlayerFieldState _field(DuelState state, DuelParticipant participant) =>
    participant == DuelParticipant.player ? state.playerField : state.aiField;

DuelState _replaceField(
        DuelState state, DuelParticipant participant, PlayerFieldState field) =>
    participant == DuelParticipant.player
        ? state.copyWith(playerField: field)
        : state.copyWith(aiField: field);

_Location? _locate(DuelState state, String? id) {
  if (id == null) return null;
  for (final participant in DuelParticipant.values) {
    final field = _field(state, participant);
    for (var i = 0; i < field.characterZones.length; i++) {
      final card = field.characterZones[i];
      if (card is CardInstance && card.instanceId == id) {
        return _Location(participant, _Kind.character, card, i);
      }
    }
    for (var i = 0; i < field.actionTrapZones.length; i++) {
      final card = field.actionTrapZones[i];
      if (card?.instanceId == id) {
        return _Location(participant, _Kind.action, card!, i);
      }
    }
    if (field.terrainZone?.instanceId == id) {
      return _Location(participant, _Kind.terrain, field.terrainZone!);
    }
  }
  return null;
}

CardInstance? _source(DuelState state, ChainLink link) =>
    _locate(state, link.sourceCardInstanceId)?.card;
bool _sourceCode(DuelState state, ChainLink link, String code) =>
    (_source(state, link)?.cardCode ?? link.sourceCardCode) == code;
bool _used(CardInstance card, String key, int turn) =>
    card.effectUsageTurns[key] == turn;

DuelState _markUsage(DuelState state, String id, String key, int turn) =>
    _update(
        state,
        id,
        (card) => card.copyWith(
              effectUsageTurns: {...card.effectUsageTurns, key: turn},
            ));

DuelState _update(
    DuelState state, String id, CardInstance Function(CardInstance) update) {
  final location = _locate(state, id);
  if (location == null) return state;
  final field = _field(state, location.participant);
  if (location.kind == _Kind.character) {
    final zones = [...field.characterZones]..[location.index!] =
        update(location.card);
    return _replaceField(
        state, location.participant, field.copyWith(characterZones: zones));
  }
  if (location.kind == _Kind.action) {
    final zones = [...field.actionTrapZones]..[location.index!] =
        update(location.card);
    return _replaceField(
        state, location.participant, field.copyWith(actionTrapZones: zones));
  }
  return _replaceField(state, location.participant,
      field.copyWith(terrainZone: update(location.card)));
}

bool _isEquipment(CardInstance card) =>
    card.subtype == 'equipment' || card.category == CardCategory.relic;
CardInstance? _listCard(List<CardInstance> cards, String? id) => id == null
    ? null
    : cards
        .cast<CardInstance?>()
        .firstWhere((card) => card?.instanceId == id, orElse: () => null);
CardInstance? _graveCard(
        DuelState state, DuelParticipant participant, String? id) =>
    _listCard(_field(state, participant).graveyard, id);

bool _controlledCharacter(DuelState state, ChainLink link, String? id) {
  final location = _locate(state, id);
  return location?.kind == _Kind.character &&
      location?.card.controller == link.activatingPlayer;
}

bool _controlledVillageCharacter(DuelState state, ChainLink link, String? id) {
  final location = _locate(state, id);
  return location?.kind == _Kind.character &&
      location?.card.controller == link.activatingPlayer &&
      location!.card.hasFamily('village');
}

List<String> _ids(ChainLink link, String key) {
  final value = link.payload[key];
  return value is List ? value.whereType<String>().toList() : const [];
}

DuelState _modify(DuelState state, String id, RuntimeStatModifier modifier) =>
    _update(
        state,
        id,
        (card) => card.copyWith(
              runtimeModifiers: [...card.runtimeModifiers, modifier],
            ));

DuelState _gainLife(DuelState state, DuelParticipant participant, int amount) =>
    participant == DuelParticipant.player
        ? state.copyWith(playerLifePoints: state.playerLifePoints + amount)
        : state.copyWith(aiLifePoints: state.aiLifePoints + amount);

DuelState _drawDiscard(
    DuelState state, DuelParticipant participant, String id) {
  final field = _field(state, participant);
  final deck = [...field.deck];
  final hand = [...field.hand, _asHand(deck.removeAt(0))];
  final index = hand.indexWhere((card) => card.instanceId == id);
  final discarded = _asGrave(hand.removeAt(index));
  return _replaceField(
      state,
      participant,
      field.copyWith(
        deck: deck,
        hand: hand,
        graveyard: [...field.graveyard, discarded],
      ));
}

DuelState _graveToDeckBottom(
    DuelState state, DuelParticipant participant, String id) {
  final field = _field(state, participant);
  final grave = [...field.graveyard];
  final index = grave.indexWhere((card) => card.instanceId == id);
  final card = _asDeck(grave.removeAt(index));
  return _replaceField(state, participant,
      field.copyWith(graveyard: grave, deck: [...field.deck, card]));
}

DuelState _equipExisting(DuelState state, String equipmentId, String targetId,
    {int atkDelta = 0, int defDelta = 0}) {
  var next = _update(
      state,
      targetId,
      (card) => card.copyWith(
            attachedCardInstanceIds:
                {...card.attachedCardInstanceIds, equipmentId}.toList(),
            runtimeModifiers: atkDelta == 0 && defDelta == 0
                ? card.runtimeModifiers
                : [
                    ...card.runtimeModifiers,
                    RuntimeStatModifier(
                      modifierId: 'equipment:$equipmentId',
                      atkDelta: atkDelta,
                      defDelta: defDelta,
                      sourceCardInstanceId: equipmentId,
                    )
                  ],
          ));
  return _update(
      next,
      equipmentId,
      (card) => card.copyWith(
            faceUp: true,
            runtimeData: {
              ...card.runtimeData,
              CardRuntimeKeys.equippedToInstanceId: targetId,
            },
          ));
}

DuelState _equipFromGrave(DuelState state, DuelParticipant participant,
    String equipmentId, String targetId,
    {bool banishWhenLeaves = false}) {
  final field = _field(state, participant);
  final grave = [...field.graveyard];
  final index = grave.indexWhere((card) => card.instanceId == equipmentId);
  final equipment = grave.removeAt(index).copyWith(
    faceUp: true,
    runtimeData: {
      if (banishWhenLeaves) 'banish_when_leaves_field': true,
      CardRuntimeKeys.equippedToInstanceId: targetId,
    },
  );
  final zones = [...field.actionTrapZones];
  final free = zones.indexWhere((card) => card == null);
  if (free < 0) return state;
  zones[free] = equipment;
  var next = _replaceField(state, participant,
      field.copyWith(actionTrapZones: zones, graveyard: grave));
  return _equipExisting(next, equipmentId, targetId);
}

DuelState _sendFieldCardToGrave(DuelState state, String id) {
  final location = _locate(state, id);
  if (location == null) return state;
  final field = _field(state, location.participant);
  PlayerFieldState cleared;
  if (location.kind == _Kind.character) {
    final zones = [...field.characterZones]..[location.index!] = null;
    cleared = field.copyWith(characterZones: zones);
  } else if (location.kind == _Kind.action) {
    final zones = [...field.actionTrapZones]..[location.index!] = null;
    cleared = field.copyWith(actionTrapZones: zones);
  } else {
    cleared = field.copyWith(terrainZone: null);
  }
  var next = _replaceField(state, location.participant, cleared);
  for (final participant in DuelParticipant.values) {
    final owned = _field(next, participant);
    final characters = owned.characterZones.map((entry) {
      if (entry is! CardInstance ||
          !entry.attachedCardInstanceIds.contains(id)) {
        return entry;
      }
      return entry.copyWith(
        attachedCardInstanceIds:
            entry.attachedCardInstanceIds.where((item) => item != id).toList(),
        runtimeModifiers: entry.runtimeModifiers
            .where((modifier) => modifier.sourceCardInstanceId != id)
            .toList(),
      );
    }).toList();
    next = _replaceField(
        next, participant, owned.copyWith(characterZones: characters));
  }
  final owner = _field(next, location.card.owner);
  if (location.card.runtimeData['banish_when_leaves_field'] == true) {
    return _replaceField(next, location.card.owner,
        owner.copyWith(banished: [...owner.banished, _asGrave(location.card)]));
  }
  return _replaceField(next, location.card.owner,
      owner.copyWith(graveyard: [...owner.graveyard, _asGrave(location.card)]));
}

DuelState _reviveFromGrave(
    DuelState state, DuelParticipant participant, String id,
    {bool negateEffects = false}) {
  final field = _field(state, participant);
  final grave = [...field.graveyard];
  final index = grave.indexWhere((card) => card.instanceId == id);
  final zones = [...field.characterZones];
  final free = zones.indexWhere((card) => card == null);
  final card = grave.removeAt(index).copyWith(
        controller: participant,
        faceUp: true,
        position: BattlePosition.defense,
        zoneIndex: free,
        summonedTurn: state.turnNumber,
        runtimeData: negateEffects
            ? {CardRuntimeKeys.effectsNegatedUntilTurn: state.turnNumber}
            : const {},
      );
  zones[free] = card;
  return _replaceField(state, participant,
      field.copyWith(characterZones: zones, graveyard: grave));
}

DuelState _refreshVillageAura(DuelState state, String sourceId) {
  var next = state;
  for (final participant in DuelParticipant.values) {
    for (final card
        in _field(next, participant).characterZones.whereType<CardInstance>()) {
      final modifiers = card.runtimeModifiers
          .where((modifier) => modifier.sourceCardInstanceId != sourceId)
          .toList();
      if (card.hasFamily('village')) {
        modifiers.add(RuntimeStatModifier(
          modifierId: '${VillageEffectKeys.vil013}:$sourceId',
          defDelta: 200,
          sourceCardInstanceId: sourceId,
        ));
      }
      next = _update(next, card.instanceId,
          (current) => current.copyWith(runtimeModifiers: modifiers));
    }
  }
  return next;
}

DuelState _refreshHammerBonus(
    DuelState state, String hammerId, DuelParticipant participant) {
  final field = _field(state, participant);
  final count = field.actionTrapZones
      .whereType<CardInstance>()
      .where((card) => card.instanceId != hammerId && _isEquipment(card))
      .length;
  final bonus = (count * 300).clamp(0, 900);
  final equippedId = _source(
          state,
          ChainLink(
              linkId: '',
              effectKey: '',
              activatingPlayer: participant,
              speed: ChainSpeed.speed1,
              sourceCardInstanceId: hammerId))
      ?.runtimeData[CardRuntimeKeys.equippedToInstanceId] as String?;
  if (equippedId == null) return state;
  return _update(state, equippedId, (card) {
    final modifiers = card.runtimeModifiers
        .where((modifier) =>
            modifier.modifierId != '${VillageEffectKeys.vil014}:$hammerId')
        .toList()
      ..add(RuntimeStatModifier(
        modifierId: '${VillageEffectKeys.vil014}:$hammerId',
        atkDelta: bonus,
        defDelta: bonus,
        sourceCardInstanceId: hammerId,
      ));
    return card.copyWith(runtimeModifiers: modifiers);
  });
}

ChainLink? _targetLink(DuelState state, ChainLink link) {
  final id = link.payload['target_link_id'] as String?;
  if (id == null) return null;
  for (final candidate in state.chain.links) {
    if (candidate.linkId == id) return candidate;
  }
  return null;
}

DuelState _negateAndDestroy(DuelState state, ChainLink target) {
  var next = state.copyWith(
      chain: state.chain.copyWith(
    negatedLinkIds: {...state.chain.negatedLinkIds, target.linkId},
  ));
  if (target.sourceCardInstanceId != null) {
    next = resolveCardDestructionByEffect(
            state: next, cardInstanceId: target.sourceCardInstanceId!)
        .state;
  }
  return next;
}

CardInstance _asDeck(CardInstance card) => card.copyWith(
      controller: card.owner,
      faceUp: false,
      position: null,
      zoneIndex: null,
      counters: const {},
      attachedCardInstanceIds: const [],
      runtimeModifiers: const [],
      runtimeData: const {},
    );
CardInstance _asHand(CardInstance card) => _asDeck(card);
CardInstance _asGrave(CardInstance card) => card.copyWith(
      controller: card.owner,
      faceUp: true,
      position: null,
      zoneIndex: null,
      counters: const {},
      attachedCardInstanceIds: const [],
      runtimeModifiers: const [],
      runtimeData: const {},
    );
