import 'package:flutter/material.dart';
import 'battle_backdrop.dart';

/// The bar is indeterminate: status reflects actual work, not a fake percentage.
class BattleLoadingView extends StatefulWidget {
  const BattleLoadingView(
      {super.key,
      required this.status,
      this.error,
      required this.onBack,
      required this.onRetry});
  final String status;
  final Object? error;
  final VoidCallback onBack, onRetry;
  @override
  State<BattleLoadingView> createState() => _BattleLoadingViewState();
}

class _BattleLoadingViewState extends State<BattleLoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400))
    ..repeat(reverse: true);
  final _pages = PageController();
  int _tip = 0;
  static const _tips = [
    'Certaines cartes deviennent plus puissantes lorsqu’elles sont jouées en combinaison.',
    'Ton deck principal contient 40 cartes. Les Mythiques attendent dans leur Réserve.',
    'Une invocation ou une pose normale par tour : choisis bien ton Personnage.',
    'En Défense, c’est la DEF de ta carte qui est comparée à l’ATK de l’attaquant.',
    'Le joueur qui commence ne peut pas attaquer pendant le tout premier tour.',
  ];
  static const _families = <(String, IconData, Color)>[
    ('Babi', Icons.directions_bus, Color(0xFFC99EFF)),
    ('Royaume', Icons.workspace_premium, Color(0xFFFFC460)),
    ('Ancêtre', Icons.park, Color(0xFF83B877)),
    ('Masque', Icons.theater_comedy, Color(0xFFD493AE)),
    ('Dozo', Icons.gps_fixed, Color(0xFFC78A68)),
    ('Forêt', Icons.forest, Color(0xFF5FAD7D)),
    ('Lagune', Icons.waves, Color(0xFF4ABDD9)),
    ('Savane', Icons.wb_sunny, Color(0xFFD3A257)),
    ('Village', Icons.cottage, Color(0xFFD89990)),
    ('Maquis', Icons.ramen_dining, Color(0xFFC8874E)),
  ];

  @override
  void dispose() {
    _glow.dispose();
    _pages.dispose();
    super.dispose();
  }

  void _changeTip(int delta) =>
      _pages.animateToPage((_tip + delta) % _tips.length,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);

  Widget _brand(bool compact) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedBuilder(
            animation: _glow,
            builder: (context, _) => Transform.scale(
                scale: 1 + _glow.value * .055,
                child: Container(
                    width: compact ? 86 : 155,
                    height: compact ? 86 : 155,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFAE72D9)),
                        gradient: const RadialGradient(colors: [
                          Color(0xFFD984FF),
                          Color(0xFF6B20B2),
                          Color(0x00160A2D)
                        ]),
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFFB743F0)
                                  .withValues(alpha: .3 + _glow.value * .3),
                              blurRadius: 36)
                        ]),
                    // Same diamond emblem and palette as the existing home menu.
                    child: Icon(Icons.diamond_rounded,
                        key: const Key('loading-mysticartes-logo'),
                        size: compact ? 52 : 86,
                        color: const Color(0xFFF1D8FF))))),
        const SizedBox(height: 7),
        FittedBox(
            child: Text('MYSTICARTES',
                style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: compact ? 28 : 40,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFF6E6FF),
                    shadows: const [
                      Shadow(color: Color(0xFF7A30A8), blurRadius: 16)
                    ]))),
        const SizedBox(height: 6),
        const Text('L’ART DU STRATÈGE',
            style: TextStyle(
                fontFamily: 'serif',
                fontSize: 11,
                letterSpacing: 3,
                color: Color(0xFFE2C797))),
      ]);

  Widget _loading(bool compact) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text(
            widget.error == null
                ? 'Chargement…'
                : 'Le duel ne peut pas être préparé.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: compact ? 20 : 25,
                fontWeight: FontWeight.w600,
                shadows: const [Shadow(color: Colors.black, blurRadius: 8)])),
        const SizedBox(height: 12),
        if (widget.error == null) ...[
          Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: const Color(0xFF211127),
                  border: Border.all(color: const Color(0xFFC38C3F), width: 2),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(color: Color(0x6664238D), blurRadius: 16)
                  ]),
              child: const ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  child: LinearProgressIndicator(
                      minHeight: 10,
                      color: Color(0xFFB34BFF),
                      backgroundColor: Color(0xFF29183B)))),
          const SizedBox(height: 10),
          Semantics(
              liveRegion: true,
              child: Text(widget.status,
                  key: const Key('battle-loading-status'),
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFFE0D7E7)))),
        ] else ...[
          Text('${widget.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFFD4BDDB))),
          const SizedBox(height: 8),
          FilledButton.icon(
              onPressed: widget.onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer')),
        ],
      ]);

  Widget _advice(bool compact) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          IconButton(
              key: const Key('loading-tip-previous'),
              tooltip: 'Conseil précédent',
              onPressed: () => _changeTip(-1),
              icon: const Icon(Icons.chevron_left, color: Color(0xFFC56BFF))),
          Expanded(
              child: Container(
            height: compact ? 98 : 114,
            decoration: BoxDecoration(
                color: const Color(0xE510101A),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF48334E))),
            child: PageView.builder(
                controller: _pages,
                itemCount: _tips.length,
                onPageChanged: (index) => setState(() => _tip = index),
                itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      if (!compact) ...[
                        const Icon(Icons.style_outlined,
                            color: Color(0xFFFFC44C), size: 34),
                        const SizedBox(width: 14)
                      ],
                      Expanded(
                          child: SingleChildScrollView(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                            const Text('Conseil',
                                style: TextStyle(
                                    color: Color(0xFFFFC44C),
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 5),
                            Text(_tips[index],
                                style: TextStyle(
                                    fontSize: compact ? 11 : 13,
                                    color: const Color(0xFFE0D6E4))),
                          ]))),
                    ]))),
          )),
          IconButton(
              key: const Key('loading-tip-next'),
              tooltip: 'Conseil suivant',
              onPressed: () => _changeTip(1),
              icon: const Icon(Icons.chevron_right, color: Color(0xFFC56BFF))),
        ]),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var index = 0; index < _tips.length; index++)
            AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == _tip
                        ? const Color(0xFFC04EFF)
                        : const Color(0xFF40304F))),
        ]),
      ]);

  Widget _footer(bool compact) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          for (final family in _families)
            Tooltip(
                message: family.$1,
                child:
                    Icon(family.$2, color: family.$3, size: compact ? 17 : 24)),
        ]),
        if (!compact) ...[
          const SizedBox(height: 12),
          const Text('DES CARTES. DES HISTOIRES. VOTRE LÉGENDE.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 2,
                  fontFamily: 'serif',
                  color: Color(0xFFD3C2B0)))
        ],
      ]);

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF060914),
        body: LayoutBuilder(builder: (context, constraints) {
          final landscape = constraints.maxWidth > constraints.maxHeight * 1.15;
          final compact =
              constraints.maxHeight < 720 || constraints.maxWidth < 360;
          return Stack(fit: StackFit.expand, children: [
            Image.asset(
                landscape
                    ? 'assets/images/backgrounds/loading-landscape-v2.png'
                    : 'assets/images/backgrounds/loading-portrait-v2.png',
                fit: BoxFit.cover,
                alignment:
                    landscape ? Alignment.center : const Alignment(0, -.2),
                errorBuilder: (_, __, ___) => const BattleBackdrop()),
            const DecoratedBox(
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [
                  0,
                  .35,
                  .65,
                  1
                ],
                        colors: [
                  Color(0x55060A17),
                  Colors.transparent,
                  Color(0x55050812),
                  Color(0xFF040710)
                ]))),
            SafeArea(
                child: Padding(
                    padding: EdgeInsets.all(compact ? 12 : 24),
                    child: Column(children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                                key: const Key('battle-loading-back'),
                                tooltip: 'Retour',
                                onPressed: widget.onBack,
                                icon: const Icon(Icons.arrow_back_rounded)),
                            const Flexible(
                                child: Text('STRATÉGIE · RÉFLEXION · PASSION',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontFamily: 'serif',
                                        letterSpacing: 1,
                                        color: Color(0xFFD3C6D7)))),
                          ]),
                      Expanded(
                          child: landscape
                              ? Center(
                                  child: ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxWidth: 1000),
                                      child: Row(children: [
                                        Expanded(child: _brand(compact)),
                                        const SizedBox(width: 32),
                                        Expanded(
                                            child: SingleChildScrollView(
                                                child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                              _loading(compact),
                                              const SizedBox(height: 20),
                                              _advice(compact)
                                            ])))
                                      ])))
                              : Column(children: [
                                  _brand(compact),
                                  const Spacer(flex: 3),
                                  if (!compact) ...[
                                    const Text(
                                        'Plus qu’un jeu,\nune mémoire en mouvement.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontFamily: 'serif',
                                            fontStyle: FontStyle.italic,
                                            fontSize: 17,
                                            color: Color(0xFFEAE1DC))),
                                    const Spacer()
                                  ],
                                  ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxWidth: 620),
                                      child: _loading(compact)),
                                  SizedBox(height: compact ? 16 : 24),
                                  ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxWidth: 680),
                                      child: _advice(compact)),
                                  const Spacer(),
                                ])),
                      SizedBox(height: compact ? 8 : 14),
                      ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 680),
                          child: _footer(compact)),
                    ]))),
          ]);
        }),
      );
}
