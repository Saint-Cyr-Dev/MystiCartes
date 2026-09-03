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
    super.key,
  });

  final AiDifficulty difficulty;
  final String? deckId;
  final List<LocalCardPresentation>? playerDeck;
  final List<LocalCardPresentation> playerMythicReserve;
  final bool isFirstBattle;
  final BattleResultDataSource? resultRepository;

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

  @override
  void initState() {
    super.initState();
    _difficulty = widget.difficulty;
    _startedAt = DateTime.now().toUtc();
    _duel = LocalDuelController.create(
      difficulty: _difficulty,
      playerDeck: widget.playerDeck,
      playerMythicReserve: widget.playerMythicReserve,
    );
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
    });
  }

  Future<void> _playHandCard(CardInstance card) async {
    if (_aiPlaying || _duel.state.isFinished) return;
    if (_duel.state.activePlayer != DuelParticipant.player ||
        !{DuelPhase.main1, DuelPhase.main2}
            .contains(_duel.state.currentPhase)) {
      _message('Jouez les cartes pendant une Phase Principale.');
      return;
    }
    if (card.category == CardCategory.character) {
      final required = _duel.engine.requiredSacrificesForNormalPlay(card);
      if (required == null) {
        _message('Ce Personnage ne peut pas être invoqué normalement.');
        return;
      }
      if (_selectedSacrifices.length != required) {
        _message(
          required == 0
              ? 'Cette carte ne demande aucun sacrifice.'
              : 'Sélectionnez $required sacrifice${required > 1 ? 's' : ''} sur votre terrain.',
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
      _message(result.message);
      _checkEnd();
      return;
    }

    if (card.category == CardCategory.action ||
        card.category == CardCategory.trap) {
      final result = _duel.setActionOrTrap(card.instanceId);
      setState(() {});
      _message(result.message);
      return;
    }
    _message('Cette catégorie sera jouable dans une prochaine interface.');
  }

  void _tapOwnCharacter(FieldCardInstance card) {
    if (_aiPlaying || _duel.state.isFinished) return;
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
        _message('Ce Personnage est en Défense.');
        return;
      }
      final hasTarget =
          state.aiField.characterZones.any((zone) => zone != null);
      if (!hasTarget) {
        _resolveAttack(card.instanceId, null);
      } else {
        setState(() => _selectedAttackerId = card.instanceId);
        _message('Choisissez maintenant une cible adverse.');
      }
    }
  }

  void _tapOpponentCharacter(FieldCardInstance card) {
    final attackerId = _selectedAttackerId;
    if (attackerId == null) {
      _message('Sélectionnez d’abord votre attaquant.');
      return;
    }
    _resolveAttack(attackerId, card.instanceId);
  }

  void _resolveAttack(String attackerId, String? targetId) {
    final result = _duel.attack(
      attackerInstanceId: attackerId,
      targetInstanceId: targetId,
    );
    setState(() => _selectedAttackerId = null);
    _message(result.message);
    _checkEnd();
  }

  Future<void> _nextPhase() async {
    if (_aiPlaying || _duel.state.isFinished) return;
    final result = _duel.advancePlayerPhase();
    setState(() {
      _selectedSacrifices.clear();
      _selectedAttackerId = null;
    });
    if (!result.succeeded) {
      _message(result.message);
      return;
    }
    _checkEnd();
    if (_duel.state.activePlayer == DuelParticipant.ai &&
        !_duel.state.isFinished) {
      setState(() => _aiPlaying = true);
      await Future<void>.delayed(const Duration(milliseconds: 650));
      final actions = _duel.playAiTurn();
      if (!mounted) return;
      setState(() => _aiPlaying = false);
      _message(
        actions.isEmpty
            ? "L'IA termine son tour."
            : "Tour IA : ${actions.length} action${actions.length > 1 ? 's' : ''}.",
      );
      _checkEnd();
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

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final state = _duel.state;
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
                            controller: _duel),
                        const SizedBox(height: 6),
                        _ZoneRow(
                            zones: state.aiField.characterZones,
                            opponent: true,
                            controller: _duel,
                            onCardTap: _tapOpponentCharacter),
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
                            onCardTap: _tapOwnCharacter),
                        const SizedBox(height: 6),
                        _ZoneRow(
                            zones: state.playerField.actionTrapZones,
                            controller: _duel),
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
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF6B3FA0).withValues(alpha: .55)
                : Colors.black.withValues(alpha: .35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: isActive ? const Color(0xFFE5B8FF) : Colors.white24)),
        child: Row(children: [
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
  Widget build(BuildContext context) => Card(
        color: const Color(0xFF0E544B),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(children: [
            Expanded(
                child: Text(
                    aiPlaying
                        ? "L'IA réfléchit…"
                        : 'Tour $turn · ${_phaseLabel(phase)}',
                    style: const TextStyle(fontWeight: FontWeight.bold))),
            FilledButton.icon(
                onPressed: aiPlaying ? null : onNext,
                icon: const Icon(Icons.skip_next),
                label: const Text('Phase suivante'))
          ]),
        ),
      );

  static String _phaseLabel(DuelPhase phase) => switch (phase) {
        DuelPhase.draw => 'Pioche',
        DuelPhase.preparation => 'Préparation',
        DuelPhase.main1 => 'Principale 1',
        DuelPhase.battle => 'Combat',
        DuelPhase.main2 => 'Principale 2',
        DuelPhase.end => 'Fin'
      };
}

