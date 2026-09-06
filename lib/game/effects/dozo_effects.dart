import 'manual_activation_options.dart';
import '../battle_state.dart';
import '../card.dart';
import '../duel_engine.dart';
import '../duel_types.dart';
import '../mythic_summon.dart';
import '../player.dart';

abstract final class DozoEffectKeys {
  static const doz001 = 'doz_001_apprenti_pisteur';
  static const doz002 = 'doz_002_archere_des_hautes_herbes';
  static const doz004 = 'doz_004_lecteur_de_traces';
  static const doz005 = 'doz_005_chasseuse_au_manteau_brun';
  static const doz006 = 'doz_006_maitre_des_collets';
  static const doz007 = 'doz_007_capitaine_de_la_chasse_nocturne';
  static const doz008 = 'doz_008_piste_fraiche';
  static const doz009 = 'doz_009_tir_de_sommation';
  static const doz010 = 'doz_010_serment_de_la_lune_des_chasseurs';
  static const doz011 = 'doz_011_collet_des_hautes_herbes';
  static const doz012 = 'doz_012_dernier_coup_de_sifflet';
  static const doz013 = 'doz_013_campement_sous_la_lune';
  static const doz014 = 'doz_014_corne_du_premier_buffle';
  static const doz015 = 'doz_015_maitre_dozo_de_la_lune_noire';
}

abstract interface class DozoAncestralSummonExtension {
  DuelState summonFromMythicReserve({
    required DuelState state,
    required DuelParticipant participant,
    required String triggerCardCode,
    required String mythicCardCode,
  });
}

