import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ani_dash/core/services/biometric_service.dart';

class PinLockDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool isCreating;
  final bool enableBiometrics;
  final bool Function(String pin)? onVerify;
  final void Function(String pin)? onCreated;
  final VoidCallback? onBiometricSuccess;
  final VoidCallback? onCancel;
  final int credentialLength;
  final bool allowLetters;

  const PinLockDialog({
    super.key,
    required this.title,
    this.subtitle = 'Enter your 4-digit PIN',
    this.isCreating = false,
    this.enableBiometrics = false,
    this.onVerify,
    this.onCreated,
    this.onBiometricSuccess,
    this.onCancel,
    this.credentialLength = 4,
    this.allowLetters = false,
  });

  static Future<bool> showUnlock({
    required BuildContext context,
    required String title,
    required bool Function(String pin) onVerify,
    bool enableBiometrics = false,
    VoidCallback? onBiometricSuccess,
    int credentialLength = 4,
    bool allowLetters = false,
  }) async {
    final res = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => PopScope(
            canPop: false,
            child: PinLockDialog(
              title: title,
              onVerify: onVerify,
              enableBiometrics: enableBiometrics,
              onBiometricSuccess: onBiometricSuccess,
              onCancel: () => Navigator.pop(context, false),
              credentialLength: credentialLength,
              allowLetters: allowLetters,
            ),
          ),
    );
    return res ?? false;
  }

  static Future<String?> showSetup({
    required BuildContext context,
    required String title,
    int credentialLength = 4,
    bool allowLetters = false,
  }) async {
    String? createdPin;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => PinLockDialog(
            title: title,
            subtitle: 'Enter a 4-digit PIN to secure access',
            isCreating: true,
            onCreated: (pin) {
              createdPin = pin;
              Navigator.pop(context);
            },
            onCancel: () => Navigator.pop(context),
            credentialLength: credentialLength,
            allowLetters: allowLetters,
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
  final TextEditingController _passwordController = TextEditingController();
  String? _firstPin;
  bool _hasError = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  static const List<Map<String, String>> _animeQuotes = [
    {
      'quote': 'I am gonna be the King of the Pirates!',
      'character': 'Monkey D. Luffy',
      'anime': 'One Piece',
    },
    {
      'quote': 'Believe it! My ninja way never wavers!',
      'character': 'Naruto Uzumaki',
      'anime': 'Naruto',
    },
    {
      'quote': 'Dedicate your heart! Shinzou wo Sasageyo!',
      'character': 'Erwin Smith',
      'anime': 'Attack on Titan',
    },
    {
      'quote': 'If you do not take risks, you can not create a future.',
      'character': 'Monkey D. Luffy',
      'anime': 'One Piece',
    },
    {
      'quote': 'Throughout heaven and earth, I alone am the honored one.',
      'character': 'Satoru Gojo',
      'anime': 'Jujutsu Kaisen',
    },
    {
      'quote': 'Set your heart ablaze! Surpass your limits!',
      'character': 'Kyojuro Rengoku',
      'anime': 'Demon Slayer',
    },
    {
      'quote': 'Even if I die, I will never give up!',
      'character': 'Tanjiro Kamado',
      'anime': 'Demon Slayer',
    },
    {
      'quote': 'Plus Ultra! Go beyond!',
      'character': 'All Might',
      'anime': 'My Hero Academia',
    },
    {
      'quote': 'Power comes in response to a need, not a desire.',
      'character': 'Goku',
      'anime': 'Dragon Ball Z',
    },
    {
      'quote': 'Wake up to reality! Nothing ever goes as planned.',
      'character': 'Madara Uchiha',
      'anime': 'Naruto Shippuden',
    },
    {
      'quote': 'Surpass your limits. Right here, right now.',
      'character': 'Yami Sukehiro',
      'anime': 'Black Clover',
    },
  ];

  late Map<String, String> _currentQuote;
  int _quoteIndex = 0;

  @override
  void initState() {
    super.initState();
    _quoteIndex = math.Random().nextInt(_animeQuotes.length);
    _currentQuote = _animeQuotes[_quoteIndex];

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 12.0,
    ).chain(CurveTween(curve: Curves.elasticIn)).animate(_shakeController);

    // Keep portrait lock while PIN dialog is active
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    if (widget.enableBiometrics && !widget.isCreating) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted) _triggerBiometrics();
        });
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _shakeController.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  void _nextQuote() {
    setState(() {
      _quoteIndex = (_quoteIndex + 1) % _animeQuotes.length;
      _currentQuote = _animeQuotes[_quoteIndex];
    });
    HapticFeedback.lightImpact();
  }

  void _triggerBiometrics() async {
    if (!mounted || widget.isCreating || !widget.enableBiometrics) return;
    final success = await BiometricService.authenticate(
      reason: 'Authenticate with Fingerprint or Face to unlock',
    );
    if (success && mounted) {
      HapticFeedback.mediumImpact();
      if (widget.onBiometricSuccess != null) {
        widget.onBiometricSuccess!();
      } else {
        Navigator.pop(context, true);
      }
    }
  }

  void _onDigit(String d) {
    if (_pin.length >= widget.credentialLength) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pin += d;
      _hasError = false;
    });

    if (_pin.length == widget.credentialLength) {
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
          _passwordController.clear();
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
          _passwordController.clear();
        }
      }
    } else {
      final valid = widget.onVerify?.call(_pin) ?? false;
      if (valid) {
        HapticFeedback.mediumImpact();
        if (widget.onBiometricSuccess != null) {
          widget.onBiometricSuccess!();
        } else {
          Navigator.pop(context, true);
        }
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
    final subtitleText =
        widget.isCreating
            ? (_firstPin == null
                ? 'Enter your credential'
                : 'Confirm your credential')
            : (_hasError ? 'Incorrect PIN. Try again.' : widget.subtitle);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Top Bar
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

            const SizedBox(height: 12),

            // Anime Slogan Card in upper space
            GestureDetector(
              onTap: _nextQuote,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.format_quote_rounded,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'DAILY ANIME SLOGAN',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '“${_currentQuote['quote']}”',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '— ${_currentQuote['character']} (${_currentQuote['anime']})',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Subtitle and Status
            Text(
              subtitleText,
              style: TextStyle(
                color:
                    _hasError ? Colors.redAccent : colorScheme.onSurfaceVariant,
                fontSize: 13,
                fontWeight: _hasError ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 20),

            // PIN/pattern dots or an alphanumeric password field.
            if (widget.allowLetters)
              TextField(
                controller: _passwordController,
                obscureText: true,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onChanged: (value) => _pin = value,
                onSubmitted: (_) {
                  if (_pin.length >= 4) _handleSubmit();
                },
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              )
            else
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(
                      _shakeController.isAnimating
                          ? (_shakeAnimation.value *
                              (1 - _shakeController.value))
                          : 0,
                      0,
                    ),
                    child: child,
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.credentialLength, (index) {
                    final filled = index < _pin.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            filled
                                ? (_hasError
                                    ? Colors.redAccent
                                    : colorScheme.primary)
                                : colorScheme.surfaceContainerHighest,
                        border: Border.all(
                          color:
                              _hasError
                                  ? Colors.redAccent
                                  : colorScheme.outlineVariant,
                          width: 1.5,
                        ),
                      ),
                    );
                  }),
                ),
              ),

            const Spacer(),

            if (widget.allowLetters)
              FilledButton(
                onPressed: _pin.length >= 4 ? _handleSubmit : null,
                child: Text(widget.isCreating ? 'Continue' : 'Unlock'),
              )
            else
              _buildKeypad(colorScheme),
            const SizedBox(height: 16),
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
              // Left button: Biometric or empty
              if (widget.enableBiometrics && !widget.isCreating)
                InkWell(
                  onTap: _triggerBiometrics,
                  borderRadius: BorderRadius.circular(36),
                  child: Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.primary.withValues(alpha: 0.15),
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.fingerprint_rounded,
                      color: colorScheme.primary,
                      size: 32,
                    ),
                  ),
                )
              else
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
