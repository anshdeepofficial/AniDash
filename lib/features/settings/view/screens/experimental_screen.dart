import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:ani_dash/shared/providers/settings/experimental_notifier.dart';
import 'package:ani_dash/features/settings/view/widgets/settings_item.dart';

class ExperimentalScreen extends ConsumerWidget {
  const ExperimentalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final experimentalSettings = ref.watch(experimentalProvider);
    final experimentalNotifier = ref.read(experimentalProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton.filledTonal(
          onPressed: () => context.pop(),
          icon: const Icon(Iconsax.arrow_left_2),
        ),
        title: const Text('Experimental Features'),
        forceMaterialTransparency: true,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(10, 5, 10, 10),
        child: ListView(
          children: [
            ToggleableSettingsItem(
              accent: colorScheme.primary,
              icon: const Icon(Icons.replay_outlined),
              title: 'Episode Title Sync',
              description: 'Sync episode titles using JIKAN API',
              value: experimentalSettings.episodeTitleSync,
              onChanged: (value) {
                experimentalNotifier.updateSettings(
                  (state) => state.copyWith(episodeTitleSync: value),
                );
              },
            ),
            const SizedBox(height: 8),
            ToggleableSettingsItem(
              accent: colorScheme.primary,
              icon: const Icon(Icons.upcoming_rounded),
              title: 'New UI (ALPHA)',
              description: 'Modern redesigned user interface',
              value: experimentalSettings.newUI,
              onChanged: (value) {
                experimentalNotifier.updateSettings(
                  (state) => state.copyWith(newUI: value),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
