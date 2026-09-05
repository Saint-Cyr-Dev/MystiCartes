import '../battle_state.dart';
import '../card.dart';
import '../duel_engine.dart';
import '../duel_types.dart';
import '../player.dart';

/// Contexte factuel de la fenêtre courante. Il ne contient aucune décision UI.
final class ManualActivationContext {
  const ManualActivationContext({
    this.attack,
    this.destroyedCharacterRank,
    this.destroyedWasForest = false,
    this.summonedOpponentInstanceId,
    this.opponentEffectWouldLoseLife = false,
    this.events = const [],
  });

  final AttackDeclaration? attack;
  final int? destroyedCharacterRank;
  final bool destroyedWasForest;
  final String? summonedOpponentInstanceId;
  final bool opponentEffectWouldLoseLife;
  final List<PendingDuelEvent> events;

  T? firstEvent<T extends PendingDuelEvent>() {
    for (final event in events) {
      if (event is T) return event;
    }
    return null;
  }

  ManualActivationContext withAdditionalEvents(
    Iterable<PendingDuelEvent> additional,
  ) {
    return ManualActivationContext(
      attack: attack,
      destroyedCharacterRank: destroyedCharacterRank,
      destroyedWasForest: destroyedWasForest,
      summonedOpponentInstanceId: summonedOpponentInstanceId,
      opponentEffectWouldLoseLife: opponentEffectWouldLoseLife,
      events: List.unmodifiable([...events, ...additional]),
    );
  }
}

/// Activation entièrement préparée par le moteur : cible et coût sont déjà
/// encodés dans [link]. L'interface ne connaît aucun code de carte.
final class ManualActivationOption {
  const ManualActivationOption({
    required this.source,
    required this.link,
    required this.description,
  });

  final CardInstance source;
  final ChainLink link;
  final String description;
}

/// Fabrique commune des activations choisies par un joueur.
///
/// Les effets automatiques (invocation, retournement, auras) sont exclus : ils
/// continuent d'emprunter PendingEffectTrigger/AutomaticEffectTrigger.
final class ManualActivationPlanner {
  const ManualActivationPlanner(this.engine);

  final DuelEngine engine;

  List<ManualActivationOption> legalOptions({
    required DuelState state,
    required DuelParticipant participant,
    ManualActivationContext context = const ManualActivationContext(),
  }) {
    if (state.isFinished) return const [];
    final field = _field(state, participant);
    final sources = <CardInstance>[
      ...field.actionTrapZones.whereType<CardInstance>(),
      ...field.hand.where((card) => state.chain.isOpen
          ? card.category == CardCategory.action && card.subtype == 'quick'
          : card.category == CardCategory.action ||
              card.category == CardCategory.terrain ||
              card.category == CardCategory.relic),
    ].where((card) => card.effectKey != null).toList(growable: false);
    final options = <ManualActivationOption>[];
    for (final source in sources) {
      for (final draft in _drafts(state, participant, source, context)) {
        final result = engine.activateCard(
          state: state,
          participant: participant,
          cardInstanceId: source.instanceId,
          link: draft.link,
        );
        if (result.succeeded) options.add(draft);
      }
    }
    return List.unmodifiable(options);
  }

