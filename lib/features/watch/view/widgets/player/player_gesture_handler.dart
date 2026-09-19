import 'dart:async';
import 'package:flutter/material.dart';

class PlayerGestureHandler extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Function(bool isForward) onDoubleTap;
  final VoidCallback onLongPressStart;
  final Function(double diff) onLongPressUpdate;
  final VoidCallback onLongPressEnd;
  final VoidCallback? onEpisodesPressed;

  const PlayerGestureHandler({
    super.key,
    required this.child,
    required this.onTap,
    required this.onDoubleTap,
    required this.onLongPressStart,
    required this.onLongPressUpdate,
    required this.onLongPressEnd,
    required this.onEpisodesPressed,
    this.onVerticalDragStart,
    this.onVerticalDragUpdate,
    this.onVerticalDragEnd,
    this.onHorizontalDragStart,
    this.onHorizontalDragUpdate,
    this.onHorizontalDragEnd,
  });

  final Function(DragStartDetails)? onVerticalDragStart;
  final Function(DragUpdateDetails)? onVerticalDragUpdate;
  final Function(DragEndDetails)? onVerticalDragEnd;

  final Function(DragStartDetails)? onHorizontalDragStart;
  final Function(DragUpdateDetails)? onHorizontalDragUpdate;
  final Function(DragEndDetails)? onHorizontalDragEnd;

  @override
  State<PlayerGestureHandler> createState() => _PlayerGestureHandlerState();
}

class _PlayerGestureHandlerState extends State<PlayerGestureHandler> {
  double _dragStartY = 0.0;
  bool _isLongPressing = false;

  Timer? _singleTapTimer;
  Timer? _multiTapResetTimer;
  bool? _lastTapForward;
  DateTime? _lastTapTime;
  bool _isSeekingSequence = false;

  @override
  void dispose() {
    _singleTapTimer?.cancel();
    _multiTapResetTimer?.cancel();
    super.dispose();
  }

  void _resetTapState() {
    _singleTapTimer?.cancel();
    _singleTapTimer = null;
    _multiTapResetTimer?.cancel();
    _multiTapResetTimer = null;
    _lastTapForward = null;
    _lastTapTime = null;
    _isSeekingSequence = false;
  }

  void _handleTapUp(TapUpDetails details) {
    if (_isLongPressing) return;

    final w = MediaQuery.of(context).size.width;
    final dx = details.globalPosition.dx;
    final now = DateTime.now();

    final isRight = dx > (w * 0.55);
    final isLeft = dx < (w * 0.45);
    final isCenter = !isRight && !isLeft;

    if (isCenter) {
      _resetTapState();
      widget.onTap();
      return;
    }

    final forward = isRight;

    // If an active multi-tap seek sequence is already underway on the same side:
    // Every additional tap (3rd, 4th, 5th...) immediately accumulates seek!
    if (_isSeekingSequence && _lastTapForward == forward) {
      _lastTapTime = now;
      widget.onDoubleTap(forward);

      _multiTapResetTimer?.cancel();
      _multiTapResetTimer = Timer(const Duration(milliseconds: 850), () {
        _resetTapState();
      });
      return;
    }

    // Check if this tap qualifies as Tap 2 (double tap) on the same side
    final isConsecutive = _lastTapTime != null &&
        now.difference(_lastTapTime!).inMilliseconds < 500 &&
        _lastTapForward == forward;

    if (isConsecutive) {
      // Tap 2: Cancel pending single-tap and activate multi-tap seeking sequence!
      _singleTapTimer?.cancel();
      _singleTapTimer = null;
      _isSeekingSequence = true;
      _lastTapTime = now;
      _lastTapForward = forward;

      widget.onDoubleTap(forward);

      _multiTapResetTimer?.cancel();
      _multiTapResetTimer = Timer(const Duration(milliseconds: 850), () {
        _resetTapState();
      });
    } else {
      // Tap 1: Wait briefly to disambiguate single tap vs start of double tap
      _resetTapState();
      _lastTapTime = now;
      _lastTapForward = forward;

      _singleTapTimer = Timer(const Duration(milliseconds: 280), () {
        _singleTapTimer = null;
        if (!_isSeekingSequence) {
          _lastTapTime = null;
          _lastTapForward = null;
          widget.onTap();
        }
      });
    }
  }

  void _onLongPressStart(LongPressStartDetails details) {
    _resetTapState();
    if (details.globalPosition.dx > MediaQuery.of(context).size.width / 2) {
      _isLongPressing = true;
      _dragStartY = details.globalPosition.dy;
      widget.onLongPressStart();
    }
  }

  void _onLongPressUpdate(LongPressMoveUpdateDetails details) {
    if (_isLongPressing) {
      final diff = _dragStartY - details.globalPosition.dy;
      widget.onLongPressUpdate(diff);
    }
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (_isLongPressing) {
      _isLongPressing = false;
      widget.onLongPressEnd();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapUp: _handleTapUp,
      onSecondaryTap: widget.onEpisodesPressed,
      onLongPressStart: _onLongPressStart,
      onLongPressMoveUpdate: _onLongPressUpdate,
      onLongPressEnd: _onLongPressEnd,
      onVerticalDragStart: (details) {
        if (_isSeekingSequence) return;
        _resetTapState();
        widget.onVerticalDragStart?.call(details);
      },
      onVerticalDragUpdate: (details) {
        if (_isSeekingSequence) return;
        widget.onVerticalDragUpdate?.call(details);
      },
      onVerticalDragEnd: (details) {
        if (_isSeekingSequence) return;
        widget.onVerticalDragEnd?.call(details);
      },
      onHorizontalDragStart: (details) {
        if (_isSeekingSequence) return;
        _resetTapState();
        widget.onHorizontalDragStart?.call(details);
      },
      onHorizontalDragUpdate: (details) {
        if (_isSeekingSequence) return;
        widget.onHorizontalDragUpdate?.call(details);
      },
      onHorizontalDragEnd: (details) {
        if (_isSeekingSequence) return;
        widget.onHorizontalDragEnd?.call(details);
      },
      onLongPressUp: () {
        if (_isLongPressing) _onLongPressEnd(const LongPressEndDetails());
      },
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}