final class DefaultDozoAncestralSummonExtension
    implements DozoAncestralSummonExtension {
  const DefaultDozoAncestralSummonExtension();

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
typedef _PendingEvents = Iterable<PendingDuelEvent> Function(
  DuelState state,
  ChainLink link,
);

final class _FunctionalDozoEffect extends ChainEffectDefinition {
  const _FunctionalDozoEffect({
    this.onManualActivations,
    this.onCanActivate,
    this.onPayCost,
    this.onTargetLegal,
    this.onPendingEvents,
    required this.onResolve,
  });

  final _Predicate? onCanActivate;
  final _Reducer? onPayCost;
  final _Predicate? onTargetLegal;
  final _PendingEvents? onPendingEvents;
  final _Reducer onResolve;

  final ManualActivationBuilder? onManualActivations;
  @override
  Iterable<ManualActivationOption> buildManualActivations(
          ManualActivationRequest request) =>
      onManualActivations?.call(request) ?? const [];

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
  Iterable<PendingDuelEvent> pendingEvents(DuelState state, ChainLink link) =>
      onPendingEvents?.call(state, link) ?? const [];

  @override
  DuelState resolve(DuelState state, ChainLink link) => onResolve(state, link);
}

final class DozoEffectRegistry {
  const DozoEffectRegistry._();

  static Map<String, ChainEffectDefinition> create({
    DozoAncestralSummonExtension ancestralSummonExtension =
        const DefaultDozoAncestralSummonExtension(),
  }) {
    return {
      DozoEffectKeys.doz001: _doz001(),
      DozoEffectKeys.doz002: _doz002(),
      DozoEffectKeys.doz004: _doz004(),
      DozoEffectKeys.doz005: _doz005(),
      DozoEffectKeys.doz006: _doz006(),
      DozoEffectKeys.doz007: _doz007(),
      DozoEffectKeys.doz008: _doz008(),
      DozoEffectKeys.doz009: _doz009(),
      DozoEffectKeys.doz010: _doz010(ancestralSummonExtension),
      DozoEffectKeys.doz011: _doz011(),
      DozoEffectKeys.doz012: _doz012(),
      DozoEffectKeys.doz013: _doz013(),
      DozoEffectKeys.doz014: _doz014(),
      DozoEffectKeys.doz015: _doz015(),
    };
  }

  static ChainEffectDefinition _doz001() {
    return _FunctionalDozoEffect(
      onCanActivate: (state, link) =>
          _sourceHasCode(state, link, 'DOZ-001') &&
          link.payload['trigger'] == 'on_summon' &&
          _fieldFor(state, _opponent(link.activatingPlayer)).deck.isNotEmpty,
      onResolve: (state, link) {
        final opponentField =
            _fieldFor(state, _opponent(link.activatingPlayer));
        final viewerField = _fieldFor(state, link.activatingPlayer);
        return _replaceField(
          state,
          link.activatingPlayer,
          viewerField.copyWith(
            revealedCardInstanceIds: {
              ...viewerField.revealedCardInstanceIds,
              opponentField.deck.first.instanceId,
            },
          ),
        );
      },
    );
  }

  static ChainEffectDefinition _doz002() {
    // Le bonus de calcul des dégâts est lu directement par DuelEngine.
    return _FunctionalDozoEffect(
      onCanActivate: (state, link) =>
          _sourceHasCode(state, link, 'DOZ-002') &&
          link.payload['trigger'] == 'combat_calculation_refresh',
      onResolve: (state, link) => state,
    );
  }

  static ChainEffectDefinition _doz004() {
    return _FunctionalDozoEffect(
      onCanActivate: (state, link) =>
          _sourceHasCode(state, link, 'DOZ-004') &&
          link.payload['trigger'] == 'on_summon',
      onTargetLegal: _doz004SelectionIsLegal,
      onResolve: (state, link) {
        final participant = link.activatingPlayer;
        final field = _fieldFor(state, participant);
        final trapId = link.payload['trap_instance_id']! as String;
        final trapIndex =
            field.deck.indexWhere((card) => card.instanceId == trapId);
        final deck = List<CardInstance>.from(field.deck);
        final trap = _asHandCard(deck.removeAt(trapIndex));
        final hand = [...field.hand, trap];
        final bottomId = link.payload['bottom_instance_id']! as String;
        final bottomIndex =
            hand.indexWhere((card) => card.instanceId == bottomId);
        final bottom = _asDeckCard(hand.removeAt(bottomIndex));
        return _replaceField(
          state,
          participant,
          field.copyWith(deck: [...deck, bottom], hand: hand),
        );
      },
    );
  }

  static ChainEffectDefinition _doz005() {
    const usageKey = '${DozoEffectKeys.doz005}:mark_prey';
    return _FunctionalDozoEffect(
      onCanActivate: (state, link) {
        final source = _sourceCard(state, link);
        return source?.cardCode == 'DOZ-005' &&
            !_usedThisTurn(source!, usageKey, state.turnNumber);
      },
      onTargetLegal: (state, link) =>
          _isVisibleOpponentCharacter(state, link, link.target?.cardInstanceId),
      onPayCost: (state, link) => _updateFieldCard(
        state,
        link.sourceCardInstanceId!,
        (card) => _markUsed(card, usageKey, state.turnNumber),
      ),
      onResolve: (state, link) =>
          _addCounter(state, link.target!.cardInstanceId, 'proie'),
    );
  }

  static ChainEffectDefinition _doz006() {
    const usageKey = '${DozoEffectKeys.doz006}:same_turn_trap';
    return _FunctionalDozoEffect(
      onCanActivate: (state, link) {
        final source = _sourceCard(state, link);
        return source?.cardCode == 'DOZ-006' &&
            state.activePlayer == link.activatingPlayer &&
            !_usedThisTurn(source!, usageKey, state.turnNumber);
      },
      onTargetLegal: (state, link) {
        final location = _findFieldCard(state, link.target?.cardInstanceId);
        return location != null &&
            location.kind == _ZoneKind.actionTrap &&
            location.card.controller == link.activatingPlayer &&
            location.card.category == CardCategory.trap &&
            location.card.hasFamily('dozo') &&
            !location.card.faceUp &&
            location.card.runtimeData[CardRuntimeKeys.setOnTurn] ==
                state.turnNumber;
      },
      onPayCost: (state, link) => _updateFieldCard(
        state,
        link.sourceCardInstanceId!,
        (card) => _markUsed(card, usageKey, state.turnNumber),
      ),
      onResolve: (state, link) => _updateFieldCard(
        state,
        link.target!.cardInstanceId,
        (card) => card.copyWith(
          runtimeData: {
            ...card.runtimeData,
            CardRuntimeKeys.sameTurnTrapActivationAllowed: state.turnNumber,
          },
        ),
      ),
    );
  }

  static ChainEffectDefinition _doz007() {
    const usageKey = '${DozoEffectKeys.doz007}:banish_prey';
    return _FunctionalDozoEffect(
      onCanActivate: (state, link) {
        final source = _sourceCard(state, link);
        if (source?.cardCode != 'DOZ-007') return false;
        if (link.payload['mode'] == 'on_summon') return true;
        return link.payload['mode'] == 'prey_destroyed_in_combat' &&
            link.payload['destroyed_had_prey'] == true &&
            !_usedThisTurn(source!, usageKey, state.turnNumber);
      },
      onTargetLegal: (state, link) {
        if (link.payload['mode'] == 'on_summon') return link.target == null;
        return _graveyardContains(state, link.target?.cardInstanceId);
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
          final opponentField =
              _fieldFor(state, _opponent(link.activatingPlayer));
          for (final target
              in opponentField.characterZones.whereType<CardInstance>()) {
            if (target.faceUp) {
              next = _addCounter(next, target.instanceId, 'proie');
            }
          }
          return next;
        }
        return _banishFromGraveyard(state, link.target!.cardInstanceId);
      },
    );
  }

  static ChainEffectDefinition _doz008() {
    return _FunctionalDozoEffect(
      onCanActivate: (state, link) => _sourceHasCode(state, link, 'DOZ-008'),
      onTargetLegal: (state, link) {
        final searchId = link.payload['search_instance_id'] as String?;
        return _isVisibleOpponentCharacter(
                state, link, link.target?.cardInstanceId) &&
            _fieldFor(state, link.activatingPlayer).deck.any((card) =>
                card.instanceId == searchId &&
                card.category == CardCategory.character &&
                card.hasFamily('dozo') &&
                (card.rank ?? 99) <= 4);
      },
      onResolve: (state, link) {
        final marked = _addCounter(state, link.target!.cardInstanceId, 'proie');
        return _moveDeckCardToHand(
          marked,
          link.activatingPlayer,
          link.payload['search_instance_id']! as String,
        );
      },
    );
  }

  static ChainEffectDefinition _doz009() {
    return _FunctionalDozoEffect(
      onManualActivations: (request) sync* {
        final allCharacters = request.allCharacters;
        final option = request.option;
        for (final target in allCharacters
            .where((c) => c.faceUp && (c.counters['proie'] ?? 0) > 0)) {
          yield option(
              target: ChainTarget(cardInstanceId: target.instanceId),
              description: 'Affaiblir ${target.cardCode}',
              suffix: target.instanceId);
        }
      },
      onCanActivate: (state, link) => _sourceHasCode(state, link, 'DOZ-009'),
      onTargetLegal: (state, link) {
        final target = _findFieldCard(state, link.target?.cardInstanceId);
        return target != null &&
            target.kind == _ZoneKind.character &&
            target.card.faceUp &&
            (target.card.counters['proie'] ?? 0) > 0;
      },
      onResolve: (state, link) {
        final target = _findFieldCard(state, link.target!.cardInstanceId)!;
        return _updateFieldCard(
          state,
          target.card.instanceId,
          (card) => card.copyWith(
            runtimeModifiers: [
              ...card.runtimeModifiers,
              RuntimeStatModifier(
                modifierId: '${DozoEffectKeys.doz009}:${link.linkId}',
                atkDelta: -700,
                defDelta: card.position == BattlePosition.defense ? -700 : 0,
                sourceCardInstanceId: link.sourceCardInstanceId,
                expiresAtTurn: state.turnNumber,
              ),
            ],
          ),
        );
      },
    );
  }

  static ChainEffectDefinition _doz010(
    DozoAncestralSummonExtension extension,
  ) {
    return _FunctionalDozoEffect(
      onCanActivate: (state, link) => _validDozoAncestralCost(state, link),
      onPayCost: (state, link) {
        var next = _sacrificeFieldCharacter(
          state,
          link.activatingPlayer,
          link.payload['sacrifice_instance_id']! as String,
        );
        next = _banishOwnGraveyardCards(
          next,
          link.activatingPlayer,
          _payloadIds(link, 'banish_trap_instance_ids'),
        );
        return next;
      },
      onResolve: (state, link) => extension.summonFromMythicReserve(
        state: state,
        participant: link.activatingPlayer,
        triggerCardCode: 'DOZ-010',
        mythicCardCode: 'DOZ-015',
      ),
    );
  }

  static ChainEffectDefinition _doz011() {
    return _FunctionalDozoEffect(
      onManualActivations: (request) sync* {
        final attack = request.attack;
        final option = request.option;
        if (attack != null) {
          yield option(
              target: ChainTarget(cardInstanceId: attack.attackerInstanceId),
              payload: {
                'trigger': 'opponent_attack_declared',
                'attack_declaration_id': attack.declarationId
              },
              description: 'Prendre l’attaquant au collet',
              suffix: attack.declarationId);
        }
      },
      onCanActivate: (state, link) =>
          _sourceHasCode(state, link, 'DOZ-011') &&
          link.payload['trigger'] == 'opponent_attack_declared' &&
          link.payload['attack_declaration_id'] is String,
      onTargetLegal: (state, link) =>
          _isVisibleOpponentCharacter(state, link, link.target?.cardInstanceId),
      onResolve: (state, link) {
        final targetId = link.target!.cardInstanceId;
        var next = state.copyWith(
          cancelledAttackDeclarationIds: {
            ...state.cancelledAttackDeclarationIds,
            link.payload['attack_declaration_id']! as String,
          },
        );
        next = _updateFieldCard(
          next,
          targetId,
          (card) => card.copyWith(
            position: BattlePosition.defense,
            positionChangedThisTurn: true,
          ),
        );
        return _addCounter(next, targetId, 'proie');
      },
    );
  }

  static ChainEffectDefinition _doz012() {
    return _FunctionalDozoEffect(
      onManualActivations: (request) sync* {
        final state = request.state;
        final last = request.last;
        final option = request.option;
        final activatingCard = request.sourceCard(state, last);
        if (last != null &&
            activatingCard != null &&
            (activatingCard.counters['proie'] ?? 0) > 0) {
          yield option(
              payload: {'target_link_id': last.linkId},
              description: 'Annuler l’effet de la Proie',
              suffix: last.linkId);
        }
      },
      onPendingEvents: (state, link) {
        final targeted = _targetedChainLink(state, link);
        final id = targeted?.sourceCardInstanceId;
        return id == null
            ? const []
            : [
                BanishmentPending(
                  sourceLinkId: link.linkId,
                  cardInstanceId: id,
                  fromGraveyard: false,
                ),
              ];
      },
      onCanActivate: (state, link) {
        if (!_sourceHasCode(state, link, 'DOZ-012')) return false;
        final targeted = _targetedChainLink(state, link);
        final source = _findFieldCard(state, targeted?.sourceCardInstanceId);
        return targeted != null &&
            targeted.activatingPlayer != link.activatingPlayer &&
            source != null &&
            source.kind == _ZoneKind.character &&
            (source.card.counters['proie'] ?? 0) > 0;
      },
      onTargetLegal: (state, link) {
        final targeted = _targetedChainLink(state, link);
        final source = _findFieldCard(state, targeted?.sourceCardInstanceId);
        return targeted != null &&
            source != null &&
            source.kind == _ZoneKind.character &&
            (source.card.counters['proie'] ?? 0) > 0;
      },
      onResolve: (state, link) {
        final targeted = _targetedChainLink(state, link)!;
        var next = state.copyWith(
          chain: state.chain.copyWith(
            negatedLinkIds: {...state.chain.negatedLinkIds, targeted.linkId},
          ),
        );
        return _banishFieldCard(next, targeted.sourceCardInstanceId!);
      },
    );
  }

  static ChainEffectDefinition _doz013() {
    const usageKey = '${DozoEffectKeys.doz013}:trap_trigger';
    return _FunctionalDozoEffect(
      onCanActivate: (state, link) {
        final source = _sourceCard(state, link);
        if (source?.cardCode != 'DOZ-013') return false;
        if (link.payload['mode'] == 'continuous_refresh') return true;
        return link.payload['mode'] == 'trap_activated' &&
            !_usedThisTurn(source!, usageKey, state.turnNumber);
      },
      onTargetLegal: (state, link) =>
          link.payload['mode'] == 'continuous_refresh'
              ? link.target == null
              : _isVisibleOpponentCharacter(
                  state,
                  link,
                  link.target?.cardInstanceId,
                ),
      onPayCost: (state, link) {
        if (link.payload['mode'] == 'continuous_refresh') return state;
        return _updateFieldCard(
          state,
          link.sourceCardInstanceId!,
          (card) => _markUsed(card, usageKey, state.turnNumber),
        );
      },
      onResolve: (state, link) {
        var next = _refreshDozoCampAura(
          state,
          link.sourceCardInstanceId!,
          link.activatingPlayer,
        );
        if (link.payload['mode'] == 'trap_activated') {
          next = _addCounter(next, link.target!.cardInstanceId, 'proie');
        }
        return next;
      },
    );
  }

  static ChainEffectDefinition _doz014() {
    return _FunctionalDozoEffect(
      onCanActivate: (state, link) {
        final source = _sourceCard(state, link);
        if (source?.cardCode != 'DOZ-014') return false;
        if (link.payload['mode'] == 'equip') return true;
        final trapId = link.payload['trap_instance_id'] as String?;
        final field = _fieldFor(state, link.activatingPlayer);
        return link.payload['mode'] == 'equipped_destroyed_prey' &&
            link.payload['destroyed_had_prey'] == true &&
            trapId != null &&
            field.actionTrapZones.any((card) => card == null) &&
            field.hand.any((card) =>
                card.instanceId == trapId &&
                card.category == CardCategory.trap &&
                card.hasFamily('dozo'));
      },
      onTargetLegal: (state, link) {
        if (link.payload['mode'] != 'equip') return link.target == null;
        final target = _findFieldCard(state, link.target?.cardInstanceId);
        return target != null &&
            target.kind == _ZoneKind.character &&
            target.card.controller == link.activatingPlayer &&
            target.card.hasFamily('dozo');
      },
      onResolve: (state, link) {
        if (link.payload['mode'] == 'equipped_destroyed_prey') {
          return _setTrapFromHand(
            state,
            link.activatingPlayer,
            link.payload['trap_instance_id']! as String,
          );
        }
        final targetId = link.target!.cardInstanceId;
        var next = _updateFieldCard(
          state,
          targetId,
          (card) => card.copyWith(
            attachedCardInstanceIds: [
              ...card.attachedCardInstanceIds,
              link.sourceCardInstanceId!,
            ],
            runtimeModifiers: [
              ...card.runtimeModifiers,
              RuntimeStatModifier(
                modifierId:
                    '${DozoEffectKeys.doz014}:${link.sourceCardInstanceId}',
                atkDelta: 400,
                sourceCardInstanceId: link.sourceCardInstanceId,
              ),
            ],
          ),
        );
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
      },
    );
  }

  static ChainEffectDefinition _doz015() {
    const usageKey = '${DozoEffectKeys.doz015}:banish_prey';
    return _FunctionalDozoEffect(
      onPendingEvents: (state, link) => link.target == null
          ? const []
          : [
              BanishmentPending(
                sourceLinkId: link.linkId,
                cardInstanceId: link.target!.cardInstanceId,
                fromGraveyard: false,
              ),
            ],
      onCanActivate: (state, link) {
        final source = _sourceCard(state, link);
        return source?.cardCode == 'DOZ-015' &&
            link.payload['mode'] == 'banish_prey' &&
            !_usedThisTurn(source!, usageKey, state.turnNumber);
      },
      onTargetLegal: (state, link) {
        final target = _findFieldCard(state, link.target?.cardInstanceId);
        return target != null &&
            target.card.faceUp &&
            (target.card.counters['proie'] ?? 0) > 0;
      },
      onPayCost: (state, link) => _updateFieldCard(
        state,
        link.sourceCardInstanceId!,
        (card) => _markUsed(
          card.copyWith(
            runtimeData: {
              ...card.runtimeData,
              CardRuntimeKeys.cannotAttackTurn: state.turnNumber,
            },
          ),
          usageKey,
          state.turnNumber,
        ),
      ),
      onResolve: (state, link) =>
          _banishFieldCard(state, link.target!.cardInstanceId),
    );
  }
}

