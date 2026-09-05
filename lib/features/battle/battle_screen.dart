import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../game/ai/ai_strategy.dart';
import '../../game/card.dart';
import '../../game/duel_types.dart';
import 'battle_result_repository.dart';
import 'local_duel.dart';
import 'reward_screen.dart';

class BattleScreen extends StatefulWidget {
  const BattleScreen.local({
    this.difficulty = AiDifficulty.beginner,
    this.deckId,
    this.playerDeck,
    this.playerMythicReserve = const [],
    this.isFirstBattle = false,
    this.resultRepository,
    this.controller,
    super.key,
  });

  final AiDifficulty difficulty;
  final String? deckId;
  final List<LocalCardPresentation>? playerDeck;
  final List<LocalCardPresentation> playerMythicReserve;
  final bool isFirstBattle;
  final BattleResultDataSource? resultRepository;
  final LocalDuelController? controller;

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  late LocalDuelController _duel;
  final Set<String> _selectedSacrifices = {};
  String? _selectedAttackerId;
  bool _aiPlaying = false;
  bool _endDialogShown = false;
  bool _savingResult = false;
  late AiDifficulty _difficulty;
  late DateTime _startedAt;
  BattleReport? _pendingReport;
  Timer? _bannerTimer;
  Timer? _hudTimer;
  Timer? _cardFeedbackTimer;
  _MomentBannerData? _momentBanner;
  String? _hudMessage;
  bool _hudIsError = false;
  String? _feedbackCardId;
  String? _feedbackMessage;
  int _feedbackToken = 0;
  List<LocalChainResponseOption> _pendingTargetOptions = const [];
  String? _pendingChainSourceId;

  @override
  void initState() {
    super.initState();
    _difficulty = widget.difficulty;
    _startedAt = DateTime.now().toUtc();
    _duel = widget.controller ??
        LocalDuelController.create(
          difficulty: _difficulty,
          playerDeck: widget.playerDeck,
          playerMythicReserve: widget.playerMythicReserve,
        );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showTurnBanner(DuelParticipant.player);
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _hudTimer?.cancel();
    _cardFeedbackTimer?.cancel();
    super.dispose();
  }

  void _restart([AiDifficulty? difficulty]) {
    setState(() {
      _difficulty = difficulty ?? _difficulty;
      _startedAt = DateTime.now().toUtc();
      _duel = LocalDuelController.create(
        difficulty: _difficulty,
        playerDeck: widget.playerDeck,
        playerMythicReserve: widget.playerMythicReserve,
      );
      _selectedSacrifices.clear();
      _selectedAttackerId = null;
      _endDialogShown = false;
      _savingResult = false;
      _pendingReport = null;
      _momentBanner = null;
      _hudMessage = null;
      _feedbackCardId = null;
      _feedbackMessage = null;
      _pendingTargetOptions = const [];
      _pendingChainSourceId = null;
    });
    _showTurnBanner(DuelParticipant.player);
  }

  void _showTurnBanner(DuelParticipant participant) {
    _showMomentBanner(
      _MomentBannerData(
        label: participant == DuelParticipant.player
            ? 'TON TOUR'
            : "TOUR DE L'ADVERSAIRE",
        icon: participant == DuelParticipant.player
            ? Icons.local_fire_department
            : Icons.psychology,
        color: participant == DuelParticipant.player
            ? const Color(0xFF65E8C2)
            : const Color(0xFFFF6B7A),
      ),
    );
  }

  void _showPhaseBanner(DuelPhase phase) {
    final visual = _PhaseVisual.of(phase);
    _showMomentBanner(
      _MomentBannerData(
        label: visual.bannerLabel,
        icon: visual.icon,
        color: visual.color,
      ),
    );
  }

  void _showMomentBanner(_MomentBannerData data) {
    _bannerTimer?.cancel();
    setState(() => _momentBanner = data);
    _bannerTimer = Timer(const Duration(milliseconds: 1050), () {
      if (mounted) setState(() => _momentBanner = null);
    });
  }

  void _showTransition({
    required DuelParticipant previousPlayer,
    required DuelPhase previousPhase,
  }) {
    final state = _duel.state;
    if (state.activePlayer != previousPlayer) {
      _showTurnBanner(state.activePlayer);
    } else if (state.currentPhase != previousPhase) {
      _showPhaseBanner(state.currentPhase);
    }
  }

