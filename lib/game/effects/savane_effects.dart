import 'manual_activation_options.dart';
import '../battle_state.dart';
import '../card.dart';
import '../duel_engine.dart';
import '../duel_types.dart';
import '../mythic_summon.dart';
import '../player.dart';

abstract final class SavaneEffectKeys {
  static const sav001 = 'sav_001_suricate_de_l_aube';
  static const sav002 = 'sav_002_gazelle_aux_sabots_de_vent';
  static const sav004 = 'sav_004_hyene_au_rire_de_feu';
  static const sav005 = 'sav_005_eclaireuse_des_termitieres';
  static const sav006 = 'sav_006_elephant_au_front_d_orage';
  static const sav007 = 'sav_007_lionne_commandante';
  static const sav008 = 'sav_008_ruee_de_la_meute';
  static const sav009 = 'sav_009_bond_au_dernier_instant';
  static const sav010 = 'sav_010_rugissement_du_soleil_premier';
  static const sav011 = 'sav_011_poussiere_aveuglante';
  static const sav012 = 'sav_012_cercle_des_defenses';
  static const sav013 = 'sav_013_plaine_du_soleil_rouge';
  static const sav014 = 'sav_014_lance_de_la_premiere_chasse';
  static const sav015 = 'sav_015_lion_soleil_des_plaines_infinies';
}

abstract interface class SavaneFusionSummonExtension {
  DuelState summonFromMythicReserve({
    required DuelState state,
    required DuelParticipant participant,
    required String triggerCardCode,
    required String mythicCardCode,
  });
}

