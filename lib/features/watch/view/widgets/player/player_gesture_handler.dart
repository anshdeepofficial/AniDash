import 'package:flutter/material.dart';

class PlayerGestureHandler extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback onLongPressStart;
  final Function(double diff) onLongPressUpdate;
  final VoidCallback onLongPressEnd;
  final VoidCallback? onEpisodesPressed;

  const PlayerGestureHandler({
    super.key,
    required this.child,
    required this.onTap,
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

  void _handleTapUp(TapUpDetails details) {
    if (_isLongPressing) return;
    widget.onTap();
  }

  void _onLongPressStart(LongPressStartDetails details) {
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
        widget.onVerticalDragStart?.call(details);
      },
      onVerticalDragUpdate: (details) {
        widget.onVerticalDragUpdate?.call(details);
      },
      onVerticalDragEnd: (details) {
        widget.onVerticalDragEnd?.call(details);
      },
      onHorizontalDragStart: (details) {
        widget.onHorizontalDragStart?.call(details);
      },
      onHorizontalDragUpdate: (details) {
        widget.onHorizontalDragUpdate?.call(details);
      },
      onHorizontalDragEnd: (details) {
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
