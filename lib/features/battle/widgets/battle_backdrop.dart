import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Full-bleed artwork, chosen for the available viewport rather than device type.
/// The gameplay layer may scale independently; this layer always fills its parent.
class BattleBackdrop extends StatelessWidget {
  const BattleBackdrop({super.key});

  static const legacyAsset = 'assets/images/backgrounds/battle-board.png';

  static const _variants = <({double ratio, String asset})>[
    (ratio: .5, asset: 'assets/images/backgrounds/battle-portrait-v2.png'),
    (ratio: 1, asset: 'assets/images/backgrounds/battle-square-v2.png'),
    (ratio: 1.5, asset: 'assets/images/backgrounds/battle-landscape-v2.png'),
    (ratio: 2.25, asset: 'assets/images/backgrounds/battle-ultrawide-v2.png'),
  ];

  /// Comparing logarithms minimizes the proportional crop required by cover.
  /// Transitions are at ratios ~0.707, 1.225 and 1.837 (geometric midpoints).
  static String assetForSize(Size size) {
    if (size.width <= 0 || size.height <= 0 || !size.isFinite) {
      return _variants[1].asset;
    }
    final ratio = size.width / size.height;
    return _variants.reduce((best, candidate) {
      final bestDistance = math.log(ratio / best.ratio).abs();
      final candidateDistance = math.log(ratio / candidate.ratio).abs();
      return candidateDistance < bestDistance ? candidate : best;
    }).asset;
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: LayoutBuilder(
          builder: (context, constraints) => SizedBox.expand(
            key: const Key('battle-backdrop'),
            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Color(0xFF070611)),
                  Image.asset(
                    assetForSize(constraints.biggest),
                    key: const Key('battle-backdrop-image'),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (context, error, stackTrace) => Image.asset(
                      legacyAsset,
                      key: const Key('battle-backdrop-legacy'),
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.expand(),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x45080615),
                          Color(0x20160929),
                          Color(0x7504050E),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
