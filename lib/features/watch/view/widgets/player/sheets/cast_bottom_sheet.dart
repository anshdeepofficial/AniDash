import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:ani_dash/core/services/cast_service.dart';
import 'package:ani_dash/features/watch/view_model/episode_stream_provider.dart';
import 'package:ani_dash/features/watch/view_model/episode_list_provider.dart';

class CastBottomSheet extends ConsumerStatefulWidget {
  const CastBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const CastBottomSheet(),
    );
  }

  @override
  ConsumerState<CastBottomSheet> createState() => _CastBottomSheetState();
}

class _CastBottomSheetState extends ConsumerState<CastBottomSheet> {
  final CastService _castService = CastService();
  StreamSubscription<List<CastDevice>>? _sub;
  List<CastDevice> _devices = [];
  bool _isScanning = false;
  String? _castingStatus;

  @override
  void initState() {
    super.initState();
    _devices = _castService.discoveredDevices;
    _sub = _castService.devicesStream.listen((devs) {
      if (mounted) {
        setState(() {
          _devices = devs;
          _isScanning = _castService.isScanning;
        });
      }
    });

    _startScan();
  }

  void _startScan() {
    setState(() => _isScanning = true);
    _castService.startDiscovery().then((_) {
      if (mounted) setState(() => _isScanning = false);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _castService.stopDiscovery();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final streamData = ref.watch(episodeDataProvider);
    final currentSource = (streamData.selectedSourceIdx != null &&
            streamData.selectedSourceIdx! >= 0 &&
            streamData.selectedSourceIdx! < streamData.sources.length)
        ? streamData.sources[streamData.selectedSourceIdx!]
        : (streamData.sources.isNotEmpty ? streamData.sources.first : null);
    final streamUrl = currentSource?.url ?? '';
    final episodeList = ref.watch(episodeListProvider);
    final currentEp = episodeList.episodes
        .where((e) => e.number == streamData.selectedEpisode)
        .firstOrNull;
    final title = currentEp?.title ?? 'Episode ${streamData.selectedEpisode ?? 1}';

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.cast_rounded, color: colorScheme.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cast / Screen Share',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isScanning)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    IconButton(
                      tooltip: 'Rescan Wi-Fi Devices',
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                      onPressed: _startScan,
                    ),
                ],
              ),

              if (_castingStatus != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: colorScheme.primary, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _castingStatus!,
                          style: TextStyle(color: colorScheme.primary, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // DLNA Devices Section
              Text(
                'Wi-Fi Smart TVs & DLNA Devices',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              if (_devices.isEmpty && _isScanning)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Column(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Searching for DLNA/UPnP smart TVs on Wi-Fi...',
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_devices.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.wifi_off_rounded, color: Colors.white38, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No DLNA devices found on this Wi-Fi network. Make sure your Smart TV is powered on and connected to the same Wi-Fi, or use an external app below.',
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _devices.length,
                  separatorBuilder: (_, _) => const Divider(color: Colors.white12, height: 1),
                  itemBuilder: (context, idx) {
                    final device = _devices[idx];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
                        child: Icon(Icons.tv_rounded, color: colorScheme.primary, size: 20),
                      ),
                      title: Text(
                        device.friendlyName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        device.modelName ?? device.manufacturer ?? 'DLNA Media Renderer',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      trailing: FilledButton.tonal(
                        onPressed: () async {
                          if (streamUrl.isEmpty) return;
                          setState(() => _castingStatus = 'Connecting to ${device.friendlyName}...');
                          final ok = await _castService.castToDlnaDevice(
                            device,
                            streamUrl,
                            title: title,
                          );
                          if (mounted) {
                            setState(() {
                              _castingStatus = ok
                                  ? 'Now playing on ${device.friendlyName}!'
                                  : 'Failed to stream to ${device.friendlyName}. Try an external app below.';
                            });
                          }
                        },
                        child: const Text('Play on TV'),
                      ),
                    );
                  },
                ),

              const SizedBox(height: 24),

              // External Cast Apps Section
              Text(
                'Cast via External Apps',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: _AppCastButton(
                      title: 'Web Video Caster',
                      subtitle: 'Chromecast / Roku / Fire TV',
                      icon: Icons.cast_connected_rounded,
                      color: const Color(0xFF2196F3),
                      onTap: () async {
                        if (streamUrl.isEmpty) return;
                        final ok = await _castService.launchWebVideoCaster(streamUrl);
                        if (!ok && context.mounted) {
                          _showAppNotInstalledDialog(
                            context,
                            'Web Video Caster',
                            'com.instantbits.cast.webvideo',
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _AppCastButton(
                      title: 'BubbleUPnP',
                      subtitle: 'UPnP / DLNA / Chromecast',
                      icon: Icons.speaker_group_rounded,
                      color: const Color(0xFF4CAF50),
                      onTap: () async {
                        if (streamUrl.isEmpty) return;
                        final ok = await _castService.launchBubbleUPnP(streamUrl);
                        if (!ok && context.mounted) {
                          _showAppNotInstalledDialog(
                            context,
                            'BubbleUPnP',
                            'com.bubblesoft.android.bubbleupnp',
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _AppCastButton(
                      title: 'VLC for Android',
                      subtitle: 'External Network Stream',
                      icon: Icons.play_circle_outline_rounded,
                      color: const Color(0xFFFF9800),
                      onTap: () async {
                        if (streamUrl.isEmpty) return;
                        final ok = await _castService.launchVlc(streamUrl);
                        if (!ok && context.mounted) {
                          _showAppNotInstalledDialog(
                            context,
                            'VLC for Android',
                            'org.videolan.vlc',
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _AppCastButton(
                      title: 'Any Video Player',
                      subtitle: 'Open in system apps',
                      icon: Icons.open_in_new_rounded,
                      color: const Color(0xFF9C27B0),
                      onTap: () async {
                        if (streamUrl.isEmpty) return;
                        await _castService.launchGenericPlayer(streamUrl);
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Direct Stream Link / Copy
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link_rounded, color: Colors.white70),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Copy Stream URL',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            streamUrl.isNotEmpty
                                ? streamUrl
                                : 'No active stream loaded',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy to Clipboard',
                      icon: const Icon(Iconsax.copy, color: Colors.white),
                      onPressed: streamUrl.isNotEmpty
                          ? () async {
                              await _castService.copyStreamUrl(streamUrl);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Stream link copied to clipboard!'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showAppNotInstalledDialog(
    BuildContext context,
    String appName,
    String packageName,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$appName Not Found'),
        content: Text(
          '$appName is not installed on your device. Would you like to install it from Google Play to cast seamlessly to your TV?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              CastService().launchGenericPlayer(
                'https://play.google.com/store/apps/details?id=$packageName',
              );
            },
            child: const Text('Install App'),
          ),
        ],
      ),
    );
  }
}

class _AppCastButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AppCastButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
