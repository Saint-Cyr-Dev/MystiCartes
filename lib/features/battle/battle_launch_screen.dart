import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import 'battle_deck_repository.dart';
import 'battle_presentation_scheduler.dart';
import 'battle_screen.dart';
import 'progression_repository.dart';
import 'widgets/battle_loading_view.dart';

class BattleLaunchScreen extends StatefulWidget {
  const BattleLaunchScreen({
    this.progressionRepository,
    this.deckRepository,
    this.localDemoMode = false,
    super.key,
  });

  final ProgressionRepository? progressionRepository;
  final BattleDeckDataSource? deckRepository;
  final bool localDemoMode;

  @override
  State<BattleLaunchScreen> createState() => _BattleLaunchScreenState();
}

class _BattleLaunchScreenState extends State<BattleLaunchScreen> {
  Object? _error;
  String _status = 'Préparation de ton profil…';
  final _presentation = BattlePresentationScheduler();

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    _presentation.cancelAll();
    setState(() {
      _error = null;
      _status = widget.localDemoMode
          ? 'Ouverture du terrain…'
          : 'Préparation de ton profil…';
    });
    // A short reveal, concurrent with real loading; not fake progress or a
    // network delay during the duel. Leaving the page cancels this wait.
    final reveal = _presentation.wait(const Duration(milliseconds: 1000));
    try {
      if (widget.localDemoMode) {
        if (!await reveal || !mounted) return;
        _enter(const BattleScreen.local());
        return;
      }
      final setup =
          await (widget.progressionRepository ?? ProgressionRepository())
              .prepareBattle();
      if (!mounted) return;
      setState(() => _status = 'Chargement du deck actif…');
      final deck =
          await (widget.deckRepository ?? SupabaseBattleDeckRepository())
              .load(setup.deckId);
      if (!mounted) return;
      setState(() => _status = 'Ouverture du terrain…');
      if (!await reveal || !mounted) return;
      _enter(BattleScreen.local(
        difficulty: setup.difficulty,
        deckId: deck.deckId,
        playerDeck: deck.mainDeck,
        playerMythicReserve: deck.mythicReserve,
      ));
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  void _enter(Widget battle) => Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (context, animation, secondaryAnimation) => battle,
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );

  @override
  void dispose() {
    _presentation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BattleLoadingView(
        status: _status,
        error: _error,
        onRetry: _prepare,
        onBack: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            Navigator.pushReplacementNamed(context, AppRoutes.home);
          }
        },
      );
}
