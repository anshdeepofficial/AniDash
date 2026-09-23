import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';
import 'package:ani_dash/core/hindi_sources/hindi_source_manager.dart';
import 'package:ani_dash/core/hindi_sources/models/hindi_source_model.dart';
import 'package:ani_dash/core/hindi_sources/hindi_source_preferences.dart';

class HindiSourcesScreen extends ConsumerStatefulWidget {
  const HindiSourcesScreen({super.key});

  @override
  ConsumerState<HindiSourcesScreen> createState() => _HindiSourcesScreenState();
}

class _HindiSourcesScreenState extends ConsumerState<HindiSourcesScreen> {
  final Map<String, bool> _testingMap = {};
  final Map<String, String> _testResultMap = {};
  bool _autoSwitch = true;
  String _preferredProvider = 'auto';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = HindiSourcePreferences.instance;
    await prefs.init();
    if (mounted) {
      setState(() {
        _autoSwitch = prefs.getAutoSwitch();
        _preferredProvider = prefs.getPreferredProvider();
      });
    }
  }

  Future<void> _testProvider(String id) async {
    setState(() {
      _testingMap[id] = true;
      _testResultMap.remove(id);
    });

    final res = await ref.read(hindiSourceManagerProvider.notifier).testProvider(id);

    if (mounted) {
      setState(() {
        _testingMap[id] = false;
        _testResultMap[id] = res.success
            ? '${res.latencyMs}ms • Healthy'
            : 'Unreachable / Degraded';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sources = ref.watch(hindiSourceManagerProvider);
    final notifier = ref.read(hindiSourceManagerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton.filledTonal(
          onPressed: () => context.pop(),
          icon: const Icon(Iconsax.arrow_left_2),
        ),
        title: const Text('Manage Hindi Sources'),
        forceMaterialTransparency: true,
        actions: [
          IconButton(
            tooltip: 'Reset to Defaults',
            icon: const Icon(Icons.restore_rounded),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Reset Hindi Sources?'),
                  content: const Text(
                    'This will restore default provider priorities and enable status.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await notifier.resetToDefaults();
                await _loadPreferences();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Hindi sources reset to defaults'),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Section header / info banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Drag providers to change resolution order. AniDash tries enabled providers from top to bottom when Hindi is selected.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Provider switching preferences
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(Iconsax.radar_2, color: colorScheme.primary),
                    title: const Text('Auto Source Switching'),
                    subtitle: const Text(
                      'Automatically switch to next backup if primary provider fails',
                    ),
                    value: _autoSwitch,
                    onChanged: (val) async {
                      setState(() => _autoSwitch = val);
                      await HindiSourcePreferences.instance.setAutoSwitch(val);
                    },
                  ),
                  const Divider(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Iconsax.setting_4, color: colorScheme.primary),
                    title: const Text('Preferred Provider'),
                    subtitle: Text(
                      _preferredProvider == 'auto'
                          ? 'Auto (Health & Priority Based)'
                          : sources.firstWhere(
                              (s) => s.id == _preferredProvider,
                              orElse: () => sources.first,
                            ).name,
                    ),
                    trailing: DropdownButton<String>(
                      value: _preferredProvider,
                      underline: const SizedBox(),
                      items: [
                        const DropdownMenuItem(
                          value: 'auto',
                          child: Text('Auto'),
                        ),
                        ...sources.map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name),
                          ),
                        ),
                      ],
                      onChanged: (val) async {
                        if (val != null) {
                          setState(() => _preferredProvider = val);
                          await HindiSourcePreferences.instance
                              .setPreferredProvider(val);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'HINDI PROVIDERS (${sources.length})',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),

          // Reorderable provider list
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sources.length,
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex -= 1;
              final list = List<HindiSourceModel>.from(sources);
              final moved = list.removeAt(oldIndex);
              list.insert(newIndex, moved);
              notifier.reorderSources(list.map((s) => s.id).toList());
            },
            itemBuilder: (context, index) {
              final source = sources[index];
              final isTesting = _testingMap[source.id] == true;
              final testResult = _testResultMap[source.id];

              return Card(
                key: ValueKey(source.id),
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10),
                color: colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: source.enabled
                        ? colorScheme.outlineVariant.withValues(alpha: 0.5)
                        : colorScheme.outlineVariant.withValues(alpha: 0.2),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Priority rank badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '#${index + 1}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  source.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: source.enabled
                                        ? colorScheme.onSurface
                                        : colorScheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  source.baseUrl,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Enable / Disable switch
                          Switch(
                            value: source.enabled,
                            onChanged: (enabled) {
                              notifier.setSourceEnabled(source.id, enabled);
                            },
                          ),
                          // Drag handle
                          ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(Icons.drag_indicator_rounded),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Feature and status badges
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _buildBadge(
                            context,
                            'Hindi',
                            colorScheme.primaryContainer,
                            colorScheme.onPrimaryContainer,
                          ),
                          if (source.supportsMultiAudio)
                            _buildBadge(
                              context,
                              'Multi Audio',
                              colorScheme.secondaryContainer,
                              colorScheme.onSecondaryContainer,
                            ),
                          if (source.supportsDownloads)
                            _buildBadge(
                              context,
                              'Downloads',
                              colorScheme.tertiaryContainer,
                              colorScheme.onTertiaryContainer,
                            ),
                          _buildBadge(
                            context,
                            source.status.toUpperCase(),
                            source.status == 'stable'
                                ? Colors.green.withValues(alpha: 0.15)
                                : (source.status == 'backup'
                                    ? Colors.blue.withValues(alpha: 0.15)
                                    : Colors.orange.withValues(alpha: 0.15)),
                            source.status == 'stable'
                                ? Colors.green
                                : (source.status == 'backup'
                                    ? Colors.blue
                                    : Colors.orange),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Test button and live status
                      Row(
                        children: [
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                            ),
                            icon: isTesting
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.speed_rounded, size: 16),
                            label: Text(
                              isTesting ? 'Testing...' : 'Test Provider',
                              style: const TextStyle(fontSize: 12),
                            ),
                            onPressed:
                                isTesting ? null : () => _testProvider(source.id),
                          ),
                          if (testResult != null) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                testResult,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: testResult.contains('Healthy')
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ] else if (source.lastLatencyMs != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '${source.lastLatencyMs}ms',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildBadge(
    BuildContext context,
    String label,
    Color bgColor,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
