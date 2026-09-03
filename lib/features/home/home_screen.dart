import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/app_routes.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({this.localDemoMode = false, super.key});

  final bool localDemoMode;

  Future<void> _signOut(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.auth, (_) => false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('MystiCartes'),
          actions: [
            if (!localDemoMode)
              IconButton(
                tooltip: 'Se déconnecter',
                onPressed: () => _signOut(context),
                icon: const Icon(Icons.logout),
              ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                if (localDemoMode) ...[
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'MODE LOCAL V2 — aucun compte requis. Lancez un duel immédiatement.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                FilledButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.battle),
                  icon: const Icon(Icons.sports_martial_arts),
                  label: const Text('JOUER'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AppRoutes.collection,
                  ),
                  icon: const Icon(Icons.collections_bookmark),
                  label: const Text('BIBLIOTHÈQUE'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.decks),
                  icon: const Icon(Icons.style),
                  label: const Text('MES DECKS'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.settings),
                  icon: const Icon(Icons.settings),
                  label: const Text('PARAMÈTRES'),
                ),
              ],
            ),
          ),
        ),
      );
}
