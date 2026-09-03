import '../battle_state.dart';
import '../card.dart';
import '../duel_engine.dart';
import '../duel_types.dart';
import '../mythic_summon.dart';
import '../player.dart';

abstract final class ForetEffectKeys {
  static const for001 = 'for_001_graine_qui_marche';
  static const for002 = 'for_002_singe_aux_fruits_d_or';
  static const for004 = 'for_004_guerisseuse_des_lianes';
  static const for005 = 'for_005_panthere_des_racines';
  static const for006 = 'for_006_gardien_iroko';
  static const for007 = 'for_007_elephante_aux_jardins_vivants';
  static const for008 = 'for_008_germination_soudaine';
  static const for009 = 'for_009_saison_des_grandes_pluies';
  static const for010 = 'for_010_racines_du_coeur_monde';
  static const for011 = 'for_011_liane_entravante';
  static const for012 = 'for_012_reprise_sauvage';
  static const for013 = 'for_013_foret_aux_mille_souffles';
  static const for014 = 'for_014_graine_de_l_arbre_originel';
  static const for015 = 'for_015_iroko_coeur_du_monde';
}

abstract interface class ForetFusionSummonExtension {
  DuelState summonFromMythicReserve({
    required DuelState state,
    required DuelParticipant participant,
    required String triggerCardCode,
    required String mythicCardCode,
  });
}