enum _ZoneKind { character, actionTrap, terrain }

final class _FieldLocation {
  const _FieldLocation(this.participant, this.kind, this.index, this.card);

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

DuelParticipant _opponent(DuelParticipant participant) =>
    participant == DuelParticipant.player
        ? DuelParticipant.ai
        : DuelParticipant.player;

_FieldLocation? _findFieldCard(DuelState state, String? instanceId) {
  if (instanceId == null) return null;
  for (final participant in DuelParticipant.values) {
    final field = _fieldFor(state, participant);
    for (var i = 0; i < field.characterZones.length; i++) {
      final card = field.characterZones[i];
      if (card is CardInstance && card.instanceId == instanceId) {
        return _FieldLocation(participant, _ZoneKind.character, i, card);
      }
    }
    for (var i = 0; i < field.actionTrapZones.length; i++) {
      final card = field.actionTrapZones[i];
      if (card?.instanceId == instanceId) {
        return _FieldLocation(participant, _ZoneKind.actionTrap, i, card!);
      }
    }
    final terrain = field.terrainZone;
    if (terrain?.instanceId == instanceId) {
      return _FieldLocation(participant, _ZoneKind.terrain, null, terrain!);
    }
  }
  return null;
}

CardInstance? _sourceCard(DuelState state, ChainLink link) =>
    _findFieldCard(state, link.sourceCardInstanceId)?.card;

bool _sourceHasCode(DuelState state, ChainLink link, String code) =>
    _sourceCard(state, link)?.cardCode == code;

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
          state, location.participant, field.copyWith(characterZones: zones));
    case _ZoneKind.actionTrap:
      final zones = List<CardInstance?>.from(field.actionTrapZones)
        ..[location.index!] = update(location.card);
      return _replaceField(
          state, location.participant, field.copyWith(actionTrapZones: zones));
    case _ZoneKind.terrain:
      return _replaceField(state, location.participant,
          field.copyWith(terrainZone: update(location.card)));
  }
}

