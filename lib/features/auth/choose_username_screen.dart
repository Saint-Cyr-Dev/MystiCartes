import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/app_routes.dart';
import 'onboarding_repository.dart';

class ChooseUsernameScreen extends StatefulWidget {
  const ChooseUsernameScreen({this.repository, super.key});

  final OnboardingRepository? repository;

  @override
  State<ChooseUsernameScreen> createState() => _ChooseUsernameScreenState();
}

class _ChooseUsernameScreenState extends State<ChooseUsernameScreen> {
  late final OnboardingRepository _repository;
  final _controller = TextEditingController();
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? OnboardingRepository();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await _repository.saveIdentity(_controller.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.tutorial);
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.code == '23505'
            ? 'Ce pseudo est déjà utilisé.'
            : error.message;
      });
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Enregistrement impossible : $error');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_pin, size: 72),
                    const SizedBox(height: 20),
                    Text(
                      'Comment doit-on vous appeler ?',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Un seul choix suffit pour entrer dans l’arène.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _controller,
                      autofocus: true,
                      maxLength: 24,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (!_isSaving) _continue();
                      },
                      decoration: InputDecoration(
                        labelText: 'Pseudo',
                        helperText: '3 à 24 lettres, chiffres ou underscores',
                        errorText: _error,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _continue,
                      icon: _isSaving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_forward),
                      label: const Text('Continuer'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
