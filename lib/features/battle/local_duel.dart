import 'dart:math';

import '../../game/ai/beginner_ai.dart';
import '../../game/ai/ai_strategy.dart';
import '../../game/battle_state.dart';
import '../../game/card.dart';
import '../../game/duel_engine.dart';
import '../../game/duel_types.dart';
import '../../game/effects/effect_registry.dart';
import '../../game/effects/manual_activation.dart';
import '../../game/player.dart';

final class LocalCardPresentation {
  const LocalCardPresentation({
    required this.code,
    required this.name,
    required this.category,
    required this.family,
    required this.attribute,
    this.cardId,
    this.revision = 1,
    this.rank,
    this.atk,
    this.def,
    this.subtype,
    this.secondaryFamilies = const [],
    this.mythicSummonCondition = const {},
    this.effectKey,
    this.effectData = const {},
  });

  factory LocalCardPresentation.fromJson(Map<String, Object?> json) {
    final rawCategory = json['category']?.toString();
    final category = switch (rawCategory) {
      'personnage' => CardCategory.character,
      'action' => CardCategory.action,
      'piège' => CardCategory.trap,
      'terrain' => CardCategory.terrain,
      'relique' => CardCategory.relic,
      'mythique' => CardCategory.mythic,
      _ =>
        throw FormatException('Catégorie de carte V2 inconnue: $rawCategory'),
    };
    return LocalCardPresentation(
      cardId: json['id']?.toString(),
      code: json['code']!.toString(),
      name: json['name']!.toString(),
      category: category,
      family: json['primary_family']?.toString() ?? '',
      attribute: json['attribute']?.toString() ?? '',
      revision: (json['revision'] as num?)?.toInt() ?? 1,
      rank: (json['rank'] as num?)?.toInt(),
      atk: (json['atk'] as num?)?.toInt(),
      def: (json['def'] as num?)?.toInt(),
      subtype: json['subtype']?.toString(),
      secondaryFamilies:
          (json['secondary_families'] as List? ?? const <Object>[])
              .map((value) => value.toString())
              .toList(growable: false),
      mythicSummonCondition: json['mythic_summon_condition'] is Map
          ? Map<String, Object?>.from(
              json['mythic_summon_condition']! as Map,
            )
          : const {},
      effectKey: json['effect_key']?.toString(),
      effectData: json['effect_data'] is Map
          ? Map<String, Object?>.from(json['effect_data']! as Map)
          : const {},
    );
  }

  final String code;
  final String name;
  final CardCategory category;
  final String family;
  final String attribute;
  final String? cardId;
  final int revision;
  final int? rank;
  final int? atk;
  final int? def;
  final String? subtype;
  final List<String> secondaryFamilies;
  final Map<String, Object?> mythicSummonCondition;
  final String? effectKey;
  final Map<String, Object?> effectData;
}

final class LocalDuelActionResult {
  const LocalDuelActionResult(this.succeeded, this.message);

  final bool succeeded;
  final String message;
}

final class LocalChainResponseOption {
  const LocalChainResponseOption({
    required this.card,
    required this.label,
    required this.link,
  });

  final CardInstance card;
  final String label;
  final ChainLink link;
}

/// Adaptateur local entre l'écran Flutter et le moteur Dart pur V2.
///
/// Aucun accès réseau n'est effectué pendant le duel. Le petit deck fourni ici
/// sert à rendre la boucle de combat immédiatement jouable en attendant le
/// chargement du deck V2 complet depuis Supabase.
final class LocalDuelController {
  LocalDuelController._({
    required this.engine,
    required this.ai,
    required this.presentations,
    required this.state,
  });

  /// Point d'injection destiné aux tests de l'adaptateur UI/moteur.
  factory LocalDuelController.forTesting({
    required DuelEngine engine,
    required DuelAiStrategy ai,
    required Map<String, LocalCardPresentation> presentations,
    required DuelState state,
  }) =>
      LocalDuelController._(
        engine: engine,
        ai: ai,
        presentations: presentations,
        state: state,
      );

