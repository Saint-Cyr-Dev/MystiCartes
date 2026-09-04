import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/app_routes.dart';
import 'auth_session_preferences.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const _violet = Color(0xFFAC67FF);
  static const _paleViolet = Color(0xFFE5C7FF);

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _createAccount = false;
  bool _rememberMe = true;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadRememberPreference();
  }

  Future<void> _loadRememberPreference() async {
    final remember = await AuthSessionPreferences.rememberSession();
    if (mounted) setState(() => _rememberMe = remember);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.length < 6) {
      _showMessage(
        'Saisissez un e-mail et un mot de passe de 6 caractères minimum.',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_createAccount) {
        final response = await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
        );
        if (!mounted) return;
        await AuthSessionPreferences.setRememberSession(_rememberMe);
        if (response.session == null) {
          _showMessage(
            'Compte créé. Consultez votre e-mail pour le confirmer.',
          );
          return;
        }
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        await AuthSessionPreferences.setRememberSession(_rememberMe);
      }

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.startup,
        (_) => false,
      );
    } on AuthException catch (error) {
      if (mounted) _showMessage(_friendlyAuthError(error.message));
    } catch (error) {
      if (mounted) _showMessage('Connexion impossible : $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('Entrez d’abord votre adresse e-mail.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (mounted) {
        _showMessage('Un lien de réinitialisation vient de vous être envoyé.');
      }
    } on AuthException catch (error) {
      if (mounted) _showMessage(_friendlyAuthError(error.message));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyAuthError(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('invalid login credentials')) {
      return 'E-mail ou mot de passe incorrect.';
    }
    if (normalized.contains('email rate limit')) {
      return 'Trop de demandes ont été envoyées. Réessayez dans quelques minutes.';
    }
    if (normalized.contains('already registered')) {
      return 'Un compte existe déjà avec cette adresse e-mail.';
    }
    return message;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showLanguagePicker() => showModalBottomSheet<void>(
        context: context,
        backgroundColor: const Color(0xFF151024),
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Langue du jeu',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.check_circle, color: _violet),
                  title: const Text('Français'),
                  subtitle: const Text('Langue active'),
                  onTap: () => Navigator.pop(context),
                ),
                const ListTile(
                  enabled: false,
                  leading: Icon(Icons.language),
                  title: Text('Autres langues'),
                  subtitle: Text('Disponibles dans une prochaine version'),
                ),
              ],
            ),
          ),
        ),
      );

  Future<void> _showHelp() => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF171126),
          icon: const Icon(Icons.help_outline_rounded, color: _violet),
          title: const Text('Besoin d’aide ?'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Créer un compte',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'Choisissez « Créer un nouveau compte », puis utilisez un e-mail valide et un mot de passe d’au moins 6 caractères.',
              ),
              SizedBox(height: 16),
              Text(
                'Compte inaccessible',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'Entrez votre e-mail puis choisissez « Mot de passe oublié ? » pour recevoir un lien de récupération.',
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('J’ai compris'),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070410),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/backgrounds/auth-mystic-city.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x0A000000),
                  Color(0x33070410),
                  Color(0xB8070410),
                  Color(0xEE070410),
                ],
                stops: [0, .31, .72, 1],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wideLayout = constraints.maxWidth >= 900;
                final topSpace = wideLayout
                    ? 34.0
                    : (constraints.maxHeight * .26)
                        .clamp(165.0, 300.0)
                        .toDouble();
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Align(
                    alignment:
                        wideLayout ? Alignment.topRight : Alignment.topCenter,
                    child: Padding(
                      padding: EdgeInsets.only(right: wideLayout ? 42 : 0),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: wideLayout ? 520 : 610,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(height: topSpace),
                            const _BrandHeader(),
                            const SizedBox(height: 26),
                            _MysticTextField(
                              controller: _emailController,
                              label: 'E-mail',
                              hint: 'Entrez votre adresse e-mail',
                              icon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                            ),
                            const SizedBox(height: 14),
                            _MysticTextField(
                              controller: _passwordController,
                              label: 'Mot de passe',
                              hint: 'Entrez votre mot de passe',
                              icon: Icons.lock_outline_rounded,
                              obscureText: _obscurePassword,
                              autofillHints: [
                                _createAccount
                                    ? AutofillHints.newPassword
                                    : AutofillHints.password,
                              ],
                              onSubmitted: (_) {
                                if (!_isLoading) _submit();
                              },
                              suffix: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Afficher le mot de passe'
                                    : 'Masquer le mot de passe',
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: _paleViolet,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Checkbox(
                                  value: _rememberMe,
                                  activeColor: _violet,
                                  checkColor: const Color(0xFF1A082E),
                                  side: const BorderSide(color: _paleViolet),
                                  onChanged: _isLoading
                                      ? null
                                      : (value) => setState(
                                            () => _rememberMe = value ?? true,
                                          ),
                                ),
                                const Expanded(
                                    child: Text('Se souvenir de moi')),
                                TextButton(
                                  onPressed: _isLoading ? null : _resetPassword,
                                  child: const Text('Mot de passe oublié ?'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _PrimaryAuthButton(
                              loading: _isLoading,
                              label: _createAccount
                                  ? 'Créer mon compte'
                                  : 'Se connecter',
                              onPressed: _submit,
                            ),
                            const SizedBox(height: 22),
                            const _OrDivider(),
                            const SizedBox(height: 18),
                            OutlinedButton.icon(
                              onPressed: _isLoading
                                  ? null
                                  : () => setState(
                                        () => _createAccount = !_createAccount,
                                      ),
                              icon: Icon(
                                _createAccount
                                    ? Icons.login_rounded
                                    : Icons.person_rounded,
                              ),
                              label: Text(
                                _createAccount
                                    ? 'J’ai déjà un compte'
                                    : 'Créer un nouveau compte',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _violet,
                                minimumSize: const Size.fromHeight(60),
                                side:
                                    const BorderSide(color: Color(0xFF7442AF)),
                                backgroundColor: const Color(0xB8120C22),
                                textStyle: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                            const SizedBox(height: 26),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.verified_user_outlined,
                                  color: Color(0xFFB8AEC9),
                                ),
                                SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    'Vos données sont protégées et sécurisées',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Color(0xFFB8AEC9)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 34),
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              runAlignment: WrapAlignment.center,
                              spacing: 12,
                              runSpacing: 10,
                              children: [
                                _FooterPill(
                                  icon: Icons.language_rounded,
                                  label: 'Français',
                                  onPressed: _showLanguagePicker,
                                ),
                                _FooterPill(
                                  icon: Icons.help_outline_rounded,
                                  label: 'Besoin d’aide ?',
                                  iconAtEnd: true,
                                  onPressed: _showHelp,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) => Column(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFF9EFFF), Color(0xFFC68BFF)],
            ).createShader(bounds),
            child: Text(
              'MYSTICARTES',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'serif',
                fontSize: MediaQuery.sizeOf(context).width < 430 ? 39 : 52,
                height: 1,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w600,
                shadows: const [
                  Shadow(color: Color(0xFF8D36E8), blurRadius: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              Expanded(child: _GlowingRule()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  Icons.auto_awesome,
                  size: 17,
                  color: Color(0xFFC680FF),
                ),
              ),
              Expanded(child: _GlowingRule()),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Maîtrisez la magie. Dominez le destin.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFC27CFF),
              fontSize: 18,
              letterSpacing: .2,
            ),
          ),
        ],
      );
}

