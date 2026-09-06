import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/app_routes.dart';
import '../../app/mystic_navigation.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({this.localDemoMode = false, super.key});
  final bool localDemoMode;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<_HomeData> _data = _loadData();

  Future<_HomeData> _loadData() async {
    if (widget.localDemoMode) return const _HomeData.demo();
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return const _HomeData.demo();
    try {
      final rows = await Future.wait([
        client
            .from('profiles')
            .select('username,display_name')
            .eq('id', user.id)
            .maybeSingle(),
        client
            .from('currencies')
            .select('gold,gems,total_xp,account_level')
            .eq('user_id', user.id)
            .maybeSingle(),
      ]);
      final profile = rows[0] ?? const <String, dynamic>{};
      final money = rows[1] ?? const <String, dynamic>{};
      return _HomeData(
        name: (profile['display_name'] ?? profile['username'] ?? 'Invocateur')
            .toString(),
        gold: (money['gold'] as num?)?.toInt() ?? 0,
        gems: (money['gems'] as num?)?.toInt() ?? 0,
        xp: (money['total_xp'] as num?)?.toInt() ?? 0,
        level: (money['account_level'] as num?)?.toInt() ?? 1,
      );
    } catch (_) {
      return const _HomeData.demo();
    }
  }

  void _open(String route) => Navigator.pushNamed(context, route);

  void _soon(String name) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name arrive bientôt dans MystiCartes.')),
      );

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.auth, (_) => false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF050611),
        body: FutureBuilder<_HomeData>(
          future: _data,
          builder: (context, snapshot) {
            final data = snapshot.data ?? const _HomeData.demo();
            return Stack(fit: StackFit.expand, children: [
              Image.asset('assets/images/backgrounds/home-mystic-city-v2.png',
                  fit: BoxFit.cover),
              const DecoratedBox(
                  decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xB8050611),
                      Color(0x69160A2D),
                      Color(0xF0050611)
                    ]),
              )),
              SafeArea(child: LayoutBuilder(builder: (context, constraints) {
                final layout = _HomeLayout.from(constraints);
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    layout.horizontalPadding,
                    layout.topPadding,
                    layout.horizontalPadding,
                    108,
                  ),
                  child: Center(
                      child: ConstrainedBox(
                    constraints:
                        BoxConstraints(maxWidth: layout.maxContentWidth),
                    child: Column(children: [
                      _TopBar(
                          data: data,
                          local: widget.localDemoMode,
                          onProfile: () => _open(AppRoutes.settings),
                          onShop: () => _open(AppRoutes.shop),
                          onLogout: _signOut),
                      SizedBox(height: layout.brandTopGap),
                      _Brand(compact: layout.compact),
                      SizedBox(height: layout.menuTopGap),
                      _MenuButton(
                          key: const ValueKey('home-play'),
                          icon: Icons.sports_martial_arts_rounded,
                          title: 'JOUER',
                          compact: layout.compact,
                          primary: true,
                          onTap: () => _open(AppRoutes.battle)),
                      SizedBox(height: layout.menuGap),
                      _MenuButton(
                          icon: Icons.menu_book_rounded,
                          title: 'BIBLIOTHÈQUE',
                          compact: layout.compact,
                          onTap: () => _open(AppRoutes.collection)),
                      SizedBox(height: layout.menuGap),
                      _MenuButton(
                          icon: Icons.style_rounded,
                          title: 'MES DECKS',
                          compact: layout.compact,
                          onTap: () => _open(AppRoutes.decks)),
                      SizedBox(height: layout.menuGap),
                      _MenuButton(
                          icon: Icons.explore_rounded,
                          title: 'DÉFIS',
                          compact: layout.compact,
                          onTap: () => _soon('La section Défis')),
                      if (widget.localDemoMode)
                        const Padding(
                            padding: EdgeInsets.only(top: 14),
                            child: _LocalNotice()),
                    ]),
                  )),
                );
              })),
              Align(
                  alignment: Alignment.bottomCenter,
                  child: const MysticBottomNavigation(
                    currentRoute: AppRoutes.home,
                  )),
            ]);
          },
        ),
      );
}

