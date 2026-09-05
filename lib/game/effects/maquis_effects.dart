import '../battle_state.dart';
import '../card.dart';
import '../duel_engine.dart';
import '../duel_types.dart';
import '../mythic_summon.dart';
import '../player.dart';

abstract final class MaquisEffectKeys {
  static const maq001 = 'maq_001_serveur_aux_sandales_rapides';
  static const maq002 = 'maq_002_vendeuse_d_alloco_solaire';
  static const maq004 = 'maq_004_dj_du_car_rapide';
  static const maq005 = 'maq_005_cuisiniere_de_minuit';
  static const maq006 = 'maq_006_patron_du_coin_lumineux';
  static const maq007 = 'maq_007_legende_du_quartier_sans_sommeil';
  static const maq008 = 'maq_008_tournee_generale';
  static const maq009 = 'maq_009_commande_express';
  static const maq010 = 'maq_010_banquet_des_etoiles_urbaines';
  static const maq011 = 'maq_011_plateau_tres_glissant';
  static const maq012 = 'maq_012_addition_contestee';
  static const maq013 = 'maq_013_maquis_des_mille_saveurs';
  static const maq014 = 'maq_014_marmite_qui_ne_se_vide_jamais';
  static const maq015 = 'maq_015_grand_maquisard_cosmique';
}

abstract interface class MaquisAncestralSummonExtension {
  DuelState summonFromMythicReserve({
    required DuelState state,
    required DuelParticipant participant,
    required String triggerCardCode,
    required String mythicCardCode,
  });
}

final class DefaultMaquisAncestralSummonExtension
    implements MaquisAncestralSummonExtension {
  const DefaultMaquisAncestralSummonExtension();
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
    this.can,
    this.cost,
    this.legal,
    this.events,
    required this.resolveEffect,
  });
  final _Predicate? can;
  final _Reducer? cost;
  final _Predicate? legal;
  final _PendingEvents? events;
  final _Reducer resolveEffect;
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
  DuelState resolve(DuelState state, ChainLink link) =>
      resolveEffect(state, link);
}

final class MaquisEffectRegistry {
  const MaquisEffectRegistry._();

  static Map<String, ChainEffectDefinition> create({
    MaquisAncestralSummonExtension ancestralSummonExtension =
        const DefaultMaquisAncestralSummonExtension(),
  }) =>
      {
        MaquisEffectKeys.maq001: _maq001(),
        MaquisEffectKeys.maq002: _maq002(),
        MaquisEffectKeys.maq004: _maq004(),
        MaquisEffectKeys.maq005: _maq005(),
        MaquisEffectKeys.maq006: _maq006(),
        MaquisEffectKeys.maq007: _maq007(),
        MaquisEffectKeys.maq008: _maq008(),
        MaquisEffectKeys.maq009: _maq009(),
        MaquisEffectKeys.maq010: _maq010(ancestralSummonExtension),
        MaquisEffectKeys.maq011: _maq011(),
        MaquisEffectKeys.maq012: _maq012(),
        MaquisEffectKeys.maq013: _maq013(),
        MaquisEffectKeys.maq014: _maq014(),
        MaquisEffectKeys.maq015: _maq015(),
      };

  static ChainEffectDefinition _maq001() => _Effect(
        can: (state, link) =>
            _sourceIs(state, link, 'MAQ-001') &&
            link.payload['trigger'] == 'on_summon',
        legal: (state, link) {
          final target = _locate(state, link.target?.cardInstanceId);
          return target != null &&
              target.card.controller == link.activatingPlayer &&
              target.card.instanceId != link.sourceCardInstanceId &&
              target.card.hasFamily('maquis');
        },
        resolveEffect: (state, link) => _gainLife(
          _returnToOwnerHand(state, link.target!.cardInstanceId),
          link.activatingPlayer,
          300,
        ),
      );