DuelState _addCounter(
  DuelState state,
  String instanceId,
  String counterType, [
  int count = 1,
]) =>
    _updateFieldCard(
      state,
      instanceId,
      (card) => card.copyWith(counters: {
        ...card.counters,
        counterType: (card.counters[counterType] ?? 0) + count,
      }),
    );

bool _usedThisTurn(CardInstance card, String key, int turn) =>
    card.effectUsageTurns[key] == turn;

CardInstance _markUsed(CardInstance card, String key, int turn) =>
    card.copyWith(
      effectUsageTurns: {...card.effectUsageTurns, key: turn},
    );

bool _isVisibleOpponentCharacter(
  DuelState state,
  ChainLink link,
  String? instanceId,
) {
  final target = _findFieldCard(state, instanceId);
  return target != null &&
      target.kind == _ZoneKind.character &&
      target.card.controller != link.activatingPlayer &&
      target.card.faceUp;
}

bool _doz004SelectionIsLegal(DuelState state, ChainLink link) {
  final field = _fieldFor(state, link.activatingPlayer);
  final trapId = link.payload['trap_instance_id'] as String?;
  final bottomId = link.payload['bottom_instance_id'] as String?;
  CardInstance? trap;
  for (final card in field.deck) {
    if (card.instanceId == trapId) {
      trap = card;
      break;
    }
  }
  if (trap == null ||
      trap.category != CardCategory.trap ||
      !trap.hasFamily('dozo') ||
      bottomId == null) {
    return false;
  }
  return bottomId == trapId ||
      field.hand.any((card) => card.instanceId == bottomId);
}