  void _showHudMessage(String message, {bool error = false}) {
    _hudTimer?.cancel();
    setState(() {
      _hudMessage = message;
      _hudIsError = error;
    });
    _hudTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _hudMessage = null);
    });
  }

  void _showCardError(String cardInstanceId, String message) {
    _cardFeedbackTimer?.cancel();
    setState(() {
      _feedbackCardId = cardInstanceId;
      _feedbackMessage = message;
      _feedbackToken++;
    });
    _cardFeedbackTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted || _feedbackCardId != cardInstanceId) return;
      setState(() {
        _feedbackCardId = null;
        _feedbackMessage = null;
      });
    });
  }

  List<LocalChainResponseOption> get _chainOptions =>
      _duel.awaitingPlayerPriority
          ? _duel.availablePlayerResponses()
          : const [];

  Set<String> get _activatableCardIds =>
      _chainOptions.map((option) => option.card.instanceId).toSet();

  Set<String> get _validChainTargetIds => _pendingTargetOptions
      .map((option) => option.link.target?.cardInstanceId)
      .whereType<String>()
      .toSet();

  Future<void> _chooseChainCard(String cardInstanceId) async {
    final options = _chainOptions
        .where((option) => option.card.instanceId == cardInstanceId)
        .toList(growable: false);
    if (options.isEmpty) return;
    if (options.length == 1) {
      _activateChainOption(options.single);
      return;
    }
    final targetIds = options
        .map((option) => option.link.target?.cardInstanceId)
        .whereType<String>()
        .toList(growable: false);
    if (targetIds.length == options.length && targetIds.toSet().length > 1) {
      setState(() {
        _pendingChainSourceId = cardInstanceId;
        _pendingTargetOptions = options;
      });
      _showHudMessage('Choisis une cible lumineuse');
      return;
    }
    final selected = await showModalBottomSheet<LocalChainResponseOption>(
      context: context,
      backgroundColor: const Color(0xFF171124),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.link, color: Color(0xFF72F7D0)),
              const SizedBox(height: 6),
              const Text(
                'Choisis le coût ou la combinaison',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              for (final option in options)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.bolt),
                  title: Text(option.label),
                  onTap: () => Navigator.pop(context, option),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) _activateChainOption(selected);
  }

  bool _trySelectChainTarget(String cardInstanceId) {
    final option = _pendingTargetOptions
        .where(
          (candidate) =>
              candidate.link.target?.cardInstanceId == cardInstanceId,
        )
        .firstOrNull;
    if (option == null) return false;
    _activateChainOption(option);
    return true;
  }

  void _activateChainOption(LocalChainResponseOption option) {
    final result = _duel.activatePlayerResponse(option: option);
    setState(() {
      _pendingTargetOptions = const [];
      _pendingChainSourceId = null;
    });
    if (!result.succeeded) {
      _showCardError(option.card.instanceId, result.message);
    }
    _checkEnd();
  }

  Future<void> _passChainPriority() async {
    final result = _duel.passPlayerPriority();
    setState(() {
      _pendingTargetOptions = const [];
      _pendingChainSourceId = null;
    });
    if (!result.succeeded) {
      _showHudMessage(result.message, error: true);
      return;
    }
    _checkEnd();
    if (!mounted || _duel.state.isFinished) return;
    if (_duel.state.activePlayer == DuelParticipant.ai) {
      await _runAiUntilDecision();
    }
  }

  Future<void> _playHandCard(CardInstance card) async {
    if (_aiPlaying || _duel.state.isFinished) return;
    if (_duel.awaitingPlayerPriority) {
      await _chooseChainCard(card.instanceId);
      return;
    }
    if (_duel.state.activePlayer != DuelParticipant.player ||
        !{DuelPhase.main1, DuelPhase.main2}
            .contains(_duel.state.currentPhase)) {
      _showCardError(
        card.instanceId,
        'Attends une Phase Principale',
      );
      return;
    }
    if (card.category == CardCategory.character) {
      final required = _duel.engine.requiredSacrificesForNormalPlay(card);
      if (required == null) {
        _showCardError(card.instanceId, 'Invocation spéciale requise');
        return;
      }
      if (_selectedSacrifices.length != required) {
        _showCardError(
          card.instanceId,
          required == 0
              ? 'Cette carte ne demande aucun sacrifice.'
              : '$required sacrifice${required > 1 ? 's' : ''} requis',
        );
        if (required > 0) return;
      }
      if (!mounted) return;
      final faceUp = await showModalBottomSheet<bool>(
        context: context,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(card.cardCode,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(context, true),
                        icon: const Icon(Icons.flash_on),
                        label: const Text('Invoquer en Attaque'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context, false),
                        icon: const Icon(Icons.shield),
                        label: const Text('Poser en Défense'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      if (faceUp == null) return;
      final result = _duel.playCharacter(
        cardInstanceId: card.instanceId,
        faceUpAttack: faceUp,
        sacrificeInstanceIds: _selectedSacrifices.toList(growable: false),
      );
      setState(() {
        _selectedSacrifices.clear();
        _selectedAttackerId = null;
      });
      if (!result.succeeded) {
        _showCardError(card.instanceId, result.message);
      }
      _checkEnd();
      return;
    }

    if (card.category == CardCategory.action ||
        card.category == CardCategory.trap) {
      if (card.category == CardCategory.action) {
        final choice = await showModalBottomSheet<String>(
          context: context,
          builder: (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _duel.presentationOf(card).name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(context, 'activate'),
                    icon: const Icon(Icons.bolt),
                    label: const Text('Activer maintenant'),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context, 'set'),
                    icon: const Icon(Icons.visibility_off),
                    label: const Text('Poser face cachée'),
                  ),
                ],
              ),
            ),
          ),
        );
        if (choice == 'activate') {
          await _activateEffectCard(card);
          return;
        }
        if (choice != 'set') return;
      }
      final result = _duel.setActionOrTrap(card.instanceId);
      setState(() {});
      if (!result.succeeded) {
        _showCardError(card.instanceId, result.message);
      }
      return;
    }
    if (card.category == CardCategory.terrain ||
        card.category == CardCategory.relic) {
      await _activateEffectCard(card);
      return;
    }
    _showCardError(card.instanceId, 'Cette carte ne se joue pas ici');
  }

  Future<void> _activateEffectCard(CardInstance card) async {
    final options = _duel.availablePlayerActivations(card.instanceId);
    if (options.isEmpty) {
      _showCardError(card.instanceId, 'Effet indisponible maintenant');
      return;
    }
    LocalChainResponseOption? selected;
    if (options.length == 1) {
      selected = options.single;
    } else {
      final index = await showDialog<int>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Choisissez la cible ou le coût'),
          children: [
            for (var index = 0; index < options.length; index++)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, index),
                child: Text(options[index].label),
              ),
          ],
        ),
      );
      if (index == null) return;
      selected = options[index];
    }
    final result = _duel.activatePreparedOption(
      option: selected,
      resolveImmediately: true,
    );
    if (!mounted) return;
    setState(() {});
    if (!result.succeeded) {
      _showCardError(card.instanceId, result.message);
    }
    _checkEnd();
  }

  void _showCards(String title, List<CardInstance> cards) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (cards.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Aucune carte.'),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: cards.length,
                    itemBuilder: (context, index) {
                      final card = cards[index];
                      return ListTile(
                        leading: Icon(
                            card.faceUp ? Icons.style : Icons.visibility_off),
                        title: Text(_duel.presentationOf(card).name),
                        subtitle: Text(card.cardCode),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _tapOwnCharacter(FieldCardInstance card) {
    if (_aiPlaying || _duel.state.isFinished) return;
    if (_trySelectChainTarget(card.instanceId)) return;
    final state = _duel.state;
    if ({DuelPhase.main1, DuelPhase.main2}.contains(state.currentPhase)) {
      setState(() {
        if (!_selectedSacrifices.remove(card.instanceId)) {
          _selectedSacrifices.add(card.instanceId);
        }
      });
      return;
    }
    if (state.currentPhase == DuelPhase.battle) {
      if (card.position != BattlePosition.attack) {
        _showCardError(card.instanceId, 'Position Défense');
        return;
      }
      final hasTarget =
          state.aiField.characterZones.any((zone) => zone != null);
      if (!hasTarget) {
        _resolveAttack(card.instanceId, null);
      } else {
        setState(() => _selectedAttackerId = card.instanceId);
        _showHudMessage('Choisis une cible adverse');
      }
    }
  }

  void _tapOpponentCharacter(FieldCardInstance card) {
    if (_trySelectChainTarget(card.instanceId)) return;
    final attackerId = _selectedAttackerId;
    if (attackerId == null) {
      _showCardError(card.instanceId, 'Choisis d’abord un attaquant');
      return;
    }
    _resolveAttack(attackerId, card.instanceId);
  }

  void _tapSupportCard(FieldCardInstance card) {
    if (_trySelectChainTarget(card.instanceId)) return;
    if (card is! CardInstance) return;
    if (_duel.awaitingPlayerPriority) {
      _chooseChainCard(card.instanceId);
      return;
    }
    _activateEffectCard(card);
  }

  void _resolveAttack(String attackerId, String? targetId) {
    final result = _duel.attack(
      attackerInstanceId: attackerId,
      targetInstanceId: targetId,
    );
    setState(() => _selectedAttackerId = null);
    if (!result.succeeded) {
      _showCardError(attackerId, result.message);
    }
    _checkEnd();
  }

  Future<void> _nextPhase() async {
    if (_aiPlaying || _duel.state.isFinished) return;
    final previousPlayer = _duel.state.activePlayer;
    final previousPhase = _duel.state.currentPhase;
    final result = _duel.advancePlayerPhase();
    setState(() {
      _selectedSacrifices.clear();
      _selectedAttackerId = null;
    });
    if (!result.succeeded) {
      _showHudMessage(result.message, error: true);
      return;
    }
    _showTransition(
      previousPlayer: previousPlayer,
      previousPhase: previousPhase,
    );
    _checkEnd();
    if (_duel.state.activePlayer == DuelParticipant.ai &&
        !_duel.state.isFinished) {
      await _runAiUntilDecision();
    }
  }

  Future<void> _runAiUntilDecision() async {
    if (!mounted ||
        _duel.state.isFinished ||
        _duel.state.activePlayer != DuelParticipant.ai) {
      return;
    }
    setState(() => _aiPlaying = true);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final previousPlayer = _duel.state.activePlayer;
    final previousPhase = _duel.state.currentPhase;
    final actions = _duel.playAiUntilPlayerDecision();
    if (!mounted) return;
    setState(() => _aiPlaying = false);
    _showTransition(
      previousPlayer: previousPlayer,
      previousPhase: previousPhase,
    );
    _checkEnd();
    if (_duel.state.isFinished) return;

    if (_duel.awaitingPlayerPriority) {
      return;
    }

    if (_duel.state.activePlayer == DuelParticipant.player &&
        actions.isNotEmpty) {
      _showHudMessage(
        '${actions.length} action${actions.length > 1 ? 's' : ''} adverse${actions.length > 1 ? 's' : ''}',
      );
    }
  }

  void _checkEnd() {
    if (!_duel.state.isFinished || _endDialogShown || !mounted) return;
    _endDialogShown = true;
    if (widget.deckId != null) {
      _saveCompletedDuel();
      return;
    }
    _showLocalResultDialog();
  }

  Future<void> _saveCompletedDuel() async {
    final report = _pendingReport ??= BattleReport.fromDuelState(
      state: _duel.state,
      deckId: widget.deckId!,
      aiKey: 'solo-v2-${_difficulty.name}',
      difficulty: _difficulty.name,
      startedAt: _startedAt,
      completedAt: DateTime.now().toUtc(),
    );
    setState(() => _savingResult = true);
    try {
      final reward =
          await (widget.resultRepository ?? SupabaseBattleResultRepository())
              .save(report);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.reward,
        arguments: BattleRewardScreenData(
          report: report,
          reward: reward,
          isFirstBattle: widget.isFirstBattle,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _savingResult = false);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Sauvegarde impossible'),
          content: Text(
            'Le duel est terminé mais son résultat n’a pas encore été enregistré.\n\n$error',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.maybePop(context);
              },
              child: const Text('Quitter'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _saveCompletedDuel();
              },
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }
  }

  void _showLocalResultDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final victory = _duel.state.winner == DuelParticipant.player;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: Icon(victory ? Icons.emoji_events : Icons.flag, size: 54),
          title: Text(victory ? 'Victoire !' : 'Défaite'),
          content: Text(
            victory
                ? 'Vous avez remporté ce duel local V2.'
                : "L'IA débutante remporte ce duel. Revanche ?",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.maybePop(context);
              },
              child: const Text('Quitter'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _restart();
              },
              child: const Text('Rejouer'),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = _duel.state;
    final activatableIds = _activatableCardIds;
    final validTargetIds = _validChainTargetIds;
    return Scaffold(
      appBar: AppBar(
        title: Text('Duel V2 · ${_difficultyLabel(_difficulty)}'),
        actions: [
          if (!widget.isFirstBattle)
            PopupMenuButton<AiDifficulty>(
              tooltip: 'Choisir la difficulté',
              initialValue: _difficulty,
              onSelected: _restart,
              itemBuilder: (context) => [
                for (final difficulty in AiDifficulty.values)
                  PopupMenuItem(
                    value: difficulty,
                    child: Text(_difficultyLabel(difficulty)),
                  ),
              ],
              icon: const Icon(Icons.psychology),
            ),
          IconButton(
            tooltip: 'Recommencer',
            onPressed: _restart,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF17111F),
                  Color(0xFF33203C),
                  Color(0xFF102B28)
                ],
              ),
            ),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight - 24),
                    child: Column(
                      children: [
                        _PlayerStatus(
                            name:
                                'IA ${_difficultyLabel(_difficulty).toLowerCase()}',
                            lifePoints: state.aiLifePoints,
                            handCount: state.aiField.hand.length,
                            deckCount: state.aiField.deck.length,
                            graveyardCount: state.aiField.graveyard.length,
                            isActive: state.activePlayer == DuelParticipant.ai),
                        const SizedBox(height: 8),
                        _ZoneRow(
                            zones: state.aiField.actionTrapZones,
                            opponent: true,
                            controller: _duel,
                            feedbackCardId: _feedbackCardId,
                            feedbackMessage: _feedbackMessage,
                            feedbackToken: _feedbackToken,
                            activatableIds: activatableIds,
                            validTargetIds: validTargetIds,
                            onCardTap: _tapSupportCard),
                        const SizedBox(height: 6),
                        _ZoneRow(
                            zones: state.aiField.characterZones,
                            opponent: true,
                            controller: _duel,
                            feedbackCardId: _feedbackCardId,
                            feedbackMessage: _feedbackMessage,
                            feedbackToken: _feedbackToken,
                            activatableIds: activatableIds,
                            validTargetIds: validTargetIds,
                            onCardTap: _tapOpponentCharacter),
                        const SizedBox(height: 6),
                        _TerrainSlot(
                          card: state.aiField.terrainZone,
                          controller: _duel,
                          opponent: true,
                          feedbackCardId: _feedbackCardId,
                          feedbackMessage: _feedbackMessage,
                          feedbackToken: _feedbackToken,
                          activatable: activatableIds
                              .contains(state.aiField.terrainZone?.instanceId),
                          validTarget: validTargetIds
                              .contains(state.aiField.terrainZone?.instanceId),
                          onTap: state.aiField.terrainZone == null
                              ? null
                              : () =>
                                  _tapSupportCard(state.aiField.terrainZone!),
                        ),
                        const SizedBox(height: 12),
                        _PhaseBar(
                            phase: state.currentPhase,
                            turn: state.turnNumber,
                            aiPlaying: _aiPlaying,
                            onNext: state.activePlayer == DuelParticipant.player
                                ? _nextPhase
                                : null),
                        const SizedBox(height: 12),
                        _ZoneRow(
                            zones: state.playerField.characterZones,
                            controller: _duel,
                            selectedIds: {
                              ..._selectedSacrifices,
                              if (_selectedAttackerId != null)
                                _selectedAttackerId!
                            },
                            feedbackCardId: _feedbackCardId,
                            feedbackMessage: _feedbackMessage,
                            feedbackToken: _feedbackToken,
                            activatableIds: activatableIds,
                            validTargetIds: validTargetIds,
                            onCardTap: _tapOwnCharacter),
                        const SizedBox(height: 6),
                        _ZoneRow(
                            zones: state.playerField.actionTrapZones,
                            controller: _duel,
                            selectedIds: {
                              if (_pendingChainSourceId != null)
                                _pendingChainSourceId!,
                            },
                            feedbackCardId: _feedbackCardId,
                            feedbackMessage: _feedbackMessage,
                            feedbackToken: _feedbackToken,
                            activatableIds: activatableIds,
                            validTargetIds: validTargetIds,
                            onCardTap: _tapSupportCard),
                        const SizedBox(height: 6),
                        _TerrainSlot(
                          card: state.playerField.terrainZone,
                          controller: _duel,
                          feedbackCardId: _feedbackCardId,
                          feedbackMessage: _feedbackMessage,
                          feedbackToken: _feedbackToken,
                          activatable: activatableIds.contains(
                            state.playerField.terrainZone?.instanceId,
                          ),
                          validTarget: validTargetIds.contains(
                            state.playerField.terrainZone?.instanceId,
                          ),
                          onTap: state.playerField.terrainZone == null
                              ? null
                              : () => _tapSupportCard(
                                    state.playerField.terrainZone!,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        _PlayerStatus(
                            name: 'Vous',
                            lifePoints: state.playerLifePoints,
                            handCount: state.playerField.hand.length,
                            deckCount: state.playerField.deck.length,
                            graveyardCount: state.playerField.graveyard.length,
                            isActive:
                                state.activePlayer == DuelParticipant.player),
                        if (_selectedSacrifices.isNotEmpty)
                          Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                  '${_selectedSacrifices.length} sacrifice(s) sélectionné(s)',
                                  style: const TextStyle(
                                      color: Color(0xFFFFD166)))),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          children: [
                            TextButton.icon(
                              onPressed: () => _showCards(
                                'Votre Cimetière',
                                state.playerField.graveyard,
                              ),
                              icon: const Icon(Icons.auto_delete),
                              label: Text(
                                'Cimetière (${state.playerField.graveyard.length})',
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _showCards(
                                'Réserve des Mythiques',
                                state.playerField.mythicReserve,
                              ),
                              icon: const Icon(Icons.auto_awesome),
                              label: Text(
                                'Réserve (${state.playerField.mythicReserve.length})',
                              ),
                            ),
                          ],
                        ),
                        if (_duel.lastChainEvents.isNotEmpty)
                          Card(
                            color: const Color(0xFF34204A),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Row(
                                children: [
                                  const Icon(Icons.link),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _duel.lastChainEvents.join(' → '),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 146,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: state.playerField.hand.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final card = state.playerField.hand[index];
                              return _DuelCard(
                                  card: card,
                                  presentation: _duel.presentationOf(card),
                                  compact: false,
                                  selected:
                                      _pendingChainSourceId == card.instanceId,
                                  feedbackMessage:
                                      _feedbackCardId == card.instanceId
                                          ? _feedbackMessage
                                          : null,
                                  feedbackToken: _feedbackToken,
                                  activatable:
                                      activatableIds.contains(card.instanceId),
                                  validTarget:
                                      validTargetIds.contains(card.instanceId),
                                  onTap: () => _playHandCard(card));
                            },
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('Main — touchez une carte pour la jouer',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_savingResult)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0xAA000000),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Enregistrement du résultat…'),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            top: 22,
            left: 24,
            right: 24,
            child: IgnorePointer(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _momentBanner == null
                    ? const SizedBox.shrink()
                    : _MomentBanner(
                        key: ValueKey(
                          '${_momentBanner!.label}-${_momentBanner.hashCode}',
                        ),
                        data: _momentBanner!,
                      ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 170,
            child: IgnorePointer(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _hudMessage == null
                    ? const SizedBox.shrink()
                    : _HudFeedback(
                        key: ValueKey(_hudMessage),
                        message: _hudMessage!,
                        isError: _hudIsError,
                      ),
              ),
            ),
          ),
          if (_duel.awaitingPlayerPriority)
            Positioned(
              right: 18,
              bottom: 18,
              child: SafeArea(
                child: _ChainPassButton(
                  hasActivations: activatableIds.isNotEmpty,
                  onPressed: _passChainPriority,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _difficultyLabel(AiDifficulty difficulty) =>
      switch (difficulty) {
        AiDifficulty.beginner => 'Débutant',
        AiDifficulty.intermediate => 'Intermédiaire',
        AiDifficulty.advanced => 'Avancé',
        AiDifficulty.expert => 'Expert',
      };
}

class _PlayerStatus extends StatelessWidget {
  const _PlayerStatus(
      {required this.name,
      required this.lifePoints,
      required this.handCount,
      required this.deckCount,
      required this.graveyardCount,
      required this.isActive});
  final String name;
  final int lifePoints;
  final int handCount;
  final int deckCount;
  final int graveyardCount;
  final bool isActive;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF6B3FA0).withValues(alpha: .55)
                : Colors.black.withValues(alpha: .35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: isActive ? const Color(0xFFE5B8FF) : Colors.white24),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: const Color(0xFFB66CFF).withValues(alpha: .55),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ]
                : const []),
        child: Row(children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: isActive ? 1 : .18,
            child: const Icon(Icons.adjust, size: 16, color: Color(0xFF8BFFD9)),
          ),
          const SizedBox(width: 7),
          Expanded(
              child: Text(name,
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          const Icon(Icons.favorite, size: 18, color: Color(0xFFFF6B6B)),
          Text(' $lifePoints PV'),
          const SizedBox(width: 14),
          Text(
              'Main $handCount  •  Deck $deckCount  •  Cimetière $graveyardCount')
        ]),
      );
}

class _PhaseBar extends StatelessWidget {
  const _PhaseBar(
      {required this.phase,
      required this.turn,
      required this.aiPlaying,
      required this.onNext});
  final DuelPhase phase;
  final int turn;
  final bool aiPlaying;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: .08),
            ),
            child: Text('$turn',
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final candidate in DuelPhase.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _PhaseDot(
                      visual: _PhaseVisual.of(candidate),
                      active: candidate == phase,
                    ),
                  ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Phase suivante',
            onPressed: aiPlaying ? null : onNext,
            icon: const Icon(Icons.skip_next_rounded),
          ),
        ],
      ),
    );
  }
}