  static ChainEffectDefinition _maq002() {
    const usage = '${MaquisEffectKeys.maq002}:life_gain';
    return _Effect(
      can: (state, link) {
        final source = _source(state, link);
        return source?.cardCode == 'MAQ-002' &&
            link.payload['trigger'] == 'controller_gained_life' &&
            !_used(source!, usage, state.turnNumber);
      },
      legal: (state, link) {
        final target = _locate(state, link.target?.cardInstanceId);
        return target?.kind == _Kind.character &&
            target!.card.controller == link.activatingPlayer &&
            target.card.hasFamily('maquis');
      },
      cost: (state, link) => _update(state, link.sourceCardInstanceId!,
          (card) => _mark(card, usage, state.turnNumber)),
      resolveEffect: (state, link) => _modifier(
        state,
        link.target!.cardInstanceId,
        RuntimeStatModifier(
          modifierId: '${MaquisEffectKeys.maq002}:${link.linkId}',
          atkDelta: 300,
          sourceCardInstanceId: link.sourceCardInstanceId,
          expiresAtTurn: state.turnNumber,
        ),
      ),
    );
  }

  static ChainEffectDefinition _maq004() {
    const usage = '${MaquisEffectKeys.maq004}:first_action';
    return _Effect(
      can: (state, link) {
        final source = _source(state, link);
        return source?.cardCode == 'MAQ-004' &&
            link.payload['trigger'] == 'maquis_action_activated' &&
            !_used(source!, usage, state.turnNumber);
      },
      cost: (state, link) => _update(state, link.sourceCardInstanceId!,
          (card) => _mark(card, usage, state.turnNumber)),
      resolveEffect: (state, link) => _modifier(
        state,
        link.sourceCardInstanceId!,
        RuntimeStatModifier(
          modifierId: '${MaquisEffectKeys.maq004}:${link.linkId}',
          atkDelta: 400,
          sourceCardInstanceId: link.sourceCardInstanceId,
          expiresAtTurn: state.turnNumber,
        ),
      ),
    );
  }

  static ChainEffectDefinition _maq005() => _Effect(
        can: (state, link) {
          if (!_sourceIs(state, link, 'MAQ-005') ||
              link.payload['trigger'] != 'on_summon') {
            return false;
          }
          final field = _field(state, link.activatingPlayer);
          final top = field.deck.take(3).toList();
          final chosen = link.payload['chosen_action_instance_id'] as String?;
          final bottomOrder = _ids(link, 'bottom_order_instance_ids');
          return chosen != null &&
              top.any((card) =>
                  card.instanceId == chosen &&
                  card.category == CardCategory.action &&
                  card.hasFamily('maquis')) &&
              bottomOrder.length == top.length - 1 &&
              bottomOrder.toSet().length == bottomOrder.length &&
              bottomOrder.every((id) =>
                  top.any((card) => card.instanceId == id) && id != chosen);
        },
        resolveEffect: (state, link) {
          final participant = link.activatingPlayer;
          final field = _field(state, participant);
          final revealed = field.deck.take(3).toList();
          final remainingDeck = field.deck.skip(revealed.length).toList();
          final chosenId = link.payload['chosen_action_instance_id']! as String;
          final chosen =
              revealed.singleWhere((card) => card.instanceId == chosenId);
          final order = _ids(link, 'bottom_order_instance_ids');
          final bottom = order.map(
              (id) => revealed.singleWhere((card) => card.instanceId == id));
          return _replaceField(
            state,
            participant,
            field.copyWith(
              deck: [...remainingDeck, ...bottom.map(_asDeck)],
              hand: [...field.hand, _asHand(chosen)],
            ),
          );
        },
      );

  static ChainEffectDefinition _maq006() {
    const usage = '${MaquisEffectKeys.maq006}:after_action';
    return _Effect(
      can: (state, link) {
        final source = _source(state, link);
        if (source?.cardCode != 'MAQ-006' ||
            link.payload['trigger'] != 'maquis_action_resolved' ||
            _used(source!, usage, state.turnNumber)) {
          return false;
        }
        final before =
            link.payload['life_gained_before_resolution'] as int? ?? 0;
        return before < 400 ||
            _canDrawDiscard(state, link.activatingPlayer, link);
      },
      cost: (state, link) => _update(state, link.sourceCardInstanceId!,
          (card) => _mark(card, usage, state.turnNumber)),
      resolveEffect: (state, link) {
        final before =
            link.payload['life_gained_before_resolution'] as int? ?? 0;
        var next = _gainLife(state, link.activatingPlayer, 400);
        return before + 400 >= 800
            ? _drawDiscard(next, link.activatingPlayer, link)
            : next;
      },
    );
  }