class _HomeLayout {
  const _HomeLayout({
    required this.compact,
    required this.horizontalPadding,
    required this.topPadding,
    required this.maxContentWidth,
    required this.brandTopGap,
    required this.menuTopGap,
    required this.menuGap,
  });

  factory _HomeLayout.from(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final compact = width < 600;
    if (compact) {
      return const _HomeLayout(
        compact: true,
        horizontalPadding: 10,
        topPadding: 10,
        maxContentWidth: 520,
        brandTopGap: 18,
        menuTopGap: 18,
        menuGap: 8,
      );
    }
    if (width < 1000) {
      return const _HomeLayout(
        compact: false,
        horizontalPadding: 22,
        topPadding: 16,
        maxContentWidth: 680,
        brandTopGap: 34,
        menuTopGap: 24,
        menuGap: 11,
      );
    }
    return const _HomeLayout(
      compact: false,
      horizontalPadding: 28,
      topPadding: 18,
      maxContentWidth: 760,
      brandTopGap: 48,
      menuTopGap: 26,
      menuGap: 12,
    );
  }

  final bool compact;
  final double horizontalPadding;
  final double topPadding;
  final double maxContentWidth;
  final double brandTopGap;
  final double menuTopGap;
  final double menuGap;
}

class _HomeData {
  const _HomeData(
      {required this.name,
      required this.gold,
      required this.gems,
      required this.xp,
      required this.level});
  const _HomeData.demo()
      : name = 'Invocateur',
        gold = 1230,
        gems = 5,
        xp = 275,
        level = 1;
  final String name;
  final int gold, gems, xp, level;
}

class _TopBar extends StatelessWidget {
  const _TopBar(
      {required this.data,
      required this.local,
      required this.onProfile,
      required this.onShop,
      required this.onLogout});
  final _HomeData data;
  final bool local;
  final VoidCallback onProfile, onShop, onLogout;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final gap = compact ? 5.0 : 10.0;
          return Row(children: [
            Expanded(
              flex: compact ? 5 : 6,
              child: _Panel(
                child: InkWell(
                  onTap: onProfile,
                  child: Padding(
                    padding: EdgeInsets.all(compact ? 7 : 10),
                    child: Row(children: [
                      CircleAvatar(
                        radius: compact ? 18 : 27,
                        backgroundColor: const Color(0xFF6A2DA0),
                        child: Icon(Icons.person,
                            size: compact ? 22 : 35,
                            color: const Color(0xFFE2BCFF)),
                      ),
                      SizedBox(width: compact ? 6 : 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(data.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: compact ? 13 : 18,
                                    fontWeight: FontWeight.w800)),
                            Text('Niv. ${data.level}',
                                maxLines: 1,
                                style: TextStyle(
                                    fontSize: compact ? 10 : 14,
                                    color: const Color(0xFFC874FF))),
                            SizedBox(height: compact ? 3 : 5),
                            Row(children: [
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: (data.xp % 500) / 500,
                                  minHeight: compact ? 5 : 7,
                                  borderRadius: BorderRadius.circular(8),
                                  color: const Color(0xFFB65AF4),
                                  backgroundColor: const Color(0xFF332642),
                                ),
                              ),
                              if (!compact) ...[
                                const SizedBox(width: 7),
                                Text('${data.xp % 500}/500',
                                    style: const TextStyle(fontSize: 10)),
                              ],
                            ]),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              flex: 2,
              child: _Currency(
                  icon: Icons.monetization_on_rounded,
                  value: data.gold,
                  color: const Color(0xFFFFB829),
                  compact: compact,
                  onTap: onShop),
            ),
            SizedBox(width: gap),
            Expanded(
              flex: 2,
              child: _Currency(
                  icon: Icons.diamond_rounded,
                  value: data.gems,
                  color: const Color(0xFFD34FFF),
                  compact: compact,
                  onTap: onShop),
            ),
            if (!local) ...[
              SizedBox(width: gap),
              SizedBox(
                width: compact ? 36 : 48,
                child: _Panel(
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: 'Se déconnecter',
                    onPressed: onLogout,
                    icon: Icon(Icons.logout,
                        size: compact ? 18 : 24,
                        color: const Color(0xFFD59CFF)),
                  ),
                ),
              ),
            ],
          ]);
        },
      );
}

