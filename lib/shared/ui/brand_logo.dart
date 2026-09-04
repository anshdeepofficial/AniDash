import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  final double size;
  final BorderRadius? borderRadius;

  const BrandLogo({super.key, this.size = 40, this.borderRadius});

  @override
  Widget build(BuildContext context) {
    final asset =
        Theme.of(context).brightness == Brightness.dark
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
