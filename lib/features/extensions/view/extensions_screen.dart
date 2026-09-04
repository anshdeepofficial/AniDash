import 'package:cached_network_image/cached_network_image.dart';
import 'package:dartotsu_extension_bridge/dartotsu_extension_bridge.dart'
    hide Extension;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';

class ExtensionScreen extends StatefulWidget {
  const ExtensionScreen({super.key});

  @override
  State<ExtensionScreen> createState() => _ExtensionScreenState();
}

class _ExtensionScreenState extends ExtensionManagerScreen<ExtensionScreen> {
  @override
  Text get title =>
      const Text('Extensions', style: TextStyle(fontWeight: FontWeight.bold));

  @override
  ExtensionScreenBuilder get extensionScreenBuilder =>
      (itemType, isInstalled, searchQuery, selectedLanguage) {
        return ExtensionListWidget(
          itemType: itemType,
          isInstalled: isInstalled,
          searchQuery: searchQuery,
          selectedLanguage: selectedLanguage,
        );
      };

  @override
  List<Widget> extensionActions(
    BuildContext context,
    TabController tabController,
    String currentLanguage,
    Future<void> Function(List<String> repoUrl, ItemType type) onRepoSaved,
    void Function(String currentLanguage) onLanguageChanged,
  ) {
    return [
      IconButton(
        onPressed: () => _showAddRepoDialog(context, onRepoSaved),
        icon: const Icon(Iconsax.add),
        tooltip: 'Add Repository',
      ),
      PopupMenuButton<String>(
        icon: const Icon(Iconsax.translate),
        tooltip: 'Filter Language',
        onSelected: onLanguageChanged,
        itemBuilder: (context) {
          final languages = [
            'All',
            'en',
            'es',
            'fr',
            'pt',
            'it',
            'de',
            'ru',
            'ja',
            'ko',
            'zh',
            'ar',
            'id',
            'vi',
            'th',
            'tr',
          ];
          return languages.map((lang) {
            return PopupMenuItem(
              value: lang,
              child: Text(lang == 'All' ? 'All Languages' : lang),
            );
          }).toList();
        },
      ),
      IconButton(
        onPressed: () async {
          await Get.find<ExtensionManager>().currentManager
              .fetchAvailableAnimeExtensions([
                "https://kohiden.xyz/Kohi-den/extensions/raw/branch/main/index.min.json",
              ]);
        },
        icon: const Icon(Iconsax.refresh),
        tooltip: 'Refresh',
      ),
      PopupMenuButton<ExtensionType>(
        icon: const Icon(Iconsax.category),
        tooltip: 'Filter Extension Type',
        onSelected: (type) {
          Get.find<ExtensionManager>().setCurrentManager(type);
        },
        itemBuilder: (context) {
          return ExtensionType.values.map((type) {
            return PopupMenuItem(
              value: type,
              child: Text(type.name.toUpperCase()),
            );
          }).toList();
        },
      ),
      IconButton(
        onPressed: () => context.push('/settings/extensions/playground'),
        icon: const Icon(Iconsax.code),
        tooltip: 'Playground',
      ),
    ];
  }