class _Brand extends StatelessWidget {
  const _Brand({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
            width: compact ? 82 : 116,
            height: compact ? 82 : 116,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(colors: [
                  Color(0xFFD984FF),
                  Color(0xFF6B20B2),
                  Color(0x00160A2D)
                ]),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFFB743F0).withValues(alpha: .7),
                      blurRadius: 36)
                ]),
            child: Icon(Icons.diamond_rounded,
                size: compact ? 52 : 72, color: const Color(0xFFF1D8FF))),
        SizedBox(height: compact ? 9 : 14),
        FittedBox(
            child: Text('MYSTICARTES',
                style: TextStyle(
                    fontSize: compact ? 32 : 42,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    fontFamily: 'serif'))),
        Text('Maîtrisez la magie. Dominez le destin.',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: const Color(0xFFC47AF3), fontSize: compact ? 12 : 16)),
      ]);
}

class _MenuButton extends StatelessWidget {
  const _MenuButton(
      {required this.icon,
      required this.title,
      required this.compact,
      required this.onTap,
      this.primary = false,
      super.key});
  final IconData icon;
  final String title;
  final bool compact;
  final VoidCallback onTap;
  final bool primary;
  @override
  Widget build(BuildContext context) => Material(
      color: Colors.transparent,
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 16 : 24,
              vertical: compact ? 13 : 18,
            ),
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: primary
                        ? const [Color(0xFFCD7AFF), Color(0xFF7431C3)]
                        : const [Color(0xEC2B1747), Color(0xEC17102A)]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: primary
                        ? const Color(0xFFF1C6FF)
                        : const Color(0xFF57336F),
                    width: primary ? 2 : 1),
                boxShadow: primary
                    ? [
                        BoxShadow(
                            color:
                                const Color(0xFFB84EFF).withValues(alpha: .45),
                            blurRadius: 22)
                      ]
                    : null),
            child: Row(children: [
              Icon(icon,
                  size: compact ? 32 : 42, color: const Color(0xFFF0D6FF)),
              SizedBox(width: compact ? 13 : 20),
              Expanded(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: compact ? 18 : 23,
                        fontWeight: FontWeight.w900)),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFDEB7F8)),
            ]),
          )));
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(
          color: const Color(0xDB11101F),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF45315D))),
      child: child);
}

class _Currency extends StatelessWidget {
  const _Currency(
      {required this.icon,
      required this.value,
      required this.color,
      required this.compact,
      required this.onTap});
  final IconData icon;
  final int value;
  final Color color;
  final bool compact;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => _Panel(
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: compact ? 4 : 12, vertical: compact ? 10 : 14),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, color: color, size: compact ? 19 : 27),
                SizedBox(width: compact ? 3 : 7),
                Text('$value',
                    style: TextStyle(
                        fontSize: compact ? 13 : 17,
                        fontWeight: FontWeight.w800)),
                SizedBox(width: compact ? 2 : 7),
                Icon(Icons.add,
                    size: compact ? 15 : 24, color: const Color(0xFFC875FF)),
              ]),
            ),
          )));
}

class _LocalNotice extends StatelessWidget {
  const _LocalNotice();
  @override
  Widget build(BuildContext context) => const _Panel(
          child: Padding(
        padding: EdgeInsets.all(12),
        child: Text(
            'MODE LOCAL V2 — aucun compte requis. Lancez un duel immédiatement.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFCBA6E7))),
      ));
}