List<String> _payloadIds(ChainLink link, String key) {
  final value = link.payload[key];
  return value is List ? value.whereType<String>().toList() : const [];
}

bool _validDozoAncestralCost(DuelState state, ChainLink link) {
  if (!_sourceHasCode(state, link, 'DOZ-010')) return false;
  final sacrifice = _findFieldCard(
    state,
    link.payload['sacrifice_instance_id'] as String?,
  );
  final trapIds = _payloadIds(link, 'banish_trap_instance_ids');
  final field = _fieldFor(state, link.activatingPlayer);
  return sacrifice != null &&
      sacrifice.kind == _ZoneKind.character &&
      sacrifice.card.controller == link.activatingPlayer &&
      sacrifice.card.hasFamily('dozo') &&
      (sacrifice.card.rank ?? 0) >= 6 &&
      trapIds.length == 2 &&
      trapIds.toSet().length == 2 &&
      trapIds.every((id) => field.graveyard.any(
            (card) =>
                card.instanceId == id && card.category == CardCategory.trap,
          ));
}

DuelState _sacrificeFieldCharacter(
  DuelState state,
  DuelParticipant controller,
  String instanceId,
) {
  final location = _findFieldCard(state, instanceId)!;
  final field = _fieldFor(state, controller);
  final zones = List<FieldCardInstance?>.from(field.characterZones)
    ..[location.index!] = null;
  var next = _replaceField(
    state,
    controller,
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

DuelState _banishOwnGraveyardCards(
  DuelState state,
  DuelParticipant participant,
  List<String> ids,
) {
  final field = _fieldFor(state, participant);
  final selected = ids.toSet();
  final graveyard = <CardInstance>[];
  final banished = [...field.banished];
  for (final card in field.graveyard) {
    if (selected.contains(card.instanceId)) {
      banished.add(_asBanishedCard(card));
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

bool _graveyardContains(DuelState state, String? instanceId) =>
    instanceId != null &&
    DuelParticipant.values.any((participant) => _fieldFor(state, participant)
        .graveyard
        .any((card) => card.instanceId == instanceId));

DuelState _banishFromGraveyard(DuelState state, String instanceId) {
  for (final participant in DuelParticipant.values) {
    final field = _fieldFor(state, participant);
    final index =
        field.graveyard.indexWhere((card) => card.instanceId == instanceId);
    if (index < 0) continue;
    final graveyard = List<CardInstance>.from(field.graveyard);
    final card = _asBanishedCard(graveyard.removeAt(index));
    return _replaceField(
      state,
      participant,
      field.copyWith(graveyard: graveyard, banished: [...field.banished, card]),
    );
  }
  return state;
}

DuelState _banishFieldCard(DuelState state, String instanceId) {
  final location = _findFieldCard(state, instanceId);
  if (location == null) return state;
  final field = _fieldFor(state, location.participant);
  late PlayerFieldState without;
  switch (location.kind) {
    case _ZoneKind.character:
      final zones = List<FieldCardInstance?>.from(field.characterZones)
        ..[location.index!] = null;
      without = field.copyWith(characterZones: zones);
    case _ZoneKind.actionTrap:
      final zones = List<CardInstance?>.from(field.actionTrapZones)
        ..[location.index!] = null;
      without = field.copyWith(actionTrapZones: zones);
    case _ZoneKind.terrain:
      without = field.copyWith(terrainZone: null);
  }
  var next = _replaceField(state, location.participant, without);
  final ownerField = _fieldFor(next, location.card.owner);
  return _replaceField(
    next,
    location.card.owner,
    ownerField.copyWith(
      banished: [...ownerField.banished, _asBanishedCard(location.card)],
    ),
  );
}

DuelState _moveDeckCardToHand(
  DuelState state,
  DuelParticipant participant,
  String instanceId,
) {
  final field = _fieldFor(state, participant);
  final index = field.deck.indexWhere((card) => card.instanceId == instanceId);
  if (index < 0) return state;
  final deck = List<CardInstance>.from(field.deck);
  final card = _asHandCard(deck.removeAt(index));
  return _replaceField(
    state,
    participant,
    field.copyWith(deck: deck, hand: [...field.hand, card]),
  );
}

DuelState _setTrapFromHand(
  DuelState state,
  DuelParticipant participant,
  String instanceId,
) {
  final field = _fieldFor(state, participant);
  final handIndex =
      field.hand.indexWhere((card) => card.instanceId == instanceId);
  final zoneIndex = field.actionTrapZones.indexWhere((card) => card == null);
  if (handIndex < 0 || zoneIndex < 0) return state;
  final hand = List<CardInstance>.from(field.hand);
  final original = hand.removeAt(handIndex);
  final card = original.copyWith(
    controller: participant,
    faceUp: false,
    position: null,
    zoneIndex: zoneIndex,
    runtimeData: {
      ...original.runtimeData,
      CardRuntimeKeys.setOnTurn: state.turnNumber,
    },
  );
  final zones = List<CardInstance?>.from(field.actionTrapZones)
    ..[zoneIndex] = card;
  return _replaceField(
    state,
    participant,
    field.copyWith(hand: hand, actionTrapZones: zones),
  );
}

DuelState _refreshDozoCampAura(
  DuelState state,
  String sourceId,
  DuelParticipant participant,
) {
  final source = _findFieldCard(state, sourceId);
  if (source == null ||
      source.kind != _ZoneKind.terrain ||
      !source.card.faceUp) {
    return state;
  }
  var next = state;
  for (final owner in DuelParticipant.values) {
    final field = _fieldFor(next, owner);
    for (final target in field.characterZones.whereType<CardInstance>()) {
      final modifiers = target.runtimeModifiers
          .where((modifier) => modifier.sourceCardInstanceId != sourceId)
          .toList();
      if (target.hasFamily('dozo')) {
        modifiers.add(RuntimeStatModifier(
          modifierId: '${DozoEffectKeys.doz013}:$sourceId',
          atkDelta: 200,
          defDelta: 200,
          sourceCardInstanceId: sourceId,
        ));
      }
      next = _updateFieldCard(
        next,
        target.instanceId,
        (card) => card.copyWith(runtimeModifiers: modifiers),
      );
    }
  }
  return next;
}

ChainLink? _targetedChainLink(DuelState state, ChainLink link) {
  final id = link.payload['target_link_id'] as String?;
  if (id == null) return null;
  for (final candidate in state.chain.links) {
    if (candidate.linkId == id) return candidate;
  }
  return null;
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

CardInstance _asBanishedCard(CardInstance card) => _asGraveyardCard(card);