  static ChainEffectDefinition _maq007() {
    const usage = '${MaquisEffectKeys.maq007}:second_attack';
    return _Effect(
      can: (state, link) {
        final source = _source(state, link);
        final discard = _handCard(state, link.activatingPlayer,
            link.payload['discard_instance_id'] as String?);
        return source?.cardCode == 'MAQ-007' &&
            source!.attackedThisTurn &&
            !_used(source, usage, state.turnNumber) &&
            discard?.category == CardCategory.action;
      },
      cost: (state, link) {
        var next = _discardFromHand(state, link.activatingPlayer,
            link.payload['discard_instance_id']! as String);
        return _update(next, link.sourceCardInstanceId!,
            (card) => _mark(card, usage, state.turnNumber));
      },
      resolveEffect: (state, link) => _update(
        state,
        link.sourceCardInstanceId!,
        (card) => card.copyWith(attackedThisTurn: false, runtimeData: {
          ...card.runtimeData,
          CardRuntimeKeys.directAttackForbiddenTurn: state.turnNumber,
          CardRuntimeKeys.combatDamageDivisor: 2,
          CardRuntimeKeys.combatDamageDivisorTurn: state.turnNumber,
        }),
      ),
    );
  }

  static ChainEffectDefinition _maq008() => _Effect(
        can: (state, link) =>
            _sourceIs(state, link, 'MAQ-008') &&
            _canDrawDiscard(state, link.activatingPlayer, link),
        resolveEffect: (state, link) {
          var next = _gainLife(state, DuelParticipant.player, 500);
          next = _gainLife(next, DuelParticipant.ai, 500);
          return _drawDiscard(next, link.activatingPlayer, link);
        },
      );

  static ChainEffectDefinition _maq009() => _Effect(
        can: (state, link) {
          if (!_sourceIs(state, link, 'MAQ-009')) return false;
          final summon = _handCard(state, link.activatingPlayer,
              link.payload['summon_instance_id'] as String?);
          return summon != null &&
              summon.category == CardCategory.character &&
              summon.hasFamily('maquis');
        },
        legal: (state, link) {
          final target = _locate(state, link.target?.cardInstanceId);
          final summon = _handCard(state, link.activatingPlayer,
              link.payload['summon_instance_id'] as String?);
          return target?.kind == _Kind.character &&
              target!.card.controller == link.activatingPlayer &&
              target.card.hasFamily('maquis') &&
              (summon?.rank ?? 99) < (target.card.rank ?? -1);
        },
        resolveEffect: (state, link) {
          var next = _returnToOwnerHand(state, link.target!.cardInstanceId);
          return _specialSummonFromHand(next, link.activatingPlayer,
              link.payload['summon_instance_id']! as String);
        },
      );

  static ChainEffectDefinition _maq010(
          MaquisAncestralSummonExtension extension) =>
      _Effect(
        can: _validAncestralCost,
        cost: (state, link) {
          var next = state;
          for (final id in _ids(link, 'discard_action_instance_ids')) {
            next = _discardFromHand(next, link.activatingPlayer, id);
          }
          for (final id in _ids(link, 'sacrifice_instance_ids')) {
            next = _sendCharacterToGrave(next, id);
          }
          return next;
        },
        resolveEffect: (state, link) => extension.summonFromMythicReserve(
          state: state,
          participant: link.activatingPlayer,
          triggerCardCode: 'MAQ-010',
          mythicCardCode: 'MAQ-015',
        ),
      );

  static ChainEffectDefinition _maq011() => _Effect(
        can: (state, link) =>
            _sourceIs(state, link, 'MAQ-011') &&
            link.payload['trigger'] == 'opponent_attack_declared' &&
            link.payload['attack_declaration_id'] is String,
        legal: (state, link) {
          final target = _locate(state, link.target?.cardInstanceId);
          return target != null &&
              target.card.controller == link.activatingPlayer &&
              target.card.hasFamily('maquis');
        },
        resolveEffect: (state, link) => _returnToOwnerHand(
          state.copyWith(cancelledAttackDeclarationIds: {
            ...state.cancelledAttackDeclarationIds,
            link.payload['attack_declaration_id']! as String,
          }),
          link.target!.cardInstanceId,
        ),
      );