final class _PhaseVisual {
  const _PhaseVisual(this.icon, this.color, this.bannerLabel);

  final IconData icon;
  final Color color;
  final String bannerLabel;

  static _PhaseVisual of(DuelPhase phase) => switch (phase) {
        DuelPhase.draw => const _PhaseVisual(
            Icons.style_rounded, Color(0xFF76C7FF), 'PHASE DE PIOCHE'),
        DuelPhase.preparation => const _PhaseVisual(Icons.wb_twilight_rounded,
            Color(0xFFFFC86B), 'PHASE DE PRÉPARATION'),
        DuelPhase.main1 => const _PhaseVisual(Icons.auto_awesome_rounded,
            Color(0xFFC990FF), 'PHASE PRINCIPALE 1'),
        DuelPhase.battle => const _PhaseVisual(
            Icons.sports_martial_arts_rounded,
            Color(0xFFFF667A),
            'PHASE DE COMBAT'),
        DuelPhase.main2 => const _PhaseVisual(Icons.auto_awesome_motion_rounded,
            Color(0xFFA88BFF), 'PHASE PRINCIPALE 2'),
        DuelPhase.end => const _PhaseVisual(
            Icons.nights_stay_rounded, Color(0xFF7D93B8), 'PHASE DE FIN'),
      };
}