  factory LocalDuelController.create({
    int? seed,
    AiDifficulty difficulty = AiDifficulty.beginner,
    List<LocalCardPresentation>? playerDeck,
    List<LocalCardPresentation> playerMythicReserve = const [],
  }) {
    final random = Random(seed);
    final engine = DuelEngine(chainEffects: V2EffectRegistry.create());
    final presentations = {
      for (final definition in _definitions) definition.code: definition,
      if (playerDeck != null)
        for (final definition in playerDeck) definition.code: definition,
      for (final definition in playerMythicReserve) definition.code: definition,
    };
    final suppliedPlayerDeck = playerDeck == null
        ? null
        : (List<LocalCardPresentation>.of(playerDeck)..shuffle(random));
    final playerCards = suppliedPlayerDeck == null
        ? _buildDeck(DuelParticipant.player)
        : _buildInstances(suppliedPlayerDeck, DuelParticipant.player);
    final playerMythics =
        _buildInstances(playerMythicReserve, DuelParticipant.player);
    final aiCards = _buildDeck(DuelParticipant.ai);
    // Les cinq premières cartes sont volontairement des Personnages de rang
    // faible : une partie de démonstration ne peut donc pas démarrer bloquée.
    final playerHand = playerCards.take(5).toList(growable: false);
    final aiHand = aiCards.take(5).toList(growable: false);
    final state = DuelState(
      playerField: PlayerFieldState.empty(
        participant: DuelParticipant.player,
        deck: playerCards.skip(5).toList(growable: false),
        mythicReserve: playerMythics,
      ).copyWith(hand: playerHand),
      aiField: PlayerFieldState.empty(
        participant: DuelParticipant.ai,
        deck: aiCards.skip(5).toList(growable: false),
      ).copyWith(hand: aiHand),
    );
    return LocalDuelController._(
      engine: engine,
      ai: createDuelAi(
        difficulty: difficulty,
        engine: engine,
        random: DartAiRandomSource(random),
      ),
      presentations: presentations,
      state: state,
    );
  }

  final DuelEngine engine;
  final DuelAiStrategy ai;
  final Map<String, LocalCardPresentation> presentations;
  DuelState state;
  AttackDeclaration? _pendingAiAttack;
  AttackDeclaration? _pendingPlayerAttack;
  int _aiMainActionsTurn = -1;
  bool _aiMonsterActionDone = false;
  bool _aiBackrowActionDone = false;
  ManualActivationContext _responseContext = const ManualActivationContext();
  List<String> lastChainEvents = const [];

  bool get awaitingPlayerPriority =>
      state.chain.isOpen &&
      state.chain.priorityPlayer == DuelParticipant.player &&
      !state.isFinished;

  AttackDeclaration? get pendingAiAttack => _pendingAiAttack;

  /// Attaque du joueur dont le calcul attend la fermeture normale de la
  /// fenêtre de réponse. Elle reste en suspens tant que les deux joueurs
  /// n'ont pas passé consécutivement.
  AttackDeclaration? get pendingPlayerAttack => _pendingPlayerAttack;

  ManualActivationContext get _currentResponseContext =>
      _pendingAiAttack == null
          ? _responseContext
          : ManualActivationContext(attack: _pendingAiAttack);

  LocalCardPresentation presentationOf(FieldCardInstance card) {
    if (card is CardInstance) return presentations[card.cardCode]!;
    return const LocalCardPresentation(
      code: 'JETON',
      name: 'Jeton',
      category: CardCategory.character,
      family: '—',
      attribute: '—',
    );
  }

  LocalDuelActionResult playCharacter({
    required String cardInstanceId,
    required bool faceUpAttack,
    List<String> sacrificeInstanceIds = const [],
  }) {
    final result = faceUpAttack
        ? engine.normalSummon(
            state: state,
            participant: DuelParticipant.player,
            cardInstanceId: cardInstanceId,
            sacrificeInstanceIds: sacrificeInstanceIds,
          )
        : engine.normalSet(
            state: state,
            participant: DuelParticipant.player,
            cardInstanceId: cardInstanceId,
            sacrificeInstanceIds: sacrificeInstanceIds,
          );
    if (!result.succeeded) return _failure(result.failure);
    final previousIds = state.playerField.characterZones
        .whereType<CardInstance>()
        .map((card) => card.instanceId)
        .toSet();
    state = result.state;
    final summoned = state.playerField.characterZones
        .whereType<CardInstance>()
        .where((card) => !previousIds.contains(card.instanceId))
        .firstOrNull;
    _responseContext = ManualActivationContext(
      summonedOpponentInstanceId: summoned?.instanceId,
    );
    _playAiPriorityOnce();
    return const LocalDuelActionResult(true, 'Personnage joué.');
  }