  static ChainEffectDefinition _maq012() => _Effect(
        can: (state, link) {
          if (!_sourceIs(state, link, 'MAQ-012') ||
              link.payload['trigger'] != 'opponent_effect_life_loss') {
            return false;
          }
          final discard = _handCard(state, link.activatingPlayer,
              link.payload['discard_instance_id'] as String?);
          final opposed =
              _chainLink(state, link.payload['target_link_id'] as String?);
          return discard != null &&
              opposed != null &&
              opposed.activatingPlayer != link.activatingPlayer;
        },
        cost: (state, link) => _discardFromHand(
          state,
          link.activatingPlayer,
          link.payload['discard_instance_id']! as String,
        ),
        resolveEffect: (state, link) {
          final targetId = link.payload['target_link_id']! as String;
          return _gainLife(
            state.copyWith(
                chain: state.chain.copyWith(
              negatedLinkIds: {...state.chain.negatedLinkIds, targetId},
            )),
            link.activatingPlayer,
            300,
          );
        },
      );

  static ChainEffectDefinition _maq013() {
    const usage = '${MaquisEffectKeys.maq013}:life_gain';
    return _Effect(
      can: (state, link) {
        final source = _source(state, link);
        if (source?.cardCode != 'MAQ-013') return false;
        if (link.payload['mode'] == 'continuous_refresh') return true;
        return link.payload['mode'] == 'other_card_life_gain' &&
            link.payload['source_card_instance_id'] != source!.instanceId &&
            !_used(source, usage, state.turnNumber);
      },
      cost: (state, link) => link.payload['mode'] == 'continuous_refresh'
          ? state
          : _update(state, link.sourceCardInstanceId!,
              (card) => _mark(card, usage, state.turnNumber)),
      resolveEffect: (state, link) {
        final next = _refreshAura(state, link.sourceCardInstanceId!);
        return link.payload['mode'] == 'continuous_refresh'
            ? next
            : _gainLife(next, link.activatingPlayer, 200);
      },
    );
  }

  static ChainEffectDefinition _maq014() {
    const usage = '${MaquisEffectKeys.maq014}:portion';
    return _Effect(
      can: (state, link) {
        final source = _source(state, link);
        if (source?.cardCode != 'MAQ-014') return false;
        if (link.payload['mode'] == 'activate') return true;
        return link.payload['mode'] == 'consume' &&
            (source!.counters['portion'] ?? 0) > 0 &&
            !_used(source, usage, state.turnNumber);
      },
      cost: (state, link) => link.payload['mode'] == 'activate'
          ? state
          : _update(state, link.sourceCardInstanceId!,
              (card) => _mark(card, usage, state.turnNumber)),
      resolveEffect: (state, link) {
        if (link.payload['mode'] == 'activate') {
          return _update(
              state,
              link.sourceCardInstanceId!,
              (card) => card.copyWith(
                    faceUp: true,
                    counters: {...card.counters, 'portion': 3},
                  ));
        }
        final source = _source(state, link)!;
        final remaining = (source.counters['portion'] ?? 0) - 1;
        var next = _gainLife(state, link.activatingPlayer, 600);
        if (remaining > 0) {
          return _update(
              next,
              source.instanceId,
              (card) => card.copyWith(
                    counters: {...card.counters, 'portion': remaining},
                  ));
        }
        next = _sendFieldCardToGrave(next, source.instanceId);
        return _draw(next, link.activatingPlayer);
      },
    );
  }

