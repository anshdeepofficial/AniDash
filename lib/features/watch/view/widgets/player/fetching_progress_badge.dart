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

  @override
  void initState() {
    super.initState();
    _startProgressSimulation();
  }

  void _startProgressSimulation() {
    _timer = Timer.periodic(const Duration(milliseconds: 350), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_progress < 30) {
          _progress += 8;
        } else if (_progress < 60) {
          _progress += 6;
        } else if (_progress < 85) {
          _progress += 4;
        } else if (_progress < 98) {
          _progress += 1;
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

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              value: _progress / 100.0,
              strokeWidth: 3.5,
              color: colorScheme.primary,
              backgroundColor: Colors.white24,
              strokeCap: StrokeCap.round,
            ),
          ),
          Text(
            '$_progress%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(color: Colors.black87, blurRadius: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