  LocalDuelActionResult setActionOrTrap(String cardInstanceId) {
    final result = engine.setActionOrTrap(
      state: state,
      participant: DuelParticipant.player,
      cardInstanceId: cardInstanceId,
    );
    if (!result.succeeded) return _failure(result.failure);
    state = result.state;
    _responseContext = const ManualActivationContext();
    _playAiPriorityOnce();
    return const LocalDuelActionResult(true, 'Carte posée face cachée.');
  }

  List<LocalChainResponseOption> availablePlayerResponses() {
    if (!awaitingPlayerPriority) return const [];
    return ManualActivationPlanner(engine)
        .legalOptions(
          state: state,
          participant: DuelParticipant.player,
          context: _currentResponseContext,
        )
        .map(
          (option) => LocalChainResponseOption(
            card: option.source,
            link: option.link,
            label:
                '${presentationOf(option.source).name} — ${option.description}',
          ),
        )
        .toList(growable: false);
  }

  List<LocalChainResponseOption> availablePlayerActivations(
    String cardInstanceId,
  ) {
    return ManualActivationPlanner(engine)
        .legalOptions(
          state: state,
          participant: DuelParticipant.player,
          context: _currentResponseContext,
        )
        .where((option) => option.source.instanceId == cardInstanceId)
        .map(
          (option) => LocalChainResponseOption(
            card: option.source,
            link: option.link,
            label: option.description,
          ),
        )
        .toList(growable: false);
  }

  LocalDuelActionResult activatePreparedOption({
    required LocalChainResponseOption option,
    required bool resolveImmediately,
  }) {
    final result = engine.activateCard(
      state: state,
      participant: DuelParticipant.player,
      cardInstanceId: option.card.instanceId,
      link: option.link,
    );
    if (!result.succeeded) return _failure(result.failure);
    lastChainEvents = ['Activation : ${presentationOf(option.card).name}'];
    state = result.state;
    _playAiPriorityOnce();
    if (resolveImmediately && !awaitingPlayerPriority) {
      state = _settleWindow(state, recordResolution: true);
    }
    return LocalDuelActionResult(
      true,
      resolveImmediately
          ? 'Effet activé et Chaîne résolue.'
          : 'Effet ajouté à la Chaîne.',
    );
  }

  LocalDuelActionResult activatePlayerResponse({
    required LocalChainResponseOption option,
    String? targetInstanceId,
    String? discardInstanceId,
  }) {
    if (!awaitingPlayerPriority) {
      return const LocalDuelActionResult(false, 'Vous n’avez pas la priorité.');
    }
    return activatePreparedOption(option: option, resolveImmediately: false);
  }

  void _playAiPriorityOnce() {
    if (!state.chain.isOpen ||
        state.chain.priorityPlayer != DuelParticipant.ai ||
        state.isFinished) {
      return;
    }
    final options = ManualActivationPlanner(engine).legalOptions(
      state: state,
      participant: DuelParticipant.ai,
      context: _currentResponseContext,
    );
    final selected = ai.chooseChainActivation(
      state: state,
      availableActivations:
          options.map((option) => option.link).toList(growable: false),
    );
    if (selected != null) {
      final activated = engine.activateCard(
        state: state,
        participant: DuelParticipant.ai,
        cardInstanceId: selected.sourceCardInstanceId!,
        link: selected,
      );
      if (activated.succeeded) {
        state = activated.state;
        return;
      }
    }
    final passed = engine.passPriority(
      state: state,
      participant: DuelParticipant.ai,
    );
    if (passed.succeeded) {
      _recordPassResolution(passed);
      state = passed.state;
    }
  }

  LocalDuelActionResult passPlayerPriority() {
    if (!awaitingPlayerPriority) {
      return const LocalDuelActionResult(false, 'Vous n’avez pas la priorité.');
    }
    final result = engine.passPriority(
      state: state,
      participant: DuelParticipant.player,
    );
    if (!result.succeeded) return _failure(result.failure);
    _recordPassResolution(result);
    state = result.state;
    if (state.chain.isOpen &&
        state.chain.priorityPlayer == DuelParticipant.ai) {
      _playAiPriorityOnce();
    }
    _autoPassPlayerWhenNoResponseExists();
    if (!state.chain.isOpen) {
      _resolvePendingPlayerAttack();
    }
    if (!state.chain.isOpen && _pendingPlayerAttack == null) {
      _responseContext = const ManualActivationContext();
    }
    return const LocalDuelActionResult(true, 'Priorité passée.');
  }

