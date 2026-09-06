import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/app_routes.dart';
import '../../app/mystic_navigation.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({this.localDemoMode = false, super.key});

  final bool localDemoMode;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _soundEnabled = true;
  bool _animationsEnabled = true;
  bool _signingOut = false;

  static const _entries = <_MoreEntryData>[
    _MoreEntryData('Premium', Icons.workspace_premium_rounded),
    _MoreEntryData('Profil', Icons.account_circle_rounded),
    _MoreEntryData('Récompenses', Icons.card_giftcard_rounded),
    _MoreEntryData('Événements', Icons.event_available_rounded),
    _MoreEntryData('Quêtes', Icons.task_alt_rounded),
    _MoreEntryData('Classement', Icons.emoji_events_rounded),
    _MoreEntryData('Prix', Icons.sell_rounded),
    _MoreEntryData('Amis', Icons.group_rounded),
    _MoreEntryData('Messages', Icons.mail_rounded),
    _MoreEntryData('Paramètres', Icons.settings_rounded),
    _MoreEntryData('Support', Icons.support_agent_rounded),
  ];

  void _openEntry(_MoreEntryData entry) {
    switch (entry.label) {
      case 'Profil':
        _showProfile();
        return;
      case 'Paramètres':
        _showPreferences();
        return;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${entry.label} sera disponible prochainement dans MystiCartes.',
            ),
          ),
        );
        return;
    }
  }

  void _showProfile() {
    var accountLabel = 'Mode local — aucun compte connecté';
    if (!widget.localDemoMode) {
      try {
        accountLabel = Supabase.instance.client.auth.currentUser?.email ??
            'Compte MystiCartes connecté';
      } catch (_) {
        accountLabel = 'Mode local — aucun compte connecté';
      }
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF171124),
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 34,
                backgroundColor: Color(0xFF6A2DA0),
                child: Icon(Icons.person_rounded,
                    size: 40, color: Color(0xFFEBD4FF)),
              ),
              const SizedBox(height: 12),
              const Text('PROFIL',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(
                accountLabel,
                key: const Key('more-profile-account'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFD2B9E5)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPreferences() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF171124),
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  leading:
                      Icon(Icons.settings_rounded, color: Color(0xFFC875FF)),
                  title: Text('PARAMÈTRES',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text('Préférences de jeu locales'),
                ),
                SwitchListTile(
                  value: _soundEnabled,
                  secondary: const Icon(Icons.volume_up_rounded),
                  title: const Text('Sons du jeu'),
                  onChanged: (value) {
                    setState(() => _soundEnabled = value);
                    setSheetState(() {});
                  },
                ),
                SwitchListTile(
                  value: _animationsEnabled,
                  secondary: const Icon(Icons.animation_rounded),
                  title: const Text('Animations'),
                  onChanged: (value) {
                    setState(() => _animationsEnabled = value);
                    setSheetState(() {});
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    if (widget.localDemoMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun compte à déconnecter en mode local.'),
        ),
      );
      return;
    }
    setState(() => _signingOut = true);
    try {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.auth, (_) => false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _signingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La déconnexion a échoué. Réessayez.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF070814),
        appBar: AppBar(
          backgroundColor: const Color(0xEE090A18),
          surfaceTintColor: Colors.transparent,
          title:
              const Text('PLUS', style: TextStyle(fontWeight: FontWeight.w900)),
        ),
        bottomNavigationBar: const MysticBottomNavigation(
          currentRoute: AppRoutes.settings,
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -1),
              radius: 1.4,
              colors: [Color(0xFF241047), Color(0xFF070814)],
            ),
          ),
          child: ListView(
            key: const Key('more-list'),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
            children: [
              const _MoreHeader(),
              const SizedBox(height: 14),
              for (final entry in _entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _MoreEntry(
                    data: entry,
                    onTap: () => _openEntry(entry),
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('more-sign-out'),
                onPressed: _signingOut ? null : _signOut,
                icon: _signingOut
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout_rounded),
                label: const Text('DÉCONNEXION'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF9BAB),
                  side: const BorderSide(color: Color(0xFF8B4055)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      );
}

class _MoreHeader extends StatelessWidget {
  const _MoreHeader();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xC5161027),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF563875)),
        ),
        child: const Row(
          children: [
            Icon(Icons.auto_awesome_rounded,
                size: 34, color: Color(0xFFD78DFF)),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mon espace MystiCartes',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  SizedBox(height: 3),
                  Text('Compte, communauté et préférences',
                      style: TextStyle(color: Color(0xFFCDB9D9))),
                ],
              ),
            ),
          ],
        ),
      );
}

class _MoreEntryData {
  const _MoreEntryData(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _MoreEntry extends StatelessWidget {
  const _MoreEntry({required this.data, required this.onTap});

  final _MoreEntryData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xC5161027),
        borderRadius: BorderRadius.circular(15),
        child: ListTile(
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: const BorderSide(color: Color(0xFF423054)),
          ),
          leading: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF35204D),
            ),
            child: Icon(data.icon, color: const Color(0xFFD59CFF)),
          ),
          title: Text(data.label,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          trailing:
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFB68CCB)),
        ),
      );
}