class _ZoneRow extends StatelessWidget {
  const _ZoneRow(
      {required this.zones,
      required this.controller,
      this.opponent = false,
      this.selectedIds = const {},
      this.onCardTap});
  final List<FieldCardInstance?> zones;
  final LocalDuelController controller;
  final bool opponent;
  final Set<String> selectedIds;
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
                      onTap: onCardTap == null
                          ? null
                          : () => onCardTap!(zones[index]!)),
            ),
          ],
        ],
      );
}

class _DuelCard extends StatelessWidget {
  const _DuelCard(
      {required this.card,
      required this.presentation,
      required this.compact,
      this.hideIdentity = false,
      this.selected = false,
      this.onTap});
  final FieldCardInstance card;
  final LocalCardPresentation presentation;
  final bool compact;
  final bool hideIdentity;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isCharacter = presentation.category == CardCategory.character ||
        presentation.category == CardCategory.mythic;
    return SizedBox(
      width: compact ? 68 : 104,
      child: Material(
        color: hideIdentity
            ? const Color(0xFF3A1C55)
            : isCharacter
                ? const Color(0xFF744C2D)
                : presentation.category == CardCategory.trap
                    ? const Color(0xFF7A285D)
                    : const Color(0xFF235C7A),
        borderRadius: BorderRadius.circular(9),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.all(compact ? 5 : 8),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                    color: selected ? const Color(0xFFFFD166) : Colors.white38,
                    width: selected ? 3 : 1)),
            child: hideIdentity
                ? const Center(child: Icon(Icons.auto_awesome, size: 30))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        Text(presentation.name,
                            maxLines: compact ? 2 : 3,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: compact ? 9 : 11,
                                fontWeight: FontWeight.bold)),
                        const Spacer(),
                        if (isCharacter) ...[
                          Text(
                              'R${presentation.rank}  ${card.position == BattlePosition.defense ? 'DEF' : 'ATK'}',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: compact ? 8 : 10)),
                          Text('${card.effectiveAtk}/${card.effectiveDef}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: compact ? 9 : 11,
                                  fontWeight: FontWeight.w700)),
                        ] else
                          Text(
                              presentation.category == CardCategory.trap
                                  ? 'PIÈGE'
                                  : 'ACTION',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: compact ? 9 : 11)),
                        if (!card.faceUp && isCharacter)
                          const Icon(Icons.visibility_off, size: 13),
                      ]),
          ),
        ),
      ),
    );
  }
}
