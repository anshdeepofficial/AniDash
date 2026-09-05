import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PinLockDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool isCreating;
  final bool Function(String pin)? onVerify;
  final void Function(String pin)? onCreated;
  final VoidCallback? onCancel;

  const PinLockDialog({
    super.key,
    required this.title,
    this.subtitle = 'Enter your 4-digit PIN',
    this.isCreating = false,
    this.onVerify,
    this.onCreated,
    this.onCancel,
  });

  static Future<bool> showUnlock({
    required BuildContext context,
    required String title,
    required bool Function(String pin) onVerify,
  }) async {
    final res = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PopScope(
        canPop: false,
        child: PinLockDialog(
          title: title,
          onVerify: onVerify,
          onCancel: () => Navigator.pop(context, false),
        ),
      ),
    );
    return res ?? false;
  }

  static Future<String?> showSetup({
    required BuildContext context,
    required String title,
  }) async {
    String? createdPin;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PinLockDialog(
        title: title,
        subtitle: 'Enter a 4-digit PIN to secure access',
        isCreating: true,
        onCreated: (pin) {
          createdPin = pin;
          Navigator.pop(context);
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
    return createdPin;
  }

  @override
  State<PinLockDialog> createState() => _PinLockDialogState();
}

class _PinLockDialogState extends State<PinLockDialog>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  String? _firstPin;
  bool _hasError = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 12.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onDigit(String d) {
    if (_pin.length >= 4) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pin += d;
      _hasError = false;
    });

    if (_pin.length == 4) {
      _handleSubmit();
    }
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _hasError = false;
    });
  }

  void _handleSubmit() async {
    if (widget.isCreating) {
      if (_firstPin == null) {
        setState(() {
          _firstPin = _pin;
          _pin = '';
        });
      } else {
        if (_pin == _firstPin) {
          HapticFeedback.mediumImpact();
          widget.onCreated?.call(_pin);
        } else {
          _triggerError();
          setState(() {
            _pin = '';
            _firstPin = null;
          });
        }
      }
    } else {
      final valid = widget.onVerify?.call(_pin) ?? false;
      if (valid) {
        HapticFeedback.mediumImpact();
        Navigator.pop(context, true);
      } else {
        _triggerError();
      }
    }
  }

  void _triggerError() {
    HapticFeedback.heavyImpact();
    setState(() {
      _hasError = true;
      _pin = '';
    });
    _shakeController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final subtitleText = widget.isCreating
        ? (_firstPin == null ? 'Enter a 4-digit PIN' : 'Confirm your 4-digit PIN')
        : (_hasError ? 'Incorrect PIN. Try again.' : widget.subtitle);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (widget.onCancel != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: widget.onCancel,
                  )
                else
                  const SizedBox(width: 48),
                Text(
                  widget.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitleText,
              style: TextStyle(
                color: _hasError ? Colors.redAccent : colorScheme.onSurfaceVariant,
                fontSize: 13,
                fontWeight: _hasError ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 24),
            // Pin Dots
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                    _shakeController.isAnimating
                        ? (_shakeAnimation.value * (1 - _shakeController.value))
                        : 0,
                    0,
                  ),
                  child: child,
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final filled = index < _pin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled
                          ? (_hasError ? Colors.redAccent : colorScheme.primary)
                          : colorScheme.surfaceContainerHighest,
                      border: Border.all(
                        color: _hasError
                            ? Colors.redAccent
                            : colorScheme.outlineVariant,
                        width: 1.5,
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 32),
            // Keypad
            _buildKeypad(colorScheme),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad(ColorScheme colorScheme) {
    return Column(
      children: [
        for (int r = 0; r < 3; r++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (int c = 1; c <= 3; c++)
                  _buildKey('${r * 3 + c}', colorScheme),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const SizedBox(width: 72, height: 72),
              _buildKey('0', colorScheme),
              InkWell(
                onTap: _onDelete,
                borderRadius: BorderRadius.circular(36),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: Icon(
                    Icons.backspace_outlined,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKey(String label, ColorScheme colorScheme) {
    return InkWell(
      onTap: () => _onDigit(label),
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