final class DefaultSavaneFusionSummonExtension
    implements SavaneFusionSummonExtension {
  const DefaultSavaneFusionSummonExtension();
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

final class _Effect extends ChainEffectDefinition {
  const _Effect(
      {this.onManualActivations,
      this.can,
      this.cost,
      this.legal,
      required this.resolveEffect});
  final _Predicate? can;
  final _Reducer? cost;
  final _Predicate? legal;
  final _Reducer resolveEffect;
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
  DuelState resolve(DuelState state, ChainLink link) =>
      resolveEffect(state, link);
}

final class SavaneEffectRegistry {
  const SavaneEffectRegistry._();

  static Map<String, ChainEffectDefinition> create({
    SavaneFusionSummonExtension fusionSummonExtension =
        const DefaultSavaneFusionSummonExtension(),
  }) =>
      {
        SavaneEffectKeys.sav001: _sav001(),
        SavaneEffectKeys.sav002:
            _passive('SAV-002', 'combat_calculation_refresh'),
        SavaneEffectKeys.sav004:
            _extraAttack('SAV-004', SavaneEffectKeys.sav004),
        SavaneEffectKeys.sav005: _sav005(),
        SavaneEffectKeys.sav006:
            _passive('SAV-006', 'combat_calculation_refresh'),
        SavaneEffectKeys.sav007: _sav007(),
        SavaneEffectKeys.sav008: _sav008(),
        SavaneEffectKeys.sav009: _sav009(),
        SavaneEffectKeys.sav010: _sav010(fusionSummonExtension),
        SavaneEffectKeys.sav011: _sav011(),
        SavaneEffectKeys.sav012: _sav012(),
        SavaneEffectKeys.sav013: _sav013(),
        SavaneEffectKeys.sav014: _sav014(),
        SavaneEffectKeys.sav015:
            _extraAttack('SAV-015', SavaneEffectKeys.sav015),
      };

  static ChainEffectDefinition _sav001() => _Effect(
        can: (state, link) {
          if (!_sourceIs(state, link, 'SAV-001') ||
              link.payload['trigger'] != 'on_summon') {
            return false;
          }
          final field = _field(state, link.activatingPlayer);
          if (field.deck.isEmpty) {
            return true;
          }
          final top = field.deck.first;
          final take = link.payload['take_top'] == true;
          final bottomId = link.payload['bottom_instance_id'] as String?;
          if (!take) return bottomId == null;
          return top.category == CardCategory.character &&
              top.hasFamily('savane') &&
              bottomId != null &&
              (bottomId == top.instanceId ||
                  field.hand.any((card) => card.instanceId == bottomId));
        },
        resolveEffect: (state, link) {
          if (link.payload['take_top'] != true) return state;
          final participant = link.activatingPlayer;
          final field = _field(state, participant);
          final deck = List<CardInstance>.from(field.deck);
          final hand = [...field.hand, _asHand(deck.removeAt(0))];
          final bottomId = link.payload['bottom_instance_id']! as String;
          final index = hand.indexWhere((card) => card.instanceId == bottomId);
          final bottom = _asDeck(hand.removeAt(index));
          return _replaceField(state, participant,
              field.copyWith(deck: [...deck, bottom], hand: hand));
        },
      );

  static ChainEffectDefinition _passive(String code, String trigger) => _Effect(
        can: (state, link) =>
            _sourceIs(state, link, code) && link.payload['trigger'] == trigger,
        resolveEffect: (state, link) => state,
      );

  static ChainEffectDefinition _extraAttack(String code, String key) {
    final usageKey = '$key:extra_attack';
    return _Effect(
      can: (state, link) {
        final source = _source(state, link);
        final expected = code == 'SAV-004'
            ? 'other_savane_destroyed_in_combat'
            : 'self_destroyed_character_in_combat';
        return source?.cardCode == code &&
            link.payload['trigger'] == expected &&
            !_used(source!, usageKey, state.turnNumber) &&
            source.attackedThisTurn;
      },
      cost: (state, link) => _update(state, link.sourceCardInstanceId!,
          (card) => _mark(card, usageKey, state.turnNumber)),
      resolveEffect: (state, link) => _update(
          state,
          link.sourceCardInstanceId!,
          (card) => card.copyWith(
                attackedThisTurn: false,
                runtimeData: {
                  ...card.runtimeData,
                  CardRuntimeKeys.directAttackForbiddenTurn: state.turnNumber,
                },
              )),
    );
  }

  static ChainEffectDefinition _sav005() => _Effect(
        can: (state, link) =>
            _sourceIs(state, link, 'SAV-005') &&
            link.payload['trigger'] == 'on_summon',
        legal: (state, link) =>
            _visibleOpponent(state, link, link.target?.cardInstanceId),
        resolveEffect: (state, link) {
          final own = _field(state, link.activatingPlayer)
              .characterZones
              .whereType<CardInstance>();
          final count = own
              .where((card) =>
                  card.instanceId != link.sourceCardInstanceId &&
                  card.hasFamily('savane'))
              .length;
          return _modifier(
              state,
              link.target!.cardInstanceId,
              RuntimeStatModifier(
                modifierId: '${SavaneEffectKeys.sav005}:${link.linkId}',
                atkDelta: -300 * count,
                sourceCardInstanceId: link.sourceCardInstanceId,
                expiresAtTurn: state.turnNumber,
              ));
        },
      );

  static ChainEffectDefinition _sav007() {
    const usage = '${SavaneEffectKeys.sav007}:after_attack';
    return _Effect(
      can: (state, link) {
        final source = _source(state, link);
        if (source?.cardCode != 'SAV-007') return false;
        if (link.payload['mode'] == 'continuous_refresh') return true;
        final target = _locate(state, link.target?.cardInstanceId);
        return link.payload['mode'] == 'other_savane_attacked' &&
            !_used(source!, usage, state.turnNumber) &&
            target != null &&
            target.card.controller == link.activatingPlayer &&
            target.card.instanceId != source.instanceId &&
            target.card.hasFamily('savane');
      },
      legal: (state, link) =>
          link.payload['mode'] == 'continuous_refresh' ||
          _locate(state, link.target?.cardInstanceId) != null,
      cost: (state, link) => link.payload['mode'] == 'continuous_refresh'
          ? state
          : _update(state, link.sourceCardInstanceId!,
              (card) => _mark(card, usage, state.turnNumber)),
      resolveEffect: (state, link) =>
          link.payload['mode'] == 'continuous_refresh'
              ? state
              : _update(
                  state,
                  link.target!.cardInstanceId,
                  (card) => card.copyWith(
                      position: BattlePosition.defense,
                      positionChangedThisTurn: true)),
    );
  }

  static ChainEffectDefinition _sav008() => _Effect(
        can: (state, link) {
          if (!_sourceIs(state, link, 'SAV-008')) return false;
          if (link.payload['mode'] == 'after_attack') {
            final target = _locate(state, link.target?.cardInstanceId);
            return target
                    ?.card.runtimeData['sav008_defend_after_attack_turn'] ==
                state.turnNumber;
          }
          return link.payload['mode'] == 'activate' &&
              _ids(link, 'target_instance_ids').length <= 3;
        },
        legal: (state, link) {
          if (link.payload['mode'] == 'after_attack') {
            return _locate(state, link.target?.cardInstanceId) != null;
          }
          return _ids(link, 'target_instance_ids').every((id) {
            final target = _locate(state, id);
            return target != null &&
                target.card.controller == link.activatingPlayer &&
                target.card.hasFamily('savane');
          });
        },
        resolveEffect: (state, link) {
          if (link.payload['mode'] == 'after_attack') {
            return _update(state, link.target!.cardInstanceId, (card) {
              final runtimeData = Map<String, Object?>.from(card.runtimeData)
                ..remove('sav008_defend_after_attack_turn');
              return card.copyWith(
                position: BattlePosition.defense,
                positionChangedThisTurn: true,
                runtimeData: runtimeData,
              );
            });
          }
          var next = state;
          for (final id in _ids(link, 'target_instance_ids')) {
            next = _modifier(
                next,
                id,
                RuntimeStatModifier(
                  modifierId: '${SavaneEffectKeys.sav008}:${link.linkId}:$id',
                  atkDelta: 300,
                  sourceCardInstanceId: link.sourceCardInstanceId,
                  expiresAtTurn: state.turnNumber,
                ));
            next = _update(
                next,
                id,
                (card) => card.copyWith(runtimeData: {
                      ...card.runtimeData,
                      'sav008_defend_after_attack_turn': state.turnNumber
                    }));
          }
          return next;
        },
      );

  static ChainEffectDefinition _sav009() => _Effect(
        onManualActivations: (request) sync* {
          final ownCharacters = request.ownCharacters;
          final option = request.option;
          for (final target
              in ownCharacters.where((c) => c.hasFamily('savane'))) {
            yield option(
                target: ChainTarget(cardInstanceId: target.instanceId),
                description: 'Donner 700 ATK à ${target.cardCode}',
                suffix: target.instanceId);
          }
        },
        can: (state, link) =>
            _sourceIs(state, link, 'SAV-009') &&
            state.currentPhase == DuelPhase.battle,
        legal: (state, link) =>
            _locate(state, link.target?.cardInstanceId)
                ?.card
                .hasFamily('savane') ==
            true,
        resolveEffect: (state, link) => _update(
            state,
            link.target!.cardInstanceId,
            (card) => card.copyWith(runtimeData: {
                  ...card.runtimeData,
                  CardRuntimeKeys.combatOnlyAtkDelta:
                      (card.runtimeData[CardRuntimeKeys.combatOnlyAtkDelta]
                                  as int? ??
                              0) +
                          700,
                })),
      );

  static ChainEffectDefinition _sav010(SavaneFusionSummonExtension extension) =>
      _Effect(
        can: (state, link) =>
            _sourceIs(state, link, 'SAV-010') &&
            _validMaterials(state, link, const ['SAV-006', 'SAV-007']),
        cost: (state, link) {
          var next = state;
          for (final id in _ids(link, 'material_instance_ids')) {
            next = _sendCharacterToGrave(next, id);
          }
          return next;
        },
        resolveEffect: (state, link) => extension.summonFromMythicReserve(
          state: state,
          participant: link.activatingPlayer,
          triggerCardCode: 'SAV-010',
          mythicCardCode: 'SAV-015',
        ),
      );

  static ChainEffectDefinition _sav011() => _Effect(
        onManualActivations: (request) sync* {
          final attack = request.attack;
          final option = request.option;
          if (attack != null) {
            yield option(
                target: ChainTarget(cardInstanceId: attack.attackerInstanceId),
                payload: {'mode': 'attack_declared'},
                description: 'Aveugler l’attaquant',
                suffix: attack.declarationId);
          }
        },
        can: (state, link) =>
            _sourceIs(state, link, 'SAV-011') &&
            (link.payload['mode'] == 'attack_declared' ||
                link.payload['mode'] == 'after_combat'),
        legal: (state, link) =>
            _visibleOpponent(state, link, link.target?.cardInstanceId),
        resolveEffect: (state, link) =>
            _update(state, link.target!.cardInstanceId, (card) {
          if (link.payload['mode'] == 'after_combat') {
            return card.copyWith(
                position: BattlePosition.defense,
                positionChangedThisTurn: true);
          }
          return card.copyWith(runtimeData: {
            ...card.runtimeData,
            CardRuntimeKeys.combatOnlyAtkDelta:
                (card.runtimeData[CardRuntimeKeys.combatOnlyAtkDelta] as int? ??
                        0) -
                    1000,
          });
        }),
      );

  static ChainEffectDefinition _sav012() {
    const usage = '${SavaneEffectKeys.sav012}:redirect';
    return _Effect(
      onManualActivations: (request) sync* {
        final ownCharacters = request.ownCharacters;
        final attack = request.attack;
        final option = request.option;
        if (attack != null) {
          for (final target in ownCharacters.where((c) =>
              c.hasFamily('savane') &&
              c.instanceId != attack.targetInstanceId)) {
            yield option(
                target: ChainTarget(cardInstanceId: target.instanceId),
                payload: {'attack_declaration_id': attack.declarationId},
                description: 'Rediriger vers ${target.cardCode}',
                suffix: target.instanceId);
          }
        }
      },
      can: (state, link) {
        final source = _source(state, link);
        return source?.cardCode == 'SAV-012' &&
            link.payload['attack_declaration_id'] is String &&
            !_used(source!, usage, state.turnNumber);
      },
      legal: (state, link) {
        final target = _locate(state, link.target?.cardInstanceId);
        return target != null &&
            target.card.controller == link.activatingPlayer &&
            target.card.hasFamily('savane');
      },
      cost: (state, link) => _update(state, link.sourceCardInstanceId!,
          (card) => _mark(card, usage, state.turnNumber)),
      resolveEffect: (state, link) => state.copyWith(attackTargetOverrides: {
        ...state.attackTargetOverrides,
        link.payload['attack_declaration_id']! as String:
            link.target!.cardInstanceId,
      }),
    );
  }

  static ChainEffectDefinition _sav013() => _Effect(
        can: (state, link) =>
            _sourceIs(state, link, 'SAV-013') &&
            (link.payload['mode'] == 'continuous_refresh' ||
                link.payload['mode'] == 'savane_destroyed_in_combat'),
        resolveEffect: (state, link) {
          var next = _refreshPlainDef(state, link.sourceCardInstanceId!);
          return link.payload['mode'] == 'savane_destroyed_in_combat'
              ? _gainLife(
                  next,
                  _participant(link.payload['destroyer_controller']) ??
                      link.activatingPlayer,
                  200)
              : next;
        },
      );

  static ChainEffectDefinition _sav014() => _Effect(
        can: (state, link) =>
            _sourceIs(state, link, 'SAV-014') &&
            (link.payload['mode'] == 'equip' ||
                link.payload['mode'] == 'destroyed_higher_rank'),
        legal: (state, link) {
          if (link.payload['mode'] != 'equip') return link.target == null;
          final target = _locate(state, link.target?.cardInstanceId);
          return target != null &&
              target.card.controller == link.activatingPlayer &&
              target.card.hasFamily('savane');
        },
        resolveEffect: (state, link) {
          if (link.payload['mode'] == 'destroyed_higher_rank') {
            return _draw(state, link.activatingPlayer);
          }
          final targetId = link.target!.cardInstanceId;
          var next = _update(
              state,
              targetId,
              (card) => card.copyWith(
                    attachedCardInstanceIds: [
                      ...card.attachedCardInstanceIds,
                      link.sourceCardInstanceId!
                    ],
                    runtimeData: {
                      ...card.runtimeData,
                      CardRuntimeKeys.savaneSpearEquipped: true
                    },
                  ));
          return _update(
              next,
              link.sourceCardInstanceId!,
              (card) => card.copyWith(
                    faceUp: true,
                    runtimeData: {
                      ...card.runtimeData,
                      CardRuntimeKeys.equippedToInstanceId: targetId
                    },
                  ));
        },
      );
}

enum _Kind { character, actionTrap, terrain }

final class _Location {
  const _Location(this.participant, this.kind, this.index, this.card);
  final DuelParticipant participant;
  final _Kind kind;
  final int? index;
  final CardInstance card;
}

PlayerFieldState _field(DuelState state, DuelParticipant p) =>
    p == DuelParticipant.player ? state.playerField : state.aiField;
DuelState _replaceField(
        DuelState state, DuelParticipant p, PlayerFieldState field) =>
    p == DuelParticipant.player
        ? state.copyWith(playerField: field)
        : state.copyWith(aiField: field);

_Location? _locate(DuelState state, String? id) {
  if (id == null) return null;
  for (final p in DuelParticipant.values) {
    final field = _field(state, p);
    for (var i = 0; i < field.characterZones.length; i++) {
      final card = field.characterZones[i];
      if (card is CardInstance && card.instanceId == id) {
        return _Location(p, _Kind.character, i, card);
      }
    }
    for (var i = 0; i < field.actionTrapZones.length; i++) {
      final card = field.actionTrapZones[i];
      if (card?.instanceId == id) {
        return _Location(p, _Kind.actionTrap, i, card!);
      }
    }
    if (field.terrainZone?.instanceId == id) {
      return _Location(p, _Kind.terrain, null, field.terrainZone!);
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

bool _visibleOpponent(DuelState state, ChainLink link, String? id) {
  final target = _locate(state, id);
  return target != null &&
      target.kind == _Kind.character &&
      target.card.faceUp &&
      target.card.controller != link.activatingPlayer;
}

bool _used(CardInstance card, String key, int turn) =>
    card.effectUsageTurns[key] == turn;
CardInstance _mark(CardInstance card, String key, int turn) =>
    card.copyWith(effectUsageTurns: {...card.effectUsageTurns, key: turn});
List<String> _ids(ChainLink link, String key) => link.payload[key] is List
    ? (link.payload[key] as List).whereType<String>().toList()
    : const [];
DuelState _modifier(DuelState state, String id, RuntimeStatModifier modifier) =>
    _update(
        state,
        id,
        (card) => card
            .copyWith(runtimeModifiers: [...card.runtimeModifiers, modifier]));

bool _validMaterials(DuelState state, ChainLink link, List<String> codes) {
  final ids = _ids(link, 'material_instance_ids');
  if (ids.length != codes.length || ids.toSet().length != ids.length) {
    return false;
  }
  final actual = ids.map((id) => _locate(state, id)).toList();
  return actual.every((item) =>
          item != null &&
          item.kind == _Kind.character &&
          item.card.controller == link.activatingPlayer) &&
      codes.every((code) => actual.any((item) => item!.card.cardCode == code));
}

DuelState _sendCharacterToGrave(DuelState state, String id) {
  final location = _locate(state, id)!;
  final field = _field(state, location.participant);
  final zones = List<FieldCardInstance?>.from(field.characterZones)
    ..[location.index!] = null;
  var next = _replaceField(
      state, location.participant, field.copyWith(characterZones: zones));
  final ownerField = _field(next, location.card.owner);
  return _replaceField(
      next,
      location.card.owner,
      ownerField.copyWith(
          graveyard: [...ownerField.graveyard, _asGrave(location.card)]));
}

DuelState _refreshPlainDef(DuelState state, String sourceId) {
  final source = _locate(state, sourceId);
  if (source == null || !source.card.faceUp) return state;
  var next = state;
  for (final p in DuelParticipant.values) {
    for (final card
        in _field(next, p).characterZones.whereType<CardInstance>()) {
      final modifiers = card.runtimeModifiers
          .where((m) => m.sourceCardInstanceId != sourceId)
          .toList();
      if (card.hasFamily('savane')) {
        modifiers.add(RuntimeStatModifier(
            modifierId: '${SavaneEffectKeys.sav013}:$sourceId',
            defDelta: -100,
            sourceCardInstanceId: sourceId));
      }
      next = _update(next, card.instanceId,
          (current) => current.copyWith(runtimeModifiers: modifiers));
    }
  }
  return next;
}

DuelState _draw(DuelState state, DuelParticipant p) {
  final field = _field(state, p);
  if (field.deck.isEmpty) {
    return state.copyWith(
        winner: p == DuelParticipant.player
            ? DuelParticipant.ai
            : DuelParticipant.player,
        endReason: DuelEndReason.deckOut);
  }
  final deck = List<CardInstance>.from(field.deck);
  final card = _asHand(deck.removeAt(0));
  return _replaceField(
      state, p, field.copyWith(deck: deck, hand: [...field.hand, card]));
}

DuelState _gainLife(DuelState state, DuelParticipant p, int amount) =>
    p == DuelParticipant.player
        ? state.copyWith(playerLifePoints: state.playerLifePoints + amount)
        : state.copyWith(aiLifePoints: state.aiLifePoints + amount);
DuelParticipant? _participant(Object? value) => value == 'player'
    ? DuelParticipant.player
    : value == 'ai'
        ? DuelParticipant.ai
        : null;
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
