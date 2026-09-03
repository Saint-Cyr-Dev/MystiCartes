import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/app_routes.dart';
import 'onboarding_repository.dart';

class StartupGateScreen extends StatefulWidget {
  const StartupGateScreen({this.repository, super.key});

  final OnboardingRepository? repository;

  @override
  State<StartupGateScreen> createState() => _StartupGateScreenState();
}

class _StartupGateScreenState extends State<StartupGateScreen> {
  late final OnboardingRepository _repository;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? OnboardingRepository();
    _resolveDestination();
  }

  Future<void> _resolveDestination() async {
    setState(() => _error = null);
    if (Supabase.instance.client.auth.currentUser == null) {
      _replaceAll(AppRoutes.auth);
      return;
    }
    try {
      final status = await _repository.fetchStatus();
      if (!mounted) return;
      // La présence d'un deck ready est la source de vérité: une reconnexion
      // ne repasse jamais par le tutoriel une fois ce deck obtenu.
      final destination = switch (destinationFor(status)) {
        OnboardingDestination.home => AppRoutes.home,
        OnboardingDestination.tutorial => AppRoutes.tutorial,
        OnboardingDestination.chooseUsername => AppRoutes.chooseUsername,
      };
      _replaceAll(destination);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  void _replaceAll(String route) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: _error == null
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Préparation de votre aventure…'),
                  ],
                )
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Impossible de charger votre profil.'),
                      const SizedBox(height: 8),
                      Text('$_error', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _resolveDestination,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
        ),
      );
}
