import 'manual_activation_options.dart';
import '../battle_state.dart';
import '../card.dart';
import '../duel_engine.dart';
import '../duel_types.dart';
import '../mythic_summon.dart';
import '../player.dart';

abstract final class MasqueEffectKeys {
  static const mas001 = 'mas_001_porte_masque_novice';
  static const mas002 = 'mas_002_danseur_aux_pas_croises';
  static const mas004 = 'mas_004_rieuse_aux_deux_visages';
  static const mas005 = 'mas_005_sculpteur_des_gestes_secrets';
  static const mas006 = 'mas_006_masque_dan_gardien_des_seuils';
  static const mas007 = 'mas_007_maitresse_du_ballet_invisible';
  static const mas008 = 'mas_008_changement_de_visage';
  static const mas009 = 'mas_009_danse_de_revelation';
  static const mas010 = 'mas_010_rythme_des_mille_visages';
  static const mas011 = 'mas_011_faux_mouvement';
  static const mas012 = 'mas_012_visage_interdit';
  static const mas013 = 'mas_013_place_des_danses_secretes';
  static const mas014 = 'mas_014_ciseau_du_maitre_sculpteur';
  static const mas015 = 'mas_015_masque_du_premier_rythme';
}

abstract interface class MasqueFusionSummonExtension {
  DuelState summonFromMythicReserve({
    required DuelState state,
    required DuelParticipant participant,
    required String triggerCardCode,
    required String mythicCardCode,
  });
}