  LocalDuelActionResult attack({
    required String attackerInstanceId,
    String? targetInstanceId,
  }) {
    final declaration = engine.declareAttack(
      state: state,
      participant: DuelParticipant.player,
      attackerInstanceId: attackerInstanceId,
      targetInstanceId: targetInstanceId,
    );
    if (!declaration.succeeded) return _failure(declaration.failure);
    _responseContext = ManualActivationContext(attack: declaration.declaration);
    _pendingPlayerAttack = declaration.declaration;
    state = declaration.state;
    _playAiPriorityOnce();
    _autoPassPlayerWhenNoResponseExists();
    if (state.chain.isOpen) {
      return const LocalDuelActionResult(true, 'Attaque déclarée.');
    }
    final combat = _resolvePendingPlayerAttack();
    if (combat == null) {
      return const LocalDuelActionResult(false, 'Attaque interrompue.');
    }
    return LocalDuelActionResult(
      combat.status == CombatResolutionStatus.resolved,
      combat.status == CombatResolutionStatus.resolved
          ? 'Attaque résolue.'
          : 'Attaque interrompue.',
    );
  }

  CombatResolutionResult? _resolvePendingPlayerAttack() {
    final declaration = _pendingPlayerAttack;
    if (declaration == null || state.chain.isOpen || state.isFinished) {
      return null;
    }
    _pendingPlayerAttack = null;
    final aiCharactersBefore = {
      for (final card in state.aiField.characterZones.whereType<CardInstance>())
        card.instanceId: card,
    };
    final combat = engine.resolveAttack(
      state: state,
      declaration: declaration,
    );
    state = combat.state;
    final destroyedAiCards = combat.destroyedCardInstanceIds
        .map((id) => aiCharactersBefore[id])
        .whereType<CardInstance>()
        .toList(growable: false);
    if (!state.isFinished &&
        !state.chain.isOpen &&
        destroyedAiCards.isNotEmpty) {
      final destroyed = destroyedAiCards.first;
      _responseContext = ManualActivationContext(
        destroyedCharacterRank: destroyed.rank,
        destroyedWasForest: destroyed.hasFamily('forêt'),
      );
      state = state.copyWith(
        chain: ChainState(
          window: ResponseWindowType.effectActivation,
          priorityPlayer: DuelParticipant.ai,
        ),
      );
      _playAiPriorityOnce();
    }
    return combat;
  }

  /// Conserve l'alternance réglementaire sans afficher une fausse décision :
  /// le joueur passe automatiquement seulement si le moteur ne lui propose
  /// strictement aucune activation légale. Dès qu'une contre-réponse existe,
  /// la boucle s'arrête et l'UI garde la fenêtre ouverte.
  void _autoPassPlayerWhenNoResponseExists() {
    var guard = 0;
    while (awaitingPlayerPriority && guard++ < 12) {
      if (availablePlayerResponses().isNotEmpty) return;
      final passed = engine.passPriority(
        state: state,
        participant: DuelParticipant.player,
      );
      if (!passed.succeeded) return;
      _recordPassResolution(passed);
      state = passed.state;
      if (!state.chain.isOpen) return;
      if (state.chain.priorityPlayer != DuelParticipant.ai) return;
      _playAiPriorityOnce();
    }
  }

  LocalDuelActionResult advancePlayerPhase() {
    if (state.activePlayer != DuelParticipant.player) {
      return const LocalDuelActionResult(false, "C'est le tour de l'IA.");
    }
    if (state.currentPhase == DuelPhase.end) {
      final requirement = engine.handDiscardRequirement(
        state,
        DuelParticipant.player,
      );
      if (requirement != null) {
        final ids = requirement.candidates.reversed
            .take(requirement.requiredCount)
            .map((card) => card.instanceId)
            .toList(growable: false);
        state = engine
            .discardForHandLimit(
              state: state,
              participant: DuelParticipant.player,
              cardInstanceIds: ids,
            )
            .state;
      }
    }
    final result = engine.advancePhase(state);
    if (!result.succeeded) return _failure(result.failure);
    state = result.state;
    return const LocalDuelActionResult(true, 'Phase suivante.');
  }

