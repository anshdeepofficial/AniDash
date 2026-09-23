import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:ani_dash/features/browse/view/browse_screen.dart';
import 'package:ani_dash/features/downloads/view/downloads_screen.dart';
import 'package:ani_dash/features/home/view/home_screen.dart' as h_screen;
import 'package:ani_dash/features/loading/view_model/initialization_notifier.dart';
import 'package:ani_dash/features/watchlist/view/watchlist_screen.dart';
import 'package:ani_dash/features/manga/view/manga_screen.dart';
import 'package:ani_dash/core/services/offline_sync_queue_service.dart';
import 'package:ani_dash/core/services/notification_service.dart';
import 'package:ani_dash/core/services/update_scheduler.dart';
import 'package:ani_dash/core/services/update_service.dart';
import 'package:ani_dash/core/utils/updater.dart';
import 'package:ani_dash/core/utils/app_logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ani_dash/shared/providers/settings/update_settings_notifier.dart';
import 'package:ani_dash/shared/providers/permissions_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NavItem {
  final String path;
  final IconData icon;
  final Widget screen;

  const NavItem({required this.path, required this.icon, required this.screen});
}

final List<NavItem> navItems = [
  const NavItem(path: '/', icon: Iconsax.home, screen: h_screen.HomeScreen()),
  const NavItem(
    path: '/browse',
    icon: Iconsax.search_normal_1,
    screen: BrowseScreen(),
  ),
  const NavItem(path: '/manga', icon: Iconsax.book, screen: MangaScreen()),
  const NavItem(
    path: '/downloads',
    icon: Iconsax.receive_square,
    screen: DownloadsScreen(),
  ),
  const NavItem(
    path: '/watchlist',
    icon: Iconsax.bookmark,
    screen: WatchlistScreen(),
  ),
];

class AppRouterScreen extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  final List<Widget> children;

  const AppRouterScreen({
    super.key,
    required this.navigationShell,
    required this.children,
  });

  @override
  ConsumerState<AppRouterScreen> createState() => _AppRouterScreenState();
}

