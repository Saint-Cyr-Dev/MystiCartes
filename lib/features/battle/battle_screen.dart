import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../game/ai/ai_strategy.dart';
import '../../game/battle_state.dart';
import '../../game/card.dart';
import '../../game/duel_types.dart';
import 'battle_result_repository.dart';
import 'battle_presentation_scheduler.dart';
import 'battle_settings_dialog.dart';
import 'local_duel.dart';
import 'reward_screen.dart';
import 'widgets/battle_backdrop.dart';
import 'widgets/battle_pausable_animation.dart';

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
  final _presentation = BattlePresentationScheduler();
  BattleAnimationPace _animationPace = BattleAnimationPace.normal;
  Duration _activeSpotlightDuration = const Duration(milliseconds: 2000);
  BattlePresentationTask? _bannerTimer;
  BattlePresentationTask? _hudTimer;
  BattlePresentationTask? _cardFeedbackTimer;
  _MomentBannerData? _momentBanner;
  String? _hudMessage;
  bool _hudIsError = false;
  String? _feedbackCardId;
  String? _feedbackMessage;
  int _feedbackToken = 0;
  List<LocalChainResponseOption> _pendingTargetOptions = const [];
  String? _pendingChainSourceId;
  final Map<String, String> _cardFloatLabels = {};
  final Map<String, int> _cardFloatTokens = {};
  final Set<String> _summoningCardIds = {};
  final List<_BattleOverlayEvent> _overlayEvents = [];
  final List<_BattleOverlayEvent> _spotlightQueue = [];
  _BattleOverlayEvent? _activeSpotlight;
  final Set<String> _signaledPlayedCardIds = {};
  final List<BattlePresentationTask> _visualTimers = [];
  String? _attackingCardId;
  int _attackAnimationToken = 0;
  int _visualSerial = 0;

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
      if (!mounted) return;
      _showTurnBanner(_duel.state.activePlayer);
      _consumeDuelVisualEvents();
    });
  }

  @override
  void dispose() {
    _presentation.dispose();
    _bannerTimer?.cancel();
    _hudTimer?.cancel();
    _cardFeedbackTimer?.cancel();
    for (final timer in _visualTimers) {
      timer.cancel();
    }
    super.dispose();
  }

  void _restart([AiDifficulty? difficulty]) {
    _presentation.cancelAll();
    _visualTimers.clear();
    setState(() {
      _aiPlaying = false;
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
      _cardFloatLabels.clear();
      _cardFloatTokens.clear();
      _summoningCardIds.clear();
      _overlayEvents.clear();
      _spotlightQueue.clear();
      _activeSpotlight = null;
      _signaledPlayedCardIds.clear();
      _attackingCardId = null;
    });
    _showTurnBanner(DuelParticipant.player);
  }

  /// Presentation-only pause: neither pending AI pacing nor visual queues
  /// advance while the modal is open. No duel rule/state is rewritten.
  Future<void> _openSettings() async {
    if (_presentation.isPaused || _savingResult || _duel.state.isFinished) {
      return;
    }
    setState(_presentation.pause);
    try {
      final settings = await showDialog<BattleSettingsResult>(
        context: context,
        barrierDismissible: false,
        builder: (_) => BattleSettingsDialog(pace: _animationPace),
      );
      if (!mounted) return;
      if (settings != null) {
        setState(() => _animationPace = settings.pace);
        if (settings.restart) _restart();
      }
    } finally {
      if (mounted) setState(_presentation.resume);
    }
  }

  Duration _spotlightDuration(_BattleOverlayEvent event) {
    final milliseconds = switch (event.kind) {
      _BattleOverlayKind.cardPlayed => 2000,
      _BattleOverlayKind.effectActivated => 1800,
      _BattleOverlayKind.attackSource => 1600,
      _ => 1200,
    };
    return Duration(
      milliseconds: (milliseconds * _animationPace.durationScale).round(),
    );
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
    _bannerTimer =
        _presentation.schedule(const Duration(milliseconds: 1050), () {
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
    _hudTimer = _presentation.schedule(const Duration(milliseconds: 1500), () {
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
    _cardFeedbackTimer =
        _presentation.schedule(const Duration(milliseconds: 1500), () {
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
    final before = _duel.state;
    final result = _duel.activatePlayerResponse(option: option);
    setState(() {
      _pendingTargetOptions = const [];
      _pendingChainSourceId = null;
    });
    if (!result.succeeded) {
      _showCardError(option.card.instanceId, result.message);
    } else {
      _consumeDuelVisualEvents();
      _visualizeStateDelta(before, _duel.state);
    }
    _checkEnd();
  }

  Future<void> _passChainPriority() async {
    final before = _duel.state;
    final result = _duel.passPlayerPriority();
    setState(() {
      _pendingTargetOptions = const [];
      _pendingChainSourceId = null;
    });
    if (!result.succeeded) {
      _showHudMessage(result.message, error: true);
      return;
    }
    _consumeDuelVisualEvents();
    _visualizeStateDelta(before, _duel.state);
    _checkEnd();
    if (!mounted || _duel.state.isFinished) return;
    if (_duel.state.activePlayer == DuelParticipant.ai) {
      await _runAiUntilDecision();
    }
  }

  void _showCardFloat(String instanceId, String label) {
    final token = ++_visualSerial;
    setState(() {
      _cardFloatLabels[instanceId] = label;
      _cardFloatTokens[instanceId] = token;
    });
    late final BattlePresentationTask timer;
    timer = _presentation.schedule(const Duration(milliseconds: 1500), () {
      _visualTimers.remove(timer);
      if (!mounted || _cardFloatTokens[instanceId] != token) return;
      setState(() {
        _cardFloatLabels.remove(instanceId);
        _cardFloatTokens.remove(instanceId);
      });
    });
    _visualTimers.add(timer);
  }

  void _addOverlayEvent(_BattleOverlayEvent event) {
    if (event.isCardSpotlight) {
      _spotlightQueue.add(event);
      _showNextSpotlight();
      return;
    }
    setState(() => _overlayEvents.add(event));
    late final BattlePresentationTask timer;
    timer = _presentation.schedule(const Duration(milliseconds: 1400), () {
      _visualTimers.remove(timer);
      if (mounted) setState(() => _overlayEvents.remove(event));
    });
    _visualTimers.add(timer);
  }

  void _showNextSpotlight() {
    if (!mounted || _activeSpotlight != null || _spotlightQueue.isEmpty) {
      return;
    }
    final event = _spotlightQueue.removeAt(0);
    setState(() {
      _activeSpotlight = event;
      _activeSpotlightDuration = _spotlightDuration(event);
      _overlayEvents.add(event);
    });
    late final BattlePresentationTask timer;
    timer = _presentation.schedule(_activeSpotlightDuration, () {
      _visualTimers.remove(timer);
      if (!mounted) return;
      setState(() {
        _overlayEvents.remove(event);
        if (_activeSpotlight == event) _activeSpotlight = null;
      });
      _showNextSpotlight();
      _checkEnd();
    });
    _visualTimers.add(timer);
  }

  void _consumeDuelVisualEvents() {
    for (final event in _duel.takeVisualEvents()) {
      final presentation = _duel.presentationOf(event.card);
      switch (event.kind) {
        case LocalDuelVisualEventKind.cardPlayed:
          _signaledPlayedCardIds.add(event.card.instanceId);
          _addOverlayEvent(
            _BattleOverlayEvent.cardPlayed(
              serial: ++_visualSerial,
              cardInstanceId: event.card.instanceId,
              cardCode: presentation.code,
              label: presentation.name,
              forPlayer: event.participant == DuelParticipant.player,
              hidden:
                  event.participant == DuelParticipant.ai && !event.card.faceUp,
            ),
          );
        case LocalDuelVisualEventKind.effectActivated:
          _addOverlayEvent(
            _BattleOverlayEvent.effectActivated(
              serial: ++_visualSerial,
              cardInstanceId: event.card.instanceId,
              cardCode: presentation.code,
              label: presentation.name,
              forPlayer: event.participant == DuelParticipant.player,
            ),
          );
        case LocalDuelVisualEventKind.attackDeclared:
          _addOverlayEvent(
            _BattleOverlayEvent.attackSource(
              serial: ++_visualSerial,
              cardInstanceId: event.card.instanceId,
              cardCode: presentation.code,
              label: presentation.name,
              forPlayer: event.participant == DuelParticipant.player,
            ),
          );
          _addOverlayEvent(
            _BattleOverlayEvent.impact(
              serial: ++_visualSerial,
              direct: event.targetInstanceId == null,
            ),
          );
      }
    }
  }

  void _visualizeStateDelta(DuelState before, DuelState after) {
    final beforeCards = _fieldCards(before);
    final afterCards = _fieldCards(after);
    for (final entry in afterCards.entries) {
      final previous = beforeCards[entry.key];
      final current = entry.value;
      if (previous == null) {
        final presentation = _duel.presentationOf(current);
        if (!_signaledPlayedCardIds.remove(current.instanceId)) {
          _addOverlayEvent(
            _BattleOverlayEvent.cardPlayed(
              serial: ++_visualSerial,
              cardInstanceId: current.instanceId,
              cardCode: presentation.code,
              label: presentation.name,
              forPlayer: current.controller == DuelParticipant.player,
              hidden:
                  current.controller == DuelParticipant.ai && !current.faceUp,
            ),
          );
        }
        if (current.category == CardCategory.character ||
            current.category == CardCategory.mythic) {
          final id = current.instanceId;
          setState(() => _summoningCardIds.add(id));
          late final BattlePresentationTask timer;
          timer =
              _presentation.schedule(const Duration(milliseconds: 1000), () {
            _visualTimers.remove(timer);
            if (mounted) setState(() => _summoningCardIds.remove(id));
          });
          _visualTimers.add(timer);
          if (current.category == CardCategory.mythic) {
            _addOverlayEvent(
              _BattleOverlayEvent.mythic(
                serial: ++_visualSerial,
                label: _duel.presentationOf(current).name,
              ),
            );
          }
        }
        continue;
      }
      final atkDelta =
          (current.effectiveAtk ?? 0) - (previous.effectiveAtk ?? 0);
      final defDelta =
          (current.effectiveDef ?? 0) - (previous.effectiveDef ?? 0);
      final labels = <String>[];
      if (atkDelta != 0) labels.add('${atkDelta > 0 ? '+' : ''}$atkDelta ATK');
      if (defDelta != 0) labels.add('${defDelta > 0 ? '+' : ''}$defDelta DEF');
      if (labels.isNotEmpty) _showCardFloat(entry.key, labels.join('  '));

      final changedCounters = <String>[];
      final counterNames = {
        ...previous.counters.keys,
        ...current.counters.keys
      };
      for (final name in counterNames) {
        final delta =
            (current.counters[name] ?? 0) - (previous.counters[name] ?? 0);
        if (delta != 0) {
          changedCounters.add('${delta > 0 ? '+' : ''}$delta $name');
        }
      }
      if (changedCounters.isNotEmpty) {
        _showCardFloat(entry.key, '✦ ${changedCounters.join('  ')}');
      }
    }

    for (final entry in beforeCards.entries) {
      if (afterCards.containsKey(entry.key)) continue;
      final wasDestroyed = after.playerField.graveyard
              .any((card) => card.instanceId == entry.key) ||
          after.aiField.graveyard.any((card) => card.instanceId == entry.key);
      if (wasDestroyed) {
        _addOverlayEvent(
          _BattleOverlayEvent.destruction(
            serial: ++_visualSerial,
            label: _duel.presentationOf(entry.value).name,
          ),
        );
      }
    }

    final playerLifeDelta = after.playerLifePoints - before.playerLifePoints;
    final aiLifeDelta = after.aiLifePoints - before.aiLifePoints;
    if (playerLifeDelta != 0) {
      _addOverlayEvent(
        _BattleOverlayEvent.life(
          serial: ++_visualSerial,
          amount: playerLifeDelta,
          forPlayer: true,
        ),
      );
    }
    if (aiLifeDelta != 0) {
      _addOverlayEvent(
        _BattleOverlayEvent.life(
          serial: ++_visualSerial,
          amount: aiLifeDelta,
          forPlayer: false,
        ),
      );
    }
    _signaledPlayedCardIds.clear();
  }

  Map<String, CardInstance> _fieldCards(DuelState state) => {
        for (final field in [state.playerField, state.aiField]) ...{
          for (final card in field.characterZones.whereType<CardInstance>())
            card.instanceId: card,
          for (final card in field.actionTrapZones.whereType<CardInstance>())
            card.instanceId: card,
          if (field.terrainZone case final CardInstance terrain)
            terrain.instanceId: terrain,
        },
      };

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
      final before = _duel.state;
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
      } else {
        _consumeDuelVisualEvents();
        _visualizeStateDelta(before, _duel.state);
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
      final before = _duel.state;
      final result = _duel.setActionOrTrap(card.instanceId);
      setState(() {});
      if (!result.succeeded) {
        _showCardError(card.instanceId, result.message);
      } else {
        _consumeDuelVisualEvents();
        _visualizeStateDelta(before, _duel.state);
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
    final before = _duel.state;
    final result = _duel.activatePreparedOption(
      option: selected,
      resolveImmediately: true,
    );
    if (!mounted) return;
    setState(() {});
    if (!result.succeeded) {
      _showCardError(card.instanceId, result.message);
    } else {
      _consumeDuelVisualEvents();
      _visualizeStateDelta(before, _duel.state);
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

  Future<void> _resolveAttack(String attackerId, String? targetId) async {
    final before = _duel.state;
    final result = _duel.attack(
      attackerInstanceId: attackerId,
      targetInstanceId: targetId,
    );
    if (!result.succeeded) {
      _consumeDuelVisualEvents();
      _showCardError(attackerId, result.message);
      return;
    }
    _consumeDuelVisualEvents();
    setState(() {
      _attackingCardId = attackerId;
      _attackAnimationToken++;
    });
    if (!await _presentation.wait(const Duration(milliseconds: 360)) ||
        !mounted) {
      return;
    }
    setState(() {
      _selectedAttackerId = null;
      _attackingCardId = null;
    });
    _visualizeStateDelta(before, _duel.state);
    _checkEnd();
  }

  Future<void> _nextPhase() async {
    if (_aiPlaying || _duel.state.isFinished) return;
    final previousState = _duel.state;
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
    _visualizeStateDelta(previousState, _duel.state);
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
    if (!await _presentation.wait(const Duration(milliseconds: 450)) ||
        !mounted) {
      return;
    }
    final previousState = _duel.state;
    final previousPlayer = _duel.state.activePlayer;
    final previousPhase = _duel.state.currentPhase;
    _duel.playAiUntilPlayerDecision();
    if (!mounted) return;
    setState(() => _aiPlaying = false);
    _consumeDuelVisualEvents();
    _visualizeStateDelta(previousState, _duel.state);
    _showTransition(
      previousPlayer: previousPlayer,
      previousPhase: previousPhase,
    );
    _checkEnd();
    if (_duel.state.isFinished) return;

    if (_duel.awaitingPlayerPriority) {
      return;
    }
  }

  void _checkEnd() {
    if (!_duel.state.isFinished || _endDialogShown || !mounted) return;
    // The engine has already ended the duel. Only result presentation waits,
    // so the final attack/effect is not cut off by the reward screen.
    if (_activeSpotlight != null || _spotlightQueue.isNotEmpty) return;
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
    return Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(child: BattleBackdrop()),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: const Color(0xA0080917),
            surfaceTintColor: Colors.transparent,
            title: Row(children: [
              const Icon(Icons.auto_awesome,
                  size: 20, color: Color(0xFFC45FFF)),
              const SizedBox(width: 6),
              const Expanded(
                child: Text('Duel V2',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(_difficultyLabel(_difficulty),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFFCDA8EB))),
              ),
            ]),
            actions: [
              if (!widget.isFirstBattle)
                PopupMenuButton<AiDifficulty>(
                  tooltip: 'Choisir la difficulté',
                  enabled: !_savingResult && !state.isFinished,
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
                key: const Key('battle-settings'),
                tooltip: 'Paramètres / Pause',
                onPressed:
                    _savingResult || state.isFinished ? null : _openSettings,
                icon: const Icon(Icons.settings_rounded),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(64),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 7),
                child: _PhaseBar(
                  phase: state.currentPhase,
                  turn: state.turnNumber,
                ),
              ),
            ),
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              TickerMode(
                enabled: !_presentation.isPaused,
                child: SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final designWidth = constraints.maxWidth < 600
                          ? 480.0
                          : math.min(760.0, constraints.maxWidth - 16);
                      return Padding(
                        padding: const EdgeInsets.all(8),
                        child: FittedBox(
                          key: const Key('battle-fitted-board'),
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: designWidth,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _PlayerStatus(
                                    name:
                                        'IA ${_difficultyLabel(_difficulty).toLowerCase()}',
                                    lifePoints: state.aiLifePoints,
                                    handCount: state.aiField.hand.length,
                                    deckCount: state.aiField.deck.length,
                                    graveyardCount:
                                        state.aiField.graveyard.length,
                                    isActive: state.activePlayer ==
                                        DuelParticipant.ai),
                                const SizedBox(height: 8),
                                _ZoneRow(
                                    zones: state.aiField.actionTrapZones,
                                    opponent: true,
                                    controller: _duel,
                                    feedbackCardId: _feedbackCardId,
                                    feedbackMessage: _feedbackMessage,
                                    feedbackToken: _feedbackToken,
                                    floatLabels: _cardFloatLabels,
                                    floatTokens: _cardFloatTokens,
                                    activatableIds: activatableIds,
                                    validTargetIds: validTargetIds,
                                    onCardTap: _tapSupportCard),
                                const SizedBox(height: 6),
                                _ZoneRow(
                                    zones: state.aiField.characterZones,
                                    opponent: true,
                                    controller: _duel,
                                    attackingCardId: _duel
                                        .pendingAiAttack?.attackerInstanceId,
                                    attackAnimationToken: _duel.pendingAiAttack
                                            ?.declarationId.hashCode ??
                                        0,
                                    summoningIds: _summoningCardIds,
                                    feedbackCardId: _feedbackCardId,
                                    feedbackMessage: _feedbackMessage,
                                    feedbackToken: _feedbackToken,
                                    floatLabels: _cardFloatLabels,
                                    floatTokens: _cardFloatTokens,
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
                                  floatLabel: state.aiField.terrainZone == null
                                      ? null
                                      : _cardFloatLabels[state
                                          .aiField.terrainZone!.instanceId],
                                  floatToken: state.aiField.terrainZone == null
                                      ? 0
                                      : _cardFloatTokens[state.aiField
                                              .terrainZone!.instanceId] ??
                                          0,
                                  activatable: activatableIds.contains(
                                      state.aiField.terrainZone?.instanceId),
                                  validTarget: validTargetIds.contains(
                                      state.aiField.terrainZone?.instanceId),
                                  onTap: state.aiField.terrainZone == null
                                      ? null
                                      : () => _tapSupportCard(
                                          state.aiField.terrainZone!),
                                ),
                                const SizedBox(height: 10),
                                _ZoneRow(
                                    zones: state.playerField.characterZones,
                                    controller: _duel,
                                    attackingCardId: _attackingCardId,
                                    attackAnimationToken: _attackAnimationToken,
                                    summoningIds: _summoningCardIds,
                                    selectedIds: {
                                      ..._selectedSacrifices,
                                      if (_selectedAttackerId != null)
                                        _selectedAttackerId!
                                    },
                                    feedbackCardId: _feedbackCardId,
                                    feedbackMessage: _feedbackMessage,
                                    feedbackToken: _feedbackToken,
                                    floatLabels: _cardFloatLabels,
                                    floatTokens: _cardFloatTokens,
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
                                    floatLabels: _cardFloatLabels,
                                    floatTokens: _cardFloatTokens,
                                    activatableIds: activatableIds,
                                    validTargetIds: validTargetIds,
                                    onCardTap: _tapSupportCard),
                                const SizedBox(height: 6),
                                Row(
                                  key: const Key('battle-player-action-row'),
                                  children: [
                                    Expanded(
                                      child: _TerrainSlot(
                                        card: state.playerField.terrainZone,
                                        controller: _duel,
                                        feedbackCardId: _feedbackCardId,
                                        feedbackMessage: _feedbackMessage,
                                        feedbackToken: _feedbackToken,
                                        floatLabel:
                                            state.playerField.terrainZone ==
                                                    null
                                                ? null
                                                : _cardFloatLabels[state
                                                    .playerField
                                                    .terrainZone!
                                                    .instanceId],
                                        floatToken:
                                            state.playerField.terrainZone ==
                                                    null
                                                ? 0
                                                : _cardFloatTokens[state
                                                        .playerField
                                                        .terrainZone!
                                                        .instanceId] ??
                                                    0,
                                        activatable: activatableIds.contains(
                                          state.playerField.terrainZone
                                              ?.instanceId,
                                        ),
                                        validTarget: validTargetIds.contains(
                                          state.playerField.terrainZone
                                              ?.instanceId,
                                        ),
                                        onTap: state.playerField.terrainZone ==
                                                null
                                            ? null
                                            : () => _tapSupportCard(
                                                  state
                                                      .playerField.terrainZone!,
                                                ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _PlayerTurnControl(
                                      phase: state.currentPhase,
                                      deckCount: state.playerField.deck.length,
                                      playerTurn: state.activePlayer ==
                                          DuelParticipant.player,
                                      openingDrawSkipped:
                                          state.turnNumber == 1 &&
                                              state.activePlayer ==
                                                  state.startingPlayer,
                                      aiPlaying: _aiPlaying,
                                      awaitingPriority:
                                          _duel.awaitingPlayerPriority,
                                      hasActivations: activatableIds.isNotEmpty,
                                      onNextPhase: _nextPhase,
                                      onPassPriority: _passChainPriority,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _PlayerStatus(
                                    name: 'Vous',
                                    lifePoints: state.playerLifePoints,
                                    handCount: state.playerField.hand.length,
                                    deckCount: state.playerField.deck.length,
                                    graveyardCount:
                                        state.playerField.graveyard.length,
                                    isActive: state.activePlayer ==
                                        DuelParticipant.player),
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
                                  _ChainResolutionIndicator(
                                    count: _duel.lastChainEvents.length,
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
                                      final card =
                                          state.playerField.hand[index];
                                      return _DuelCard(
                                          card: card,
                                          presentation:
                                              _duel.presentationOf(card),
                                          compact: false,
                                          selected: _pendingChainSourceId ==
                                              card.instanceId,
                                          feedbackMessage:
                                              _feedbackCardId == card.instanceId
                                                  ? _feedbackMessage
                                                  : null,
                                          feedbackToken: _feedbackToken,
                                          floatLabel:
                                              _cardFloatLabels[card.instanceId],
                                          floatToken: _cardFloatTokens[
                                                  card.instanceId] ??
                                              0,
                                          activatable: activatableIds
                                              .contains(card.instanceId),
                                          validTarget: validTargetIds
                                              .contains(card.instanceId),
                                          onTap: () => _playHandCard(card));
                                    },
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text('Main — touchez une carte pour la jouer',
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
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
              for (final event in _overlayEvents)
                Positioned.fill(
                  child: IgnorePointer(
                    child: _BattleEventOverlay(
                      key: ValueKey('battle-event-${event.serial}'),
                      event: event,
                      paused: _presentation.isPaused,
                      spotlightDuration: _activeSpotlightDuration,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
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
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
            radius: 21,
            backgroundColor:
                isActive ? const Color(0xFF813CD0) : const Color(0xFF292033),
            child: Icon(name == 'Vous' ? Icons.person : Icons.psychology,
                color: const Color(0xFFE6C5FF)),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: isActive ? 1 : .18,
                    child: const Icon(Icons.adjust,
                        size: 14, color: Color(0xFF8BFFD9)),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.favorite,
                      size: 16, color: Color(0xFFFF6B6B)),
                  Text(' $lifePoints PV',
                      maxLines: 1,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: (lifePoints / 8000).clamp(0, 1),
                      color: name == 'Vous'
                          ? const Color(0xFF1F88F5)
                          : const Color(0xFFE33C58),
                      backgroundColor: const Color(0xFF29162F),
                    )),
                const SizedBox(height: 7),
                Row(children: [
                  Expanded(
                    child: _StatusMetric(
                        icon: Icons.style_rounded,
                        label: 'Main',
                        value: handCount),
                  ),
                  Expanded(
                    child: _StatusMetric(
                        icon: Icons.layers_rounded,
                        label: 'Deck',
                        value: deckCount),
                  ),
                  Expanded(
                    child: _StatusMetric(
                        icon: Icons.delete_outline_rounded,
                        label: 'Cimetière',
                        value: graveyardCount),
                  ),
                ]),
              ])),
        ]),
      );
}

class _StatusMetric extends StatelessWidget {
  const _StatusMetric(
      {required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFFCDA8E8)),
          const SizedBox(width: 3),
          Flexible(
            child: Text('$label $value',
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: const TextStyle(fontSize: 11, color: Color(0xFFE0CCE9))),
          ),
        ],
      );
}

class _PhaseBar extends StatelessWidget {
  const _PhaseBar({required this.phase, required this.turn});
  final DuelPhase phase;
  final int turn;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;
    return Container(
      key: const Key('battle-top-phase-bar'),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            constraints: BoxConstraints(minWidth: compact ? 48 : 58),
            height: compact ? 30 : 34,
            padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 7),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Text('Tour $turn',
                maxLines: 1,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          ),
          SizedBox(width: compact ? 4 : 10),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final candidate in DuelPhase.values)
                    Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: compact ? 1 : 3),
                      child: _PhaseDot(
                        visual: _PhaseVisual.of(candidate),
                        active: candidate == phase,
                        compact: compact,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerTurnControl extends StatelessWidget {
  const _PlayerTurnControl({
    required this.phase,
    required this.deckCount,
    required this.playerTurn,
    required this.openingDrawSkipped,
    required this.aiPlaying,
    required this.awaitingPriority,
    required this.hasActivations,
    required this.onNextPhase,
    required this.onPassPriority,
  });

  final DuelPhase phase;
  final int deckCount;
  final bool playerTurn;
  final bool openingDrawSkipped;
  final bool aiPlaying;
  final bool awaitingPriority;
  final bool hasActivations;
  final VoidCallback onNextPhase;
  final VoidCallback onPassPriority;

  @override
  Widget build(BuildContext context) {
    if (awaitingPriority) {
      return _ChainPassButton(
        hasActivations: hasActivations,
        onPressed: onPassPriority,
      );
    }
    if (!playerTurn) return const SizedBox(width: 48, height: 48);
    if (phase == DuelPhase.draw) {
      return _DrawPileButton(
        count: deckCount,
        openingDrawSkipped: openingDrawSkipped,
        onPressed: aiPlaying ? null : onNextPhase,
      );
    }
    return IconButton.filledTonal(
      key: const Key('battle-next-phase'),
      tooltip: 'Passer à la phase suivante',
      onPressed: aiPlaying ? null : onNextPhase,
      icon: const Icon(Icons.skip_next_rounded),
    );
  }
}

class _DrawPileButton extends StatelessWidget {
  const _DrawPileButton({
    required this.count,
    required this.openingDrawSkipped,
    required this.onPressed,
  });

  final int count;
  final bool openingDrawSkipped;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tooltip = openingDrawSkipped
        ? 'Passer la pioche du premier tour'
        : 'Piocher une carte — $count restantes';
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: SizedBox(
          key: const Key('battle-draw-pile'),
          width: 47,
          height: 50,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: 0,
                top: 1,
                child: _DrawPileCard(
                  color: const Color(0xFF3A1B58),
                  borderColor: const Color(0xFF7948A4),
                ),
              ),
              Positioned(
                right: 3,
                top: 3,
                child: _DrawPileCard(
                  color: const Color(0xFF4D206F),
                  borderColor: const Color(0xFF9B5AC9),
                ),
              ),
              Positioned(
                left: 0,
                bottom: 0,
                child: Material(
                  color: const Color(0xFF241036),
                  borderRadius: BorderRadius.circular(6),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onPressed,
                    child: Container(
                      width: 37,
                      height: 46,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: onPressed == null
                              ? Colors.white24
                              : const Color(0xFFC66CFF),
                          width: 1.5,
                        ),
                        boxShadow: onPressed == null
                            ? null
                            : const [
                                BoxShadow(
                                  color: Color(0x779D43E8),
                                  blurRadius: 9,
                                ),
                              ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            openingDrawSkipped
                                ? Icons.skip_next_rounded
                                : Icons.style_rounded,
                            size: 15,
                            color: const Color(0xFFE8C9FF),
                          ),
                          Text(
                            '$count',
                            key: const Key('battle-draw-pile-count'),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawPileCard extends StatelessWidget {
  const _DrawPileCard({required this.color, required this.borderColor});

  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) => Container(
        width: 37,
        height: 46,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor),
        ),
      );
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
  const _PhaseDot({
    required this.visual,
    required this.active,
    required this.compact,
  });

  final _PhaseVisual visual;
  final bool active;
  final bool compact;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        width: active ? (compact ? 29 : 35) : (compact ? 21 : 25),
        height: active ? (compact ? 29 : 35) : (compact ? 21 : 25),
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
          size: active ? (compact ? 16 : 19) : (compact ? 11 : 13),
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

class _ChainResolutionIndicator extends StatelessWidget {
  const _ChainResolutionIndicator({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '$count éléments de Chaîne résolus',
        child: SizedBox(
          height: 34,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.link_rounded, color: Color(0xFFC990FF)),
              const SizedBox(width: 6),
              for (var index = 0; index < count.clamp(1, 6); index++)
                TweenAnimationBuilder<double>(
                  duration: Duration(milliseconds: 220 + index * 55),
                  tween: Tween(begin: .35, end: 1),
                  builder: (context, value, child) => Transform.scale(
                    scale: value,
                    child: child,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(
                      Icons.auto_awesome,
                      size: 13,
                      color: Color(0xFFE2C2FF),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}

enum _BattleOverlayKind {
  impact,
  life,
  destruction,
  mythic,
  cardPlayed,
  effectActivated,
  attackSource,
}

final class _BattleOverlayEvent {
  const _BattleOverlayEvent._({
    required this.serial,
    required this.kind,
    this.amount,
    this.forPlayer,
    this.label,
    this.direct,
    this.cardCode,
    this.cardInstanceId,
    this.hidden = false,
  });

  factory _BattleOverlayEvent.life({
    required int serial,
    required int amount,
    required bool forPlayer,
  }) =>
      _BattleOverlayEvent._(
        serial: serial,
        kind: _BattleOverlayKind.life,
        amount: amount,
        forPlayer: forPlayer,
      );

  factory _BattleOverlayEvent.impact({
    required int serial,
    required bool direct,
  }) =>
      _BattleOverlayEvent._(
        serial: serial,
        kind: _BattleOverlayKind.impact,
        direct: direct,
      );

  factory _BattleOverlayEvent.destruction({
    required int serial,
    required String label,
  }) =>
      _BattleOverlayEvent._(
        serial: serial,
        kind: _BattleOverlayKind.destruction,
        label: label,
      );

  factory _BattleOverlayEvent.mythic({
    required int serial,
    required String label,
  }) =>
      _BattleOverlayEvent._(
        serial: serial,
        kind: _BattleOverlayKind.mythic,
        label: label,
      );

  factory _BattleOverlayEvent.cardPlayed({
    required int serial,
    required String cardInstanceId,
    required String cardCode,
    required String label,
    required bool forPlayer,
    required bool hidden,
  }) =>
      _BattleOverlayEvent._(
        serial: serial,
        kind: _BattleOverlayKind.cardPlayed,
        cardInstanceId: cardInstanceId,
        cardCode: cardCode,
        label: label,
        forPlayer: forPlayer,
        hidden: hidden,
      );

  factory _BattleOverlayEvent.effectActivated({
    required int serial,
    required String cardInstanceId,
    required String cardCode,
    required String label,
    required bool forPlayer,
  }) =>
      _BattleOverlayEvent._(
        serial: serial,
        kind: _BattleOverlayKind.effectActivated,
        cardInstanceId: cardInstanceId,
        cardCode: cardCode,
        label: label,
        forPlayer: forPlayer,
      );

  factory _BattleOverlayEvent.attackSource({
    required int serial,
    required String cardInstanceId,
    required String cardCode,
    required String label,
    required bool forPlayer,
  }) =>
      _BattleOverlayEvent._(
        serial: serial,
        kind: _BattleOverlayKind.attackSource,
        cardInstanceId: cardInstanceId,
        cardCode: cardCode,
        label: label,
        forPlayer: forPlayer,
      );

  final int serial;
  final _BattleOverlayKind kind;
  final int? amount;
  final bool? forPlayer;
  final String? label;
  final bool? direct;
  final String? cardCode;
  final String? cardInstanceId;
  final bool hidden;

  bool get isCardSpotlight => const {
        _BattleOverlayKind.cardPlayed,
        _BattleOverlayKind.effectActivated,
        _BattleOverlayKind.attackSource,
      }.contains(kind);
}

class _BattleEventOverlay extends StatelessWidget {
  const _BattleEventOverlay(
      {required this.event,
      required this.paused,
      required this.spotlightDuration,
      super.key});

  final _BattleOverlayEvent event;
  final bool paused;
  final Duration spotlightDuration;

  @override
  Widget build(BuildContext context) => switch (event.kind) {
        _BattleOverlayKind.impact => _ImpactFlash(event: event, paused: paused),
        _BattleOverlayKind.life => _LifeFloat(event: event, paused: paused),
        _BattleOverlayKind.destruction =>
          _DestructionFloat(event: event, paused: paused),
        _BattleOverlayKind.mythic => _MythicFlash(event: event, paused: paused),
        _BattleOverlayKind.cardPlayed => _CardSourceSpotlight(
            event: event,
            paused: paused,
            duration: spotlightDuration,
            mode: _CardSpotlightMode.played,
          ),
        _BattleOverlayKind.effectActivated => _CardSourceSpotlight(
            event: event,
            paused: paused,
            duration: spotlightDuration,
            mode: _CardSpotlightMode.effect,
          ),
        _BattleOverlayKind.attackSource => _CardSourceSpotlight(
            event: event,
            paused: paused,
            duration: spotlightDuration,
            mode: _CardSpotlightMode.attack,
          ),
      };
}

enum _CardSpotlightMode { played, effect, attack }

class _CardSourceSpotlight extends StatelessWidget {
  const _CardSourceSpotlight(
      {required this.event,
      required this.mode,
      required this.paused,
      required this.duration});

  final _BattleOverlayEvent event;
  final _CardSpotlightMode mode;
  final bool paused;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final visual = switch (mode) {
      _CardSpotlightMode.played => (
          label: event.hidden ? 'CARTE POSÉE' : 'CARTE JOUÉE',
          color: const Color(0xFFAE65FF),
          icon: Icons.style_rounded,
          keyPrefix: 'battle-card-played',
        ),
      _CardSpotlightMode.effect => (
          label: 'EFFET ACTIVÉ',
          color: const Color(0xFF55E6FF),
          icon: Icons.bolt_rounded,
          keyPrefix: 'battle-effect-source',
        ),
      _CardSpotlightMode.attack => (
          label: 'ATTAQUE',
          color: const Color(0xFFFF704D),
          icon: Icons.flash_on_rounded,
          keyPrefix: 'battle-attack-source',
        ),
    };
    final belongsToPlayer = event.forPlayer ?? true;
    return BattlePausableAnimation(
      key: Key('${visual.keyPrefix}-${event.cardInstanceId}'),
      paused: paused,
      duration: duration,
      builder: (context, value, child) {
        // Enter briefly, HOLD fully readable, then move away. Previously a
        // single sine curve made the enlarged card look like a blinking flash.
        final entrance =
            Curves.easeOutCubic.transform((value / .15).clamp(0, 1));
        final exit =
            Curves.easeInCubic.transform(((value - .78) / .22).clamp(0, 1));
        final opacity = entrance * (1 - exit);
        final direction = mode == _CardSpotlightMode.played
            ? (belongsToPlayer ? 1.0 : -1.0)
            : (belongsToPlayer ? -1.0 : 1.0);
        final offset = switch (mode) {
          _CardSpotlightMode.played => Offset(
              0,
              direction * (145 * exit + 35 * (1 - entrance)),
            ),
          _CardSpotlightMode.effect => Offset(
              0,
              direction * 22 * exit,
            ),
          _CardSpotlightMode.attack => Offset(
              0,
              direction * 105 * exit,
            ),
        };
        final scale = switch (mode) {
          _CardSpotlightMode.played => .72 + .34 * entrance - .34 * exit,
          _CardSpotlightMode.effect => .8 + .25 * entrance - .25 * exit,
          _CardSpotlightMode.attack => .78 + .3 * entrance - .1 * exit,
        };
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: offset,
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 230,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    visual.color.withValues(alpha: .5),
                    visual.color.withValues(alpha: .08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Container(
              width: 154,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xF20C0818),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: visual.color, width: 2.2),
                boxShadow: [
                  BoxShadow(
                    color: visual.color.withValues(alpha: .72),
                    blurRadius: mode == _CardSpotlightMode.effect ? 34 : 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AspectRatio(
                    aspectRatio: .72,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: event.hidden
                          ? const _MysticCardBack()
                          : _BattleSpotlightArtwork(code: event.cardCode!),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(visual.icon, size: 16, color: visual.color),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          visual.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: visual.color,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    belongsToPlayer ? 'VOUS' : 'ADVERSAIRE',
                    style: TextStyle(
                      color: visual.color.withValues(alpha: .82),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    event.hidden ? 'Carte adverse' : event.label!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BattleSpotlightArtwork extends StatelessWidget {
  const _BattleSpotlightArtwork({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/images/cards/${code.toLowerCase()}.png',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3A1463), Color(0xFF10091F)],
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.auto_awesome,
              color: Color(0xFFDCA9FF),
              size: 48,
            ),
          ),
        ),
      );
}

class _MysticCardBack extends StatelessWidget {
  const _MysticCardBack();

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF5D2095), Color(0xFF160925), Color(0xFF321058)],
          ),
          border: Border.all(color: const Color(0xFFC77DFF), width: 2),
        ),
        child: const Center(
          child: Icon(
            Icons.auto_awesome,
            color: Color(0xFFE9C8FF),
            size: 54,
            shadows: [Shadow(color: Color(0xFFC26BFF), blurRadius: 22)],
          ),
        ),
      );
}

class _ImpactFlash extends StatelessWidget {
  const _ImpactFlash({required this.event, required this.paused});

  final _BattleOverlayEvent event;
  final bool paused;

  @override
  Widget build(BuildContext context) => Align(
        alignment: event.direct! ? const Alignment(0, -.76) : Alignment.center,
        child: BattlePausableAnimation(
          key: const Key('battle-attack-impact'),
          paused: paused,
          duration: const Duration(milliseconds: 1000),
          builder: (context, value, child) => Opacity(
            opacity: math.sin(value * math.pi).clamp(0, 1).toDouble(),
            child: Transform.scale(
              scale: .2 + value * 1.6,
              child: Transform.rotate(angle: value * .45, child: child),
            ),
          ),
          child: const Icon(
            Icons.brightness_7_rounded,
            size: 92,
            color: Color(0xFFFFD56B),
            shadows: [Shadow(color: Color(0xFFFF553D), blurRadius: 24)],
          ),
        ),
      );
}

class _LifeFloat extends StatelessWidget {
  const _LifeFloat({required this.event, required this.paused});

  final _BattleOverlayEvent event;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final amount = event.amount!;
    return Align(
      alignment:
          event.forPlayer! ? const Alignment(0, .62) : const Alignment(0, -.78),
      child: BattlePausableAnimation(
        key: const Key('battle-life-float'),
        paused: paused,
        duration: const Duration(milliseconds: 1300),
        builder: (context, value, child) => Opacity(
          opacity: (1 - value).clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, -42 * value),
            child: Transform.scale(scale: .72 + value * .45, child: child),
          ),
        ),
        child: Text(
          '${amount > 0 ? '+' : ''}$amount',
          style: TextStyle(
            color:
                amount < 0 ? const Color(0xFFFF405C) : const Color(0xFF70F5B9),
            fontSize: 42,
            fontWeight: FontWeight.w900,
            shadows: const [Shadow(color: Colors.black, blurRadius: 8)],
          ),
        ),
      ),
    );
  }
}

class _DestructionFloat extends StatelessWidget {
  const _DestructionFloat({required this.event, required this.paused});

  final _BattleOverlayEvent event;
  final bool paused;

  @override
  Widget build(BuildContext context) => Center(
        child: BattlePausableAnimation(
          key: const Key('battle-destruction-float'),
          paused: paused,
          duration: const Duration(milliseconds: 1100),
          builder: (context, value, child) => Opacity(
            opacity: (1 - value).clamp(0, 1),
            child: Transform.translate(
              offset: Offset(0, 65 * value),
              child: Transform.rotate(angle: value * .15, child: child),
            ),
          ),
          child: Container(
            width: 150,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xE8461320),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFF5A70)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_delete,
                    color: Color(0xFFFF8290), size: 34),
                const SizedBox(height: 5),
                Text(
                  event.label!,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      );
}

class _MythicFlash extends StatelessWidget {
  const _MythicFlash({required this.event, required this.paused});

  final _BattleOverlayEvent event;
  final bool paused;

  @override
  Widget build(BuildContext context) => BattlePausableAnimation(
        key: const Key('battle-mythic-flash'),
        paused: paused,
        duration: const Duration(milliseconds: 1300),
        builder: (context, value, child) => DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                const Color(0xFFA947FF)
                    .withValues(alpha: math.sin(value * math.pi) * .72),
                Colors.transparent,
              ],
            ),
          ),
          child: Opacity(
            opacity: math.sin(value * math.pi).clamp(0, 1),
            child: Transform.scale(scale: .55 + value * .75, child: child),
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome, size: 82, color: Colors.white),
              const Text(
                'INVOCATION MYTHIQUE',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 5),
              Text(event.label!, style: const TextStyle(fontSize: 17)),
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
    this.floatLabel,
    this.floatToken = 0,
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
  final String? floatLabel;
  final int floatToken;
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
                    floatLabel: floatLabel,
                    floatToken: floatToken,
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
      this.floatLabels = const {},
      this.floatTokens = const {},
      this.activatableIds = const {},
      this.validTargetIds = const {},
      this.attackingCardId,
      this.attackAnimationToken = 0,
      this.summoningIds = const {},
      this.onCardTap});
  final List<FieldCardInstance?> zones;
  final LocalDuelController controller;
  final bool opponent;
  final Set<String> selectedIds;
  final String? feedbackCardId;
  final String? feedbackMessage;
  final int feedbackToken;
  final Map<String, String> floatLabels;
  final Map<String, int> floatTokens;
  final Set<String> activatableIds;
  final Set<String> validTargetIds;
  final String? attackingCardId;
  final int attackAnimationToken;
  final Set<String> summoningIds;
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
                      floatLabel: floatLabels[zones[index]!.instanceId],
                      floatToken: floatTokens[zones[index]!.instanceId] ?? 0,
                      activatable:
                          activatableIds.contains(zones[index]!.instanceId),
                      validTarget:
                          validTargetIds.contains(zones[index]!.instanceId),
                      attacking: attackingCardId == zones[index]!.instanceId,
                      attackDirection: opponent ? 1 : -1,
                      attackAnimationToken: attackAnimationToken,
                      justSummoned:
                          summoningIds.contains(zones[index]!.instanceId),
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
      this.floatLabel,
      this.floatToken = 0,
      this.activatable = false,
      this.validTarget = false,
      this.attacking = false,
      this.attackDirection = -1,
      this.attackAnimationToken = 0,
      this.justSummoned = false,
      this.onTap});
  final FieldCardInstance card;
  final LocalCardPresentation presentation;
  final bool compact;
  final bool hideIdentity;
  final bool selected;
  final String? feedbackMessage;
  final int feedbackToken;
  final String? floatLabel;
  final int floatToken;
  final bool activatable;
  final bool validTarget;
  final bool attacking;
  final double attackDirection;
  final int attackAnimationToken;
  final bool justSummoned;
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
  late final AnimationController _attackController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );
  late final AnimationController _entranceController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
    value: widget.justSummoned ? 0 : 1,
  );

  @override
  void initState() {
    super.initState();
    _syncPulse();
    if (widget.attacking) _attackController.forward(from: 0);
    if (widget.justSummoned) _entranceController.forward();
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
    if (widget.attacking &&
        (!oldWidget.attacking ||
            widget.attackAnimationToken != oldWidget.attackAnimationToken)) {
      _attackController.forward(from: 0);
    }
    if (widget.justSummoned && !oldWidget.justSummoned) {
      _entranceController.forward(from: 0);
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
    _attackController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCharacter =
        widget.presentation.category == CardCategory.character ||
            widget.presentation.category == CardCategory.mythic;
    return AnimatedBuilder(
      animation: Listenable.merge(
        [
          _shakeController,
          _pulseController,
          _attackController,
          _entranceController,
        ],
      ),
      builder: (context, child) {
        final progress = _shakeController.value;
        final offset = math.sin(progress * math.pi * 6) * (1 - progress) * 7;
        final lunge = math.sin(_attackController.value * math.pi) *
            30 *
            widget.attackDirection;
        return Transform.translate(
          offset: Offset(offset, lunge),
          child: Opacity(
            opacity: _entranceController.value,
            child: Transform.scale(
              scale: (.55 + _entranceController.value * .45) *
                  (1 + math.sin(_attackController.value * math.pi) * .08),
              child: child,
            ),
          ),
        );
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
                        Image.asset(
                          'assets/images/cards/${widget.presentation.code.toLowerCase()}.png',
                          key: ValueKey('battle-art-${widget.card.instanceId}'),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Image.asset(
                            'assets/images/cards/${widget.presentation.code.toUpperCase()}.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.auto_awesome,
                                  color: Colors.white24),
                            ),
                          ),
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black87,
                                Colors.transparent,
                                Colors.black87
                              ],
                              stops: [0, .45, 1],
                            ),
                          ),
                        ),
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
                        if (widget.floatLabel != null)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: TweenAnimationBuilder<double>(
                                key: ValueKey(
                                  'card-float-${widget.card.instanceId}-${widget.floatToken}',
                                ),
                                duration: const Duration(milliseconds: 850),
                                tween: Tween(begin: 0, end: 1),
                                builder: (context, value, child) => Opacity(
                                  opacity: (1 - value).clamp(0, 1),
                                  child: Transform.translate(
                                    offset: Offset(0, -22 * value),
                                    child: child,
                                  ),
                                ),
                                child: Center(
                                  child: Container(
                                    key: const Key('battle-card-float'),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    color: Colors.black87,
                                    child: Text(
                                      widget.floatLabel!,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color:
                                            widget.floatLabel!.startsWith('-')
                                                ? const Color(0xFFFF7384)
                                                : const Color(0xFF8CFFD9),
                                        fontSize: widget.compact ? 8 : 10,
                                        fontWeight: FontWeight.w900,
                                      ),
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
