import 'package:flutter/material.dart';

enum BattleAnimationPace {
  normal('Normal', 1),
  readable('Plus lisible', 1.5);

  const BattleAnimationPace(this.label, this.durationScale);

  final String label;
  final double durationScale;
}

final class BattleSettingsResult {
  const BattleSettingsResult({required this.pace, this.restart = false});

  final BattleAnimationPace pace;
  final bool restart;
}

/// The caller pauses the battle before showing this dialog and resumes it
/// after applying the returned settings (or restarts after confirmation).
class BattleSettingsDialog extends StatefulWidget {
  const BattleSettingsDialog({super.key, required this.pace});

  final BattleAnimationPace pace;

  @override
  State<BattleSettingsDialog> createState() => _BattleSettingsDialogState();
}

class _BattleSettingsDialogState extends State<BattleSettingsDialog> {
  late BattleAnimationPace _pace = widget.pace;

  Future<void> _confirmRestart() async {
    final restart = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recommencer le duel ?'),
        content: const Text('La partie en cours sera abandonnée.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            key: const Key('battle-confirm-restart'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Recommencer'),
          ),
        ],
      ),
    );
    if (!mounted || restart != true) return;
    Navigator.pop(
      context,
      BattleSettingsResult(pace: _pace, restart: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('battle-settings-dialog'),
      backgroundColor: const Color(0xff171023),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xff6f429b)),
      ),
      title: const Row(
        children: [
          Icon(Icons.pause_circle_outline, color: Color(0xffcc9bff)),
          SizedBox(width: 10),
          Flexible(child: Text('Partie en pause')),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Durée des animations'),
              const SizedBox(height: 12),
              SegmentedButton<BattleAnimationPace>(
                segments: [
                  for (final pace in BattleAnimationPace.values)
                    ButtonSegment(value: pace, label: Text(pace.label)),
                ],
                selected: {_pace},
                onSelectionChanged: (values) =>
                    setState(() => _pace = values.single),
              ),
              const SizedBox(height: 12),
              const Text(
                '« Plus lisible » laisse davantage de temps pour voir '
                'les cartes jouées, les effets et les attaques.',
                style: TextStyle(fontSize: 13, color: Color(0xffbeb0cf)),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const Key('battle-resume'),
                onPressed: () => Navigator.pop(
                  context,
                  BattleSettingsResult(pace: _pace),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Reprendre'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                key: const Key('battle-restart-from-settings'),
                onPressed: _confirmRestart,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Recommencer le duel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