  List<String> playAiTurn() {
    if (state.activePlayer != DuelParticipant.ai || state.isFinished) {
      return const [];
    }
    final result = ai.playTurn(state);
    state = result.state;
    return result.actions;
  }

  /// Joue l'IA jusqu'à la prochaine décision du joueur. Contrairement à
  /// [playAiTurn], cette méthode ne ferme jamais une priorité appartenant au
  /// joueur et permet donc à l'interface d'afficher ses réponses de Chaîne.
  List<String> playAiUntilPlayerDecision() {
    final actions = <String>[];
    var guard = 0;
    while (!state.isFinished &&
        state.activePlayer == DuelParticipant.ai &&
        guard++ < 120) {
      if (state.chain.isOpen) {
        if (state.chain.priorityPlayer == DuelParticipant.player) break;
        final options = ManualActivationPlanner(engine).legalOptions(
          state: state,
          participant: DuelParticipant.ai,
          context: ManualActivationContext(attack: _pendingAiAttack),
        );
        final selected = ai.chooseChainActivation(
          state: state,
          availableActivations:
              options.map((option) => option.link).toList(growable: false),
        );
        if (selected != null) {
          final activated = engine.activateCard(
            state: state,
            participant: DuelParticipant.ai,
            cardInstanceId: selected.sourceCardInstanceId!,
            link: selected,
          );
          if (activated.succeeded) {
            state = activated.state;
            actions.add('effet_activé');
            continue;
          }
        }
        final passed = engine.passPriority(
          state: state,
          participant: DuelParticipant.ai,
        );
        if (!passed.succeeded) break;
        _recordPassResolution(passed);
        state = passed.state;
        continue;
      }

      if (_pendingAiAttack != null) {
        final playerCharactersBefore = {
          for (final card
              in state.playerField.characterZones.whereType<CardInstance>())
            card.instanceId: card,
        };
        final combat = engine.resolveAttack(
          state: state,
          declaration: _pendingAiAttack!,
        );
        state = combat.state;
        actions.add(
          combat.status == CombatResolutionStatus.cancelled
              ? 'attaque_annulée'
              : 'attaque',
        );
        _pendingAiAttack = null;
        final destroyedPlayerCards = combat.destroyedCardInstanceIds
            .map((id) => playerCharactersBefore[id])
            .whereType<CardInstance>()
            .toList(growable: false);
        if (!state.isFinished &&
            !state.chain.isOpen &&
            destroyedPlayerCards.isNotEmpty) {
          final destroyed = destroyedPlayerCards.first;
          _responseContext = ManualActivationContext(
            destroyedCharacterRank: destroyed.rank,
            destroyedWasForest: destroyed.hasFamily('forêt'),
          );
          state = state.copyWith(
            chain: ChainState(
              window: ResponseWindowType.effectActivation,
              priorityPlayer: DuelParticipant.player,
            ),
          );
        }
        continue;
      }

      if (state.currentPhase == DuelPhase.draw ||
          state.currentPhase == DuelPhase.preparation) {
        final advanced = engine.advancePhase(state);
        if (!advanced.succeeded) break;
        state = advanced.state;
        continue;
      }

      if (state.currentPhase == DuelPhase.main1) {
        if (_aiMainActionsTurn != state.turnNumber) {
          _aiMainActionsTurn = state.turnNumber;
          _aiMonsterActionDone = false;
          _aiBackrowActionDone = false;
        }
        if (!_aiMonsterActionDone) {
          _aiMonsterActionDone = true;
          final previousIds = state.aiField.characterZones
              .whereType<CardInstance>()
              .map((card) => card.instanceId)
              .toSet();
          final monster = ai.playMainMonster(state);
          if (monster != null && monster.succeeded) {
            state = monster.state;
            final summoned = state.aiField.characterZones
                .whereType<CardInstance>()
                .where((card) => !previousIds.contains(card.instanceId))
                .firstOrNull;
            if (summoned != null) {
              _responseContext = ManualActivationContext(
                summonedOpponentInstanceId: summoned.instanceId,
              );
            }
            actions.add('personnage_joué');
            continue;
          }
        }
        if (!_aiBackrowActionDone) {
          _aiBackrowActionDone = true;
          final support = ai.setBackrow(state);
          if (support != null && support.succeeded) {
            state = support.state;
            actions.add('carte_posée');
            continue;
          }
        }
        final advanced = engine.advancePhase(state);
        if (!advanced.succeeded) break;
        state = advanced.state;
        continue;
      }

      if (state.currentPhase == DuelPhase.battle) {
        final attack = ai.declareAttack(state);
        if (attack != null && attack.succeeded) {
          state = attack.state;
          _pendingAiAttack = attack.declaration;
          actions.add('attaque_déclarée');
          continue;
        }
        final advanced = engine.advancePhase(state);
        if (!advanced.succeeded) break;
        state = advanced.state;
        continue;
      }

      if (state.currentPhase == DuelPhase.main2) {
        final advanced = engine.advancePhase(state);
        if (!advanced.succeeded) break;
        state = advanced.state;
        continue;
      }

      if (state.currentPhase == DuelPhase.end) {
        final discard = ai.discardExcessHand(state);
        if (discard != null && discard.succeeded) {
          state = discard.state;
          actions.add('défausse');
        }
        final advanced = engine.advancePhase(state);
        if (!advanced.succeeded) break;
        state = advanced.state;
      }
    }
    return actions;
  }

