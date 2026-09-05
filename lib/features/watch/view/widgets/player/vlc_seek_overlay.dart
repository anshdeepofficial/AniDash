import 'package:flutter/material.dart';

class VlcSeekOverlay extends StatelessWidget {
  final Duration targetPosition;
  final Duration totalDuration;
  final Duration diffDuration;
  final bool isForward;

  const VlcSeekOverlay({
    super.key,
    required this.targetPosition,
    required this.totalDuration,
    required this.diffDuration,
    required this.isForward,
  });

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatDiff(Duration d) {
    final totalSeconds = d.inSeconds.abs();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final sign = isForward ? '+' : '-';
    if (minutes > 0) {
      return '$sign${minutes}m ${seconds}s';
    }
    return '$sign${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final progress = totalDuration.inMilliseconds > 0
        ? (targetPosition.inMilliseconds / totalDuration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (isForward ? Colors.cyanAccent : Colors.orangeAccent).withValues(alpha: 0.7),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isForward ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
                  color: isForward ? Colors.cyanAccent : Colors.orangeAccent,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Text(
                  _formatDiff(diffDuration),
                  style: TextStyle(
                    color: isForward ? Colors.cyanAccent : Colors.orangeAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatDuration(targetPosition),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (totalDuration > Duration.zero) ...[
                  Text(
                    ' / ${_formatDuration(totalDuration)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 180,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isForward ? Colors.cyanAccent : Colors.orangeAccent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
