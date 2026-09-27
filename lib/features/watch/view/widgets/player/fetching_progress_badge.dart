import 'package:flutter/material.dart';

/// An honest indeterminate loader. Stream extraction and buffering do not
/// expose a measurable percentage, so displaying a simulated value (for
/// example 94%) incorrectly makes a healthy network wait look frozen.
class FetchingProgressBadge extends StatelessWidget {
  final String? title;
  final bool isEpisode;

  const FetchingProgressBadge({super.key, this.title, this.isEpisode = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 48,
        height: 48,
        child: CircularProgressIndicator(
          strokeWidth: 3.5,
          color: Theme.of(context).colorScheme.primary,
          backgroundColor: Colors.white24,
          strokeCap: StrokeCap.round,
        ),
      ),
    );
  }
}
