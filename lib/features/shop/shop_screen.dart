import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../app/mystic_navigation.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF070814),
        appBar: AppBar(
          backgroundColor: const Color(0xFF090A18),
          surfaceTintColor: Colors.transparent,
          title:
              const Text('SHOP', style: TextStyle(fontWeight: FontWeight.w900)),
        ),
        bottomNavigationBar: const MysticBottomNavigation(
          currentRoute: AppRoutes.shop,
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.25,
              colors: [Color(0xFF32105A), Color(0xFF070814)],
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xDF141224),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF6E3B91)),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shopping_bag_rounded,
                        size: 72, color: Color(0xFFD59CFF)),
                    SizedBox(height: 18),
                    Text('La boutique se prépare',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w900)),
                    SizedBox(height: 10),
                    Text(
                      'Les packs et objets arriveront bientôt. Vos pièces et gemmes sont déjà conservées sur votre compte.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFFD0BEDD), height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
