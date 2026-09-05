import 'package:flutter_riverpod/flutter_riverpod.dart';

final nextEpisodePromptProvider =
    NotifierProvider<NextEpisodePromptNotifier, bool>(
  NextEpisodePromptNotifier.new,
);

class NextEpisodePromptNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void show() => state = true;
  void dismiss() => state = false;
}
