import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:ani_dash/core/hindi_sources/models/hindi_source_model.dart';

class HindiProviderIcon extends StatelessWidget {
  final HindiSourceModel source;
  final double size;
  final double borderRadius;

  const HindiProviderIcon({
    super.key,
    required this.source,
    this.size = 36,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Widget fallbackWidget() {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Text(
          source.fallbackInitials,
          style: TextStyle(
            color: colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w900,
            fontSize: size * 0.38,
            letterSpacing: -0.5,
          ),
        ),
      );
    }

    if (source.hasLocalAsset) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          source.localAssetPath,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallbackWidget(),
        ),
      );
    }

    if (source.logoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: CachedNetworkImage(
          imageUrl: source.logoUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => fallbackWidget(),
          placeholder: (_, __) => Container(
            width: size,
            height: size,
            color: colorScheme.surfaceContainerHighest,
          ),
        ),
      );
    }

    return fallbackWidget();
  }
}
