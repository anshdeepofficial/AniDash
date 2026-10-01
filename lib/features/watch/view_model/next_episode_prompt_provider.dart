import 'package:flutter_riverpod/flutter_riverpod.dart';

final nextEpisodePromptProvider =
    NotifierProvider<NextEpisodePromptNotifier, bool>(
      NextEpisodePromptNotifier.new,
    );

class NextEpisodePromptNotifier extends Notifier<bool> {
  DateTime? _suppressedUntil;

  @override
  bool build() => false;

  void show() {
    final until = _suppressedUntil;
    if (until != null && DateTime.now().isBefore(until)) return;
    state = true;
  }

  void dismiss() => state = false;

  /// Prevents the finishing episode's final position event from immediately
  /// reopening the prompt while the next stream is being selected/opened.
  void dismissForEpisodeTransition() {
    _suppressedUntil = DateTime.now().add(const Duration(seconds: 5));
    state = false;
  }
}