  Iterable<ManualActivationOption> _drafts(
    DuelState state,
    DuelParticipant participant,
    CardInstance source,
    ManualActivationContext context,
  ) sync* {
    final effectiveContext = context.withAdditionalEvents(
      engine.pendingEventsForCurrentChain(state),
    );
    final own = _field(state, participant);
    final enemy = _field(state, _opponent(participant));
    final ownCharacters = own.characterZones.whereType<CardInstance>().toList();
    final enemyCharacters =
        enemy.characterZones.whereType<CardInstance>().toList();
    final allCharacters = [...ownCharacters, ...enemyCharacters];
    final last = state.chain.links.lastOrNull;
    final attack = effectiveContext.attack;

    ManualActivationOption option({
      ChainTarget? target,
      Map<String, Object?> payload = const {},
      String description = 'Activer',
      String suffix = '0',
    }) {
      final attacker =
          attack == null ? null : _findCard(state, attack.attackerInstanceId);
      final strategicPayload = <String, Object?>{
        ...payload,
        'createsAdvantage': true,
        if (attack != null) 'preventsAttack': true,
        if (attacker?.effectiveAtk != null)
          'incomingDamage': attacker!.effectiveAtk,
      };
      final speed = source.category == CardCategory.trap &&
              source.subtype == 'counter'
          ? ChainSpeed.speed3
          : source.category == CardCategory.trap || source.subtype == 'quick'
              ? ChainSpeed.speed2
              : ChainSpeed.speed1;
      return ManualActivationOption(
        source: source,
        description: description,
        link: ChainLink(
          linkId:
              'manual:${state.turnNumber}:${state.chain.links.length}:${source.instanceId}:$suffix',
          effectKey: source.effectKey!,
          activatingPlayer: participant,
          speed: speed,
          sourceCardInstanceId: source.instanceId,
          sourceCardCode: source.cardCode,
          target: target,
          payload: strategicPayload,
        ),
      );
    }

    switch (source.cardCode) {
      case 'BAB-008':
        for (final target in ownCharacters.where((c) => c.hasFamily('babi'))) {
          yield option(
              target: ChainTarget(cardInstanceId: target.instanceId),
              description: 'Changer la position de ${target.cardCode}',
              suffix: target.instanceId);
        }
      case 'BAB-009':
        for (final target in enemy.actionTrapZones
            .whereType<CardInstance>()
            .where((card) => !card.faceUp)) {
          yield option(
            target: ChainTarget(cardInstanceId: target.instanceId),
            description: 'Renvoyer la carte posée ${target.cardCode}',
            suffix: target.instanceId,
          );
        }
      case 'BAB-010':
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
      case 'BAB-011':
        if (attack != null) {
          yield option(payload: {
            'trigger': 'attack_declared',
            'attack_declaration_id': attack.declarationId,
            'attacker_instance_id': attack.attackerInstanceId
          }, description: 'Annuler l’attaque', suffix: attack.declarationId);
        }
      case 'BAB-012':
        if (last != null &&
            _sourceCard(state, last)?.category == CardCategory.action) {
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
      case 'BAB-013':
        yield option(description: 'Activer le Terrain');
      case 'BAB-014':
        for (final target in ownCharacters.where((c) => c.hasFamily('babi'))) {
          yield option(
            target: ChainTarget(cardInstanceId: target.instanceId),
            payload: const {'mode': 'equip'},
            description: 'Équiper ${target.cardCode}',
            suffix: target.instanceId,
          );
        }
      case 'ROY-009':
        final destruction =
            effectiveContext.firstEvent<EffectDestructionPending>();
        final protected = destruction == null
            ? _targetCard(state, last)
            : _findCard(state, destruction.cardInstanceId);
        if (protected != null &&
            protected.controller == participant &&
            protected.hasFamily('royaume')) {
          for (final sacrifice in ownCharacters
              .where((c) => c.instanceId != protected.instanceId)) {
            yield option(
                target: ChainTarget(cardInstanceId: protected.instanceId),
                payload: {
                  'trigger': 'destruction_pending',
                  'sacrifice_instance_id': sacrifice.instanceId
                },
                description:
                    'Sacrifier ${sacrifice.cardCode} pour protéger ${protected.cardCode}',
                suffix: sacrifice.instanceId);
          }
        }
      case 'ROY-011':
        if (attack != null) {
          yield option(
              target: ChainTarget(cardInstanceId: attack.attackerInstanceId),
              payload: {
                'trigger': 'attack_declared',
                'attack_declaration_id': attack.declarationId,
                'attack_target_instance_id': attack.targetInstanceId
              },
              description: 'Affaiblir l’attaquant',
              suffix: attack.declarationId);
        }
      case 'ROY-012':
        final target = _targetCard(state, last);
        if (last != null &&
            target != null &&
            target.controller == participant &&
            target.hasFamily('royaume')) {
          yield option(
              payload: {'target_link_id': last.linkId},
              description: 'Annuler l’effet ciblant ${target.cardCode}',
              suffix: last.linkId);
        }
      case 'ANC-009':
        for (final ally in ownCharacters.where((c) => c.hasFamily('ancêtre'))) {
          for (final foe in enemyCharacters) {
            yield option(
                target: ChainTarget(cardInstanceId: ally.instanceId),
                payload: {'enemy_instance_id': foe.instanceId},
                description:
                    'Renforcer ${ally.cardCode} et affaiblir ${foe.cardCode}',
                suffix: '${ally.instanceId}:${foe.instanceId}');
          }
        }
      case 'ANC-010':
        final materials = own.graveyard
            .where((card) =>
                card.category == CardCategory.character &&
                card.hasFamily('ancêtre'))
            .toList(growable: false);
        if (materials.fold<int>(0, (sum, card) => sum + (card.rank ?? 0)) >=
            10) {
          yield option(
            payload: {
              'banish_instance_ids':
                  materials.map((card) => card.instanceId).toList(),
            },
            description: 'Bannir les matériaux Ancêtre du Cimetière',
          );
        }
      case 'ANC-011':
        final rank = effectiveContext.destroyedCharacterRank;
        if (rank != null) {
          for (final selected in own.graveyard.where((c) =>
              c.category == CardCategory.character &&
              c.hasFamily('ancêtre') &&
              (c.rank ?? 99) < rank)) {
            yield option(
                payload: {
                  'trigger': 'controlled_character_destroyed',
                  'destroyed_rank': rank,
                  'selected_instance_id': selected.instanceId
                },
                description: 'Invoquer ${selected.cardCode} du Cimetière',
                suffix: selected.instanceId);
          }
        }
      case 'ANC-012':
        if (last != null && last.activatingPlayer != participant) {
          final banishment = effectiveContext.firstEvent<BanishmentPending>();
          final graveId = banishment?.fromGraveyard == true
              ? banishment!.cardInstanceId
              : last.target?.cardInstanceId ??
                  last.payload['graveyard_instance_id'] as String?;
          if (graveId != null &&
              own.graveyard.any((c) => c.instanceId == graveId)) {
            yield option(payload: {
              'target_link_id': last.linkId,
              'threatened_graveyard_instance_id': graveId,
            }, description: 'Empêcher le bannissement', suffix: last.linkId);
          }
        }
      case 'MAS-008':
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
      case 'MAS-011':
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
      case 'MAS-012':
        if (last != null && last.activatingPlayer != participant) {
          final reveal = effectiveContext.firstEvent<FaceDownRevealPending>();
          final threatenedIds = reveal?.cardInstanceIds.where((id) {
                final card = _findCard(state, id);
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
            final card = _findCard(state, id);
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
      case 'DOZ-009':
        for (final target in allCharacters
            .where((c) => c.faceUp && (c.counters['proie'] ?? 0) > 0)) {
          yield option(
              target: ChainTarget(cardInstanceId: target.instanceId),
              description: 'Affaiblir ${target.cardCode}',
              suffix: target.instanceId);
        }
      case 'DOZ-011':
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
      case 'DOZ-012':
        final activatingCard = _sourceCard(state, last);
        if (last != null &&
            activatingCard != null &&
            (activatingCard.counters['proie'] ?? 0) > 0) {
          yield option(
              payload: {'target_link_id': last.linkId},
              description: 'Annuler l’effet de la Proie',
              suffix: last.linkId);
        }
      case 'FOR-008':
        yield option(description: 'Créer un Jeton Sylve');
      case 'FOR-011':
        if (attack != null) {
          yield option(
              target: ChainTarget(cardInstanceId: attack.attackerInstanceId),
              payload: {
                'trigger': 'opponent_attack_declared',
                'attack_declaration_id': attack.declarationId
              },
              description: 'Entraver l’attaquant',
              suffix: attack.declarationId);
        }
      case 'FOR-012':
        if (effectiveContext.destroyedWasForest) {
          yield option(payload: {
            'trigger': 'controlled_forest_destroyed',
            'destroyed_was_forest': true
          }, description: 'Créer un Jeton Sylve');
        }
      case 'LAG-008':
        for (final ally in ownCharacters.where((c) => c.hasFamily('lagune'))) {
          for (final foe in enemyCharacters
              .where((c) => (c.rank ?? 99) <= (ally.rank ?? -1))) {
            yield option(
                target: ChainTarget(cardInstanceId: ally.instanceId),
                payload: {'opponent_instance_id': foe.instanceId},
                description: 'Renvoyer ${ally.cardCode} et ${foe.cardCode}',
                suffix: '${ally.instanceId}:${foe.instanceId}');
          }
        }
      case 'LAG-011':
        final summonedId = effectiveContext.summonedOpponentInstanceId;
        if (summonedId != null) {
          yield option(
              target: ChainTarget(cardInstanceId: summonedId),
              payload: {'trigger': 'opponent_character_summoned'},
              description: 'Prendre le nouveau Personnage au filet',
              suffix: summonedId);
        }
      case 'LAG-012':
        final destruction =
            effectiveContext.firstEvent<EffectDestructionPending>();
        final target = destruction == null
            ? _targetCard(state, last)
            : _findCard(state, destruction.cardInstanceId);
        if (last != null &&
            target != null &&
            target.controller == participant &&
            target.hasFamily('lagune')) {
          yield option(
              target: ChainTarget(cardInstanceId: target.instanceId),
              payload: {
                'target_link_id': last.linkId,
                'threatened_instance_id': target.instanceId,
              },
              description: 'Sauver ${target.cardCode} par Reflux',
              suffix: last.linkId);
        }
      case 'SAV-009':
        for (final target
            in ownCharacters.where((c) => c.hasFamily('savane'))) {
          yield option(
              target: ChainTarget(cardInstanceId: target.instanceId),
              description: 'Donner 700 ATK à ${target.cardCode}',
              suffix: target.instanceId);
        }
      case 'SAV-011':
        if (attack != null) {
          yield option(
              target: ChainTarget(cardInstanceId: attack.attackerInstanceId),
              payload: {'mode': 'attack_declared'},
              description: 'Aveugler l’attaquant',
              suffix: attack.declarationId);
        }
      case 'SAV-012':
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
      case 'VIL-009':
        for (final target
            in ownCharacters.where((c) => c.hasFamily('village'))) {
          yield option(
              target: ChainTarget(cardInstanceId: target.instanceId),
              payload: {'mode': 'equip'},
              description: 'Équiper ${target.cardCode}',
              suffix: target.instanceId);
        }
      case 'VIL-011':
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
      case 'VIL-012':
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
      case 'MAQ-009':
        for (final target
            in ownCharacters.where((c) => c.hasFamily('maquis'))) {
          for (final summon in own.hand.where((c) =>
              c.category == CardCategory.character &&
              c.hasFamily('maquis') &&
              (c.rank ?? 99) < (target.rank ?? -1))) {
            yield option(
                target: ChainTarget(cardInstanceId: target.instanceId),
                payload: {'summon_instance_id': summon.instanceId},
                description:
                    'Renvoyer ${target.cardCode} et invoquer ${summon.cardCode}',
                suffix: '${target.instanceId}:${summon.instanceId}');
          }
        }
      case 'MAQ-011':
        if (attack != null) {
          for (final target
              in ownCharacters.where((c) => c.hasFamily('maquis'))) {
            yield option(
                target: ChainTarget(cardInstanceId: target.instanceId),
                payload: {
                  'trigger': 'opponent_attack_declared',
                  'attack_declaration_id': attack.declarationId
                },
                description: 'Annuler et reprendre ${target.cardCode}',
                suffix: target.instanceId);
          }
        }
      case 'MAQ-012':
        final lifeLoss = effectiveContext.firstEvent<LifePointLossPending>();
        if (last != null &&
            (effectiveContext.opponentEffectWouldLoseLife ||
                (lifeLoss != null &&
                    lifeLoss.participant == participant &&
                    last.activatingPlayer != participant))) {
          for (final discard in own.hand) {
            yield option(
                payload: {
                  'trigger': 'opponent_effect_life_loss',
                  'target_link_id': last.linkId,
                  'discard_instance_id': discard.instanceId
                },
                description: 'Défausser ${discard.cardCode} et contester',
                suffix: discard.instanceId);
          }
        }
    }
  }

  PlayerFieldState _field(DuelState state, DuelParticipant participant) =>
      participant == DuelParticipant.player ? state.playerField : state.aiField;

  DuelParticipant _opponent(DuelParticipant participant) =>
      participant == DuelParticipant.player
          ? DuelParticipant.ai
          : DuelParticipant.player;

  CardInstance? _sourceCard(DuelState state, ChainLink? link) =>
      link?.sourceCardInstanceId == null
          ? null
          : _findCard(state, link!.sourceCardInstanceId!);

  CardInstance? _targetCard(DuelState state, ChainLink? link) =>
      link?.target == null
          ? null
          : _findCard(state, link!.target!.cardInstanceId);

  CardInstance? _findCard(DuelState state, String instanceId) {
    for (final field in [state.playerField, state.aiField]) {
      for (final card in [
        ...field.hand,
        ...field.graveyard,
        ...field.banished,
        ...field.mythicReserve,
        ...field.characterZones.whereType<CardInstance>(),
        ...field.actionTrapZones.whereType<CardInstance>(),
        if (field.terrainZone case final CardInstance terrain) terrain,
      ]) {
        if (card.instanceId == instanceId) return card;
      }
    }
    return null;
  }
}