class _GlowingRule extends StatelessWidget {
  const _GlowingRule();

  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.transparent, Color(0xFFC680FF)],
          ),
        ),
      );
}

class _MysticTextField extends StatelessWidget {
  const _MysticTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.autofillHints,
    this.obscureText = false,
    this.suffix,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xD4141024),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF5B347D)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          autofillHints: autofillHints,
          obscureText: obscureText,
          onSubmitted: onSubmitted,
          style: const TextStyle(fontSize: 17, color: Color(0xFFF4EDFF)),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            prefixIcon: Icon(icon, color: const Color(0xFFAB62FF), size: 28),
            suffixIcon: suffix,
            labelStyle: const TextStyle(
              color: Color(0xFFE4D8EF),
              fontSize: 17,
            ),
            hintStyle: const TextStyle(
              color: Color(0xFF827A8F),
              fontSize: 16,
            ),
            floatingLabelBehavior: FloatingLabelBehavior.always,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            border: InputBorder.none,
          ),
        ),
      );
}

class _PrimaryAuthButton extends StatelessWidget {
  const _PrimaryAuthButton({
    required this.loading,
    required this.label,
    required this.onPressed,
  });

  final bool loading;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFC17AFF), Color(0xFF9545F4)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF0D2FF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x668A35F0),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: FilledButton(
          onPressed: loading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: const Color(0xFF1B082E),
            minimumSize: const Size.fromHeight(68),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            textStyle: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),
          child: loading
              ? const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF28103E),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(label),
                      ),
                    ),
                    const SizedBox(width: 18),
                    const Icon(Icons.arrow_forward_rounded, size: 30),
                  ],
                ),
        ),
      );
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) => const Row(
        children: [
          Expanded(child: Divider(color: Color(0xFF704497))),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              'OU',
              style: TextStyle(color: Color(0xFFC680FF), fontSize: 17),
            ),
          ),
          Expanded(child: Divider(color: Color(0xFF704497))),
        ],
      );
}

class _FooterPill extends StatelessWidget {
  const _FooterPill({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.iconAtEnd = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool iconAtEnd;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(
      icon,
      size: 22,
      color: const Color(0xFFC9BED9),
    );
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFFD7CCDF),
        backgroundColor: const Color(0xA7141024),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!iconAtEnd) iconWidget,
          if (!iconAtEnd) const SizedBox(width: 9),
          Text(label),
          if (iconAtEnd) const SizedBox(width: 9),
          if (iconAtEnd) iconWidget,
        ],
      ),
    );
  }
}