class _AppRouterScreenState extends ConsumerState<AppRouterScreen>
    with WidgetsBindingObserver {
  late final PageController _pageController;
  bool _updateCheckInProgress = false;
  bool _updateSheetVisible = false;
  DateTime? _lastForegroundUpdateCheck;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _foregroundUpdateTimer;
  StreamSubscription<String>? _updateTapSubscription;
  ProviderSubscription? _updateSettingsSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(
      () => ref.read(initializationProvider.notifier).initialize(),
    );
    _pageController = PageController(
      initialPage: widget.navigationShell.currentIndex,
    );
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        OfflineSyncQueueService.flushQueue(ref);
      }
    });
    _updateTapSubscription = NotificationService().onUpdateTapped.listen((
      version,
    ) {
      if (mounted) {
        _checkForScheduledUpdate(isAppOpen: true, force: true);
      }
    });
    _updateSettingsSub = ref.listenManual(updateSettingsProvider, (prev, next) {
      _startPeriodicForegroundUpdateCheck();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _openDownloadsOffline();
      try {
        await ref
            .read(permissionsProvider.notifier)
            .requestNotificationPermission();
      } catch (_) {}
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _checkForScheduledUpdate(isAppOpen: true);
      });
      _startPeriodicForegroundUpdateCheck();
      OfflineSyncQueueService.flushQueue(ref);
    });
  }

  @override
  void dispose() {
    _foregroundUpdateTimer?.cancel();
    _updateSettingsSub?.close();
    _updateTapSubscription?.cancel();
    _connectivitySubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkForScheduledUpdate(isAppOpen: true);
      _startPeriodicForegroundUpdateCheck();
      OfflineSyncQueueService.flushQueue(ref);
    } else if (state == AppLifecycleState.paused) {
      _foregroundUpdateTimer?.cancel();
    }
  }

  void _startPeriodicForegroundUpdateCheck() {
    _foregroundUpdateTimer?.cancel();
    final settings = ref.read(updateSettingsProvider);
    if (!settings.autoCheckEnabled) return;
    final minutes = settings.checkIntervalMinutes.clamp(1, 60);
    _foregroundUpdateTimer = Timer.periodic(Duration(minutes: minutes), (_) {
      _checkForScheduledUpdate(isAppOpen: true);
    });
  }

  Future<void> _checkForScheduledUpdate({
    bool isAppOpen = false,
    bool force = false,
  }) async {
    if (_updateCheckInProgress || !mounted) return;
    final settings = ref.read(updateSettingsProvider);
    if (!settings.autoCheckEnabled && !force) return;

    // Strict window check: if not in 24-hour mode, only check within user's custom window
    if (!force && !UpdateScheduler.isInsideWindow(settings)) {
      return;
    }

    final now = DateTime.now();
    if (!force &&
        !isAppOpen &&
        _lastForegroundUpdateCheck != null &&
        now.difference(_lastForegroundUpdateCheck!).inMinutes < 1) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    _updateCheckInProgress = true;
    _lastForegroundUpdateCheck = now;
    try {
      final updateInfo = await UpdateService().checkForUpdate();
      if (updateInfo != null && mounted) {
        final latest = updateInfo.version.replaceFirst('v', '').trim();

        // Check if user snoozed ("Remind in 1 hour" or "Skip for today")
        final remindAfter = prefs.getInt('remind_update_after') ?? 0;
        final remindVersion = prefs.getString('remind_update_version');
        final isSnoozed =
            !force &&
            remindVersion == latest &&
            now.millisecondsSinceEpoch < remindAfter;

        if (isSnoozed) {
          return;
        }

        // A foreground timer, app-resume callback and the background worker can
        // all discover the same release. Present it at most once per 24 hours.
        final lastPresentedVersion = prefs.getString('last_presented_update');
        final lastPresentedAt = prefs.getInt('last_presented_update_time') ?? 0;
        final wasRecentlyPresented =
            lastPresentedVersion == latest &&
            now.millisecondsSinceEpoch - lastPresentedAt <
                const Duration(hours: 24).inMilliseconds;
        if (!force && (wasRecentlyPresented || _updateSheetVisible)) return;

        if (remindAfter != 0 && now.millisecondsSinceEpoch >= remindAfter) {
          await prefs.remove('remind_update_after');
          await prefs.remove('remind_update_version');
        }

        // Post to the notification bar with the action buttons in safe try-catch
        try {
          await NotificationService().showUpdateAvailableNotification(latest);
        } catch (notifErr) {
          AppLogger.w(
            'Notification post encountered non-fatal error: $notifErr',
          );
        }

        // Also trigger the in-app update dialog so the user sees it immediately on screen
        final packageInfo = await PackageInfo.fromPlatform();
        if (!mounted) return;
        _updateSheetVisible = true;
        await prefs.setString('last_presented_update', latest);
        await prefs.setInt(
          'last_presented_update_time',
          now.millisecondsSinceEpoch,
        );
        if (!mounted) return;
        try {
          await showUpdateBottomSheet(
            context,
            updateInfo.version,
            packageInfo.version,
            UpdateType.stable,
            releaseNotes: updateInfo.releaseNotes,
            apkDownloadUrl: updateInfo.downloadUrl,
          );
        } finally {
          _updateSheetVisible = false;
        }
      }
    } catch (e) {
      AppLogger.w('Update check encountered error: $e');
    } finally {
      _updateCheckInProgress = false;
    }
  }

  Future<void> _openDownloadsOffline() async {
    final connections = await Connectivity().checkConnectivity();
    if (!mounted || widget.navigationShell.currentIndex != 0) return;
    if (connections.every(
      (connection) => connection == ConnectivityResult.none,
    )) {
      widget.navigationShell.goBranch(3);
      _pageController.jumpToPage(3);
    }
  }

  @override
  void didUpdateWidget(covariant AppRouterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.navigationShell.currentIndex != _pageController.page?.round()) {
      _pageController.animateToPage(
        widget.navigationShell.currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onPageChanged(int index) {
    if (index != widget.navigationShell.currentIndex) {
      widget.navigationShell.goBranch(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(updateSettingsProvider, (previous, next) {
      if (previous?.checkIntervalMinutes != next.checkIntervalMinutes ||
          previous?.autoCheckEnabled != next.autoCheckEnabled ||
          previous?.fullDay != next.fullDay ||
          previous?.startHour != next.startHour ||
          previous?.endHour != next.endHour) {
        _startPeriodicForegroundUpdateCheck();
      }
    });

    final isWide = MediaQuery.sizeOf(context).width > 800;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (widget.navigationShell.currentIndex != 0) {
          widget.navigationShell.goBranch(0);
        } else {
          showExitConfirmationDialog(context, isSystemExit: true);
        }
      },
      child: Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        body: Stack(
          fit: StackFit.expand,
          children: [
            PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              physics: const BouncingScrollPhysics(),
              children:
                  widget.children.map((child) {
                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                        isWide ? 90 : 0,
                        isWide ? 15 : 0,
                        0,
                        isWide ? 15 : 0,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: _KeepAliveWrapper(child: child),
                      ),
                    );
                  }).toList(),
            ),
            Positioned(
              left: isWide ? 10 : 0,
              right: isWide ? null : 0,
              top: isWide ? 10 : null,
              bottom: 10,
              child: SafeArea(
                child:
                    isWide
                        ? _SideNav(shell: widget.navigationShell)
                        : _BottomNav(shell: widget.navigationShell),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideNav extends StatelessWidget {
  final StatefulNavigationShell shell;

  const _SideNav({required this.shell});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: 75,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(35),
        border: Border.all(color: colorScheme.primary),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: List.generate(navItems.length, (index) {
          final isSelected = shell.currentIndex == index;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: InkWell(
                onTap: () => shell.goBranch(index),
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    color:
                        isSelected
                            ? colorScheme.primary.withValues(alpha: 0.2)
                            : null,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    navItems[index].icon,
                    color:
                        isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final StatefulNavigationShell shell;

  const _BottomNav({required this.shell});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: width * 0.08),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(navItems.length, (index) {
                final isSelected = shell.currentIndex == index;
                return Expanded(
                  child: InkWell(
                    onTap: () => shell.goBranch(index),
                    borderRadius: BorderRadius.circular(100),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? colorScheme.primary.withValues(alpha: 0.2)
                                : null,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        navItems[index].icon,
                        color:
                            isSelected
                                ? colorScheme.primary
                                : colorScheme.onSurface,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

void showExitConfirmationDialog(
  BuildContext context, {
  bool isSystemExit = false,
}) {
  showDialog(
    context: context,
    builder:
        (context) => AlertDialog(
          title: const Text('Confirm Exit'),
          content: const Text('Are you sure you want to exit the app?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (isSystemExit) {
                  SystemNavigator.pop();
                } else {
                  context.pop();
                }
              },
              child: const Text('Exit'),
            ),
          ],
        ),
  );
}

class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;

  const _KeepAliveWrapper({required this.child});

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }

  @override
  bool get wantKeepAlive => true;
}