class _PhaseDot extends StatelessWidget {
  const _PhaseDot({required this.visual, required this.active});

  final _PhaseVisual visual;
  final bool active;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        width: active ? 35 : 25,
        height: active ? 35 : 25,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: visual.color.withValues(alpha: active ? .92 : .12),
          border: Border.all(
            color: visual.color.withValues(alpha: active ? 1 : .34),
            width: active ? 2 : 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: visual.color.withValues(alpha: .65),
                    blurRadius: 13,
                  ),
                ]
              : const [],
        ),
        child: Icon(
          visual.icon,
          size: active ? 19 : 13,
          color: active ? Colors.white : Colors.white54,
        ),
      );
}

final class _MomentBannerData {
  const _MomentBannerData({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

class _MomentBanner extends StatelessWidget {
  const _MomentBanner({required this.data, super.key});

  final _MomentBannerData data;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        key: const Key('battle-moment-banner'),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutBack,
        tween: Tween(begin: 0, end: 1),
        builder: (context, value, child) => Opacity(
          opacity: value.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, -24 * (1 - value)),
            child: Transform.scale(scale: .92 + value * .08, child: child),
          ),
        ),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xEF120D1C),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: data.color, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: data.color.withValues(alpha: .55),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(data.icon, color: data.color),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    data.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _HudFeedback extends StatelessWidget {
  const _HudFeedback({
    required this.message,
    required this.isError,
    super.key,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          key: const Key('battle-hud-feedback'),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          decoration: BoxDecoration(
            color: (isError ? const Color(0xFF7A1830) : const Color(0xFF171124))
                .withValues(alpha: .94),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isError ? const Color(0xFFFF6B7A) : Colors.white24,
            ),
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
}

class _ChainPassButton extends StatelessWidget {
  const _ChainPassButton({
    required this.hasActivations,
    required this.onPressed,
  });

  final bool hasActivations;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 320),
        tween: Tween(begin: .9, end: 1),
        curve: Curves.easeOutBack,
        builder: (context, value, child) => Transform.scale(
          scale: value,
          child: child,
        ),
        child: Container(
          key: const Key('battle-chain-controls'),
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(
            color: const Color(0xF21A1228),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF72F7D0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF72F7D0).withValues(alpha: .28),
                blurRadius: 18,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasActivations ? Icons.touch_app_rounded : Icons.link_rounded,
                color: const Color(0xFF72F7D0),
                size: 20,
              ),
              const SizedBox(width: 7),
              if (hasActivations)
                const Text(
                  'Carte lumineuse',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              if (hasActivations) const SizedBox(width: 8),
              FilledButton.tonalIcon(
                key: const Key('battle-chain-pass'),
                onPressed: onPressed,
                icon: const Icon(Icons.fast_forward_rounded, size: 18),
                label: const Text('Passer'),
              ),
            ],
          ),
        ),
      );
}