  static ChainEffectDefinition _maq015() {
    const usage = '${MaquisEffectKeys.maq015}:second_action';
    return _Effect(
      events: (state, link) =>
          link.payload['mode'] == 'second_action_resolved' &&
                  link.target != null
              ? [
                  EffectDestructionPending(
                    sourceLinkId: link.linkId,
                    cardInstanceId: link.target!.cardInstanceId,
                  ),
                ]
              : const [],
      can: (state, link) {
        final source = _source(state, link);
        if (source?.cardCode != 'MAQ-015') return false;
        if (link.payload['mode'] == 'on_summon') {
          final recoverId =
              link.payload['recover_action_instance_id'] as String?;
          if (recoverId == null) return true;
          final action = _graveCard(state, link.activatingPlayer, recoverId);
          return action?.category == CardCategory.action &&
              action!.hasFamily('maquis');
        }
        return link.payload['mode'] == 'second_action_resolved' &&
            !_used(source!, usage, state.turnNumber);
      },
      legal: (state, link) {
        if (link.payload['mode'] == 'on_summon') return link.target == null;
        final target = _locate(state, link.target?.cardInstanceId);
        return target != null &&
            target.card.controller != link.activatingPlayer &&
            target.card.faceUp;
      },
      cost: (state, link) => link.payload['mode'] == 'on_summon'
          ? state
          : _update(state, link.sourceCardInstanceId!,
              (card) => _mark(card, usage, state.turnNumber)),
      resolveEffect: (state, link) {
        if (link.payload['mode'] == 'on_summon') {
          final gained = _gainLife(state, link.activatingPlayer, 1000);
          final recoverId =
              link.payload['recover_action_instance_id'] as String?;
          return recoverId == null
              ? gained
              : _recoverGraveToHand(
                  gained,
                  link.activatingPlayer,
                  recoverId,
                );
        }
        return resolveCardDestructionByEffect(
          state: state,
          cardInstanceId: link.target!.cardInstanceId,
        ).state;
      },
    );
  }
}

enum _Kind { character, actionTrap, terrain }

final class _Location {
  const _Location(this.participant, this.kind, this.index, this.card);
  final DuelParticipant participant;
  final _Kind kind;
  final int? index;
  final CardInstance card;
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
        return _Location(participant, _Kind.character, i, card);
      }
    }
    for (var i = 0; i < field.actionTrapZones.length; i++) {
      final card = field.actionTrapZones[i];
      if (card?.instanceId == id) {
        return _Location(participant, _Kind.actionTrap, i, card!);
      }
    }
    if (field.terrainZone?.instanceId == id) {
      return _Location(participant, _Kind.terrain, null, field.terrainZone!);
    }
  }
  return null;
}

CardInstance? _source(DuelState state, ChainLink link) =>
    _locate(state, link.sourceCardInstanceId)?.card;
bool _sourceIs(DuelState state, ChainLink link, String code) =>
    link.sourceCardCode == code || _source(state, link)?.cardCode == code;

DuelState _update(
    DuelState state, String id, CardInstance Function(CardInstance) transform) {
  final location = _locate(state, id);
  if (location == null) return state;
  final field = _field(state, location.participant);
  switch (location.kind) {
    case _Kind.character:
      final zones = List<FieldCardInstance?>.from(field.characterZones)
        ..[location.index!] = transform(location.card);
      return _replaceField(
          state, location.participant, field.copyWith(characterZones: zones));
    case _Kind.actionTrap:
      final zones = List<CardInstance?>.from(field.actionTrapZones)
        ..[location.index!] = transform(location.card);
      return _replaceField(
          state, location.participant, field.copyWith(actionTrapZones: zones));
    case _Kind.terrain:
      return _replaceField(state, location.participant,
          field.copyWith(terrainZone: transform(location.card)));
  }
}

bool _used(CardInstance card, String key, int turn) =>
    card.effectUsageTurns[key] == turn;
CardInstance _mark(CardInstance card, String key, int turn) =>
    card.copyWith(effectUsageTurns: {...card.effectUsageTurns, key: turn});
DuelState _modifier(DuelState state, String id, RuntimeStatModifier modifier) =>
    _update(
        state,
        id,
        (card) => card
            .copyWith(runtimeModifiers: [...card.runtimeModifiers, modifier]));

CardInstance? _handCard(
    DuelState state, DuelParticipant participant, String? id) {
  if (id == null) return null;
  return _field(state, participant)
      .hand
      .where((card) => card.instanceId == id)
      .firstOrNull;
}

CardInstance? _graveCard(
    DuelState state, DuelParticipant participant, String? id) {
  if (id == null) return null;
  return _field(state, participant)
      .graveyard
      .where((card) => card.instanceId == id)
      .firstOrNull;
}

