import 'package:flutter/material.dart';

import 'app_routes.dart';

class MysticBottomNavigation extends StatelessWidget {
  const MysticBottomNavigation({required this.currentRoute, super.key});

  final String currentRoute;

  static const _routes = [
    AppRoutes.home,
    AppRoutes.collection,
    AppRoutes.decks,
    AppRoutes.shop,
    AppRoutes.settings,
  ];

  void _navigate(BuildContext context, int index) {
    final route = _routes[index];
    if (route == currentRoute) return;
    Navigator.pushReplacementNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _routes.indexOf(currentRoute).clamp(0, 4);
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        decoration: BoxDecoration(
          color: const Color(0xF2121020),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF493160)),
          boxShadow: const [
            BoxShadow(color: Color(0x66000000), blurRadius: 18),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) => _navigate(context, index),
          backgroundColor: Colors.transparent,
          indicatorColor: const Color(0xFF442166),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_rounded), label: 'Accueil'),
            NavigationDestination(
                icon: Icon(Icons.menu_book_rounded), label: 'Bibliothèque'),
            NavigationDestination(
                icon: Icon(Icons.style_rounded), label: 'Decks'),
            NavigationDestination(
                icon: Icon(Icons.shopping_cart_rounded), label: 'Shop'),
            NavigationDestination(
                icon: Icon(Icons.more_horiz_rounded), label: 'Plus'),
          ],
        ),
      ),
    );
  }
}