final class DefaultForetFusionSummonExtension
    implements ForetFusionSummonExtension {
  const DefaultForetFusionSummonExtension();

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

typedef ForetTokenIdGenerator = String Function(
  DuelState state,
  DuelParticipant participant,
  int sequence,
);
typedef _Predicate = bool Function(DuelState state, ChainLink link);
typedef _Reducer = DuelState Function(DuelState state, ChainLink link);

final class _FunctionalForetEffect extends ChainEffectDefinition {
  const _FunctionalForetEffect({
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

final class ForetEffectRegistry {
  const ForetEffectRegistry._();

  static Map<String, ChainEffectDefinition> create({
    ForetFusionSummonExtension fusionSummonExtension =
        const DefaultForetFusionSummonExtension(),
    ForetTokenIdGenerator tokenIdGenerator = _defaultTokenId,
  }) {
    return {
      ForetEffectKeys.for001: _for001(tokenIdGenerator),
      ForetEffectKeys.for002: _for002(),
      ForetEffectKeys.for004: _for004(),
      ForetEffectKeys.for005: _for005(),
      ForetEffectKeys.for006: _for006(),
      ForetEffectKeys.for007: _for007(tokenIdGenerator),
      ForetEffectKeys.for008: _for008(tokenIdGenerator),
      ForetEffectKeys.for009: _for009(tokenIdGenerator),
      ForetEffectKeys.for010: _for010(fusionSummonExtension),
      ForetEffectKeys.for011: _for011(),
      ForetEffectKeys.for012: _for012(tokenIdGenerator),
      ForetEffectKeys.for013: _for013(),
      ForetEffectKeys.for014: _for014(),
      ForetEffectKeys.for015: _for015(tokenIdGenerator),
    };
  }

  static ChainEffectDefinition _for001(ForetTokenIdGenerator ids) {
    return _FunctionalForetEffect(
      onCanActivate: (state, link) =>
          _sourceHasCode(state, link, 'FOR-001') &&
          link.payload['trigger'] == 'sent_from_field_to_graveyard' &&
          _hasFreeCharacterZone(state, link.activatingPlayer),
      onResolve: (state, link) =>
          _createSylveTokens(state, link.activatingPlayer, 1, ids).state,
    );
  }

  static ChainEffectDefinition _for002() {
    const usageKey = '${ForetEffectKeys.for002}:life_gained';
    return _FunctionalForetEffect(
      onCanActivate: (state, link) {
        final source = _sourceCard(state, link);
        return source?.cardCode == 'FOR-002' &&
            link.payload['trigger'] == 'life_gained' &&
            (link.payload['amount'] as int? ?? 0) > 0 &&
            !_usedThisTurn(source!, usageKey, state.turnNumber);
      },
      onPayCost: (state, link) => _updateCatalogFieldCard(
        state,
        link.sourceCardInstanceId!,
        (card) => _markUsed(card, usageKey, state.turnNumber),
      ),
      onResolve: (state, link) => _addTemporaryModifier(
        state,
        link.sourceCardInstanceId!,
        RuntimeStatModifier(
          modifierId: '${ForetEffectKeys.for002}:${link.linkId}',
          atkDelta: 300,
          sourceCardInstanceId: link.sourceCardInstanceId,
          expiresAtTurn: state.turnNumber,
        ),
      ),
    );
  }

  static ChainEffectDefinition _for004() {
    const usageKey = '${ForetEffectKeys.for004}:token_created';
    return _FunctionalForetEffect(
      onCanActivate: (state, link) {
        final source = _sourceCard(state, link);
        if (source?.cardCode != 'FOR-004') return false;
        if (link.payload['trigger'] == 'on_summon') return true;
        return link.payload['trigger'] == 'token_created_on_own_field' &&
            !_usedThisTurn(source!, usageKey, state.turnNumber);
      },
      onPayCost: (state, link) {
        if (link.payload['trigger'] == 'on_summon') return state;
        return _updateCatalogFieldCard(
          state,
          link.sourceCardInstanceId!,
          (card) => _markUsed(card, usageKey, state.turnNumber),
        );
      },
      onResolve: (state, link) => _gainLifePoints(
        state,
        link.activatingPlayer,
        link.payload['trigger'] == 'on_summon' ? 500 : 200,
      ),
    );
  }

  static ChainEffectDefinition _for005() {
    // La permission d'attaque directe et la division des dégâts sont
    // consultées par DuelEngine au moment de la déclaration/résolution.
    return _FunctionalForetEffect(
      onCanActivate: (state, link) =>
          _sourceHasCode(state, link, 'FOR-005') &&
          link.payload['trigger'] == 'continuous_refresh',
      onResolve: (state, link) => state,
    );
  }

  static ChainEffectDefinition _for006() {
    const usageKey = '${ForetEffectKeys.for006}:prevent_destruction';
    return _FunctionalForetEffect(
      onCanActivate: (state, link) {
        final source = _sourceCard(state, link);
        final tokenId = link.payload['token_instance_id'] as String?;
        return source?.cardCode == 'FOR-006' &&
            link.payload['trigger'] == 'forest_card_would_be_destroyed' &&
            !_usedThisTurn(source!, usageKey, state.turnNumber) &&
            _isControlledToken(state, link.activatingPlayer, tokenId);
      },
      onTargetLegal: (state, link) {
        final target = _findCatalogFieldCard(
          state,
          link.target?.cardInstanceId,
        );
        return target != null &&
            target.card.controller == link.activatingPlayer &&
            target.card.hasFamily('forêt');
      },
      onPayCost: (state, link) {
        var next = _removeToken(
          state,
          link.activatingPlayer,
          link.payload['token_instance_id']! as String,
        );
        return _updateCatalogFieldCard(
          next,
          link.sourceCardInstanceId!,
          (card) => _markUsed(card, usageKey, state.turnNumber),
        );
      },
      onResolve: (state, link) => state.copyWith(
        preventedEffectDestructionInstanceIds: {
          ...state.preventedEffectDestructionInstanceIds,
          link.target!.cardInstanceId,
        },
      ),
    );
  }

  static ChainEffectDefinition _for007(ForetTokenIdGenerator ids) {
    return _FunctionalForetEffect(
      onCanActivate: (state, link) {
        if (!_sourceHasCode(state, link, 'FOR-007')) return false;
        final mode = link.payload['mode'];
        if (mode == 'continuous_refresh') return true;
        final requested = link.payload['token_count'] as int? ?? 0;
        return mode == 'on_summon' && requested >= 0 && requested <= 2;
      },
      onResolve: (state, link) {
        var next = state;
        if (link.payload['mode'] == 'on_summon') {
          final requested = link.payload['token_count'] as int? ?? 0;
          next = _createSylveTokens(
            next,
            link.activatingPlayer,
            requested,
            ids,
          ).state;
        }
        return _refreshElephantTokenAura(
          next,
          link.sourceCardInstanceId!,
          link.activatingPlayer,
        );
      },
    );
  }

  static ChainEffectDefinition _for008(ForetTokenIdGenerator ids) {
    return _FunctionalForetEffect(
      onCanActivate: (state, link) =>
          _sourceHasCode(state, link, 'FOR-008') &&
          _hasFreeCharacterZone(state, link.activatingPlayer),
      onResolve: (state, link) => _createSylveTokens(
        state,
        link.activatingPlayer,
        1,
        ids,
        cannotBeSacrificedTurn: state.turnNumber,
      ).state,
    );
  }

  static ChainEffectDefinition _for009(ForetTokenIdGenerator ids) {
    return _FunctionalForetEffect(
      onCanActivate: (state, link) {
        final source = _sourceCard(state, link);
        if (source?.cardCode != 'FOR-009') return false;
        final mode = link.payload['mode'];
        if (mode == 'preparation') {
          return state.currentPhase == DuelPhase.preparation &&
              state.activePlayer == link.activatingPlayer;
        }
        if (mode != 'create_token' && mode != 'gain_life') return false;
        if ((source!.counters['graine'] ?? 0) < 2) return false;
        return mode != 'create_token' ||
            _hasFreeCharacterZone(state, link.activatingPlayer);
      },
      onPayCost: (state, link) {
        if (link.payload['mode'] == 'preparation') return state;
        return _updateCatalogFieldCard(
          state,
          link.sourceCardInstanceId!,
          (card) => card.copyWith(counters: {
            ...card.counters,
            'graine': (card.counters['graine'] ?? 0) - 2,
          }),
        );
      },
      onResolve: (state, link) {
        final mode = link.payload['mode'];
        if (mode == 'preparation') {
          return _addCounter(
            state,
            link.sourceCardInstanceId!,
            'graine',
          );
        }
        if (mode == 'gain_life') {
          return _gainLifePoints(state, link.activatingPlayer, 500);
        }
        return _createSylveTokens(
          state,
          link.activatingPlayer,
          1,
          ids,
        ).state;
      },
    );
  }

  static ChainEffectDefinition _for010(ForetFusionSummonExtension extension) {
    return _FunctionalForetEffect(
      onCanActivate: _validFusionCost,
      onPayCost: (state, link) {
        var next = _sendCatalogCharacterToGraveyard(
          state,
          link.activatingPlayer,
          link.payload['iroko_instance_id']! as String,
        );
        for (final tokenId in _payloadIds(link, 'token_instance_ids')) {
          next = _removeToken(next, link.activatingPlayer, tokenId);
        }
        return next;
      },
      onResolve: (state, link) => extension.summonFromMythicReserve(
        state: state,
        participant: link.activatingPlayer,
        triggerCardCode: 'FOR-010',
        mythicCardCode: 'FOR-015',
      ),
    );
  }

  static ChainEffectDefinition _for011() {
    return _FunctionalForetEffect(
      onCanActivate: (state, link) =>
          _sourceHasCode(state, link, 'FOR-011') &&
          link.payload['trigger'] == 'opponent_attack_declared' &&
          link.payload['attack_declaration_id'] is String,
      onTargetLegal: (state, link) {
        final target = _findCharacter(state, link.target?.cardInstanceId);
        return target != null &&
            target.card.controller != link.activatingPlayer;
      },
      onResolve: (state, link) {
        var next = state.copyWith(
          cancelledAttackDeclarationIds: {
            ...state.cancelledAttackDeclarationIds,
            link.payload['attack_declaration_id']! as String,
          },
        );
        return _updateFieldCharacter(next, link.target!.cardInstanceId, (card) {
          if (card is CardInstance) {
            return card.copyWith(runtimeData: {
              ...card.runtimeData,
              CardRuntimeKeys.positionLockedTurn: state.turnNumber + 2,
            });
          }
          final token = card as TokenInstance;
          return token.copyWith(runtimeData: {
            ...token.runtimeData,
            CardRuntimeKeys.positionLockedTurn: state.turnNumber + 2,
          });
        });
      },
    );
  }

  static ChainEffectDefinition _for012(ForetTokenIdGenerator ids) {
    const usageKey = '${ForetEffectKeys.for012}:replacement_token';
    return _FunctionalForetEffect(
      onCanActivate: (state, link) {
        final source = _sourceCard(state, link);
        return source?.cardCode == 'FOR-012' &&
            link.payload['trigger'] == 'controlled_forest_destroyed' &&
            link.payload['destroyed_was_forest'] == true &&
            !_usedThisTurn(source!, usageKey, state.turnNumber) &&
            _hasFreeCharacterZone(state, link.activatingPlayer);
      },
      onPayCost: (state, link) => _updateCatalogFieldCard(
        state,
        link.sourceCardInstanceId!,
        (card) => _markUsed(card, usageKey, state.turnNumber),
      ),
      onResolve: (state, link) =>
          _createSylveTokens(state, link.activatingPlayer, 1, ids).state,
    );
  }

  static ChainEffectDefinition _for013() {
    return _FunctionalForetEffect(
      onCanActivate: (state, link) =>
          _sourceHasCode(state, link, 'FOR-013') &&
          link.payload['mode'] == 'continuous_refresh',
      onResolve: (state, link) => _refreshForestTerrainAura(
        state,
        link.sourceCardInstanceId!,
      ),
    );
  }

  static ChainEffectDefinition _for014() {
    const preparationKey = 'for_014_preparation_count';
    return _FunctionalForetEffect(
      onCanActivate: (state, link) {
        final source = _sourceCard(state, link);
        if (source?.cardCode != 'FOR-014') return false;
        if (link.payload['mode'] == 'activate') return true;
        if (link.payload['mode'] != 'preparation' ||
            state.currentPhase != DuelPhase.preparation ||
            state.activePlayer != link.activatingPlayer) {
          return false;
        }
        final nextCount =
            (source!.runtimeData[preparationKey] as int? ?? 0) + 1;
        if (nextCount < 3) return true;
        final selectedId = link.payload['selected_instance_id'] as String?;
        final field = _fieldFor(state, link.activatingPlayer);
        return field.characterZones.any((card) => card == null) &&
            field.deck.any((card) =>
                card.instanceId == selectedId &&
                card.category == CardCategory.character &&
                card.hasFamily('forêt') &&
                (card.rank == 7 || card.rank == 8));
      },
      onResolve: (state, link) {
        if (link.payload['mode'] == 'activate') {
          return _updateCatalogFieldCard(
            state,
            link.sourceCardInstanceId!,
            (card) => card.copyWith(
              faceUp: true,
              runtimeData: {...card.runtimeData, preparationKey: 0},
            ),
          );
        }
        final source = _sourceCard(state, link)!;
        final nextCount = (source.runtimeData[preparationKey] as int? ?? 0) + 1;
        if (nextCount < 3) {
          return _updateCatalogFieldCard(
            state,
            source.instanceId,
            (card) => card.copyWith(
              runtimeData: {...card.runtimeData, preparationKey: nextCount},
            ),
          );
        }
        var next = _sendActionTrapToGraveyard(state, source.instanceId);
        return _specialSummonForestFromDeck(
          next,
          link.activatingPlayer,
          link.payload['selected_instance_id']! as String,
        );
      },
    );
  }

  static ChainEffectDefinition _for015(ForetTokenIdGenerator ids) {
    const usageKey = '${ForetEffectKeys.for015}:sacrifice_token';
    return _FunctionalForetEffect(
      onCanActivate: (state, link) {
        final source = _sourceCard(state, link);
        if (source?.cardCode != 'FOR-015') return false;
        if (link.payload['mode'] == 'on_summon') {
          final count = link.payload['token_count'] as int? ?? 0;
          return count >= 0 && count <= 3;
        }
        return link.payload['mode'] == 'sacrifice_token' &&
            !_usedThisTurn(source!, usageKey, state.turnNumber) &&
            _isControlledToken(
              state,
              link.activatingPlayer,
              link.payload['token_instance_id'] as String?,
            );
      },
      onPayCost: (state, link) {
        if (link.payload['mode'] == 'on_summon') return state;
        var next = _removeToken(
          state,
          link.activatingPlayer,
          link.payload['token_instance_id']! as String,
        );
        return _updateCatalogFieldCard(
          next,
          link.sourceCardInstanceId!,
          (card) => _markUsed(card, usageKey, state.turnNumber),
        );
      },
      onResolve: (state, link) {
        if (link.payload['mode'] == 'on_summon') {
          return _createSylveTokens(
            state,
            link.activatingPlayer,
            link.payload['token_count'] as int? ?? 0,
            ids,
          ).state;
        }
        var next = _gainLifePoints(state, link.activatingPlayer, 800);
        return _addTemporaryModifier(
          next,
          link.sourceCardInstanceId!,
          RuntimeStatModifier(
            modifierId: '${ForetEffectKeys.for015}:${link.linkId}',
            atkDelta: 400,
            sourceCardInstanceId: link.sourceCardInstanceId,
            expiresAtTurn: state.turnNumber,
          ),
        );
      },
    );
  }
}

enum _ZoneKind { character, actionTrap, terrain }

final class _CatalogLocation {
  const _CatalogLocation(this.participant, this.kind, this.index, this.card);

  final DuelParticipant participant;
  final _ZoneKind kind;
  final int? index;
  final CardInstance card;
}

final class _CharacterLocation {
  const _CharacterLocation(this.participant, this.index, this.card);

  final DuelParticipant participant;
  final int index;
  final FieldCardInstance card;
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

_CatalogLocation? _findCatalogFieldCard(DuelState state, String? id) {
  if (id == null) return null;
  for (final participant in DuelParticipant.values) {
    final field = _fieldFor(state, participant);
    for (var i = 0; i < field.characterZones.length; i++) {
      final card = field.characterZones[i];
      if (card is CardInstance && card.instanceId == id) {
        return _CatalogLocation(participant, _ZoneKind.character, i, card);
      }
    }
    for (var i = 0; i < field.actionTrapZones.length; i++) {
      final card = field.actionTrapZones[i];
      if (card?.instanceId == id) {
        return _CatalogLocation(participant, _ZoneKind.actionTrap, i, card!);
      }
    }
    if (field.terrainZone?.instanceId == id) {
      return _CatalogLocation(
        participant,
        _ZoneKind.terrain,
        null,
        field.terrainZone!,
      );
    }
  }
  return null;
}

_CharacterLocation? _findCharacter(DuelState state, String? id) {
  if (id == null) return null;
  for (final participant in DuelParticipant.values) {
    final field = _fieldFor(state, participant);
    final index = field.characterZones.indexWhere(
      (card) => card?.instanceId == id,
    );
    if (index >= 0) {
      return _CharacterLocation(
          participant, index, field.characterZones[index]!);
    }
  }
  return null;
}

CardInstance? _sourceCard(DuelState state, ChainLink link) =>
    _findCatalogFieldCard(state, link.sourceCardInstanceId)?.card;

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

DuelState _updateCatalogFieldCard(
  DuelState state,
  String id,
  CardInstance Function(CardInstance card) update,
) {
  final location = _findCatalogFieldCard(state, id);
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

DuelState _updateFieldCharacter(
  DuelState state,
  String id,
  FieldCardInstance Function(FieldCardInstance card) update,
) {
  final location = _findCharacter(state, id);
  if (location == null) return state;
  final field = _fieldFor(state, location.participant);
  final zones = List<FieldCardInstance?>.from(field.characterZones)
    ..[location.index] = update(location.card);
  return _replaceField(
    state,
    location.participant,
    field.copyWith(characterZones: zones),
  );
}

DuelState _addCounter(DuelState state, String id, String type) =>
    _updateCatalogFieldCard(
      state,
      id,
      (card) => card.copyWith(counters: {
        ...card.counters,
        type: (card.counters[type] ?? 0) + 1,
      }),
    );

DuelState _addTemporaryModifier(
  DuelState state,
  String id,
  RuntimeStatModifier modifier,
) =>
    _updateCatalogFieldCard(
      state,
      id,
      (card) => card.copyWith(
        runtimeModifiers: [...card.runtimeModifiers, modifier],
      ),
    );

bool _usedThisTurn(CardInstance card, String key, int turn) =>
    card.effectUsageTurns[key] == turn;

CardInstance _markUsed(CardInstance card, String key, int turn) =>
    card.copyWith(
      effectUsageTurns: {...card.effectUsageTurns, key: turn},
    );

bool _hasFreeCharacterZone(DuelState state, DuelParticipant participant) =>
    _fieldFor(state, participant).characterZones.any((card) => card == null);

bool _isControlledToken(
  DuelState state,
  DuelParticipant participant,
  String? id,
) {
  final location = _findCharacter(state, id);
  if (location == null || location.card is! TokenInstance) return false;
  final token = location.card as TokenInstance;
  return token.controller == participant &&
      token.runtimeData[CardRuntimeKeys.cannotBeSacrificedTurn] !=
          state.turnNumber;
}

({DuelState state, List<String> tokenIds}) _createSylveTokens(
  DuelState state,
  DuelParticipant participant,
  int requested,
  ForetTokenIdGenerator ids, {
  int? cannotBeSacrificedTurn,
}) {
  var next = state;
  final created = <String>[];
  for (var sequence = 0; sequence < requested; sequence++) {
    final field = _fieldFor(next, participant);
    final zone = field.characterZones.indexWhere((card) => card == null);
    if (zone < 0) break;
    final id = ids(next, participant, sequence);
    final token = TokenInstance(
      instanceId: id,
      tokenKey: 'sylve',
      owner: participant,
      controller: participant,
      faceUp: true,
      position: BattlePosition.defense,
      atk: 500,
      def: 500,
      zoneIndex: zone,
      summonedTurn: state.turnNumber,
      runtimeData: cannotBeSacrificedTurn == null
          ? const {}
          : {
              CardRuntimeKeys.cannotBeSacrificedTurn: cannotBeSacrificedTurn,
            },
    );
    final zones = List<FieldCardInstance?>.from(field.characterZones)
      ..[zone] = token;
    next = _replaceField(
      next,
      participant,
      field.copyWith(characterZones: zones),
    );
    next = _applyActiveTokenAuras(next, participant, id);
    created.add(id);
  }
  return (state: next, tokenIds: created);
}

String _defaultTokenId(
  DuelState state,
  DuelParticipant participant,
  int sequence,
) {
  final occupied = DuelParticipant.values.fold<int>(
    0,
    (count, owner) =>
        count +
        _fieldFor(state, owner)
            .characterZones
            .where((card) => card != null)
            .length,
  );
  return 'sylve:${participant.name}:${state.turnNumber}:$occupied:$sequence';
}

DuelState _applyActiveTokenAuras(
  DuelState state,
  DuelParticipant participant,
  String tokenId,
) {
  final field = _fieldFor(state, participant);
  var next = state;
  for (final card in field.characterZones.whereType<CardInstance>()) {
    if (card.faceUp && card.cardCode == 'FOR-007') {
      next = _replaceTokenModifier(
        next,
        tokenId,
        card.instanceId,
        atkDelta: 0,
        defDelta: 300,
      );
    }
  }
  for (final owner in DuelParticipant.values) {
    final terrain = _fieldFor(state, owner).terrainZone;
    if (terrain?.faceUp == true && terrain?.cardCode == 'FOR-013') {
      next = _replaceTokenModifier(
        next,
        tokenId,
        terrain!.instanceId,
        atkDelta: 500,
        defDelta: 500,
      );
    }
  }
  return next;
}

DuelState _removeToken(
  DuelState state,
  DuelParticipant participant,
  String id,
) {
  final field = _fieldFor(state, participant);
  final index = field.characterZones.indexWhere(
    (card) => card is TokenInstance && card.instanceId == id,
  );
  if (index < 0) return state;
  final zones = List<FieldCardInstance?>.from(field.characterZones)
    ..[index] = null;
  return _replaceField(
    state,
    participant,
    field.copyWith(characterZones: zones),
  );
}

bool _validFusionCost(DuelState state, ChainLink link) {
  if (!_sourceHasCode(state, link, 'FOR-010')) return false;
  final material = _findCatalogFieldCard(
    state,
    link.payload['iroko_instance_id'] as String?,
  );
  final tokenIds = _payloadIds(link, 'token_instance_ids');
  return material != null &&
      material.kind == _ZoneKind.character &&
      material.card.controller == link.activatingPlayer &&
      material.card.cardCode == 'FOR-006' &&
      tokenIds.length == 2 &&
      tokenIds.toSet().length == 2 &&
      tokenIds.every(
        (id) => _isControlledToken(state, link.activatingPlayer, id),
      );
}

List<String> _payloadIds(ChainLink link, String key) {
  final value = link.payload[key];
  return value is List ? value.whereType<String>().toList() : const [];
}

DuelState _sendCatalogCharacterToGraveyard(
  DuelState state,
  DuelParticipant participant,
  String id,
) {
  final location = _findCatalogFieldCard(state, id)!;
  final field = _fieldFor(state, participant);
  final zones = List<FieldCardInstance?>.from(field.characterZones)
    ..[location.index!] = null;
  var next = _replaceField(
    state,
    participant,
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

DuelState _sendActionTrapToGraveyard(DuelState state, String id) {
  final location = _findCatalogFieldCard(state, id);
  if (location == null || location.kind != _ZoneKind.actionTrap) return state;
  final field = _fieldFor(state, location.participant);
  final zones = List<CardInstance?>.from(field.actionTrapZones)
    ..[location.index!] = null;
  var next = _replaceField(
    state,
    location.participant,
    field.copyWith(actionTrapZones: zones),
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

DuelState _specialSummonForestFromDeck(
  DuelState state,
  DuelParticipant participant,
  String id,
) {
  final field = _fieldFor(state, participant);
  final deckIndex = field.deck.indexWhere((card) => card.instanceId == id);
  final zoneIndex = field.characterZones.indexWhere((card) => card == null);
  if (deckIndex < 0 || zoneIndex < 0) return state;
  final deck = List<CardInstance>.from(field.deck);
  final summoned = deck.removeAt(deckIndex).copyWith(
    controller: participant,
    faceUp: true,
    position: BattlePosition.attack,
    zoneIndex: zoneIndex,
    summonedTurn: state.turnNumber,
    attackedThisTurn: false,
    positionChangedThisTurn: false,
    runtimeData: {
      CardRuntimeKeys.effectsNegatedUntilTurn: state.turnNumber,
    },
  );
  final zones = List<FieldCardInstance?>.from(field.characterZones)
    ..[zoneIndex] = summoned;
  return _replaceField(
    state,
    participant,
    field.copyWith(deck: deck, characterZones: zones),
  );
}

DuelState _refreshElephantTokenAura(
  DuelState state,
  String sourceId,
  DuelParticipant participant,
) {
  final source = _findCatalogFieldCard(state, sourceId);
  if (source == null || !source.card.faceUp) return state;
  var next = state;
  final field = _fieldFor(next, participant);
  for (final token in field.characterZones.whereType<TokenInstance>()) {
    next = _replaceTokenModifier(
      next,
      token.instanceId,
      sourceId,
      atkDelta: 0,
      defDelta: 300,
    );
  }
  return next;
}

DuelState _refreshForestTerrainAura(DuelState state, String sourceId) {
  final source = _findCatalogFieldCard(state, sourceId);
  if (source == null ||
      source.kind != _ZoneKind.terrain ||
      !source.card.faceUp) {
    return state;
  }
  var next = state;
  for (final participant in DuelParticipant.values) {
    final field = _fieldFor(next, participant);
    for (final character in field.characterZones) {
      if (character is CardInstance && character.hasFamily('forêt')) {
        next = _replaceCatalogModifier(
          next,
          character.instanceId,
          sourceId,
          atkDelta: 200,
          defDelta: 200,
        );
      } else if (character is TokenInstance && character.tokenKey == 'sylve') {
        next = _replaceTokenModifier(
          next,
          character.instanceId,
          sourceId,
          atkDelta: 500,
          defDelta: 500,
        );
      }
    }
  }
  return next;
}

DuelState _replaceCatalogModifier(
  DuelState state,
  String id,
  String sourceId, {
  required int atkDelta,
  required int defDelta,
}) =>
    _updateCatalogFieldCard(
      state,
      id,
      (card) => card.copyWith(runtimeModifiers: [
        ...card.runtimeModifiers.where(
          (modifier) => modifier.sourceCardInstanceId != sourceId,
        ),
        RuntimeStatModifier(
          modifierId: 'forest-aura:$sourceId',
          atkDelta: atkDelta,
          defDelta: defDelta,
          sourceCardInstanceId: sourceId,
        ),
      ]),
    );

DuelState _replaceTokenModifier(
  DuelState state,
  String id,
  String sourceId, {
  required int atkDelta,
  required int defDelta,
}) =>
    _updateFieldCharacter(state, id, (card) {
      final token = card as TokenInstance;
      return token.copyWith(runtimeModifiers: [
        ...token.runtimeModifiers.where(
          (modifier) => modifier.sourceCardInstanceId != sourceId,
        ),
        RuntimeStatModifier(
          modifierId: 'forest-token-aura:$sourceId',
          atkDelta: atkDelta,
          defDelta: defDelta,
          sourceCardInstanceId: sourceId,
        ),
      ]);
    });

DuelState _gainLifePoints(
  DuelState state,
  DuelParticipant participant,
  int amount,
) =>
    participant == DuelParticipant.player
        ? state.copyWith(playerLifePoints: state.playerLifePoints + amount)
        : state.copyWith(aiLifePoints: state.aiLifePoints + amount);

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