final class DefaultMasqueFusionSummonExtension
    implements MasqueFusionSummonExtension {
  const DefaultMasqueFusionSummonExtension();

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
typedef _AutomaticTriggerBuilder = ChainLink? Function(
  DuelState state,
  CardInstance source,
  AutomaticEffectTrigger event,
  String linkId,
);
typedef _PendingEventsBuilder = Iterable<PendingDuelEvent> Function(
  DuelState state,
  ChainLink link,
);

final class _FunctionalMasqueEffect extends ChainEffectDefinition {
  const _FunctionalMasqueEffect({
    this.onManualActivations,
    this.onCanActivate,
    this.onPayCost,
    this.onTargetLegal,
    this.onAutomaticTrigger,
    this.onPendingEvents,
    required this.onResolve,
  });

  final _StateLinkPredicate? onCanActivate;
  final _StateLinkReducer? onPayCost;
  final _StateLinkPredicate? onTargetLegal;
  final _AutomaticTriggerBuilder? onAutomaticTrigger;
  final _PendingEventsBuilder? onPendingEvents;
  final _StateLinkReducer onResolve;

  final ManualActivationBuilder? onManualActivations;
  @override
  Iterable<ManualActivationOption> buildManualActivations(
          ManualActivationRequest request) =>
      onManualActivations?.call(request) ?? const [];

  @override
  ChainLink? createAutomaticTriggerLink({
    required DuelState state,
    required CardInstance source,
    required AutomaticEffectTrigger event,
    required String linkId,
  }) {
    return onAutomaticTrigger?.call(state, source, event, linkId);
  }

  @override
  bool canActivate(DuelState state, ChainLink link) {
    return onCanActivate?.call(state, link) ?? true;
  }

  @override
  Iterable<PendingDuelEvent> pendingEvents(DuelState state, ChainLink link) =>
      onPendingEvents?.call(state, link) ?? const [];

  @override
  DuelState payCost(DuelState state, ChainLink link) {
    return onPayCost?.call(state, link) ?? state;
  }

  @override
  bool isTargetLegal(DuelState state, ChainLink link) {
    return onTargetLegal?.call(state, link) ?? link.target == null;
  }

  @override
  DuelState resolve(DuelState state, ChainLink link) {
    return onResolve(state, link);
  }
}

final class MasqueEffectRegistry {
  const MasqueEffectRegistry._();

  static Map<String, ChainEffectDefinition> create({
    MasqueFusionSummonExtension fusionSummonExtension =
        const DefaultMasqueFusionSummonExtension(),
  }) {
    return {
      MasqueEffectKeys.mas001: _mas001(),
      MasqueEffectKeys.mas002: _mas002(),
      MasqueEffectKeys.mas004: _mas004(),
      MasqueEffectKeys.mas005: _mas005(),
      MasqueEffectKeys.mas006: _mas006(),
      MasqueEffectKeys.mas007: _mas007(),
      MasqueEffectKeys.mas008: _mas008(),
      MasqueEffectKeys.mas009: _mas009(),
      MasqueEffectKeys.mas010: _mas010(fusionSummonExtension),
      MasqueEffectKeys.mas011: _mas011(),
      MasqueEffectKeys.mas012: _mas012(),
      MasqueEffectKeys.mas013: _mas013(),
      MasqueEffectKeys.mas014: _mas014(),
      MasqueEffectKeys.mas015: _mas015(),
    };
  }

  static ChainEffectDefinition _mas001() {
    return _FunctionalMasqueEffect(
      onAutomaticTrigger: _buildAutomaticFlipTrigger,
      onCanActivate: (state, link) =>
          _sourceHasCode(state, link, 'MAS-001') &&
          link.payload['trigger'] == 'flipped_face_up' &&
          _canDrawThenDiscard(state, link),
      onResolve: _drawThenDiscard,
    );
  }

  static ChainEffectDefinition _mas002() {
    const usageKey = '${MasqueEffectKeys.mas002}:position';
    return _FunctionalMasqueEffect(
      onCanActivate: (state, link) {
        final source = _sourceCard(state, link);
        return source?.cardCode == 'MAS-002' &&
            source!.position != null &&
            !_usedThisTurn(source, usageKey, state.turnNumber);
      },
      onResolve: (state, link) => _updateFieldCard(
        state,
        link.sourceCardInstanceId!,
        (card) {
          final newPosition = card.position == BattlePosition.attack
              ? BattlePosition.defense
              : BattlePosition.attack;
          final modifiers = [...card.runtimeModifiers];
          if (newPosition == BattlePosition.defense) {
            modifiers.add(
              RuntimeStatModifier(
                modifierId: '$usageKey:${state.turnNumber}',
                defDelta: 300,
                sourceCardInstanceId: card.instanceId,
                expiresAtTurn: state.turnNumber,
                expiresAfterPhase: DuelPhase.end,
              ),
            );
          }
          return _markUsed(
            card.copyWith(
              position: newPosition,
              positionChangedThisTurn: true,
              runtimeModifiers: modifiers,
            ),
            usageKey,
            state.turnNumber,
          );
        },
      ),
    );
  }

  static ChainEffectDefinition _mas004() {
    return _FunctionalMasqueEffect(
      onAutomaticTrigger: _buildAutomaticFlipTrigger,
      onCanActivate: (state, link) =>
          _sourceHasCode(state, link, 'MAS-004') &&
          link.payload['trigger'] == 'flipped_face_up',
      onTargetLegal: (state, link) {
        final target = _findFieldCard(state, link.target?.cardInstanceId);
        return target != null &&
            target.kind == _ZoneKind.character &&
            target.card.controller != link.activatingPlayer &&
            target.card.faceUp &&
            target.card.effectiveAtk != null &&
            target.card.effectiveDef != null;
      },
      onResolve: (state, link) => _updateFieldCard(
        state,
        link.target!.cardInstanceId,
        (card) {
          final atk = card.effectiveAtk!;
          final def = card.effectiveDef!;
          return card.copyWith(
            runtimeModifiers: [
              ...card.runtimeModifiers,
              RuntimeStatModifier(
                modifierId: '${MasqueEffectKeys.mas004}:${link.linkId}',
                atkDelta: def - atk,
                defDelta: atk - def,
                sourceCardInstanceId: link.sourceCardInstanceId,
                expiresAtTurn: state.turnNumber,
                expiresAfterPhase: DuelPhase.end,
              ),
            ],
          );
        },
      ),
    );
  }

  static ChainEffectDefinition _mas005() {
    return _FunctionalMasqueEffect(
      onCanActivate: (state, link) {
        if (!_sourceHasCode(state, link, 'MAS-005') ||
            link.payload['trigger'] != 'on_summon') {
          return false;
        }
        if (link.payload['use_effect'] != true) return true;
        final selectedId = link.payload['selected_instance_id'] as String?;
        final field = _fieldFor(state, link.activatingPlayer);
        return selectedId != null &&
            field.characterZones.any((card) => card == null) &&
            field.hand.any(
              (card) =>
                  card.instanceId == selectedId &&
                  card.category == CardCategory.character &&
                  card.hasFamily('masque') &&
                  (card.rank ?? 99) <= 4,
            );
      },
      onResolve: (state, link) {
        if (link.payload['use_effect'] != true) return state;
        return _setCharacterFromHand(
          state,
          link.activatingPlayer,
          link.payload['selected_instance_id']! as String,
        );
      },
    );
  }

  static ChainEffectDefinition _mas006() {
    const usageKey = '${MasqueEffectKeys.mas006}:set_other';
    return _FunctionalMasqueEffect(
      onCanActivate: (state, link) {
        final source = _sourceCard(state, link);
        return source?.cardCode == 'MAS-006' &&
            link.payload['mode'] == 'set_other' &&
            !_usedThisTurn(source!, usageKey, state.turnNumber);
      },
      onTargetLegal: (state, link) {
        final target = _findFieldCard(state, link.target?.cardInstanceId);
        return target != null &&
            target.kind == _ZoneKind.character &&
            target.card.instanceId != link.sourceCardInstanceId &&
            target.card.controller == link.activatingPlayer &&
            target.card.hasFamily('masque') &&
            target.card.faceUp;
      },
      onResolve: (state, link) {
        var nextState = _turnFaceDownDefense(
          state,
          link.target!.cardInstanceId,
        );
        nextState = _updateFieldCard(
          nextState,
          link.sourceCardInstanceId!,
          (card) => _markUsed(card, usageKey, state.turnNumber),
        );
        return nextState;
      },
    );
  }

  static ChainEffectDefinition _mas007() {
    const usageKey = '${MasqueEffectKeys.mas007}:position';
    return _FunctionalMasqueEffect(
      onCanActivate: (state, link) {
        final source = _sourceCard(state, link);
        return source?.cardCode == 'MAS-007' &&
            !_usedThisTurn(source!, usageKey, state.turnNumber);
      },
      onTargetLegal: (state, link) {
        final target = _findFieldCard(state, link.target?.cardInstanceId);
        return target != null && target.kind == _ZoneKind.character;
      },
      onResolve: (state, link) {
        final targetId = link.target!.cardInstanceId;
        final original = _findFieldCard(state, targetId)!.card;
        final maySetAfter = original.controller == link.activatingPlayer &&
            original.hasFamily('masque');
        var nextState = _updateFieldCard(
          state,
          targetId,
          (card) => card.copyWith(
            faceUp: true,
            position: BattlePosition.defense,
            positionChangedThisTurn: true,
            runtimeData: card.faceUp
                ? card.runtimeData
                : {
                    ...card.runtimeData,
                    CardRuntimeKeys.flippedFaceUpTurn: state.turnNumber,
                  },
          ),
        );
        if (maySetAfter && link.payload['set_face_down_after'] == true) {
          nextState = _turnFaceDownDefense(nextState, targetId);
        }
        nextState = _updateFieldCard(
          nextState,
          link.sourceCardInstanceId!,
          (card) => _markUsed(card, usageKey, state.turnNumber),
        );
        return nextState;
      },
    );
  }

  static ChainEffectDefinition _mas008() {
    return _FunctionalMasqueEffect(
      onManualActivations: (request) sync* {
        final ownCharacters = request.ownCharacters;
        final option = request.option;
        for (final target
            in ownCharacters.where((c) => c.hasFamily('masque'))) {
          yield option(
              target: ChainTarget(cardInstanceId: target.instanceId),
              payload: {'turn_face_up': !target.faceUp},
              description: target.faceUp
                  ? 'Retourner ${target.cardCode} face cachée'
                  : 'Révéler ${target.cardCode}',
              suffix: target.instanceId);
        }
      },
      onCanActivate: (state, link) =>
          _sourceHasCode(state, link, 'MAS-008') &&
          link.payload['turn_face_up'] is bool,
      onPendingEvents: (state, link) =>
          link.payload['turn_face_up'] == true && link.target != null
              ? [
                  FaceDownRevealPending(
                    sourceLinkId: link.linkId,
                    cardInstanceIds: [link.target!.cardInstanceId],
                  ),
                ]
              : const [],
      onTargetLegal: (state, link) {
        final target = _findFieldCard(state, link.target?.cardInstanceId);
        return target != null &&
            target.kind == _ZoneKind.character &&
            target.card.controller == link.activatingPlayer &&
            target.card.hasFamily('masque');
      },
      onResolve: (state, link) {
        if (link.payload['turn_face_up'] == false) {
          return _turnFaceDownDefense(state, link.target!.cardInstanceId);
        }
        return _turnFaceUp(
          state,
          link.target!.cardInstanceId,
          state.turnNumber,
        );
      },
    );
  }

  static ChainEffectDefinition _mas009() {
    return _FunctionalMasqueEffect(
      onPendingEvents: (state, link) => [
        FaceDownRevealPending(
          sourceLinkId: link.linkId,
          cardInstanceIds: _payloadIds(link, 'reveal_instance_ids'),
        ),
      ],
      onCanActivate: (state, link) {
        if (!_sourceHasCode(state, link, 'MAS-009')) return false;
        final ids = _payloadIds(link, 'reveal_instance_ids');
        return ids.length <= 2 &&
            ids.toSet().length == ids.length &&
            ids.every((id) {
              final card = _findFieldCard(state, id);
              return card != null &&
                  card.kind == _ZoneKind.character &&
                  !card.card.faceUp;
            });
      },
      onResolve: (state, link) {
        var nextState = state;
        for (final id in _payloadIds(link, 'reveal_instance_ids')) {
          final card = _findFieldCard(nextState, id);
          if (card != null && !card.card.faceUp) {
            nextState = _turnFaceUp(nextState, id, state.turnNumber);
          }
        }
        return nextState;
      },
    );
  }

  static ChainEffectDefinition _mas010(
    MasqueFusionSummonExtension fusionSummonExtension,
  ) {
    return _FunctionalMasqueEffect(
      onCanActivate: _hasFusionMaterials,
      onPayCost: (state, link) {
        var nextState = state;
        for (final id in _payloadIds(link, 'material_instance_ids')) {
          nextState = _sendFieldCardToGraveyard(nextState, id);
        }
        return nextState;
      },
      onResolve: (state, link) {
        return fusionSummonExtension.summonFromMythicReserve(
          state: state,
          participant: link.activatingPlayer,
          triggerCardCode: 'MAS-010',
          mythicCardCode: 'MAS-015',
        );
      },
    );
  }

  static ChainEffectDefinition _mas011() {
    return _FunctionalMasqueEffect(
      onManualActivations: (request) sync* {
        final ownCharacters = request.ownCharacters;
        final attack = request.attack;
        final option = request.option;
        if (attack != null) {
          final attacked = ownCharacters
              .where(
                  (c) => c.instanceId == attack.targetInstanceId && !c.faceUp)
              .firstOrNull;
          if (attacked != null) {
            final alternatives = ownCharacters
                .where((c) => c.instanceId != attacked.instanceId)
                .toList();
            if (alternatives.isEmpty) {
              yield option(
                  target: ChainTarget(cardInstanceId: attacked.instanceId),
                  payload: {
                    'trigger': 'face_down_character_attacked',
                    'attack_declaration_id': attack.declarationId,
                    'new_target_instance_id': null
                  },
                  description: 'Activer Faux Mouvement',
                  suffix: attack.declarationId);
            }
            for (final replacement in alternatives) {
              yield option(
                  target: ChainTarget(cardInstanceId: attacked.instanceId),
                  payload: {
                    'trigger': 'face_down_character_attacked',
                    'attack_declaration_id': attack.declarationId,
                    'new_target_instance_id': replacement.instanceId
                  },
                  description: 'Rediriger vers ${replacement.cardCode}',
                  suffix: replacement.instanceId);
            }
          }
        }
      },
      onCanActivate: (state, link) =>
          _sourceHasCode(state, link, 'MAS-011') &&
          link.payload['trigger'] == 'face_down_character_attacked' &&
          link.payload['attack_declaration_id'] is String,
      onTargetLegal: (state, link) {
        final attacked = _findFieldCard(state, link.target?.cardInstanceId);
        if (attacked == null ||
            attacked.kind != _ZoneKind.character ||
            attacked.card.controller != link.activatingPlayer ||
            attacked.card.faceUp) {
          return false;
        }
        final alternatives = _fieldFor(state, link.activatingPlayer)
            .characterZones
            .whereType<CardInstance>()
            .where((card) => card.instanceId != attacked.card.instanceId)
            .toList();
        final newTargetId = link.payload['new_target_instance_id'] as String?;
        if (alternatives.isEmpty) return newTargetId == null;
        return alternatives.any((card) => card.instanceId == newTargetId);
      },
      onResolve: (state, link) {
        final newTargetId = link.payload['new_target_instance_id'] as String?;
        if (newTargetId == null) return state;
        return state.copyWith(
          attackTargetOverrides: {
            ...state.attackTargetOverrides,
            link.payload['attack_declaration_id']! as String: newTargetId,
          },
        );
      },
    );
  }

  static ChainEffectDefinition _mas012() {
    return _FunctionalMasqueEffect(
      onManualActivations: (request) sync* {
        final state = request.state;
        final participant = request.participant;
        final effectiveContext = request.context;
        final last = request.last;
        final option = request.option;
        if (last != null && last.activatingPlayer != participant) {
          final reveal = effectiveContext.firstEvent<FaceDownRevealPending>();
          final threatenedIds = reveal?.cardInstanceIds.where((id) {
                final card = request.findCard(state, id);
                return card != null &&
                    card.controller == participant &&
                    !card.faceUp;
              }).toList(growable: false) ??
              const <String>[];
          final legacyIds = <String>{
            if (last.target != null) last.target!.cardInstanceId,
            ...(last.payload['reveal_instance_ids'] as List? ?? const [])
                .whereType<String>(),
          }.where((id) {
            final card = request.findCard(state, id);
            return card != null &&
                card.controller == participant &&
                !card.faceUp;
          }).toList(growable: false);
          final protectedIds =
              threatenedIds.isNotEmpty ? threatenedIds : legacyIds;
          if (protectedIds.isNotEmpty) {
            yield option(payload: {
              'target_link_id': last.linkId,
              'threatened_face_down_instance_ids': protectedIds,
            }, description: 'Annuler la révélation', suffix: last.linkId);
          }
        }
      },
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
        if (!_sourceHasCode(state, link, 'MAS-012') ||
            link.speed != ChainSpeed.speed3 ||
            targetLink == null ||
            targetLink.activatingPlayer == link.activatingPlayer) {
          return false;
        }
        final ids = <String>{
          ..._payloadIds(link, 'threatened_face_down_instance_ids'),
          if (targetLink.target != null) targetLink.target!.cardInstanceId,
          ..._payloadIds(targetLink, 'reveal_instance_ids'),
        };
        return ids.any((id) {
          final card = _findFieldCard(state, id);
          return card != null &&
              card.card.controller == link.activatingPlayer &&
              !card.card.faceUp;
        });
      },
      onResolve: (state, link) => _negateAndDestroySource(
        state,
        _targetedChainLink(state, link)!,
      ),
    );
  }

  static ChainEffectDefinition _mas013() {
    const usageKey = '${MasqueEffectKeys.mas013}:first_flip';
    return _FunctionalMasqueEffect(
      onCanActivate: (state, link) {
        final source = _sourceCard(state, link);
        if (source?.cardCode != 'MAS-013') return false;
        if (link.payload['mode'] == 'continuous_refresh') return true;
        final flipped = _findFieldCard(
          state,
          link.payload['flipped_instance_id'] as String?,
        );
        return link.payload['mode'] == 'card_flipped_face_up' &&
            !_usedThisTurn(source!, usageKey, state.turnNumber) &&
            flipped != null &&
            flipped.card.faceUp;
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
        var nextState = _refreshSecretDanceAura(
          state,
          link.sourceCardInstanceId!,
        );
        if (link.payload['mode'] == 'continuous_refresh') return nextState;
        final flipped = _findFieldCard(
          nextState,
          link.payload['flipped_instance_id']! as String,
        );
        if (flipped == null) return nextState;
        return _gainLifePoints(nextState, flipped.card.controller, 300);
      },
    );
  }

  static ChainEffectDefinition _mas014() {
    const usageKey = '${MasqueEffectKeys.mas014}:set_trap';
    return _FunctionalMasqueEffect(
      onCanActivate: (state, link) {
        final source = _sourceCard(state, link);
        if (source?.cardCode != 'MAS-014') return false;
        if (link.payload['mode'] == 'equip') return true;
        if (link.payload['mode'] != 'set_trap' ||
            _usedThisTurn(source!, usageKey, state.turnNumber)) {
          return false;
        }
        final equippedId =
            source.runtimeData[CardRuntimeKeys.equippedToInstanceId] as String?;
        final equipped = _findFieldCard(state, equippedId);
        final trapId = link.payload['trap_instance_id'] as String?;
        final field = _fieldFor(state, link.activatingPlayer);
        return equipped != null &&
            equipped.card.runtimeData[CardRuntimeKeys.flippedFaceUpTurn] ==
                state.turnNumber &&
            trapId != null &&
            field.actionTrapZones.any((card) => card == null) &&
            field.hand.any(
              (card) =>
                  card.instanceId == trapId &&
                  card.category == CardCategory.trap,
            );
      },
      onTargetLegal: (state, link) {
        if (link.payload['mode'] == 'set_trap') return link.target == null;
        final target = _findFieldCard(state, link.target?.cardInstanceId);
        return target != null &&
            target.kind == _ZoneKind.character &&
            target.card.controller == link.activatingPlayer &&
            target.card.hasFamily('masque');
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
        if (link.payload['mode'] == 'set_trap') {
          return _setTrapFromHand(
            state,
            link.activatingPlayer,
            link.payload['trap_instance_id']! as String,
          );
        }
        final targetId = link.target!.cardInstanceId;
        var nextState = _updateFieldCard(
          state,
          targetId,
          (card) => card.copyWith(
            attachedCardInstanceIds: {
              ...card.attachedCardInstanceIds,
              link.sourceCardInstanceId!,
            }.toList(),
            runtimeModifiers: [
              ...card.runtimeModifiers,
              RuntimeStatModifier(
                modifierId:
                    '${MasqueEffectKeys.mas014}:${link.sourceCardInstanceId}',
                atkDelta: 300,
                defDelta: 300,
                sourceCardInstanceId: link.sourceCardInstanceId,
              ),
            ],
          ),
        );
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

  static ChainEffectDefinition _mas015() {
    const usageKey = '${MasqueEffectKeys.mas015}:flip_response';
    return _FunctionalMasqueEffect(
      onCanActivate: (state, link) {
        final source = _sourceCard(state, link);
        if (source?.cardCode != 'MAS-015') return false;
        if (link.payload['trigger'] == 'on_summon') {
          final ids = _payloadIds(link, 'target_instance_ids');
          return ids.length <= 2 &&
              ids.toSet().length == ids.length &&
              ids.every((id) {
                final card = _findFieldCard(state, id);
                return card != null &&
                    card.kind == _ZoneKind.character &&
                    card.card.controller != link.activatingPlayer;
              });
        }
        final choice = link.payload['choice'];
        return link.payload['trigger'] == 'card_flipped_face_up' &&
            !_usedThisTurn(source!, usageKey, state.turnNumber) &&
            (choice == 'negate' || choice == 'boost');
      },
      onTargetLegal: (state, link) {
        if (link.payload['trigger'] == 'on_summon' ||
            link.payload['choice'] == 'boost') {
          return link.target == null;
        }
        final target = _findFieldCard(state, link.target?.cardInstanceId);
        return target != null && target.card.faceUp;
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
          var nextState = state;
          for (final id in _payloadIds(link, 'target_instance_ids')) {
            nextState = _turnFaceDownDefense(nextState, id);
          }
          return nextState;
        }
        if (link.payload['choice'] == 'negate') {
          return _updateFieldCard(
            state,
            link.target!.cardInstanceId,
            (card) => card.copyWith(
              runtimeData: {
                ...card.runtimeData,
                CardRuntimeKeys.effectsNegatedUntilTurn: state.turnNumber,
              },
            ),
          );
        }
        return _updateFieldCard(
          state,
          link.sourceCardInstanceId!,
          (card) => card.copyWith(
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
        );
      },
    );
  }
}

ChainLink? _buildAutomaticFlipTrigger(
  DuelState state,
  CardInstance source,
  AutomaticEffectTrigger event,
  String linkId,
) {
  if (event != AutomaticEffectTrigger.flippedFaceUp ||
      source.effectKey == null) {
    return null;
  }
  final ownField = _fieldFor(state, source.controller);
  final payload = <String, Object?>{'trigger': 'flipped_face_up'};
  ChainTarget? target;
  if (source.cardCode == 'MAS-001') {
    if (ownField.deck.isNotEmpty) {
      payload['discard_instance_id'] = ownField.hand.isNotEmpty
          ? ownField.hand.first.instanceId
          : ownField.deck.first.instanceId;
    }
  } else if (source.cardCode == 'MAS-004') {
    final opponent = source.controller == DuelParticipant.player
        ? DuelParticipant.ai
        : DuelParticipant.player;
    CardInstance? selected;
    for (final candidate in _fieldFor(state, opponent)
        .characterZones
        .whereType<CardInstance>()) {
      if (candidate.faceUp &&
          candidate.effectiveAtk != null &&
          candidate.effectiveDef != null) {
        selected = candidate;
        break;
      }
    }
    if (selected == null) return null;
    target = ChainTarget(cardInstanceId: selected.instanceId);
  } else {
    return null;
  }
  return ChainLink(
    linkId: linkId,
    effectKey: source.effectKey!,
    activatingPlayer: source.controller,
    speed: ChainSpeed.speed1,
    sourceCardInstanceId: source.instanceId,
    sourceCardCode: source.cardCode,
    target: target,
    payload: payload,
  );
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
  final graveyardCard = _asGraveyardCard(removed);
  return _replaceField(
    state,
    participant,
    field.copyWith(hand: hand, graveyard: [...field.graveyard, graveyardCard]),
  );
}

DuelState _setCharacterFromHand(
  DuelState state,
  DuelParticipant participant,
  String instanceId,
) {
  final field = _fieldFor(state, participant);
  final handIndex = field.hand.indexWhere(
    (card) =>
        card.instanceId == instanceId &&
        card.category == CardCategory.character &&
        card.hasFamily('masque') &&
        (card.rank ?? 99) <= 4,
  );
  final zoneIndex = field.characterZones.indexWhere((card) => card == null);
  if (handIndex < 0 || zoneIndex < 0) return state;
  final hand = List<CardInstance>.from(field.hand);
  final card = hand.removeAt(handIndex).copyWith(
        controller: participant,
        faceUp: false,
        position: BattlePosition.defense,
        zoneIndex: zoneIndex,
        summonedTurn: state.turnNumber,
        attackedThisTurn: false,
        positionChangedThisTurn: false,
      );
  final zones = List<FieldCardInstance?>.from(field.characterZones)
    ..[zoneIndex] = card;
  return _replaceField(
    state,
    participant,
    field.copyWith(characterZones: zones, hand: hand),
  );
}

DuelState _turnFaceDownDefense(DuelState state, String instanceId) {
  return _updateFieldCard(
    state,
    instanceId,
    (card) => card.copyWith(
      faceUp: false,
      position: BattlePosition.defense,
      positionChangedThisTurn: true,
    ),
  );
}

DuelState _turnFaceUp(DuelState state, String instanceId, int turnNumber) {
  return _updateFieldCard(
    state,
    instanceId,
    (card) => card.copyWith(
      faceUp: true,
      runtimeData: card.faceUp
          ? card.runtimeData
          : {
              ...card.runtimeData,
              CardRuntimeKeys.flippedFaceUpTurn: turnNumber,
            },
    ),
  );
}

bool _hasFusionMaterials(DuelState state, ChainLink link) {
  if (!_sourceHasCode(state, link, 'MAS-010')) return false;
  final ids = _payloadIds(link, 'material_instance_ids');
  if (ids.length != 2 || ids.toSet().length != 2) return false;
  final cards = ids.map((id) => _findFieldCard(state, id)).toList();
  if (cards.any((card) => card == null)) return false;
  if (cards.any(
    (card) =>
        card!.kind != _ZoneKind.character ||
        card.card.controller != link.activatingPlayer,
  )) {
    return false;
  }
  return cards.map((card) => card!.card.cardCode).toSet().containsAll(
    {'MAS-004', 'MAS-006'},
  );
}

DuelState _sendFieldCardToGraveyard(DuelState state, String instanceId) {
  final location = _findFieldCard(state, instanceId);
  if (location == null) return state;
  var nextState = _removeFieldCard(state, location);
  final ownerField = _fieldFor(nextState, location.card.owner);
  return _replaceField(
    nextState,
    location.card.owner,
    ownerField.copyWith(
      graveyard: [...ownerField.graveyard, _asGraveyardCard(location.card)],
    ),
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

DuelState _refreshSecretDanceAura(DuelState state, String terrainInstanceId) {
  final modifierId = '${MasqueEffectKeys.mas013}:$terrainInstanceId';
  var nextState = state;
  for (final participant in DuelParticipant.values) {
    final field = _fieldFor(nextState, participant);
    final zones = field.characterZones.map((entry) {
      if (entry is! CardInstance) return entry;
      final modifiers = entry.runtimeModifiers
          .where((modifier) => modifier.modifierId != modifierId)
          .toList();
      if (!entry.hasFamily('masque')) {
        return entry.copyWith(runtimeModifiers: modifiers);
      }
      return entry.copyWith(
        runtimeModifiers: [
          ...modifiers,
          RuntimeStatModifier(
            modifierId: modifierId,
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

DuelState _gainLifePoints(
  DuelState state,
  DuelParticipant participant,
  int amount,
) {
  return participant == DuelParticipant.player
      ? state.copyWith(playerLifePoints: state.playerLifePoints + amount)
      : state.copyWith(aiLifePoints: state.aiLifePoints + amount);
}

DuelState _setTrapFromHand(
  DuelState state,
  DuelParticipant participant,
  String instanceId,
) {
  final field = _fieldFor(state, participant);
  final handIndex = field.hand.indexWhere(
    (card) =>
        card.instanceId == instanceId && card.category == CardCategory.trap,
  );
  final zoneIndex = field.actionTrapZones.indexWhere((card) => card == null);
  if (handIndex < 0 || zoneIndex < 0) return state;
  final hand = List<CardInstance>.from(field.hand);
  final trap = hand.removeAt(handIndex).copyWith(
        controller: participant,
        faceUp: false,
        position: null,
        zoneIndex: zoneIndex,
      );
  final zones = List<CardInstance?>.from(field.actionTrapZones)
    ..[zoneIndex] = trap;
  return _replaceField(
    state,
    participant,
    field.copyWith(actionTrapZones: zones, hand: hand),
  );
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
