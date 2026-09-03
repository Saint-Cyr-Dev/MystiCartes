import 'package:flutter/material.dart';

import '../collection_card.dart';

class CardArtwork extends StatelessWidget {
  const CardArtwork({
    required this.card,
    this.placeholderIconSize = 48,
    super.key,
  });

  final CollectionCard card;
  final double placeholderIconSize;

  @override
  Widget build(BuildContext context) {
    final placeholder = _ArtworkPlaceholder(
      card: card,
      iconSize: placeholderIconSize,
    );
    final url = card.artUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _LocalArtwork(
          card: card,
          placeholder: placeholder,
        ),
      );
    }
    return _LocalArtwork(card: card, placeholder: placeholder);
  }
}

class _LocalArtwork extends StatelessWidget {
  const _LocalArtwork({required this.card, required this.placeholder});

  final CollectionCard card;
  final Widget placeholder;

  @override
  Widget build(BuildContext context) {
    final asset = card.localArtAsset;
    if (asset == null) return placeholder;
    return Image.asset(
      asset,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => placeholder,
    );
  }
}

class _ArtworkPlaceholder extends StatelessWidget {
  const _ArtworkPlaceholder({required this.card, required this.iconSize});

  final CollectionCard card;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: iconSize, color: colors.primary),
            const SizedBox(height: 8),
            Text(card.code, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}
