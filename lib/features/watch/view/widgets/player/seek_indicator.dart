import 'package:flutter/material.dart';

class SeekIndicatorOverlay extends StatelessWidget {
  final bool isForward;
  final int seconds;

  const SeekIndicatorOverlay({
    super.key,
    required this.isForward,
    required this.seconds,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width / 2,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.5),
          ],
          begin: isForward ? Alignment.centerLeft : Alignment.centerRight,
          end: isForward ? Alignment.centerRight : Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.horizontal(
          left: isForward ? const Radius.circular(100) : Radius.zero,
          right: isForward ? Radius.zero : const Radius.circular(100),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isForward
                ? Icons.fast_forward_rounded
                : Icons.fast_rewind_rounded,
            color: Colors.white,
            size: 46,
          ),
          const SizedBox(height: 8),
          Text(
            '${isForward ? '+' : '-'}${seconds}s',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
