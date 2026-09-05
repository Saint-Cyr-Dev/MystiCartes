import 'dart:math';

import '../battle_state.dart';
import '../card.dart';
import '../duel_engine.dart';
import '../duel_types.dart';
import '../mythic_summon.dart';
import '../player.dart';

abstract final class AncetreEffectKeys {
  static const anc001 = 'anc_001_porteur_de_cauris';
  static const anc002 = 'anc_002_enfant_des_songes_clairs';
  static const anc004 = 'anc_004_messager_de_la_premiere_pluie';
  static const anc005 = 'anc_005_gardienne_des_noms_oublies';
  static const anc006 = 'anc_006_conseiller_de_l_au_dela';
  static const anc007 = 'anc_007_matriarche_aux_cent_memoires';
  static const anc008 = 'anc_008_parole_transmise';
  static const anc009 = 'anc_009_main_des_aieux';
  static const anc010 = 'anc_010_appel_des_huit_veillees';
  static const anc011 = 'anc_011_conseil_des_invisibles';
  static const anc012 = 'anc_012_refus_de_l_oubli';
  static const anc013 = 'anc_013_bosquet_des_voix_anciennes';
  static const anc014 = 'anc_014_calebasse_des_huit_noms';
  static const anc015 = 'anc_015_mere_des_premieres_lueurs';
}

abstract interface class AncetreAncestralSummonExtension {
  DuelState summonFromMythicReserve({
    required DuelState state,
    required DuelParticipant participant,
    required String triggerCardCode,
    required String mythicCardCode,
  });
}

