import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import 'battle_result.dart';

class BattleRewardScreenData {
  const BattleRewardScreenData({
    required this.report,
    required this.reward,
    required this.isFirstBattle,
  });

  final BattleReport report;
  final BattleReward reward;
  final bool isFirstBattle;
}

class RewardScreen extends StatelessWidget {
  const RewardScreen({required this.data, super.key});

  final BattleRewardScreenData data;

  @override
  Widget build(BuildContext context) {
    final resultLabel = switch (data.report.result) {
      PlayerBattleResult.victory =>
        data.isFirstBattle ? 'Première victoire !' : 'Victoire !',
      PlayerBattleResult.defeat =>
        data.isFirstBattle ? 'Premier combat terminé' : 'Défaite',
      PlayerBattleResult.draw =>
        data.isFirstBattle ? 'Premier duel terminé' : 'Match nul',
    };
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.emoji_events, size: 80),
                      const SizedBox(height: 20),
                      Text(
                        resultLabel,
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '+${data.reward.xp} XP',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '+${data.reward.gold} pièces',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (data.reward.accountLevel != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Niveau de compte ${data.reward.accountLevel}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                      if (data.reward.card != null) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Nouvelle carte obtenue',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        _RewardCard(card: data.reward.card!),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        data.isFirstBattle
                            ? 'Votre deck est prêt. Vous pouvez maintenant explorer MystiCartes.'
                            : 'Votre progression a été sauvegardée.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      FilledButton(
                        onPressed: () =>
                            Navigator.of(context).pushNamedAndRemoveUntil(
                          AppRoutes.home,
                          (_) => false,
                        ),
                        child: const Text('Entrer dans le menu principal'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({required this.card});

  final BattleRewardCard card;

  @override
  Widget build(BuildContext context) {
    final localAsset = card.localArtAsset;
    final placeholder = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.style, size: 48)),
    );
    Widget localArtOrPlaceholder() => localAsset == null
        ? placeholder
        : Image.asset(
            localAsset,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => placeholder,
          );
    final artUrl = card.artUrl?.trim();
    return SizedBox(
      width: 180,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: artUrl?.isNotEmpty == true
                  ? Image.network(
                      artUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => localArtOrPlaceholder(),
                    )
                  : localArtOrPlaceholder(),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                card.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