DuelState _gainLife(DuelState state, DuelParticipant participant, int amount) =>
    participant == DuelParticipant.player
        ? state.copyWith(playerLifePoints: state.playerLifePoints + amount)
        : state.copyWith(aiLifePoints: state.aiLifePoints + amount);

DuelState _returnToOwnerHand(DuelState state, String id) {
  final location = _locate(state, id);
  if (location == null) return state;
  final field = _field(state, location.participant);
  late PlayerFieldState removed;
  switch (location.kind) {
    case _Kind.character:
      final zones = List<FieldCardInstance?>.from(field.characterZones)
        ..[location.index!] = null;
      removed = field.copyWith(characterZones: zones);
    case _Kind.actionTrap:
      final zones = List<CardInstance?>.from(field.actionTrapZones)
        ..[location.index!] = null;
      removed = field.copyWith(actionTrapZones: zones);
    case _Kind.terrain:
      removed = field.copyWith(terrainZone: null);
  }
  var next = _replaceField(state, location.participant, removed);
  final ownerField = _field(next, location.card.owner);
  return _replaceField(next, location.card.owner,
      ownerField.copyWith(hand: [...ownerField.hand, _asHand(location.card)]));
}

DuelState _discardFromHand(
    DuelState state, DuelParticipant participant, String id) {
  final field = _field(state, participant);
  final index = field.hand.indexWhere((card) => card.instanceId == id);
  if (index < 0) return state;
  final hand = List<CardInstance>.from(field.hand);
  final discarded = _asGrave(hand.removeAt(index));
  return _replaceField(state, participant,
      field.copyWith(hand: hand, graveyard: [...field.graveyard, discarded]));
}

DuelState _sendCharacterToGrave(DuelState state, String id) {
  final location = _locate(state, id);
  if (location == null || location.kind != _Kind.character) return state;
  return _sendFieldCardToGrave(state, id);
}

DuelState _sendFieldCardToGrave(DuelState state, String id) {
  final location = _locate(state, id);
  if (location == null) return state;
  final field = _field(state, location.participant);
  late PlayerFieldState removed;
  switch (location.kind) {
    case _Kind.character:
      final zones = List<FieldCardInstance?>.from(field.characterZones)
        ..[location.index!] = null;
      removed = field.copyWith(characterZones: zones);
    case _Kind.actionTrap:
      final zones = List<CardInstance?>.from(field.actionTrapZones)
        ..[location.index!] = null;
      removed = field.copyWith(actionTrapZones: zones);
    case _Kind.terrain:
      removed = field.copyWith(terrainZone: null);
  }
  var next = _replaceField(state, location.participant, removed);
  final owner = _field(next, location.card.owner);
  return _replaceField(next, location.card.owner,
      owner.copyWith(graveyard: [...owner.graveyard, _asGrave(location.card)]));
}

DuelState _draw(DuelState state, DuelParticipant participant) {
  final field = _field(state, participant);
  if (field.deck.isEmpty) return state;
  return _replaceField(
      state,
      participant,
      field.copyWith(
          deck: field.deck.skip(1).toList(),
          hand: [...field.hand, _asHand(field.deck.first)]));
}

bool _canDrawDiscard(
    DuelState state, DuelParticipant participant, ChainLink link) {
  final field = _field(state, participant);
  final discardId = link.payload['discard_instance_id'] as String?;
  return field.deck.isNotEmpty &&
      discardId != null &&
      (field.hand.any((card) => card.instanceId == discardId) ||
          field.deck.first.instanceId == discardId);
}

DuelState _drawDiscard(
    DuelState state, DuelParticipant participant, ChainLink link) {
  final field = _field(state, participant);
  final deck = List<CardInstance>.from(field.deck);
  final hand = [...field.hand, _asHand(deck.removeAt(0))];
  final id = link.payload['discard_instance_id']! as String;
  final index = hand.indexWhere((card) => card.instanceId == id);
  final discarded = _asGrave(hand.removeAt(index));
  return _replaceField(
      state,
      participant,
      field.copyWith(
          deck: deck, hand: hand, graveyard: [...field.graveyard, discarded]));
}