class _TerrainSlot extends StatelessWidget {
  const _TerrainSlot({
    required this.card,
    required this.controller,
    this.opponent = false,
    this.onTap,
    this.feedbackCardId,
    this.feedbackMessage,
    this.feedbackToken = 0,
    this.activatable = false,
    this.validTarget = false,
  });

  final CardInstance? card;
  final LocalDuelController controller;
  final bool opponent;
  final VoidCallback? onTap;
  final String? feedbackCardId;
  final String? feedbackMessage;
  final int feedbackToken;
  final bool activatable;
  final bool validTarget;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Terrain'),
          const SizedBox(width: 8),
          SizedBox(
            width: 82,
            height: 58,
            child: card == null
                ? Container(
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.greenAccent.shade100),
                    ),
                    child: const Icon(Icons.landscape, color: Colors.white38),
                  )
                : _DuelCard(
                    card: card!,
                    presentation: controller.presentationOf(card!),
                    compact: true,
                    hideIdentity: opponent && !card!.faceUp,
                    feedbackMessage: feedbackCardId == card!.instanceId
                        ? feedbackMessage
                        : null,
                    feedbackToken: feedbackToken,
                    activatable: activatable,
                    validTarget: validTarget,
                    onTap: onTap,
                  ),
          ),
        ],
      );
}