final class DefaultAncetreAncestralSummonExtension
    implements AncetreAncestralSummonExtension {
  const DefaultAncetreAncestralSummonExtension();

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

abstract interface class AncetreDeckShuffler {
  List<CardInstance> shuffle(List<CardInstance> cards);
}

/// Générateur par défaut, remplaçable par une implémentation déterministe dans
/// les tests ou par un générateur seedé lors de la création d'un duel.
final class RandomAncetreDeckShuffler implements AncetreDeckShuffler {
  RandomAncetreDeckShuffler([Random? random]) : _random = random ?? Random();

  final Random _random;

  @override
  List<CardInstance> shuffle(List<CardInstance> cards) {
    return List<CardInstance>.from(cards)..shuffle(_random);
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

final class _FunctionalAncetreEffect extends ChainEffectDefinition {
  const _FunctionalAncetreEffect({
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

final class AncetreEffectRegistry {
  const AncetreEffectRegistry._();

  static Map<String, ChainEffectDefinition> create({
    AncetreAncestralSummonExtension ancestralSummonExtension =
        const DefaultAncetreAncestralSummonExtension(),
    AncetreDeckShuffler? deckShuffler,
  }) {
    final shuffler = deckShuffler ?? RandomAncetreDeckShuffler();
    return {
      AncetreEffectKeys.anc001: _anc001(),
      AncetreEffectKeys.anc002: _anc002(),
      AncetreEffectKeys.anc004: _anc004(),
      AncetreEffectKeys.anc005: _anc005(shuffler),
      AncetreEffectKeys.anc006: _anc006(),
      AncetreEffectKeys.anc007: _anc007(shuffler),
      AncetreEffectKeys.anc008: _anc008(),
      AncetreEffectKeys.anc009: _anc009(),
      AncetreEffectKeys.anc010: _anc010(ancestralSummonExtension),
      AncetreEffectKeys.anc011: _anc011(),
      AncetreEffectKeys.anc012: _anc012(),
      AncetreEffectKeys.anc013: _anc013(),
      AncetreEffectKeys.anc014: _anc014(),
      AncetreEffectKeys.anc015: _anc015(shuffler),
    };
  }

  static ChainEffectDefinition _anc001() {
    return _FunctionalAncetreEffect(
      onCanActivate: (state, link) =>
          _sourceHasCode(state, link, 'ANC-001') &&
          link.payload['trigger'] == 'sent_from_field_to_graveyard',
      onResolve: (state, link) => _millTopCard(state, link.activatingPlayer),
    );
  }

  static ChainEffectDefinition _anc002() {
    return _FunctionalAncetreEffect(
      onCanActivate: (state, link) =>
          _sourceHasCode(state, link, 'ANC-002') &&
          link.payload['trigger'] == 'on_summon',
      onTargetLegal: (state, link) => _isOwnAncestorInGraveyard(
        state,
        link.activatingPlayer,
        link.target?.cardInstanceId,
      ),
      onResolve: (state, link) => _moveGraveyardCardToDeckBottom(
        state,
        link.activatingPlayer,
        link.target!.cardInstanceId,
      ),
    );
  }

  static ChainEffectDefinition _anc004() {
    return _FunctionalAncetreEffect(
      onCanActivate: (state, link) {
        final selectedId = link.payload['selected_instance_id'] as String?;
        return _sourceHasCode(state, link, 'ANC-004') &&
            link.payload['trigger'] == 'on_summon' &&
            selectedId != null &&
            _fieldFor(state, link.activatingPlayer).deck.any(
                  (card) =>
                      card.instanceId == selectedId &&
                      card.cardCode != 'ANC-004' &&
                      card.hasFamily('ancêtre'),
                );
      },
      onResolve: (state, link) => _moveDeckCardToGraveyard(
        state,
        link.activatingPlayer,
        link.payload['selected_instance_id']! as String,
        (card) => card.cardCode != 'ANC-004' && card.hasFamily('ancêtre'),
      ),
    );
  }

  static ChainEffectDefinition _anc005(AncetreDeckShuffler shuffler) {
    const usageKey = '${AncetreEffectKeys.anc005}:recover';
    return _FunctionalAncetreEffect(
      onCanActivate: (state, link) {
        final source = _sourceCard(state, link);
        return source?.cardCode == 'ANC-005' &&
            !_usedThisTurn(source!, usageKey, state.turnNumber);
      },
      onTargetLegal: (state, link) {
        final target = _graveyardCard(
          state,
          link.activatingPlayer,
          link.target?.cardInstanceId,
        );
        return target != null &&
            target.category == CardCategory.character &&
            (target.rank ?? 99) <= 4;
      },
      onPayCost: (state, link) => _updateFieldCard(
        state,
        link.sourceCardInstanceId!,
        (card) => _markUsed(card, usageKey, state.turnNumber),
      ),
      onResolve: (state, link) {
        var nextState = _moveFieldCardToDeck(
          state,
          link.sourceCardInstanceId!,
          shuffler,
        );
        nextState = _moveGraveyardCardToHand(
          nextState,
          link.activatingPlayer,
          link.target!.cardInstanceId,
        );
        return nextState;
      },
    );
  }

  static ChainEffectDefinition _anc006() {
    return _FunctionalAncetreEffect(
      onCanActivate: (state, link) {
        final selectedId = link.payload['selected_instance_id'] as String?;
        final field = _fieldFor(state, link.activatingPlayer);
        return _sourceHasCode(state, link, 'ANC-006') &&
            link.payload['trigger'] == 'sent_as_sacrifice_or_cost' &&
            selectedId != null &&
            field.characterZones.any((card) => card == null) &&
            field.graveyard.any(
              (card) =>
                  card.instanceId == selectedId &&
                  _isLowRankAncestorCharacter(card, 3),
            );
      },
      onResolve: (state, link) => _specialSummonFromGraveyard(
        state,
        link.activatingPlayer,
        link.payload['selected_instance_id']! as String,
        maximumRank: 3,
      ),
    );
  }

  static ChainEffectDefinition _anc007(AncetreDeckShuffler shuffler) {
    return _FunctionalAncetreEffect(
      onCanActivate: (state, link) {
        if (!_sourceHasCode(state, link, 'ANC-007') ||
            link.payload['trigger'] != 'on_summon') {
          return false;
        }
        final ids = _payloadIds(link, 'target_instance_ids');
        return ids.length <= 3 &&
            ids.toSet().length == ids.length &&
            ids.every(
              (id) => _isOwnAncestorInGraveyard(
                state,
                link.activatingPlayer,
                id,
              ),
            );
      },
      onResolve: (state, link) {
        final moved = _moveGraveyardCardsToDeck(
          state,
          link.activatingPlayer,
          _payloadIds(link, 'target_instance_ids'),
          shuffler,
        );
        var nextState = _drawOne(moved.state, link.activatingPlayer);
        if (!nextState.isFinished && moved.count > 0) {
          nextState = _updateFieldCard(
            nextState,
            link.sourceCardInstanceId!,
            (card) => card.copyWith(
              runtimeModifiers: [
                ...card.runtimeModifiers,
                RuntimeStatModifier(
                  modifierId: '${AncetreEffectKeys.anc007}:${link.linkId}',
                  atkDelta: moved.count * 100,
                  sourceCardInstanceId: card.instanceId,
                ),
              ],
            ),
          );
        }
        return nextState;
      },
    );
  }

  static ChainEffectDefinition _anc008() {
    return _FunctionalAncetreEffect(
      onCanActivate: (state, link) {
        final selectedId = link.payload['selected_instance_id'] as String?;
        final discardId = link.payload['discard_instance_id'] as String?;
        if (!_sourceHasCode(state, link, 'ANC-008') ||
            selectedId == null ||
            discardId == null ||
            !_isOwnAncestorInGraveyard(
              state,
              link.activatingPlayer,
              selectedId,
            )) {
          return false;
        }
        return discardId == selectedId ||
            _fieldFor(state, link.activatingPlayer)
                .hand
                .any((card) => card.instanceId == discardId);
      },
      onResolve: (state, link) {
        final selectedId = link.payload['selected_instance_id']! as String;
        if (!_isOwnAncestorInGraveyard(
          state,
          link.activatingPlayer,
          selectedId,
        )) {
          return state;
        }
        var nextState = _moveGraveyardCardToHand(
          state,
          link.activatingPlayer,
          selectedId,
        );
        nextState = _discardFromHand(
          nextState,
          link.activatingPlayer,
          link.payload['discard_instance_id']! as String,
        );
        return nextState;
      },
    );
  }

  static ChainEffectDefinition _anc009() {
    return _FunctionalAncetreEffect(
      onCanActivate: (state, link) => _sourceHasCode(state, link, 'ANC-009'),
      onTargetLegal: (state, link) {
        final ally = _findFieldCard(state, link.target?.cardInstanceId);
        final enemy = _findFieldCard(
          state,
          link.payload['enemy_instance_id'] as String?,
        );
        return ally != null &&
            ally.kind == _ZoneKind.character &&
            ally.card.controller == link.activatingPlayer &&
            ally.card.hasFamily('ancêtre') &&
            enemy != null &&
            enemy.kind == _ZoneKind.character &&
            enemy.card.controller != link.activatingPlayer;
      },
      onResolve: (state, link) {
        var nextState = _addTemporaryModifier(
          state,
          link.target!.cardInstanceId,
          RuntimeStatModifier(
            modifierId: '${AncetreEffectKeys.anc009}:${link.linkId}:ally',
            atkDelta: 600,
            defDelta: 600,
            sourceCardInstanceId: link.sourceCardInstanceId,
            expiresAtTurn: state.turnNumber,
            expiresAfterPhase: DuelPhase.end,
          ),
        );
        nextState = _addTemporaryModifier(
          nextState,
          link.payload['enemy_instance_id']! as String,
          RuntimeStatModifier(
            modifierId: '${AncetreEffectKeys.anc009}:${link.linkId}:enemy',
            atkDelta: -300,
            defDelta: -300,
            sourceCardInstanceId: link.sourceCardInstanceId,
            expiresAtTurn: state.turnNumber,
            expiresAfterPhase: DuelPhase.end,
          ),
        );
        return nextState;
      },
    );
  }

  static ChainEffectDefinition _anc010(
    AncetreAncestralSummonExtension ancestralSummonExtension,
  ) {
    return _FunctionalAncetreEffect(
      onCanActivate: _hasAncestralBanishMaterials,
      onPayCost: (state, link) => _banishGraveyardCards(
        state,
        link.activatingPlayer,
        _payloadIds(link, 'banish_instance_ids'),
      ),
      onResolve: (state, link) {
        return ancestralSummonExtension.summonFromMythicReserve(
          state: state,
          participant: link.activatingPlayer,
          triggerCardCode: 'ANC-010',
          mythicCardCode: 'ANC-015',
        );
      },
    );
  }

  static ChainEffectDefinition _anc011() {
    return _FunctionalAncetreEffect(
      onCanActivate: (state, link) {
        final destroyedRank = link.payload['destroyed_rank'] as int?;
        final selectedId = link.payload['selected_instance_id'] as String?;
        final field = _fieldFor(state, link.activatingPlayer);
        final selected = _graveyardCard(
          state,
          link.activatingPlayer,
          selectedId,
        );
        return _sourceHasCode(state, link, 'ANC-011') &&
            link.payload['trigger'] == 'controlled_character_destroyed' &&
            destroyedRank != null &&
            field.characterZones.any((card) => card == null) &&
            selected != null &&
            selected.category == CardCategory.character &&
            selected.hasFamily('ancêtre') &&
            (selected.rank ?? 99) < destroyedRank;
      },
      onResolve: (state, link) => _specialSummonFromGraveyard(
        state,
        link.activatingPlayer,
        link.payload['selected_instance_id']! as String,
        maximumRankExclusive: link.payload['destroyed_rank']! as int,
      ),
    );
  }

  static ChainEffectDefinition _anc012() {
    return _FunctionalAncetreEffect(
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
        if (!_sourceHasCode(state, link, 'ANC-012') ||
            link.speed != ChainSpeed.speed3 ||
            targetLink == null ||
            targetLink.activatingPlayer == link.activatingPlayer) {
          return false;
        }
        final graveyardTargetId =
            link.payload['threatened_graveyard_instance_id'] as String? ??
                targetLink.target?.cardInstanceId ??
                targetLink.payload['graveyard_instance_id'] as String?;
        return _graveyardCard(
              state,
              link.activatingPlayer,
              graveyardTargetId,
            ) !=
            null;
      },
      onResolve: (state, link) => _negateAndDestroySource(
        state,
        _targetedChainLink(state, link)!,
      ),
    );
  }

  static ChainEffectDefinition _anc013() {
    const usageKey = '${AncetreEffectKeys.anc013}:memory_trigger';
    return _FunctionalAncetreEffect(
      onCanActivate: (state, link) {
        final source = _sourceCard(state, link);
        if (source?.cardCode != 'ANC-013') return false;
        final mode = link.payload['mode'];
        if (mode == 'field_card_sent_to_graveyard') {
          return !_usedThisTurn(source!, usageKey, state.turnNumber);
        }
        if (mode != 'spend_memory' || (source!.counters['mémoire'] ?? 0) < 3) {
          return false;
        }
        final discardId = link.payload['discard_instance_id'] as String?;
        if (discardId == null) return false;
        final field = _fieldFor(state, link.activatingPlayer);
        return field.hand.any((card) => card.instanceId == discardId) ||
            (field.deck.isNotEmpty && field.deck.first.instanceId == discardId);
      },
      onPayCost: (state, link) {
        if (link.payload['mode'] == 'field_card_sent_to_graveyard') {
          return _updateFieldCard(
            state,
            link.sourceCardInstanceId!,
            (card) => _markUsed(card, usageKey, state.turnNumber),
          );
        }
        return _updateFieldCard(
          state,
          link.sourceCardInstanceId!,
          (card) => card.copyWith(
            counters: {
              ...card.counters,
              'mémoire': (card.counters['mémoire'] ?? 0) - 3,
            },
          ),
        );
      },
      onResolve: (state, link) {
        if (link.payload['mode'] == 'field_card_sent_to_graveyard') {
          return _updateFieldCard(
            state,
            link.sourceCardInstanceId!,
            (card) => card.copyWith(
              counters: {
                ...card.counters,
                'mémoire': (card.counters['mémoire'] ?? 0) + 1,
              },
            ),
          );
        }
        var nextState = _drawOne(state, link.activatingPlayer);
        if (nextState.isFinished) return nextState;
        nextState = _discardFromHand(
          nextState,
          link.activatingPlayer,
          link.payload['discard_instance_id']! as String,
        );
        return nextState;
      },
    );
  }

  static ChainEffectDefinition _anc014() {
    const namesKey = 'counted_ancestor_card_codes';
    return _FunctionalAncetreEffect(
      onCanActivate: (state, link) {
        final source = _sourceCard(state, link);
        if (source?.cardCode != 'ANC-014') return false;
        final mode = link.payload['mode'];
        if (mode == 'activate') return true;
        if (mode == 'ancestor_character_sent_to_graveyard') {
          final code = link.payload['ancestor_card_code'] as String?;
          final counted = (source!.runtimeData[namesKey] as List?)
                  ?.whereType<String>()
                  .toSet() ??
              <String>{};
          return code != null && !counted.contains(code);
        }
        return mode == 'preparation_start' &&
            state.currentPhase == DuelPhase.preparation &&
            state.activePlayer == link.activatingPlayer &&
            source!.faceUp &&
            (source.counters['nom'] ?? 0) >= 8;
      },
      onResolve: (state, link) {
        final mode = link.payload['mode'];
        if (mode == 'activate') {
          return _updateFieldCard(
            state,
            link.sourceCardInstanceId!,
            (card) => card.copyWith(faceUp: true),
          );
        }
        if (mode == 'ancestor_character_sent_to_graveyard') {
          final code = link.payload['ancestor_card_code']! as String;
          return _updateFieldCard(
            state,
            link.sourceCardInstanceId!,
            (card) {
              final counted = (card.runtimeData[namesKey] as List?)
                      ?.whereType<String>()
                      .toSet() ??
                  <String>{};
              counted.add(code);
              return card.copyWith(
                counters: {
                  ...card.counters,
                  'nom': counted.length,
                },
                runtimeData: {
                  ...card.runtimeData,
                  namesKey: counted.toList(),
                },
              );
            },
          );
        }
        return state.copyWith(
          winner: link.activatingPlayer,
          endReason: DuelEndReason.cardEffect,
        );
      },
    );
  }

  static ChainEffectDefinition _anc015(AncetreDeckShuffler shuffler) {
    const usageKey = '${AncetreEffectKeys.anc015}:ancestor_left';
    return _FunctionalAncetreEffect(
      onCanActivate: (state, link) {
        final source = _sourceCard(state, link);
        if (source?.cardCode != 'ANC-015') return false;
        final trigger = link.payload['trigger'];
        if (trigger == 'on_summon') {
          final ids = _payloadIds(link, 'target_instance_ids');
          return ids.length <= 5 &&
              ids.toSet().length == ids.length &&
              ids.every(
                (id) =>
                    _graveyardCard(state, link.activatingPlayer, id) != null,
              );
        }
        return trigger == 'ancestor_card_left_field' &&
            !_usedThisTurn(source!, usageKey, state.turnNumber);
      },
      onPayCost: (state, link) {
        if (link.payload['trigger'] == 'on_summon') return state;
        return _updateFieldCard(
          state,
          link.sourceCardInstanceId!,
          (card) => _markUsed(card, usageKey, state.turnNumber),
        );
      },
      onResolve: (state, link) {
        if (link.payload['trigger'] == 'on_summon') {
          final moved = _moveGraveyardCardsToDeck(
            state,
            link.activatingPlayer,
            _payloadIds(link, 'target_instance_ids'),
            shuffler,
          );
          return _gainLifePoints(
            moved.state,
            link.activatingPlayer,
            moved.count * 300,
          );
        }
        return _drawOne(state, link.activatingPlayer);
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
      final card = field.characterZones[index];
      if (card is CardInstance && card.instanceId == instanceId) {
        return _FieldLocation(
          participant: participant,
          kind: _ZoneKind.character,
          index: index,
          card: card,
        );
      }
    }
    for (var index = 0; index < field.actionTrapZones.length; index++) {
      final card = field.actionTrapZones[index];
      if (card?.instanceId == instanceId) {
        return _FieldLocation(
          participant: participant,
          kind: _ZoneKind.actionTrap,
          index: index,
          card: card!,
        );
      }
    }
    if (field.terrainZone?.instanceId == instanceId) {
      return _FieldLocation(
        participant: participant,
        kind: _ZoneKind.terrain,
        index: null,
        card: field.terrainZone!,
      );
    }
  }
  return null;
}

CardInstance? _sourceCard(DuelState state, ChainLink link) {
  return _findFieldCard(state, link.sourceCardInstanceId)?.card;
}

bool _sourceHasCode(DuelState state, ChainLink link, String code) {
  if (link.sourceCardCode == code ||
      _sourceCard(state, link)?.cardCode == code) {
    return true;
  }
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

CardInstance? _graveyardCard(
  DuelState state,
  DuelParticipant participant,
  String? instanceId,
) {
  if (instanceId == null) return null;
  for (final card in _fieldFor(state, participant).graveyard) {
    if (card.instanceId == instanceId) return card;
  }
  return null;
}

bool _isOwnAncestorInGraveyard(
  DuelState state,
  DuelParticipant participant,
  String? instanceId,
) {
  return _graveyardCard(state, participant, instanceId)?.hasFamily('ancêtre') ??
      false;
}

DuelState _millTopCard(DuelState state, DuelParticipant participant) {
  final field = _fieldFor(state, participant);
  if (field.deck.isEmpty) return state;
  final deck = List<CardInstance>.from(field.deck);
  final milled = _asGraveyardCard(deck.removeAt(0));
  return _replaceField(
    state,
    participant,
    field.copyWith(deck: deck, graveyard: [...field.graveyard, milled]),
  );
}

DuelState _moveGraveyardCardToDeckBottom(
  DuelState state,
  DuelParticipant participant,
  String instanceId,
) {
  final field = _fieldFor(state, participant);
  final index = field.graveyard.indexWhere(
    (card) => card.instanceId == instanceId,
  );
  if (index < 0) return state;
  final graveyard = List<CardInstance>.from(field.graveyard);
  final card = _asDeckCard(graveyard.removeAt(index));
  return _replaceField(
    state,
    participant,
    field.copyWith(graveyard: graveyard, deck: [...field.deck, card]),
  );
}

DuelState _moveDeckCardToGraveyard(
  DuelState state,
  DuelParticipant participant,
  String instanceId,
  bool Function(CardInstance card) isLegal,
) {
  final field = _fieldFor(state, participant);
  final index = field.deck.indexWhere(
    (card) => card.instanceId == instanceId && isLegal(card),
  );
  if (index < 0) return state;
  final deck = List<CardInstance>.from(field.deck);
  final card = _asGraveyardCard(deck.removeAt(index));
  return _replaceField(
    state,
    participant,
    field.copyWith(deck: deck, graveyard: [...field.graveyard, card]),
  );
}

DuelState _moveGraveyardCardToHand(
  DuelState state,
  DuelParticipant participant,
  String instanceId,
) {
  final field = _fieldFor(state, participant);
  final index = field.graveyard.indexWhere(
    (card) => card.instanceId == instanceId,
  );
  if (index < 0) return state;
  final graveyard = List<CardInstance>.from(field.graveyard);
  final card = _asHandCard(graveyard.removeAt(index));
  return _replaceField(
    state,
    participant,
    field.copyWith(graveyard: graveyard, hand: [...field.hand, card]),
  );
}

DuelState _moveFieldCardToDeck(
  DuelState state,
  String instanceId,
  AncetreDeckShuffler shuffler,
) {
  final location = _findFieldCard(state, instanceId);
  if (location == null) return state;
  var nextState = _removeFieldCard(state, location);
  final ownerField = _fieldFor(nextState, location.card.owner);
  final shuffled = shuffler.shuffle([
    ...ownerField.deck,
    _asDeckCard(location.card),
  ]);
  return _replaceField(
    nextState,
    location.card.owner,
    ownerField.copyWith(deck: shuffled),
  );
}

({DuelState state, int count}) _moveGraveyardCardsToDeck(
  DuelState state,
  DuelParticipant participant,
  List<String> ids,
  AncetreDeckShuffler shuffler,
) {
  final field = _fieldFor(state, participant);
  final selected = <CardInstance>[];
  final graveyard = <CardInstance>[];
  final idSet = ids.toSet();
  for (final card in field.graveyard) {
    if (idSet.contains(card.instanceId)) {
      selected.add(_asDeckCard(card));
    } else {
      graveyard.add(card);
    }
  }
  final deck = shuffler.shuffle([...field.deck, ...selected]);
  return (
    state: _replaceField(
      state,
      participant,
      field.copyWith(graveyard: graveyard, deck: deck),
    ),
    count: selected.length,
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
  final card = _asGraveyardCard(hand.removeAt(index));
  return _replaceField(
    state,
    participant,
    field.copyWith(hand: hand, graveyard: [...field.graveyard, card]),
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
  final drawn = _asHandCard(deck.removeAt(0));
  return _replaceField(
    state,
    participant,
    field.copyWith(deck: deck, hand: [...field.hand, drawn]),
  );
}

DuelState _specialSummonFromGraveyard(
  DuelState state,
  DuelParticipant participant,
  String instanceId, {
  int? maximumRank,
  int? maximumRankExclusive,
}) {
  final field = _fieldFor(state, participant);
  final graveyardIndex = field.graveyard.indexWhere((card) {
    final rank = card.rank ?? 99;
    return card.instanceId == instanceId &&
        card.category == CardCategory.character &&
        card.hasFamily('ancêtre') &&
        (maximumRank == null || rank <= maximumRank) &&
        (maximumRankExclusive == null || rank < maximumRankExclusive);
  });
  final zoneIndex = field.characterZones.indexWhere((card) => card == null);
  if (graveyardIndex < 0 || zoneIndex < 0) return state;
  final graveyard = List<CardInstance>.from(field.graveyard);
  final card = graveyard.removeAt(graveyardIndex).copyWith(
    controller: participant,
    faceUp: true,
    position: BattlePosition.defense,
    zoneIndex: zoneIndex,
    summonedTurn: state.turnNumber,
    attackedThisTurn: false,
    positionChangedThisTurn: false,
    counters: const {},
    runtimeModifiers: const [],
    runtimeData: const {},
  );
  final zones = List<FieldCardInstance?>.from(field.characterZones)
    ..[zoneIndex] = card;
  return _replaceField(
    state,
    participant,
    field.copyWith(characterZones: zones, graveyard: graveyard),
  );
}

bool _isLowRankAncestorCharacter(CardInstance card, int maximumRank) {
  return card.category == CardCategory.character &&
      card.hasFamily('ancêtre') &&
      (card.rank ?? 99) <= maximumRank;
}

bool _hasAncestralBanishMaterials(DuelState state, ChainLink link) {
  if (!_sourceHasCode(state, link, 'ANC-010')) return false;
  final ids = _payloadIds(link, 'banish_instance_ids');
  if (ids.isEmpty || ids.toSet().length != ids.length) return false;
  final field = _fieldFor(state, link.activatingPlayer);
  var totalRank = 0;
  for (final id in ids) {
    final card = _graveyardCard(state, link.activatingPlayer, id);
    if (card == null ||
        card.category != CardCategory.character ||
        !card.hasFamily('ancêtre') ||
        card.rank == null) {
      return false;
    }
    totalRank += card.rank!;
  }
  return totalRank >= 10 &&
      ids.every((id) => field.graveyard.any((card) => card.instanceId == id));
}

DuelState _banishGraveyardCards(
  DuelState state,
  DuelParticipant participant,
  List<String> ids,
) {
  final field = _fieldFor(state, participant);
  final idSet = ids.toSet();
  final graveyard = <CardInstance>[];
  final banished = <CardInstance>[...field.banished];
  for (final card in field.graveyard) {
    if (idSet.contains(card.instanceId)) {
      banished.add(
        card.copyWith(
          controller: card.owner,
          faceUp: true,
          position: null,
          zoneIndex: null,
          counters: const {},
          attachedCardInstanceIds: const [],
          runtimeModifiers: const [],
          runtimeData: const {},
        ),
      );
    } else {
      graveyard.add(card);
    }
  }
  return _replaceField(
    state,
    participant,
    field.copyWith(graveyard: graveyard, banished: banished),
  );
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

DuelState _addTemporaryModifier(
  DuelState state,
  String instanceId,
  RuntimeStatModifier modifier,
) {
  return _updateFieldCard(
    state,
    instanceId,
    (card) => card.copyWith(
      runtimeModifiers: [...card.runtimeModifiers, modifier],
    ),
  );
}

DuelState _gainLifePoints(
  DuelState state,
  DuelParticipant participant,
  int amount,
) {
  if (amount <= 0) return state;
  return participant == DuelParticipant.player
      ? state.copyWith(playerLifePoints: state.playerLifePoints + amount)
      : state.copyWith(aiLifePoints: state.aiLifePoints + amount);
}

CardInstance _asDeckCard(CardInstance card) {
  return card.copyWith(
    controller: card.owner,
    faceUp: false,
    position: null,
    zoneIndex: null,
    counters: const {},
    attachedCardInstanceIds: const [],
    runtimeModifiers: const [],
    runtimeData: const {},
  );
}

CardInstance _asHandCard(CardInstance card) {
  return _asDeckCard(card);
}

CardInstance _asGraveyardCard(CardInstance card) {
  return card.copyWith(
    controller: card.owner,
    faceUp: true,
    position: null,
    zoneIndex: null,
    counters: const {},
    attachedCardInstanceIds: const [],
    runtimeModifiers: const [],
    runtimeData: const {},
  );
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