DuelState _specialSummonFromHand(
    DuelState state, DuelParticipant participant, String id) {
  final field = _field(state, participant);
  final handIndex = field.hand.indexWhere((card) => card.instanceId == id);
  final zoneIndex = field.characterZones.indexWhere((card) => card == null);
  if (handIndex < 0 || zoneIndex < 0) return state;
  final hand = List<CardInstance>.from(field.hand);
  final summoned = hand.removeAt(handIndex).copyWith(
        controller: participant,
        faceUp: true,
        position: BattlePosition.attack,
        zoneIndex: zoneIndex,
        summonedTurn: state.turnNumber,
        attackedThisTurn: false,
      );
  final zones = List<FieldCardInstance?>.from(field.characterZones)
    ..[zoneIndex] = summoned;
  return _replaceField(
      state, participant, field.copyWith(characterZones: zones, hand: hand));
}

DuelState _recoverGraveToHand(
    DuelState state, DuelParticipant participant, String id) {
  final field = _field(state, participant);
  final index = field.graveyard.indexWhere((card) => card.instanceId == id);
  if (index < 0) return state;
  final grave = List<CardInstance>.from(field.graveyard);
  final recovered = _asHand(grave.removeAt(index));
  return _replaceField(state, participant,
      field.copyWith(graveyard: grave, hand: [...field.hand, recovered]));
}

bool _validAncestralCost(DuelState state, ChainLink link) {
  if (!_sourceIs(state, link, 'MAQ-010')) return false;
  final discards = _ids(link, 'discard_action_instance_ids');
  final sacrifices = _ids(link, 'sacrifice_instance_ids');
  if (discards.length != 2 ||
      discards.toSet().length != 2 ||
      sacrifices.isEmpty ||
      sacrifices.toSet().length != sacrifices.length) {
    return false;
  }
  final actions = discards
      .map((id) => _handCard(state, link.activatingPlayer, id))
      .toList();
  if (actions.any((card) =>
          card == null ||
          card.category != CardCategory.action ||
          !card.hasFamily('maquis')) ||
      actions.map((card) => card!.cardCode).toSet().length != 2) {
    return false;
  }
  var ranks = 0;
  for (final id in sacrifices) {
    final location = _locate(state, id);
    if (location?.kind != _Kind.character ||
        location!.card.controller != link.activatingPlayer ||
        !location.card.hasFamily('maquis') ||
        location.card.rank == null) {
      return false;
    }
    ranks += location.card.rank!;
  }
  return ranks >= 8;
}

DuelState _refreshAura(DuelState state, String sourceId) {
  final source = _locate(state, sourceId);
  if (source?.kind != _Kind.terrain || source!.card.faceUp != true) {
    return state;
  }
  var next = state;
  for (final participant in DuelParticipant.values) {
    for (final card
        in _field(next, participant).characterZones.whereType<CardInstance>()) {
      final modifiers = card.runtimeModifiers
          .where((modifier) => modifier.sourceCardInstanceId != sourceId)
          .toList();
      if (card.hasFamily('maquis')) {
        modifiers.add(RuntimeStatModifier(
          modifierId: '${MaquisEffectKeys.maq013}:$sourceId',
          atkDelta: 200,
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

ChainLink? _chainLink(DuelState state, String? id) {
  if (id == null) return null;
  return state.chain.links.where((link) => link.linkId == id).firstOrNull;
}

List<String> _ids(ChainLink link, String key) {
  final value = link.payload[key];
  return value is List ? value.whereType<String>().toList() : const [];
}

CardInstance _asDeck(CardInstance card) => card.copyWith(
    controller: card.owner,
    faceUp: false,
    position: null,
    zoneIndex: null,
    counters: const {},
    attachedCardInstanceIds: const [],
    runtimeModifiers: const [],
    runtimeData: const {});
CardInstance _asHand(CardInstance card) => _asDeck(card);
CardInstance _asGrave(CardInstance card) => card.copyWith(
    controller: card.owner,
    faceUp: true,
    position: null,
    zoneIndex: null,
    counters: const {},
    attachedCardInstanceIds: const [],
    runtimeModifiers: const [],
    runtimeData: const {});