  void _recordPassResolution(PriorityPassResult result) {
    if (!result.resolutionTriggered) return;
    lastChainEvents = [
      ...lastChainEvents,
      for (final id in result.resolvedLinkIds) 'Résolu : $id',
      for (final id in result.fizzledLinkIds) 'Annulé : $id',
    ];
  }

  DuelState _settleWindow(
    DuelState initial, {
    bool recordResolution = false,
  }) {
    var current = initial;
    var guard = 0;
    while (current.chain.isOpen && !current.isFinished && guard++ < 12) {
      final priority = current.chain.priorityPlayer;
      if (priority == null) break;
      final result = engine.passPriority(state: current, participant: priority);
      if (!result.succeeded) break;
      if (recordResolution && result.resolutionTriggered) {
        lastChainEvents = [
          ...lastChainEvents,
          for (final id in result.resolvedLinkIds) 'Résolu : $id',
          for (final id in result.fizzledLinkIds) 'Annulé : $id',
        ];
      }
      current = result.state;
    }
    if (!current.chain.isOpen) {
      _responseContext = const ManualActivationContext();
    }
    return current;
  }

  LocalDuelActionResult _failure(DuelActionFailure? failure) {
    final message = switch (failure) {
      DuelActionFailure.notActivePlayer => "Ce n'est pas votre tour.",
      DuelActionFailure.normalSummonAlreadyUsed =>
        'Invocation ou pose normale déjà utilisée ce tour.',
      DuelActionFailure.wrongSacrificeCount =>
        'Sélectionnez le nombre exact de sacrifices requis.',
      DuelActionFailure.characterZoneFull =>
        'Aucune Zone Personnage disponible.',
      DuelActionFailure.actionTrapZoneFull =>
        'Aucune Zone Action/Piège disponible.',
      DuelActionFailure.notMainPhase =>
        'Activez cette carte pendant une Phase Principale.',
      DuelActionFailure.cardCannotBeActivated =>
        'Cette carte ne peut pas être activée maintenant.',
      DuelActionFailure.chainActivationConditionNotMet =>
        'Les conditions de cet effet ne sont pas réunies.',
      DuelActionFailure.illegalChainTarget => 'La cible choisie est illégale.',
      DuelActionFailure.illegalChainSpeed =>
        'La vitesse de cet effet ne permet pas cette réponse.',
      DuelActionFailure.notBattlePhase =>
        'Les attaques ne sont possibles qu’en Phase de Combat.',
      DuelActionFailure.attackForbiddenOnOpeningTurn =>
        'Le joueur qui commence ne peut pas attaquer au premier tour.',
      DuelActionFailure.attackerAlreadyAttacked =>
        'Ce Personnage a déjà attaqué ce tour.',
      DuelActionFailure.attackerNotInAttackPosition =>
        'Seul un Personnage en Attaque peut attaquer.',
      DuelActionFailure.directAttackBlocked =>
        'Vous devez attaquer un Personnage adverse.',
      _ => 'Action impossible (${failure?.name ?? 'inconnue'}).',
    };
    return LocalDuelActionResult(false, message);
  }

  static List<CardInstance> _buildDeck(DuelParticipant participant) {
    final composition = <LocalCardPresentation>[
      for (var copy = 0; copy < 2; copy++) ..._definitions.take(10),
      ..._definitions.skip(10).take(10),
      ..._definitions.skip(20),
    ];
    return _buildInstances(composition, participant);
  }

