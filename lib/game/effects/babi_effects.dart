import 'manual_activation_options.dart';
import '../battle_state.dart';
import '../card.dart';
import '../duel_engine.dart';
import '../duel_types.dart';
import '../mythic_summon.dart';
import '../player.dart';

abstract final class BabiEffectKeys {
  static const bab001 = 'bab_001_apprenti_du_gbaka';
  static const bab002 = 'bab_002_messagere_woro_woro';
  static const bab004 = 'bab_004_danseuse_des_neons';
  static const bab005 = 'bab_005_hacker_du_marche';
  static const bab006 = 'bab_006_champion_du_bitume';
  static const bab007 = 'bab_007_reine_du_plateau';
  static const bab008 = 'bab_008_trajet_express';
  static const bab009 = 'bab_009_reseau_sature';
  static const bab010 = 'bab_010_battement_de_la_ville';
  static const bab011 = 'bab_011_feu_rouge_mystique';
  static const bab012 = 'bab_012_coupure_de_courant';
  static const bab013 = 'bab_013_abidjan_minuit';
  static const bab014 = 'bab_014_smartphone_des_ancetres';
  static const bab015 = 'bab_015_genie_d_abidjan_coeur_electrique';
}

/// Point d'extension de la Phase 4.6.
///
/// BAB-010 paie et valide ses deux matériels ici, puis délègue l'invocation
/// spéciale sans connaître son implémentation.
abstract interface class BabiFusionSummonExtension {
  DuelState summonFromMythicReserve({
    required DuelState state,
    required DuelParticipant participant,
    required String triggerCardCode,
    required String mythicCardCode,
  });
}

