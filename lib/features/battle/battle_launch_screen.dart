import 'package:flutter/material.dart';

import 'battle_deck_repository.dart';
import 'battle_screen.dart';
import 'progression_repository.dart';

class BattleLaunchScreen extends StatefulWidget {
  const BattleLaunchScreen({
    this.progressionRepository,
    this.deckRepository,
    super.key,
  });

  final ProgressionRepository? progressionRepository;
  final BattleDeckDataSource? deckRepository;

  @override
  State<BattleLaunchScreen> createState() => _BattleLaunchScreenState();
}

class _BattleLaunchScreenState extends State<BattleLaunchScreen> {
  Object? _error;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    setState(() => _error = null);
    try {
      final setup =
          await (widget.progressionRepository ?? ProgressionRepository())
              .prepareBattle();
      final deck =
          await (widget.deckRepository ?? SupabaseBattleDeckRepository())
              .load(setup.deckId);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => BattleScreen.local(
            difficulty: setup.difficulty,
            deckId: deck.deckId,
            playerDeck: deck.mainDeck,
            playerMythicReserve: deck.mythicReserve,
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Préparation du duel')),
        body: Center(
          child: _error == null
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Chargement du deck actif…'),
                  ],
                )
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Le duel ne peut pas être préparé.'),
                      const SizedBox(height: 8),
                      Text('$_error', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _prepare,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
        ),
      );
}
