import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import 'onboarding_repository.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({this.repository, super.key});

  final OnboardingRepository? repository;

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  static const _pages = [
    _TutorialPage(
      icon: Icons.grid_view,
      title: 'Votre terrain',
      body:
          'Vous disposez de 5 Zones Personnage, 5 Zones Action/Piège et une Zone Terrain.',
    ),
    _TutorialPage(
      icon: Icons.favorite,
      title: '8 000 Points de Vie',
      body:
          'Chaque duel commence à 8 000 PV. Réduisez ceux de l’adversaire à zéro pour gagner.',
    ),
    _TutorialPage(
      icon: Icons.person_add,
      title: 'Invoquez un Personnage',
      body:
          'Pendant votre Phase Principale, invoquez un Personnage en Attaque ou posez-le face cachée en Défense.',
    ),
    _TutorialPage(
      icon: Icons.compare_arrows,
      title: 'ATK contre ATK ou DEF',
      body:
          'Une attaque affronte l’ATK d’un Personnage en Attaque, ou la DEF d’un Personnage en Défense.',
    ),
    _TutorialPage(
      icon: Icons.sports_martial_arts,
      title: 'La Phase de Combat',
      body:
          'Sélectionnez un attaquant puis sa cible. Si le terrain adverse est vide, attaquez directement ses PV.',
    ),
  ];

  late final OnboardingRepository _repository;
  final _pageController = PageController();
  int _pageIndex = 0;
  bool _isCreatingDeck = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? OnboardingRepository();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_pageIndex < _pages.length - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
      return;
    }

    setState(() {
      _isCreatingDeck = true;
      _error = null;
    });
    try {
      final starterDeck = await _repository.createStarterDeck();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.firstBattle,
        arguments: starterDeck,
      );
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _isCreatingDeck = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Votre premier duel V2')),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (value) => setState(() => _pageIndex = value),
                  itemBuilder: (context, index) => _pages[index],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var index = 0; index < _pages.length; index++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: index == _pageIndex ? 24 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: index == _pageIndex
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Text(
                    'Création du deck impossible : $_error',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: FilledButton.icon(
                  onPressed: _isCreatingDeck ? null : _continue,
                  icon: _isCreatingDeck
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _pageIndex == _pages.length - 1
                              ? Icons.sports_martial_arts
                              : Icons.arrow_forward,
                        ),
                  label: Text(
                    _pageIndex == _pages.length - 1
                        ? 'Recevoir mon deck et jouer'
                        : 'Suivant',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _TutorialPage extends StatelessWidget {
  const _TutorialPage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 96),
                const SizedBox(height: 28),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
}