  static List<CardInstance> _buildInstances(
    List<LocalCardPresentation> definitions,
    DuelParticipant participant,
  ) =>
      [
        for (var index = 0; index < definitions.length; index++)
          _instance(definitions[index], participant, index),
      ];

  static CardInstance _instance(
    LocalCardPresentation definition,
    DuelParticipant participant,
    int index,
  ) {
    return CardInstance(
      instanceId: '${participant.name}-${definition.code}-$index',
      cardId: definition.cardId ?? 'local-${definition.code}',
      cardCode: definition.code,
      cardRevision: definition.revision,
      category: definition.category,
      rank: definition.rank,
      subtype: definition.subtype,
      attribute: definition.attribute,
      primaryFamily: definition.family,
      secondaryFamilies: definition.secondaryFamilies,
      mythicSummonCondition: definition.mythicSummonCondition,
      effectKey: definition.effectKey,
      effectData: definition.effectData,
      owner: participant,
      controller: participant,
      faceUp: false,
      position: null,
      atk: definition.atk,
      def: definition.def,
    );
  }

  static const _definitions = <LocalCardPresentation>[
    LocalCardPresentation(
        code: 'BAB-003',
        name: 'Gardien du Carrefour',
        category: CardCategory.character,
        family: 'Babi',
        attribute: 'Terre',
        rank: 4,
        atk: 1800,
        def: 1700),
    LocalCardPresentation(
        code: 'ROY-003',
        name: 'Garde du Tambour Royal',
        category: CardCategory.character,
        family: 'Royaume',
        attribute: 'Terre',
        rank: 4,
        atk: 1700,
        def: 2000),
    LocalCardPresentation(
        code: 'ANC-003',
        name: 'Veilleuse du Foyer Invisible',
        category: CardCategory.character,
        family: 'Ancêtre',
        attribute: 'Feu',
        rank: 3,
        atk: 1300,
        def: 1700),
    LocalCardPresentation(
        code: 'MAS-003',
        name: 'Sentinelle au Visage de Bois',
        category: CardCategory.character,
        family: 'Masque',
        attribute: 'Nature',
        rank: 4,
        atk: 1600,
        def: 2100),
    LocalCardPresentation(
        code: 'DOZ-003',
        name: 'Gardien au Fusil Rituel',
        category: CardCategory.character,
        family: 'Dozo',
        attribute: 'Feu',
        rank: 4,
        atk: 1800,
        def: 1800),
    LocalCardPresentation(
        code: 'FOR-003',
        name: 'Antilope des Sous-Bois',
        category: CardCategory.character,
        family: 'Forêt',
        attribute: 'Vent',
        rank: 3,
        atk: 1500,
        def: 1400),
    LocalCardPresentation(
        code: 'LAG-003',
        name: 'Crocodile de la Lagune Calme',
        category: CardCategory.character,
        family: 'Lagune',
        attribute: 'Eau',
        rank: 4,
        atk: 1900,
        def: 1700),
    LocalCardPresentation(
        code: 'SAV-003',
        name: 'Buffle des Plaines Rouges',
        category: CardCategory.character,
        family: 'Savane',
        attribute: 'Terre',
        rank: 4,
        atk: 2000,
        def: 1600),
    LocalCardPresentation(
        code: 'VIL-003',
        name: 'Maçon du Mur de Banco',
        category: CardCategory.character,
        family: 'Village',
        attribute: 'Terre',
        rank: 4,
        atk: 1600,
        def: 2200),
    LocalCardPresentation(
        code: 'MAQ-003',
        name: 'Videur au Grand Sourire',
        category: CardCategory.character,
        family: 'Maquis',
        attribute: 'Terre',
        rank: 4,
        atk: 1800,
        def: 2000),
    LocalCardPresentation(
        code: 'BAB-005',
        name: 'Hacker du Marché',
        category: CardCategory.character,
        family: 'Babi',
        attribute: 'Ombre',
        rank: 5,
        atk: 2100,
        def: 1800),
    LocalCardPresentation(
        code: 'ROY-005',
        name: 'Cavalier au Manteau Pourpre',
        category: CardCategory.character,
        family: 'Royaume',
        attribute: 'Vent',
        rank: 5,
        atk: 2200,
        def: 1700),
    LocalCardPresentation(
        code: 'ANC-005',
        name: 'Gardienne des Noms Oubliés',
        category: CardCategory.character,
        family: 'Ancêtre',
        attribute: 'Esprit',
        rank: 5,
        atk: 2100,
        def: 2200),
    LocalCardPresentation(
        code: 'MAS-005',
        name: 'Sculpteur des Gestes Secrets',
        category: CardCategory.character,
        family: 'Masque',
        attribute: 'Terre',
        rank: 5,
        atk: 2100,
        def: 2300),
    LocalCardPresentation(
        code: 'DOZ-005',
        name: 'Chasseuse au Manteau Brun',
        category: CardCategory.character,
        family: 'Dozo',
        attribute: 'Nature',
        rank: 5,
        atk: 2200,
        def: 1900),
    LocalCardPresentation(
        code: 'FOR-005',
        name: 'Panthère des Racines',
        category: CardCategory.character,
        family: 'Forêt',
        attribute: 'Ombre',
        rank: 5,
        atk: 2200,
        def: 1800),
    LocalCardPresentation(
        code: 'LAG-005',
        name: 'Gardienne des Palétuviers',
        category: CardCategory.character,
        family: 'Lagune',
        attribute: 'Nature',
        rank: 5,
        atk: 2100,
        def: 2400),
    LocalCardPresentation(
        code: 'SAV-005',
        name: 'Éclaireuse des Termitières',
        category: CardCategory.character,
        family: 'Savane',
        attribute: 'Terre',
        rank: 5,
        atk: 2200,
        def: 2000),
    LocalCardPresentation(
        code: 'VIL-005',
        name: 'Doyenne du Grenier Commun',
        category: CardCategory.character,
        family: 'Village',
        attribute: 'Nature',
        rank: 5,
        atk: 2000,
        def: 2500),
    LocalCardPresentation(
        code: 'MAQ-005',
        name: 'Cuisinière de Minuit',
        category: CardCategory.character,
        family: 'Maquis',
        attribute: 'Feu',
        rank: 5,
        atk: 2100,
        def: 2300),
    LocalCardPresentation(
        code: 'BAB-008',
        name: 'Trajet Express',
        category: CardCategory.action,
        family: 'Babi',
        attribute: 'Vent',
        subtype: 'quick'),
    LocalCardPresentation(
        code: 'ROY-008',
        name: 'Décret de Mobilisation',
        category: CardCategory.action,
        family: 'Royaume',
        attribute: 'Lumière',
        subtype: 'normal'),
    LocalCardPresentation(
        code: 'ANC-008',
        name: 'Parole Transmise',
        category: CardCategory.action,
        family: 'Ancêtre',
        attribute: 'Esprit',
        subtype: 'normal'),
    LocalCardPresentation(
        code: 'MAS-008',
        name: 'Changement de Visage',
        category: CardCategory.action,
        family: 'Masque',
        attribute: 'Ombre',
        subtype: 'quick'),
    LocalCardPresentation(
        code: 'DOZ-008',
        name: 'Piste Fraîche',
        category: CardCategory.action,
        family: 'Dozo',
        attribute: 'Terre',
        subtype: 'normal'),
    LocalCardPresentation(
        code: 'FOR-011',
        name: 'Liane Entravante',
        category: CardCategory.trap,
        family: 'Forêt',
        attribute: 'Nature',
        subtype: 'normal'),
    LocalCardPresentation(
        code: 'LAG-011',
        name: 'Filet des Piroguiers',
        category: CardCategory.trap,
        family: 'Lagune',
        attribute: 'Eau',
        subtype: 'normal'),
    LocalCardPresentation(
        code: 'SAV-011',
        name: 'Poussière Aveuglante',
        category: CardCategory.trap,
        family: 'Savane',
        attribute: 'Vent',
        subtype: 'normal'),
    LocalCardPresentation(
        code: 'VIL-011',
        name: 'Mur de Banco Renforcé',
        category: CardCategory.trap,
        family: 'Village',
        attribute: 'Terre',
        subtype: 'normal'),
    LocalCardPresentation(
        code: 'MAQ-011',
        name: 'Plateau Très Glissant',
        category: CardCategory.trap,
        family: 'Maquis',
        attribute: 'Eau',
        subtype: 'normal'),
  ];
}
