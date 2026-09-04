import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app_routes.dart';
import 'game/ai/ai_strategy.dart';
import 'features/auth/auth_screen.dart';
import 'features/auth/auth_session_preferences.dart';
import 'features/auth/choose_username_screen.dart';
import 'features/auth/onboarding_repository.dart';
import 'features/auth/startup_gate_screen.dart';
import 'features/auth/tutorial_screen.dart';
import 'features/battle/battle_screen.dart';
import 'features/battle/battle_launch_screen.dart';
import 'features/battle/local_duel.dart';
import 'features/battle/reward_screen.dart';
import 'features/collection/collection_screen.dart';
import 'features/decks/decks_screen.dart';
import 'features/home/home_screen.dart';
import 'features/settings/settings_screen.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final hasSupabaseConfiguration =
      _supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty;
  if (hasSupabaseConfiguration) {
    await Supabase.initialize(
      url: _supabaseUrl,
      publishableKey: _supabaseAnonKey,
    );
    await AuthSessionPreferences.applyAtStartup(Supabase.instance.client);
  }
  runApp(MystiCartesApp(localDemoMode: !hasSupabaseConfiguration));
}

class MystiCartesApp extends StatelessWidget {
  const MystiCartesApp({this.localDemoMode = false, super.key});

  final bool localDemoMode;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'MystiCartes',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6B3FA0),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        initialRoute: localDemoMode
            ? AppRoutes.home
            : Supabase.instance.client.auth.currentSession == null
                ? AppRoutes.auth
                : AppRoutes.startup,
        onGenerateRoute: _onGenerateRoute,
      );

  Route<void> _onGenerateRoute(RouteSettings settings) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (context) => _pageFor(context, settings),
    );
  }

  Widget _pageFor(BuildContext context, RouteSettings settings) =>
      switch (settings.name) {
        AppRoutes.auth => const AuthScreen(),
        AppRoutes.startup => const StartupGateScreen(),
        AppRoutes.chooseUsername => const ChooseUsernameScreen(),
        AppRoutes.tutorial => const TutorialScreen(),
        AppRoutes.firstBattle => _firstBattlePage(settings.arguments),
        AppRoutes.reward => settings.arguments is BattleRewardScreenData
            ? RewardScreen(data: settings.arguments! as BattleRewardScreenData)
            : const _UnknownRouteScreen(),
        AppRoutes.home => HomeScreen(localDemoMode: localDemoMode),
        AppRoutes.collection => localDemoMode
            ? const _OnlineFeatureScreen(feature: 'Bibliothèque')
            : const CollectionScreen(),
        AppRoutes.decks => localDemoMode
            ? const _OnlineFeatureScreen(feature: 'Mes decks')
            : const DecksScreen(),
        AppRoutes.battle => localDemoMode
            ? const BattleScreen.local()
            : const BattleLaunchScreen(),
        AppRoutes.settings => const SettingsScreen(),
        _ => localDemoMode
            ? const HomeScreen(localDemoMode: true)
            : const _UnknownRouteScreen(),
      };

  Widget _firstBattlePage(Object? arguments) {
    if (arguments is! StarterDeckData) return const BattleScreen.local();
    List<LocalCardPresentation> expand(List<StarterDeckCardData> cards) => [
          for (final card in cards)
            for (var copy = 0; copy < card.quantity; copy++)
              LocalCardPresentation.fromJson(card.toJson()),
        ];
    return BattleScreen.local(
      difficulty: AiDifficulty.beginner,
      deckId: arguments.deckId,
      playerDeck: expand(arguments.mainDeck),
      playerMythicReserve: expand(arguments.mythicReserve),
      isFirstBattle: true,
    );
  }
}

class _OnlineFeatureScreen extends StatelessWidget {
  const _OnlineFeatureScreen({required this.feature});

  final String feature;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(feature)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 64),
                const SizedBox(height: 16),
                Text(
                  '$feature nécessite le lancement avec vos paramètres Supabase.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context)
                      .pushNamedAndRemoveUntil(AppRoutes.home, (_) => false),
                  icon: const Icon(Icons.sports_martial_arts),
                  label: const Text('Revenir et jouer en local'),
                ),
              ],
            ),
          ),
        ),
      );
}

class _UnknownRouteScreen extends StatelessWidget {
  const _UnknownRouteScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
              AppRoutes.home,
              (_) => false,
            ),
            child: const Text('Retour à l’accueil'),
          ),
        ),
      );
}
