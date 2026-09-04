import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ani_dash/shared/providers/settings/theme_notifier.dart';

class BrandLogo extends ConsumerWidget {
  final double size;
  final BorderRadius? borderRadius;

  const BrandLogo({super.key, this.size = 40, this.borderRadius});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeSettingsProvider.select((s) => s.logoMode));
    final isDark = Theme.of(context).brightness == Brightness.dark ||
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final useWhite =
        mode == 'white' ||
        (mode == 'dynamic' && isDark) ||
        (mode != 'black' && isDark);
    final asset =
        useWhite
            ? 'assets/icons/anidash_logo_dark.png'
            : 'assets/icons/anidash_logo_light.png';

    final image = Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.cover,
      semanticLabel: 'AniDash logo',
    );

    return borderRadius == null
        ? image
        : ClipRRect(borderRadius: borderRadius!, child: image);
  }
}