  @override
  Widget searchBar(
    BuildContext context,
    TextEditingController textEditingController,
    void Function() onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: textEditingController,
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(
          hintText: 'Search extensions...',
          prefixIcon: const Icon(Iconsax.search_normal),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 0,
            horizontal: 16,
          ),
        ),
      ),
    );
  }

  @override
  Widget tabWidget(BuildContext context, String label, int count) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAddRepoDialog(
    BuildContext context,
    Future<void> Function(List<String> repoUrl, ItemType type) onRepoSaved,
  ) {
    final controller = TextEditingController();
    final presets = [
      (
        name: 'Kohi-den (Standard Anime)',
        url: 'https://kohiden.xyz/Kohi-den/extensions/raw/branch/main/index.min.json',
        type: ItemType.anime,
        is18Plus: false,
      ),
      (
        name: 'Yuzono (18+ & Anime Sources)',
        url: 'https://raw.githubusercontent.com/yuzono/anime-repo/repo/index.min.json',
        type: ItemType.anime,
        is18Plus: true,
      ),
      (
        name: 'Secozzi Aniyomi Extensions',
        url: 'https://raw.githubusercontent.com/Secozzi/aniyomi-extensions/refs/heads/repo/index.min.json',
        type: ItemType.anime,
        is18Plus: false,
      ),
    ];

    showDialog(
      context: context,
      builder: (context) {
        ItemType selectedType = ItemType.anime;
        return StatefulBuilder(
          builder: (context, setState) {
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;

            return AlertDialog(
              title: const Text('Add Repository'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<ItemType>(
                        value: selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Extension Type',
                        ),
                        items: ItemType.values
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(type.name.toUpperCase()),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => selectedType = val);
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          labelText: 'Repository URL',
                          hintText: 'https://...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Community & 18+ Repositories:',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...presets.map((preset) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: preset.is18Plus
                                  ? Colors.redAccent.withValues(alpha: 0.6)
                                  : colorScheme.outlineVariant,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color: preset.is18Plus
                                ? Colors.redAccent.withValues(alpha: 0.05)
                                : null,
                          ),
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 2,
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    preset.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                if (preset.is18Plus)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      '18+',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              preset.url,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                            trailing: TextButton(
                              onPressed: () {
                                setState(() {
                                  controller.text = preset.url;
                                  selectedType = preset.type;
                                });
                              },
                              child: const Text('Select'),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final url = controller.text.trim();
                    if (url.isNotEmpty) {
                      onRepoSaved([url], selectedType);
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class ExtensionListWidget extends StatefulWidget implements ExtensionConfig {
  @override
  final ItemType itemType;
  @override
  final bool isInstalled;
  @override
  final String searchQuery;
  @override
  final String selectedLanguage;

  const ExtensionListWidget({
    super.key,
    required this.itemType,
    required this.isInstalled,
    required this.searchQuery,
    required this.selectedLanguage,
  });

  @override
  State<ExtensionListWidget> createState() => _ExtensionListWidgetState();
}

class _ExtensionListWidgetState extends ExtensionList<ExtensionListWidget> {
  @override
  Widget extensionItem(bool isHeader, String lang, Source? source) {
    if (isHeader) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Text(
          lang.toUpperCase(), // Or map to full name
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    if (source == null) return const SizedBox.shrink();

    return ExtensionListItem(
      source: source,
      isInstalled: widget.isInstalled,
      onInstall: () => source.extensionType?.getManager().installSource(source),
      onUninstall: () => source.extensionType?.getManager().uninstallSource(source),
      onUpdate: () => source.extensionType?.getManager().updateSource(source),
      onTap: () {
        // Open details or settings if installed
        if (widget.isInstalled) {
          context.push(
            '/settings/extensions/extension-preference',
            extra: source,
          );
        } else {
          manager.installSource(source);
        }
      },
    );
  }
}

class ExtensionListItem extends StatelessWidget {
  final Source source;
  final bool isInstalled;
  final VoidCallback onInstall;
  final VoidCallback onUninstall;
  final VoidCallback onUpdate;
  final VoidCallback onTap;

  const ExtensionListItem({
    super.key,
    required this.source,
    required this.isInstalled,
    required this.onInstall,
    required this.onUninstall,
    required this.onUpdate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainer,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: source.iconUrl != null && source.iconUrl!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: source.iconUrl!,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => Container(
                    width: 40,
                    height: 40,
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.extension, size: 20),
                  ),
                )
              : Container(
                  width: 40,
                  height: 40,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.extension, size: 20),
                ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                source.name ?? 'Unknown',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (source.isNsfw == true) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '18+',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text('v${source.version ?? "?"} • ${source.lang ?? "?"}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (source.hasUpdate == true && isInstalled)
              IconButton(
                icon: const Icon(Icons.update, color: Colors.orange),
                onPressed: onUpdate,
                tooltip: 'Update',
              ),
            if (isInstalled)
              IconButton(
                icon: const Icon(Iconsax.trash, color: Colors.red),
                onPressed: onUninstall,
                tooltip: 'Uninstall',
              )
            else
              IconButton(
                icon: const Icon(Iconsax.import),
                onPressed: onInstall,
                tooltip: 'Install',
              ),
            if (isInstalled)
              IconButton(
                icon: const Icon(Iconsax.setting_2),
                onPressed: () => context.push(
                  '/settings/extensions/extension-preference',
                  extra: source,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
