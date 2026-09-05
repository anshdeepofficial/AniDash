import 'dart:async';
import 'package:flutter/material.dart';

class FetchingProgressBadge extends StatefulWidget {
  final String? title;
  final bool isEpisode;

  const FetchingProgressBadge({
    super.key,
    this.title,
    this.isEpisode = false,
  });

  @override
  State<FetchingProgressBadge> createState() => _FetchingProgressBadgeState();
}

class _FetchingProgressBadgeState extends State<FetchingProgressBadge> {
  int _progress = 12;
  Timer? _timer;
  int _step = 0;

  final List<String> _sourceSteps = [
    'Connecting to video source...',
    'Extracting stream servers...',
    'Resolving HLS quality playlists...',
    'Buffering media pipeline...',
  ];

  final List<String> _episodeSteps = [
    'Connecting to database...',
    'Fetching episode list...',
    'Syncing watch progress...',
    'Loading episodes...',
  ];

  @override
  void initState() {
    super.initState();
    _startProgressSimulation();
  }

  void _startProgressSimulation() {
    _timer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_progress < 30) {
          _progress += 8;
          _step = 0;
        } else if (_progress < 60) {
          _progress += 6;
          _step = 1;
        } else if (_progress < 85) {
          _progress += 4;
          _step = 2;
        } else if (_progress < 98) {
          _progress += 1;
          _step = 3;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final steps = widget.isEpisode ? _episodeSteps : _sourceSteps;
    final statusText = widget.title ?? steps[_step.clamp(0, steps.length - 1)];

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.4),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 58,
                  height: 58,
                  child: CircularProgressIndicator(
                    value: _progress / 100.0,
                    strokeWidth: 4.0,
                    color: colorScheme.primary,
                    backgroundColor: Colors.white12,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Text(
                  '$_progress%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              statusText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