class _ZoneRow extends StatelessWidget {
  const _ZoneRow(
      {required this.zones,
      required this.controller,
      this.opponent = false,
      this.selectedIds = const {},
      this.feedbackCardId,
      this.feedbackMessage,
      this.feedbackToken = 0,
      this.activatableIds = const {},
      this.validTargetIds = const {},
      this.onCardTap});
  final List<FieldCardInstance?> zones;
  final LocalDuelController controller;
  final bool opponent;
  final Set<String> selectedIds;
  final String? feedbackCardId;
  final String? feedbackMessage;
  final int feedbackToken;
  final Set<String> activatableIds;
  final Set<String> validTargetIds;
  final ValueChanged<FieldCardInstance>? onCardTap;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var index = 0; index < zones.length; index++) ...[
            if (index > 0) const SizedBox(width: 6),
            SizedBox(
              width: 68,
              height: 91,
              child: zones[index] == null
                  ? Container(
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .035),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24)),
                      child: Center(
                          child: Text('${index + 1}',
                              style: const TextStyle(color: Colors.white24))))
                  : _DuelCard(
                      card: zones[index]!,
                      presentation: controller.presentationOf(zones[index]!),
                      compact: true,
                      hideIdentity: opponent && !zones[index]!.faceUp,
                      selected: selectedIds.contains(zones[index]!.instanceId),
                      feedbackMessage:
                          feedbackCardId == zones[index]!.instanceId
                              ? feedbackMessage
                              : null,
                      feedbackToken: feedbackToken,
                      activatable:
                          activatableIds.contains(zones[index]!.instanceId),
                      validTarget:
                          validTargetIds.contains(zones[index]!.instanceId),
                      onTap: onCardTap == null
                          ? null
                          : () => onCardTap!(zones[index]!)),
            ),
          ],
        ],
      );
}