final class DefaultBabiFusionSummonExtension
    implements BabiFusionSummonExtension {
  const DefaultBabiFusionSummonExtension();

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

typedef _StateCallback = DuelState Function(DuelState state, ChainLink link);
typedef _LegalityCallback = bool Function(DuelState state, ChainLink link);
typedef _PrepareCallback = ChainLink Function(DuelState state, ChainLink link);
typedef _PendingEventsCallback = Iterable<PendingDuelEvent> Function(
  DuelState state,
  ChainLink link,
);

final class _FunctionalBabiEffect extends ChainEffectDefinition {
  const _FunctionalBabiEffect({
    this.onManualActivations,
    required this.onResolve,
    this.onCanActivate,
    this.onTargetLegal,
    this.onPayCost,
    this.onPrepare,
    this.onPendingEvents,
  });

  final _StateCallback onResolve;
  final _LegalityCallback? onCanActivate;
  final _LegalityCallback? onTargetLegal;
  final _StateCallback? onPayCost;
  final _PrepareCallback? onPrepare;
  final _PendingEventsCallback? onPendingEvents;

  final ManualActivationBuilder? onManualActivations;
  @override
  Iterable<ManualActivationOption> buildManualActivations(
          ManualActivationRequest request) =>
      onManualActivations?.call(request) ?? const [];

  @override
  ChainLink prepareLink(DuelState state, ChainLink link) {
    return onPrepare?.call(state, link) ?? link;
  }

  @override
  Iterable<PendingDuelEvent> pendingEvents(DuelState state, ChainLink link) =>
      onPendingEvents?.call(state, link) ?? const [];

  @override
  bool canActivate(DuelState state, ChainLink link) {
    return onCanActivate?.call(state, link) ?? true;
  }

  @override
  bool isTargetLegal(DuelState state, ChainLink link) {
    return onTargetLegal?.call(state, link) ?? link.target == null;
  }

  @override
  DuelState payCost(DuelState state, ChainLink link) {
    return onPayCost?.call(state, link) ?? state;
  }

  @override
  DuelState resolve(DuelState state, ChainLink link) {
    return onResolve(state, link);
  }
}

final class BabiEffectRegistry {
  const BabiEffectRegistry._();

  static Map<String, ChainEffectDefinition> create({
    BabiFusionSummonExtension fusionExtension =
        const DefaultBabiFusionSummonExtension(),
  }) {
    return {
      BabiEffectKeys.bab001: _bab001(),
      BabiEffectKeys.bab002: _bab002(),
      BabiEffectKeys.bab004: _bab004(),
      BabiEffectKeys.bab005: _bab005(),
      BabiEffectKeys.bab006: _bab006(),
      BabiEffectKeys.bab007: _bab007(),
      BabiEffectKeys.bab008: _bab008(),
      BabiEffectKeys.bab009: _bab009(),
      BabiEffectKeys.bab010: _bab010(fusionExtension),
      BabiEffectKeys.bab011: _bab011(),
      BabiEffectKeys.bab012: _bab012(),
      BabiEffectKeys.bab013: _bab013(),
      BabiEffectKeys.bab014: _bab014(),
      BabiEffectKeys.bab015: _bab015(),
    };
  }

  static ChainEffectDefinition _bab001() {
    return _FunctionalBabiEffect(
      onCanActivate: (state, link) =>
          _sourceHasCode(state, link, 'BAB-001') &&
          link.payload['trigger'] == 'on_summon' &&
          (link.payload['use_effect'] != true ||
              _canDrawThenDiscard(state, link)),
      onResolve: (state, link) {
        if (link.payload['use_effect'] != true) return state;
        return _drawThenDiscard(state, link);
      },
    );
  }

  static ChainEffectDefinition _bab002() {
    return _FunctionalBabiEffect(
      onCanActivate: (state, link) =>
          _sourceHasCode(state, link, 'BAB-002') &&
          link.payload['trigger'] == 'on_summon',
      onTargetLegal: (state, link) {
        final sourceId = link.sourceCardInstanceId;
        final target = _findCard(state, link.target?.cardInstanceId);
        return sourceId != null &&
            target != null &&
            target.card.instanceId != sourceId &&
            target.kind == _ZoneKind.character &&
            target.card.controller == link.activatingPlayer &&
            target.card.position != null;
      },
      onResolve: (state, link) {
        return _updateCard(
          state,
          link.target!.cardInstanceId,
          (card) => card.copyWith(
            faceUp: true,
            position: card.position == BattlePosition.attack
                ? BattlePosition.defense
                : BattlePosition.attack,
            positionChangedThisTurn: true,
          ),
        );
      },
    );
  }

  static ChainEffectDefinition _bab004() {
    const usageKey = '${BabiEffectKeys.bab004}:quick_trigger';
    return _FunctionalBabiEffect(
      onCanActivate: (state, link) {
        final source = _sourceCard(state, link);
        return source?.cardCode == 'BAB-004' &&
            link.payload['trigger'] == 'quick_action_activated' &&
            !_usedThisTurn(source!, usageKey, state.turnNumber);
      },
      onResolve: (state, link) {
        return _updateCard(state, link.sourceCardInstanceId!, (card) {
          return _markUsed(
            card.copyWith(
              runtimeModifiers: [
                ...card.runtimeModifiers,
                RuntimeStatModifier(
                  modifierId: '$usageKey:${state.turnNumber}',
                  atkDelta: 300,
                  sourceCardInstanceId: card.instanceId,
                  expiresAtTurn: state.turnNumber,
                  expiresAfterPhase: DuelPhase.end,
                ),
              ],
            ),
            usageKey,
            state.turnNumber,
          );
        });
      },
    );
  }

  static ChainEffectDefinition _bab005() {
    return _FunctionalBabiEffect(
      onCanActivate: (state, link) =>
          _sourceHasCode(state, link, 'BAB-005') &&
          link.payload['trigger'] == 'on_summon',
      onTargetLegal: (state, link) {
        final target = _findCard(state, link.target?.cardInstanceId);
        return target != null &&
            target.kind == _ZoneKind.actionTrap &&
            target.participant != link.activatingPlayer &&
            !target.card.faceUp;
      },
      onResolve: (state, link) {
        final viewer = _fieldFor(state, link.activatingPlayer);
        var nextState = _replaceField(
          state,
          link.activatingPlayer,
          viewer.copyWith(
            revealedCardInstanceIds: {
              ...viewer.revealedCardInstanceIds,
              link.target!.cardInstanceId,
            },
          ),
        );
        if (link.payload['return_to_hand'] == true) {
          nextState = _moveToHand(nextState, link.target!.cardInstanceId);
        }
        return nextState;
      },
    );
  }

  static ChainEffectDefinition _bab006() {
    const usageKey = '${BabiEffectKeys.bab006}:combat_destroy';
    return _FunctionalBabiEffect(
      onCanActivate: (state, link) {
        final source = _sourceCard(state, link);
        return source?.cardCode == 'BAB-006' &&
            link.payload['trigger'] == 'destroyed_character_in_combat' &&
            !_usedThisTurn(source!, usageKey, state.turnNumber) &&
            _canDrawThenDiscard(state, link);
      },
      onResolve: (state, link) {
        var nextState = _drawThenDiscard(state, link);
        if (!nextState.isFinished) {
          nextState = _updateCard(
            nextState,
            link.sourceCardInstanceId!,
            (card) => _markUsed(card, usageKey, state.turnNumber),
          );
        }
        return nextState;
      },
    );
  }

  static ChainEffectDefinition _bab007() {
    const usageKey = '${BabiEffectKeys.bab007}:direct_attack';
    return _FunctionalBabiEffect(
      onCanActivate: (state, link) {
        final source = _sourceCard(state, link);
        return source?.cardCode == 'BAB-007' &&
            !_usedThisTurn(source!, usageKey, state.turnNumber);
      },
      onTargetLegal: (state, link) {
        final target = _findCard(state, link.target?.cardInstanceId);
        return target != null &&
            target.card.instanceId != link.sourceCardInstanceId &&
            target.card.controller == link.activatingPlayer &&
            target.card.hasFamily('babi');
      },
      onResolve: (state, link) {
        var nextState = _moveToHand(state, link.target!.cardInstanceId);
        nextState = _updateCard(
          nextState,
          link.sourceCardInstanceId!,
          (card) => _markUsed(
            card.copyWith(
              runtimeData: {
                ...card.runtimeData,
                CardRuntimeKeys.directAttackAllowedTurn: state.turnNumber,
                CardRuntimeKeys.directAttackDamageDivisor: 2,
              },
            ),
            usageKey,
            state.turnNumber,
          ),
        );
        return nextState;
      },
    );
  }

  static ChainEffectDefinition _bab008() {
    const terrainUsageKey = '${BabiEffectKeys.bab013}:quick_protection';
    return _FunctionalBabiEffect(
      onManualActivations: (request) sync* {
        final ownCharacters = request.ownCharacters;
        final option = request.option;
        for (final target in ownCharacters.where((c) => c.hasFamily('babi'))) {
          yield option(
              target: ChainTarget(cardInstanceId: target.instanceId),
              description: 'Changer la position de ${target.cardCode}',
              suffix: target.instanceId);
        }
      },
      onPrepare: (state, link) {
        final terrain = _activeAbidjanMinuit(state, link.activatingPlayer);
        if (terrain != null &&
            !_usedThisTurn(terrain, terrainUsageKey, state.turnNumber)) {
          return link.copyWith(protectedFromSpeed2Negation: true);
        }
        return link;
      },
      onCanActivate: (state, link) => link.speed == ChainSpeed.speed2,
      onTargetLegal: (state, link) {
        final target = _findCard(state, link.target?.cardInstanceId);
        return target != null &&
            target.kind == _ZoneKind.character &&
            target.card.controller == link.activatingPlayer &&
            target.card.hasFamily('babi') &&
            target.card.position != null;
      },
      onPayCost: (state, link) {
        if (!link.protectedFromSpeed2Negation) return state;
        final terrain = _activeAbidjanMinuit(state, link.activatingPlayer)!;
        return _updateCard(
          state,
          terrain.instanceId,
          (card) => _markUsed(card, terrainUsageKey, state.turnNumber),
        );
      },
      onResolve: (state, link) {
        return _updateCard(state, link.target!.cardInstanceId, (card) {
          final newPosition = card.position == BattlePosition.attack
              ? BattlePosition.defense
              : BattlePosition.attack;
          final modifiers = [...card.runtimeModifiers];
          if (newPosition == BattlePosition.attack) {
            modifiers.add(
              RuntimeStatModifier(
                modifierId:
                    '${BabiEffectKeys.bab008}:${link.linkId}:${state.turnNumber}',
                atkDelta: 300,
                sourceCardInstanceId: link.sourceCardInstanceId,
                expiresAtTurn: state.turnNumber,
                expiresAfterPhase: DuelPhase.end,
              ),
            );
          }
          return card.copyWith(
            faceUp: true,
            position: newPosition,
            positionChangedThisTurn: true,
            runtimeModifiers: modifiers,
          );
        });
      },
    );
  }

  static ChainEffectDefinition _bab009() {
    return _FunctionalBabiEffect(
      onManualActivations: (request) sync* {
        final enemy = request.enemy;
        final option = request.option;
        for (final target in enemy.actionTrapZones
            .whereType<CardInstance>()
            .where((card) => !card.faceUp)) {
          yield option(
            target: ChainTarget(cardInstanceId: target.instanceId),
            description: 'Renvoyer la carte posée ${target.cardCode}',
            suffix: target.instanceId,
          );
        }
      },
      onTargetLegal: (state, link) {
        final target = _findCard(state, link.target?.cardInstanceId);
        return target != null &&
            target.kind == _ZoneKind.actionTrap &&
            target.participant != link.activatingPlayer &&
            !target.card.faceUp;
      },
      onResolve: (state, link) =>
          _moveToHand(state, link.target!.cardInstanceId),
    );
  }

  static ChainEffectDefinition _bab010(
    BabiFusionSummonExtension fusionExtension,
  ) {
    return _FunctionalBabiEffect(
      onManualActivations: (request) sync* {
        final ownCharacters = request.ownCharacters;
        final option = request.option;
        final messenger = ownCharacters
            .where((card) => card.cardCode == 'BAB-002')
            .firstOrNull;
        final champion = ownCharacters
            .where((card) => card.cardCode == 'BAB-006')
            .firstOrNull;
        if (messenger != null && champion != null) {
          yield option(
            payload: {
              'material_instance_ids': [
                messenger.instanceId,
                champion.instanceId,
              ],
            },
            description: 'Envoyer les deux matériaux Fusion au Cimetière',
          );
        }
      },
      onCanActivate: _hasFusionMaterials,
      onPayCost: (state, link) {
        var nextState = state;
        for (final materialId in _payloadIds(link, 'material_instance_ids')) {
          nextState = _moveToGraveyard(nextState, materialId);
        }
        return nextState;
      },
      onResolve: (state, link) {
        return fusionExtension.summonFromMythicReserve(
          state: state,
          participant: link.activatingPlayer,
          triggerCardCode: 'BAB-010',
          mythicCardCode: 'BAB-015',
        );
      },
    );
  }

  static ChainEffectDefinition _bab011() {
    return _FunctionalBabiEffect(
      onManualActivations: (request) sync* {
        final attack = request.attack;
        final option = request.option;
        if (attack != null) {
          yield option(payload: {
            'trigger': 'attack_declared',
            'attack_declaration_id': attack.declarationId,
            'attacker_instance_id': attack.attackerInstanceId
          }, description: 'Annuler l’attaque', suffix: attack.declarationId);
        }
      },
      onCanActivate: (state, link) =>
          link.payload['trigger'] == 'attack_declared' &&
          link.payload['attack_declaration_id'] is String,
      onTargetLegal: (state, link) {
        final attackerId = link.payload['attacker_instance_id'] as String?;
        final attacker = _findCard(state, attackerId);
        return attacker != null &&
            attacker.kind == _ZoneKind.character &&
            attacker.card.controller != link.activatingPlayer;
      },
      onResolve: (state, link) {
        final declarationId = link.payload['attack_declaration_id']! as String;
        var nextState = state.copyWith(
          cancelledAttackDeclarationIds: {
            ...state.cancelledAttackDeclarationIds,
            declarationId,
          },
        );
        nextState = _updateCard(
          nextState,
          link.payload['attacker_instance_id']! as String,
          (card) {
            final canChange = card.position == BattlePosition.attack &&
                !card.positionChangedThisTurn;
            return card.copyWith(
              position: canChange ? BattlePosition.defense : card.position,
              positionChangedThisTurn:
                  canChange || card.positionChangedThisTurn,
              attackedThisTurn: true,
            );
          },
        );
        return nextState;
      },
    );
  }

  static ChainEffectDefinition _bab012() {
    return _FunctionalBabiEffect(
      onManualActivations: (request) sync* {
        final state = request.state;
        final own = request.own;
        final last = request.last;
        final option = request.option;
        if (last != null &&
            request.sourceCard(state, last)?.category == CardCategory.action) {
          for (final discard in own.hand) {
            yield option(
                payload: {
                  'target_link_id': last.linkId,
                  'discard_instance_id': discard.instanceId
                },
                description: 'Défausser ${discard.cardCode} et annuler',
                suffix: discard.instanceId);
          }
        }
      },
      onPendingEvents: (state, link) {
        final sourceId = _targetedChainLink(state, link)?.sourceCardInstanceId;
        return sourceId == null
            ? const []
            : [
                EffectDestructionPending(
                  sourceLinkId: link.linkId,
                  cardInstanceId: sourceId,
                ),
              ];
      },
      onCanActivate: (state, link) {
        final targetLink = _targetedChainLink(state, link);
        final discardId = link.payload['discard_instance_id'] as String?;
        final field = _fieldFor(state, link.activatingPlayer);
        return link.speed == ChainSpeed.speed3 &&
            targetLink != null &&
            _sourceCardForLink(state, targetLink)?.category ==
                CardCategory.action &&
            discardId != null &&
            field.hand.any((card) => card.instanceId == discardId);
      },
      onPayCost: (state, link) => _discardFromHand(
        state,
        link.activatingPlayer,
        link.payload['discard_instance_id']! as String,
      ),
      onResolve: (state, link) {
        final targetLink = _targetedChainLink(state, link)!;
        if (targetLink.protectedFromSpeed2Negation &&
            link.speed == ChainSpeed.speed2) {
          return state;
        }
        var nextState = state.copyWith(
          chain: state.chain.copyWith(
            negatedLinkIds: {
              ...state.chain.negatedLinkIds,
              targetLink.linkId,
            },
          ),
        );
        final sourceId = targetLink.sourceCardInstanceId;
        if (sourceId != null) {
          nextState = _moveToGraveyard(nextState, sourceId);
        }
        return nextState;
      },
    );
  }

  static ChainEffectDefinition _bab013() {
    return _FunctionalBabiEffect(
      onManualActivations: (request) sync* {
        final option = request.option;
        yield option(description: 'Activer le Terrain');
      },
      onCanActivate: (state, link) => _sourceHasCode(state, link, 'BAB-013'),
      onResolve: (state, link) {
        final sourceId = link.sourceCardInstanceId!;
        var nextState = state;
        for (final participant in DuelParticipant.values) {
          final field = _fieldFor(nextState, participant);
          final zones = field.characterZones.map((entry) {
            if (entry is! CardInstance || !entry.hasFamily('babi')) {
              return entry;
            }
            final modifierId = '${BabiEffectKeys.bab013}:$sourceId';
            return entry.copyWith(
              runtimeModifiers: [
                ...entry.runtimeModifiers
                    .where((modifier) => modifier.modifierId != modifierId),
                RuntimeStatModifier(
                  modifierId: modifierId,
                  atkDelta: 200,
                  defDelta: 200,
                  sourceCardInstanceId: sourceId,
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
      },
    );
  }

  static ChainEffectDefinition _bab014() {
    const usageKey = '${BabiEffectKeys.bab014}:inspect_top';
    return _FunctionalBabiEffect(
      onManualActivations: (request) sync* {
        final ownCharacters = request.ownCharacters;
        final option = request.option;
        for (final target in ownCharacters.where((c) => c.hasFamily('babi'))) {
          yield option(
            target: ChainTarget(cardInstanceId: target.instanceId),
            payload: const {'mode': 'equip'},
            description: 'Équiper ${target.cardCode}',
            suffix: target.instanceId,
          );
        }
      },
      onCanActivate: (state, link) {
        final source = _sourceCard(state, link);
        final mode = link.payload['mode'];
        if (source?.cardCode != 'BAB-014') return false;
        if (mode == 'equip') return true;
        return mode == 'inspect_top' &&
            !_usedThisTurn(source!, usageKey, state.turnNumber) &&
            _fieldFor(state, link.activatingPlayer).deck.isNotEmpty;
      },
      onTargetLegal: (state, link) {
        if (link.payload['mode'] == 'inspect_top') return link.target == null;
        final target = _findCard(state, link.target?.cardInstanceId);
        return target != null &&
            target.kind == _ZoneKind.character &&
            target.card.controller == link.activatingPlayer &&
            target.card.hasFamily('babi');
      },
      onResolve: (state, link) {
        if (link.payload['mode'] == 'equip') {
          return _updateCard(state, link.target!.cardInstanceId, (card) {
            return card.copyWith(
              attachedCardInstanceIds: {
                ...card.attachedCardInstanceIds,
                link.sourceCardInstanceId!,
              }.toList(),
            );
          });
        }

        final field = _fieldFor(state, link.activatingPlayer);
        final topCard = field.deck.first;
        final deck = List<CardInstance>.from(field.deck);
        if (link.payload['place_under_deck'] == true) {
          deck
            ..removeAt(0)
            ..add(topCard);
        }
        var nextState = _replaceField(
          state,
          link.activatingPlayer,
          field.copyWith(
            deck: deck,
            revealedCardInstanceIds: {
              ...field.revealedCardInstanceIds,
              topCard.instanceId,
            },
          ),
        );
        nextState = _updateCard(
          nextState,
          link.sourceCardInstanceId!,
          (card) => _markUsed(card, usageKey, state.turnNumber),
        );
        return nextState;
      },
    );
  }

  static ChainEffectDefinition _bab015() {
    const usageKey = '${BabiEffectKeys.bab015}:quick_trigger';
    return _FunctionalBabiEffect(
      onCanActivate: (state, link) {
        final source = _sourceCard(state, link);
        if (source?.cardCode != 'BAB-015') return false;
        final trigger = link.payload['trigger'];
        if (trigger == 'on_summon') {
          final ids = _payloadIds(link, 'target_instance_ids');
          return ids.length <= 2 &&
              ids.toSet().length == ids.length &&
              ids.every((id) => _isSetOpponentActionTrap(state, link, id));
        }
        return trigger == 'quick_action_activated' &&
            !_usedThisTurn(source!, usageKey, state.turnNumber);
      },
      onResolve: (state, link) {
        if (link.payload['trigger'] == 'on_summon') {
          var nextState = state;
          for (final id in _payloadIds(link, 'target_instance_ids')) {
            if (_isSetOpponentActionTrap(nextState, link, id)) {
              nextState = _moveToHand(nextState, id);
            }
          }
          return nextState;
        }
        return _updateCard(state, link.sourceCardInstanceId!, (card) {
          return _markUsed(
            card.copyWith(
              runtimeModifiers: [
                ...card.runtimeModifiers,
                RuntimeStatModifier(
                  modifierId: '$usageKey:${state.turnNumber}',
                  atkDelta: 500,
                  sourceCardInstanceId: card.instanceId,
                  expiresAtTurn: state.turnNumber,
                  expiresAfterPhase: DuelPhase.end,
                ),
              ],
            ),
            usageKey,
            state.turnNumber,
          );
        });
      },
    );
  }
}

enum _ZoneKind { character, actionTrap, terrain }

final class _CardLocation {
  const _CardLocation({
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

_CardLocation? _findCard(DuelState state, String? instanceId) {
  if (instanceId == null) return null;
  for (final participant in DuelParticipant.values) {
    final field = _fieldFor(state, participant);
    for (var index = 0; index < field.characterZones.length; index++) {
      final entry = field.characterZones[index];
      if (entry is CardInstance && entry.instanceId == instanceId) {
        return _CardLocation(
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
        return _CardLocation(
          participant: participant,
          kind: _ZoneKind.actionTrap,
          index: index,
          card: entry,
        );
      }
    }
    final terrain = field.terrainZone;
    if (terrain != null && terrain.instanceId == instanceId) {
      return _CardLocation(
        participant: participant,
        kind: _ZoneKind.terrain,
        index: null,
        card: terrain,
      );
    }
  }
  return null;
}

CardInstance? _sourceCard(DuelState state, ChainLink link) {
  return _findCard(state, link.sourceCardInstanceId)?.card;
}

bool _sourceHasCode(DuelState state, ChainLink link, String code) {
  return _sourceCard(state, link)?.cardCode == code;
}

DuelState _updateCard(
  DuelState state,
  String instanceId,
  CardInstance Function(CardInstance card) update,
) {
  final location = _findCard(state, instanceId);
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

DuelState _removeFromField(DuelState state, _CardLocation location) {
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

DuelState _moveToHand(DuelState state, String instanceId) {
  final location = _findCard(state, instanceId);
  if (location == null) return state;
  var nextState = _removeFromField(state, location);
  final ownerField = _fieldFor(nextState, location.card.owner);
  final handCard = location.card.copyWith(
    controller: location.card.owner,
    faceUp: false,
    position: null,
    zoneIndex: null,
  );
  return _replaceField(
    nextState,
    location.card.owner,
    ownerField.copyWith(hand: [...ownerField.hand, handCard]),
  );
}

DuelState _moveToGraveyard(DuelState state, String instanceId) {
  final location = _findCard(state, instanceId);
  if (location == null) return state;
  var nextState = _removeFromField(state, location);
  final ownerField = _fieldFor(nextState, location.card.owner);
  final graveyardCard = location.card.copyWith(
    controller: location.card.owner,
    faceUp: true,
    position: null,
    zoneIndex: null,
  );
  return _replaceField(
    nextState,
    location.card.owner,
    ownerField.copyWith(
      graveyard: [...ownerField.graveyard, graveyardCard],
    ),
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
  final removedCard = hand.removeAt(index);
  final card = removedCard.copyWith(
    controller: removedCard.owner,
    faceUp: true,
    position: null,
    zoneIndex: null,
  );
  return _replaceField(
    state,
    participant,
    field.copyWith(hand: hand, graveyard: [...field.graveyard, card]),
  );
}

bool _canDrawThenDiscard(DuelState state, ChainLink link) {
  final field = _fieldFor(state, link.activatingPlayer);
  if (field.deck.isEmpty) return true;
  final discardId = link.payload['discard_instance_id'] as String?;
  if (discardId == null) return false;
  return field.hand.any((card) => card.instanceId == discardId) ||
      field.deck.first.instanceId == discardId;
}

DuelState _drawThenDiscard(DuelState state, ChainLink link) {
  final participant = link.activatingPlayer;
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
  var nextState = _replaceField(
    state,
    participant,
    field.copyWith(deck: deck, hand: [...field.hand, drawn]),
  );
  nextState = _discardFromHand(
    nextState,
    participant,
    link.payload['discard_instance_id']! as String,
  );
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

bool _hasFusionMaterials(DuelState state, ChainLink link) {
  final ids = _payloadIds(link, 'material_instance_ids');
  if (ids.length != 2 || ids.toSet().length != 2) return false;
  final cards = ids.map((id) => _findCard(state, id)).toList();
  if (cards.any((location) => location == null)) return false;
  if (cards.any(
    (location) =>
        location!.kind != _ZoneKind.character ||
        location.card.controller != link.activatingPlayer,
  )) {
    return false;
  }
  return cards.map((location) => location!.card.cardCode).toSet().containsAll(
    {'BAB-002', 'BAB-006'},
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

CardInstance? _sourceCardForLink(DuelState state, ChainLink link) {
  return _findCard(state, link.sourceCardInstanceId)?.card;
}

CardInstance? _activeAbidjanMinuit(
  DuelState state,
  DuelParticipant participant,
) {
  final terrain = _fieldFor(state, participant).terrainZone;
  return terrain?.cardCode == 'BAB-013' && terrain!.faceUp ? terrain : null;
}

bool _isSetOpponentActionTrap(
  DuelState state,
  ChainLink link,
  String instanceId,
) {
  final target = _findCard(state, instanceId);
  return target != null &&
      target.kind == _ZoneKind.actionTrap &&
      target.participant != link.activatingPlayer &&
      !target.card.faceUp;
}
