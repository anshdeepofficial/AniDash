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
    final isConsecutive = _lastTapTime != null &&
        now.difference(_lastTapTime!).inMilliseconds < 650 &&
        _lastTapForward == forward;

    _lastTapTime = now;
    _lastTapForward = forward;

    if (isConsecutive) {
      // 2nd, 3rd, 4th, 5th tap: Cancel single-tap, accumulate seek!
      _singleTapTimer?.cancel();
      _singleTapTimer = null;

      widget.onDoubleTap(forward);

      _multiTapResetTimer?.cancel();
      _multiTapResetTimer = Timer(const Duration(milliseconds: 650), () {
        _resetTapState();
      });
    } else {
      // 1st tap on left or right: wait briefly to distinguish single tap vs multi-tap
      _resetTapState();
      _lastTapTime = now;
      _lastTapForward = forward;

      _singleTapTimer = Timer(const Duration(milliseconds: 280), () {
        _resetTapState();
        widget.onTap();
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
        _resetTapState();
        widget.onVerticalDragStart?.call(details);
      },
      onVerticalDragUpdate: widget.onVerticalDragUpdate,
      onVerticalDragEnd: widget.onVerticalDragEnd,
      onHorizontalDragStart: (details) {
        _resetTapState();
        widget.onHorizontalDragStart?.call(details);
      },
      onHorizontalDragUpdate: widget.onHorizontalDragUpdate,
      onHorizontalDragEnd: widget.onHorizontalDragEnd,
      onLongPressUp: () {
        if (_isLongPressing) _onLongPressEnd(const LongPressEndDetails());
      },
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}