class _DuelCard extends StatefulWidget {
  const _DuelCard(
      {required this.card,
      required this.presentation,
      required this.compact,
      this.hideIdentity = false,
      this.selected = false,
      this.feedbackMessage,
      this.feedbackToken = 0,
      this.activatable = false,
      this.validTarget = false,
      this.onTap});
  final FieldCardInstance card;
  final LocalCardPresentation presentation;
  final bool compact;
  final bool hideIdentity;
  final bool selected;
  final String? feedbackMessage;
  final int feedbackToken;
  final bool activatable;
  final bool validTarget;
  final VoidCallback? onTap;

  @override
  State<_DuelCard> createState() => _DuelCardState();
}

class _DuelCardState extends State<_DuelCard> with TickerProviderStateMixin {
  late final AnimationController _shakeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 760),
  );

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant _DuelCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.feedbackMessage != null &&
        (widget.feedbackToken != oldWidget.feedbackToken ||
            oldWidget.feedbackMessage == null)) {
      _shakeController.forward(from: 0);
    }
    if (widget.activatable != oldWidget.activatable ||
        widget.validTarget != oldWidget.validTarget) {
      _syncPulse();
    }
  }

  void _syncPulse() {
    if (widget.activatable || widget.validTarget) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCharacter =
        widget.presentation.category == CardCategory.character ||
            widget.presentation.category == CardCategory.mythic;
    return AnimatedBuilder(
      animation: Listenable.merge([_shakeController, _pulseController]),
      builder: (context, child) {
        final progress = _shakeController.value;
        final offset = math.sin(progress * math.pi * 6) * (1 - progress) * 7;
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
      child: SizedBox(
        width: widget.compact ? 68 : 104,
        child: Material(
          color: widget.hideIdentity
              ? const Color(0xFF3A1C55)
              : isCharacter
                  ? const Color(0xFF744C2D)
                  : widget.presentation.category == CardCategory.trap
                      ? const Color(0xFF7A285D)
                      : const Color(0xFF235C7A),
          borderRadius: BorderRadius.circular(9),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            child: Container(
              key: widget.validTarget
                  ? ValueKey('battle-target-${widget.card.instanceId}')
                  : widget.activatable
                      ? ValueKey(
                          'battle-activatable-${widget.card.instanceId}',
                        )
                      : null,
              padding: EdgeInsets.all(widget.compact ? 5 : 8),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                      color: widget.feedbackMessage != null
                          ? const Color(0xFFFF4D67)
                          : widget.validTarget
                              ? const Color(0xFFFFD85A)
                              : widget.activatable
                                  ? const Color(0xFF65F5CB)
                                  : widget.selected
                                      ? const Color(0xFFFFD166)
                                      : Colors.white38,
                      width: widget.feedbackMessage != null ||
                              widget.selected ||
                              widget.activatable ||
                              widget.validTarget
                          ? 3
                          : 1),
                  boxShadow: [
                    if (widget.feedbackMessage != null)
                      BoxShadow(
                        color: const Color(0xFFFF294D).withValues(alpha: .8),
                        blurRadius: 14,
                      ),
                    if (widget.activatable || widget.validTarget)
                      BoxShadow(
                        color: (widget.validTarget
                                ? const Color(0xFFFFD85A)
                                : const Color(0xFF65F5CB))
                            .withValues(
                          alpha: .35 + _pulseController.value * .5,
                        ),
                        blurRadius: 9 + _pulseController.value * 13,
                        spreadRadius: _pulseController.value * 2,
                      ),
                  ]),
              child: widget.hideIdentity
                  ? const Center(child: Icon(Icons.auto_awesome, size: 30))
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(widget.presentation.name,
                                  maxLines: widget.compact ? 2 : 3,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: widget.compact ? 9 : 11,
                                      fontWeight: FontWeight.bold)),
                              const Spacer(),
                              if (isCharacter) ...[
                                Text(
                                    'R${widget.presentation.rank}  ${widget.card.position == BattlePosition.defense ? 'DEF' : 'ATK'}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: widget.compact ? 8 : 10)),
                                Text(
                                    '${widget.card.effectiveAtk}/${widget.card.effectiveDef}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: widget.compact ? 9 : 11,
                                        fontWeight: FontWeight.w700)),
                              ] else
                                Text(
                                    widget.presentation.category ==
                                            CardCategory.trap
                                        ? 'PIÈGE'
                                        : 'ACTION',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: widget.compact ? 9 : 11)),
                              if (!widget.card.faceUp && isCharacter)
                                const Icon(Icons.visibility_off, size: 13),
                            ]),
                        if (widget.feedbackMessage != null)
                          Positioned.fill(
                            child: ColoredBox(
                              color: const Color(0xFF5C0014)
                                  .withValues(alpha: .76),
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Text(
                                    widget.feedbackMessage!,
                                    key: const Key('battle-card-feedback'),
                                    textAlign: TextAlign.center,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: widget.compact ? 8 : 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
