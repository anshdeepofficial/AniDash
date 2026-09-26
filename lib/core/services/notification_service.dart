import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:ani_dash/core/utils/app_logger.dart';
import 'package:ani_dash/core/services/notification_inbox_service.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  final prefs = await SharedPreferences.getInstance();
  final version = response.payload?.replaceFirst('update:', '').trim() ?? '';
  if (response.actionId == 'update_remind_1h') {
    await prefs.setInt(
      'remind_update_after',
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch,
    );
    if (version.isNotEmpty) {
      await prefs.setString('remind_update_version', version);
    }
  } else if (response.actionId == 'update_skip_day') {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    await prefs.setInt('remind_update_after', tomorrow.millisecondsSinceEpoch);
    if (version.isNotEmpty) {
      await prefs.setString('remind_update_version', version);
    }
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  static const notificationCheckTask = 'anidash_notification_check';

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final StreamController<String> playbackActionController =
      StreamController<String>.broadcast();
  Stream<String> get onPlaybackAction => playbackActionController.stream;

  final StreamController<String> updateTapController =
      StreamController<String>.broadcast();
  Stream<String> get onUpdateTapped => updateTapController.stream;

  final StreamController<String> notificationRouteController =
      StreamController<String>.broadcast();
  Stream<String> get onNotificationRoute => notificationRouteController.stream;

  Future<void> registerPeriodicNotificationWorker({bool forceReplace = false}) async {
    if (!Platform.isAndroid) return;
    try {
      await Workmanager().registerPeriodicTask(
        notificationCheckTask,
        notificationCheckTask,
        frequency: const Duration(minutes: 15),
        existingWorkPolicy:
            forceReplace ? ExistingWorkPolicy.replace : ExistingWorkPolicy.keep,
        constraints: Constraints(networkType: NetworkType.connected),
      );
      AppLogger.i(
        '[NotificationWorker] Registered unique periodic task "$notificationCheckTask" (frequency: 15m, policy: ${forceReplace ? "replace" : "keep"})',
      );
    } catch (e) {
      AppLogger.w('Could not register periodic notification worker: $e');
    }
  }

  static const String _iconName = '@drawable/ic_notification';
  static const String _largeIconName = '@drawable/ic_notification_large';
  static const Color _brandColor = Color(0xFF4CAF50);

  static bool _timeZoneInitialized = false;

  static void _setupTimeZone() {
    if (_timeZoneInitialized) return;
    try {
      tz.initializeTimeZones();
      final timeZoneName = DateTime.now().timeZoneName;
      if (tz.timeZoneDatabase.locations.containsKey(timeZoneName)) {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
        _timeZoneInitialized = true;
        return;
      }
      final offset = DateTime.now().timeZoneOffset;
      for (final loc in tz.timeZoneDatabase.locations.values) {
        if (loc.currentTimeZone.offset == offset.inMilliseconds) {
          tz.setLocalLocation(loc);
          _timeZoneInitialized = true;
          return;
        }
      }
      tz.setLocalLocation(tz.getLocation('UTC'));
      _timeZoneInitialized = true;
    } catch (e) {
      AppLogger.w('Timezone initialization error: $e');
    }
  }

  Future<void> initialize({bool isBackground = false}) async {
    _setupTimeZone();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings(_iconName);

    const LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(defaultActionName: 'Open notification');

    const WindowsInitializationSettings initializationSettingsWindows =
        WindowsInitializationSettings(
          appName: 'AniDash',
          appUserModelId: 'RoshanKumar.AniDash.App.v2',
          guid: '0516d984-72bf-47d4-bfbc-b2b8fd563479',
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          linux: initializationSettingsLinux,
          windows: initializationSettingsWindows,
        );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final prefs = await SharedPreferences.getInstance();
        final version =
            response.payload?.replaceFirst('update:', '').trim() ?? '';
        if (response.actionId == 'update_remind_1h') {
          await prefs.setInt(
            'remind_update_after',
            DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch,
          );
          if (version.isNotEmpty) {
            await prefs.setString('remind_update_version', version);
          }
        } else if (response.actionId == 'update_skip_day') {
          final now = DateTime.now();
          final tomorrow = DateTime(now.year, now.month, now.day + 1);
          await prefs.setInt(
            'remind_update_after',
            tomorrow.millisecondsSinceEpoch,
          );
          if (version.isNotEmpty) {
            await prefs.setString('remind_update_version', version);
          }
        } else if (response.actionId == 'update_now' ||
            (response.payload?.startsWith('update:') == true &&
                response.actionId == null)) {
          _instance.updateTapController.add(version);
        } else if (response.actionId != null) {
          _instance.playbackActionController.add(response.actionId!);
        } else if (response.payload != null && response.payload!.isNotEmpty) {
          final payload = response.payload!;
          if (payload.startsWith('details:') || payload.startsWith('/details/')) {
            final mediaId = payload.replaceFirst('details:', '').replaceFirst('/details/', '').trim();
            final targetRoute = mediaId.contains('?')
                ? (mediaId.startsWith('/') ? mediaId : '/details/$mediaId')
                : '/details/$mediaId?tab=episodes';
            unawaited(NotificationInboxService().markReadByRouteOrMedia(targetRoute, mediaId));
            _instance.notificationRouteController.add(targetRoute);
          } else if (payload.startsWith('route:')) {
            final route = payload.replaceFirst('route:', '').trim();
            unawaited(NotificationInboxService().markReadByRouteOrMedia(route, null));
            _instance.notificationRouteController.add(route);
          } else if (payload == '/downloads' || payload == '/news' || payload == '/watchlist') {
            unawaited(NotificationInboxService().markReadByRouteOrMedia(payload, null));
            _instance.notificationRouteController.add(payload);
          }
        }
        AppLogger.infoPair('Notification tapped', response.payload);
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    await _createNotificationChannels();
    if (!isBackground) {
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();
    }
  }

  Future<void> ensureSoundChannelsCreated([String? ignoredSoundId]) async {
    final androidImplementation =
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    const newsChannel = AndroidNotificationChannel(
      'AniDash_news',
      'AniDash News',
      description: 'Notifications for latest anime news',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    const episodeChannel = AndroidNotificationChannel(
      'AniDash_episodes',
      'Episode Releases',
      description: 'Notifications when new Sub or Dub episodes are released',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    const updateChannel = AndroidNotificationChannel(
      'AniDash_updates',
      'App Updates',
      description: 'Notifications when a new AniDash version is available',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    const reminderChannel = AndroidNotificationChannel(
      'AniDash_reminders',
      'Continue Watching Reminders',
      description: 'Reminders to continue watching your paused anime',
      importance: Importance.defaultImportance,
      playSound: true,
      enableVibration: true,
    );

    await androidImplementation?.createNotificationChannel(newsChannel);
    await androidImplementation?.createNotificationChannel(episodeChannel);
    await androidImplementation?.createNotificationChannel(updateChannel);
    await androidImplementation?.createNotificationChannel(reminderChannel);
  }

  Future<void> _createNotificationChannels() async {
    final androidImplementation =
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    // Delete deprecated v1 channels to migrate to custom sound channels
    try {
      await androidImplementation?.deleteNotificationChannel(
        'AniDash_news_channel',
      );
      await androidImplementation?.deleteNotificationChannel(
        'AniDash_episodes_channel',
      );
      await androidImplementation?.deleteNotificationChannel(
        'AniDash_updates_channel',
      );
      await androidImplementation?.deleteNotificationChannel(
        'AniDash_news_channel_v2',
      );
      await androidImplementation?.deleteNotificationChannel(
        'AniDash_episodes_channel_v2',
      );
      await androidImplementation?.deleteNotificationChannel(
        'AniDash_updates_channel_v2',
      );
    } catch (_) {}

    const AndroidNotificationChannel downloadChannel =
        AndroidNotificationChannel(
          'AniDash_downloads_channel',
          'Downloads',
          description: 'Download progress and completed status',
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
          showBadge: false,
        );

    const AndroidNotificationChannel playbackChannel =
        AndroidNotificationChannel(
          'AniDash_playback_channel',
          'Media Playback',
          description:
              'Controls for active media playback and lock screen controls',
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
          showBadge: false,
        );

    await androidImplementation?.createNotificationChannel(downloadChannel);
    await androidImplementation?.createNotificationChannel(playbackChannel);

    await ensureSoundChannelsCreated();
  }

  AndroidNotificationDetails _buildAndroidDetails({
    required String channelBaseId,
    required String channelName,
    required String channelDescription,
    Importance importance = Importance.high,
    Priority priority = Priority.high,
    bool playSound = true,
    bool enableVibration = true,
    List<AndroidNotificationAction>? actions,
    StyleInformation? styleInformation,
    Color? color,
  }) {
    return AndroidNotificationDetails(
      channelBaseId,
      channelName,
      channelDescription: channelDescription,
      importance: importance,
      priority: priority,
      playSound: playSound,
      enableVibration: enableVibration,
      icon: _iconName,
      largeIcon: const DrawableResourceAndroidBitmap(_largeIconName),
      color: color ?? _brandColor,
      actions: actions,
      styleInformation: styleInformation,
      visibility: NotificationVisibility.public,
    );
  }

  Future<void> showTestNotification({String? title, String? body}) async {
    await ensureSoundChannelsCreated();

    final details = NotificationDetails(
      android: _buildAndroidDetails(
        channelBaseId: 'AniDash_updates',
        channelName: 'App Updates',
        channelDescription:
            'Notifications when a new AniDash version is available',
        styleInformation: BigTextStyleInformation(
          body ?? 'Notifications are enabled and using your system sound.',
          contentTitle: title ?? 'AniDash Notification Test',
        ),
      ),
    );

    await flutterLocalNotificationsPlugin.show(
      8888,
      title ?? 'AniDash Notification Test',
      body ?? 'Notifications are enabled and using your system sound.',
      details,
    );
  }

  Future<void> showNewsNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const notifId = 1000;
    await NotificationInboxService().add(
      title: title,
      body: body,
      route: payload,
      dedupeKey: 'news:${payload ?? title}',
      systemNotificationId: notifId,
    );
    await ensureSoundChannelsCreated();

    final platformChannelSpecifics = NotificationDetails(
      android: _buildAndroidDetails(
        channelBaseId: 'AniDash_news',
        channelName: 'AniDash News',
        channelDescription: 'Notifications for latest anime news',
      ),
    );

    await flutterLocalNotificationsPlugin.show(
      notifId,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  Future<void> showDownloadProgressNotification({
    required int id,
    required String animeTitle,
    required int episodeNumber,
    required double progress,
  }) async {
    final percent = (progress * 100).clamp(0, 100).toInt();
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'AniDash_downloads_channel',
          'Downloads',
          channelDescription: 'Download progress and completed status',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          onlyAlertOnce: true,
          showProgress: true,
          maxProgress: 100,
          progress: percent,
          icon: _iconName,
          largeIcon: const DrawableResourceAndroidBitmap(_largeIconName),
          color: _brandColor,
        );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      id,
      'Downloading EP $episodeNumber - $animeTitle',
      '$percent% completed',
      platformChannelSpecifics,
    );
  }

  Future<void> showDownloadCompletedNotification({
    required int id,
    required String animeTitle,
    required int episodeNumber,
  }) async {
    await NotificationInboxService().add(
      title: 'Download Complete',
      body: '$animeTitle - Episode $episodeNumber is ready offline',
      route: '/downloads',
      dedupeKey: 'download:$animeTitle:$episodeNumber',
      systemNotificationId: id,
    );
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'AniDash_downloads_channel',
          'Downloads',
          channelDescription: 'Download progress and completed status',
          importance: Importance.high,
          priority: Priority.high,
          ongoing: false,
          icon: _iconName,
          largeIcon: DrawableResourceAndroidBitmap(_largeIconName),
          color: _brandColor,
        );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      id,
      'Download Complete',
      '$animeTitle - Episode $episodeNumber is ready to watch offline',
      platformChannelSpecifics,
    );
  }

  Future<void> showEpisodeReleaseNotification({
    required String animeTitle,
    required int episodeNumber,
    bool isDub = false,
    String? mediaId,
    String? customTitle,
    String? customBody,
    String? audioType,
    String? dedupeKey,
  }) async {
    final title = customTitle ?? (isDub || audioType == 'english_dub' ? 'New English Dub Episode' : 'New SUB Episode');
    final body = customBody ??
        '$animeTitle Episode $episodeNumber is now available.';
    final effectiveDedupeKey = dedupeKey ??
        'release:${mediaId ?? animeTitle}:$episodeNumber:${audioType ?? (isDub ? "dub" : "sub")}';
    final notifId =
        (mediaId ?? animeTitle).hashCode ^ episodeNumber ^ (audioType ?? '').hashCode;

    await NotificationInboxService().add(
      title: title,
      body: body,
      route: mediaId != null ? '/details/$mediaId?tab=episodes' : null,
      dedupeKey: effectiveDedupeKey,
      notificationType: audioType ?? (isDub ? 'dub' : 'sub'),
      mediaId: mediaId,
      episodeNumber: episodeNumber,
      language: (isDub || audioType == 'english_dub' ? 'en' : 'ja'),
      systemNotificationId: notifId,
    );
    await ensureSoundChannelsCreated();

    final platformChannelSpecifics = NotificationDetails(
      android: _buildAndroidDetails(
        channelBaseId: 'AniDash_episodes',
        channelName: 'Episode Releases',
        channelDescription:
            'Notifications when new Sub or Dub episodes are released',
        importance: Importance.max,
        priority: Priority.max,
      ),
    );

    await flutterLocalNotificationsPlugin.show(
      notifId,
      title,
      body,
      platformChannelSpecifics,
      payload: mediaId != null ? 'details:$mediaId?tab=episodes' : null,
    );
  }

  /// Schedules exact Android alarms for upcoming episodes (24h, 2h, 1h, and exact release).
  /// These alarms are registered directly with Android AlarmManager, so they wake up the device
  /// and trigger notifications even if AniDash is closed or terminated.
  Future<void> scheduleUpcomingEpisodeAlerts({
    required int mediaId,
    required String animeTitle,
    required int episodeNumber,
    required int airingAtEpoch,
  }) async {
    if (!Platform.isAndroid) return;
    _setupTimeZone();
    await ensureSoundChannelsCreated();

    final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final timeUntilAiring = airingAtEpoch - nowEpoch;
    if (timeUntilAiring <= 0) return;

    final pref = await SharedPreferences.getInstance();

    final details = NotificationDetails(
      android: _buildAndroidDetails(
        channelBaseId: 'AniDash_episodes',
        channelName: 'Episode Releases',
        channelDescription:
            'Notifications when new Sub or Dub episodes are released',
        importance: Importance.max,
        priority: Priority.max,
      ),
    );

    // 1. 24-hour countdown alert (airingAt - 86400)
    final alert24hEpoch = airingAtEpoch - 86400;
    if (alert24hEpoch > nowEpoch &&
        !(pref.getBool('notif_24h_${mediaId}_$episodeNumber') ?? false)) {
      final scheduled24h = tz.TZDateTime.fromMillisecondsSinceEpoch(
        tz.local,
        alert24hEpoch * 1000,
      );
      final id24h =
          ((mediaId.hashCode ^ episodeNumber) * 31 + 24) & 0x7FFFFFFF;
      try {
        await flutterLocalNotificationsPlugin.zonedSchedule(
          id24h,
          'Upcoming: $animeTitle • Ep $episodeNumber',
          'Episode $episodeNumber releases tomorrow (in 24 hours)!',
          scheduled24h,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: 'details:$mediaId?tab=episodes',
        );
        AppLogger.i(
          '[NotificationService] Scheduled 24h exact alarm for $animeTitle Ep $episodeNumber at ${scheduled24h.toIso8601String()}',
        );
      } catch (e) {
        AppLogger.w('Failed to schedule 24h alarm: $e');
      }
    }

    // 2. 2-hour countdown alert (airingAt - 7200)
    final alert2hEpoch = airingAtEpoch - 7200;
    if (alert2hEpoch > nowEpoch &&
        !(pref.getBool('notif_2h_${mediaId}_$episodeNumber') ?? false)) {
      final scheduled2h = tz.TZDateTime.fromMillisecondsSinceEpoch(
        tz.local,
        alert2hEpoch * 1000,
      );
      final id2h =
          ((mediaId.hashCode ^ episodeNumber) * 31 + 2) & 0x7FFFFFFF;
      try {
        await flutterLocalNotificationsPlugin.zonedSchedule(
          id2h,
          'Upcoming: $animeTitle • Ep $episodeNumber',
          'Episode $episodeNumber releases in 2 hours!',
          scheduled2h,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: 'details:$mediaId?tab=episodes',
        );
        AppLogger.i(
          '[NotificationService] Scheduled 2h exact alarm for $animeTitle Ep $episodeNumber at ${scheduled2h.toIso8601String()}',
        );
      } catch (e) {
        AppLogger.w('Failed to schedule 2h alarm: $e');
      }
    }

    // 3. 1-hour countdown alert (airingAt - 3600)
    final alert1hEpoch = airingAtEpoch - 3600;
    if (alert1hEpoch > nowEpoch &&
        !(pref.getBool('notif_1h_${mediaId}_$episodeNumber') ?? false)) {
      final scheduled1h = tz.TZDateTime.fromMillisecondsSinceEpoch(
        tz.local,
        alert1hEpoch * 1000,
      );
      final id1h =
          ((mediaId.hashCode ^ episodeNumber) * 31 + 1) & 0x7FFFFFFF;
      try {
        await flutterLocalNotificationsPlugin.zonedSchedule(
          id1h,
          'Upcoming: $animeTitle • Ep $episodeNumber',
          'Episode $episodeNumber releases in 1 hour!',
          scheduled1h,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: 'details:$mediaId?tab=episodes',
        );
        AppLogger.i(
          '[NotificationService] Scheduled 1h exact alarm for $animeTitle Ep $episodeNumber at ${scheduled1h.toIso8601String()}',
        );
      } catch (e) {
        AppLogger.w('Failed to schedule 1h alarm: $e');
      }
    }

    // 4. Exact release alert (airingAt)
    if (airingAtEpoch > nowEpoch &&
        !(pref.getBool('sub_release_${mediaId}_$episodeNumber') ?? false)) {
      final scheduledRelease = tz.TZDateTime.fromMillisecondsSinceEpoch(
        tz.local,
        airingAtEpoch * 1000,
      );
      final idRelease =
          ((mediaId.hashCode ^ episodeNumber) * 31 + 0) & 0x7FFFFFFF;
      try {
        await flutterLocalNotificationsPlugin.zonedSchedule(
          idRelease,
          '$animeTitle • Ep $episodeNumber Released',
          'Episode $episodeNumber is now officially available to watch on AniDash.',
          scheduledRelease,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: 'details:$mediaId?tab=episodes',
        );
        AppLogger.i(
          '[NotificationService] Scheduled exact release alarm for $animeTitle Ep $episodeNumber at ${scheduledRelease.toIso8601String()}',
        );
      } catch (e) {
        AppLogger.w('Failed to schedule exact release alarm: $e');
      }
    }
  }

  Future<void> showContinueWatchingNotification({
    required String animeTitle,
    required int episodeNumber,
    String? mediaId,
    String? customBody,
  }) async {
    final title = 'Continue Watching $animeTitle';
    final body = customBody ??
        'You stopped at Episode $episodeNumber. Continue where you left off.';
    final effectiveDedupeKey =
        'continue:${mediaId ?? animeTitle}:$episodeNumber';
    final notifId = (mediaId ?? animeTitle).hashCode;

    await NotificationInboxService().add(
      title: title,
      body: body,
      route: mediaId != null ? '/details/$mediaId?tab=episodes' : '/watchlist',
      dedupeKey: effectiveDedupeKey,
      notificationType: 'continue_watching',
      mediaId: mediaId,
      episodeNumber: episodeNumber,
      systemNotificationId: notifId,
    );
    await ensureSoundChannelsCreated();

    final platformChannelSpecifics = NotificationDetails(
      android: _buildAndroidDetails(
        channelBaseId: 'AniDash_reminders',
        channelName: 'Continue Watching Reminders',
        channelDescription: 'Reminders to continue watching your paused anime',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );

    await flutterLocalNotificationsPlugin.show(
      notifId,
      title,
      body,
      platformChannelSpecifics,
      payload: mediaId != null ? 'details:$mediaId?tab=episodes' : '/watchlist',
    );
  }

  Future<void> cancelNotification(int id) async {
    try {
      await flutterLocalNotificationsPlugin.cancel(id);
    } catch (_) {}
  }

  Future<void> cancelAllNotifications() async {
    try {
      await flutterLocalNotificationsPlugin.cancelAll();
    } catch (_) {}
  }

  Future<void> showUpdateAvailableNotification(String version) async {
    const notifId = 1901;
    await NotificationInboxService().add(
      title: 'AniDash v$version is available',
      body: 'A new stable version is ready to install.',
      route: '/settings/update',
      dedupeKey: 'update:$version',
      systemNotificationId: notifId,
    );
    await ensureSoundChannelsCreated();

    final details = NotificationDetails(
      android: _buildAndroidDetails(
        channelBaseId: 'AniDash_updates',
        channelName: 'App Updates',
        channelDescription:
            'Notifications when a new AniDash version is available',
        styleInformation: const BigTextStyleInformation(
          'A new version has been released on GitHub. Tap to update or snooze.',
          contentTitle: 'AniDash Update Available',
          summaryText: 'New version available',
        ),
        actions: const <AndroidNotificationAction>[
          AndroidNotificationAction(
            'update_now',
            'Update Now',
            cancelNotification: true,
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            'update_remind_1h',
            'Remind in 1h',
            cancelNotification: true,
            showsUserInterface: false,
          ),
          AndroidNotificationAction(
            'update_skip_day',
            'Skip for today',
            cancelNotification: true,
            showsUserInterface: false,
          ),
        ],
      ),
    );
    await flutterLocalNotificationsPlugin.show(
      1901,
      'AniDash v$version is available',
      'A new version has been released on GitHub. Tap to update or snooze.',
      details,
      payload: 'update:$version',
    );
  }

  Future<void> showPlaybackNotification({
    required String animeTitle,
    required String episodeTitle,
    required int episodeNumber,
    required bool isPlaying,
    String? posterUrl,
  }) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'AniDash_playback_channel',
          'Media Playback',
          channelDescription:
              'Controls for active media playback and lock screen controls',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          showWhen: false,
          color: const Color(0xFFE91E63),
          icon: _iconName,
          styleInformation: const MediaStyleInformation(
            htmlFormatContent: false,
            htmlFormatTitle: false,
          ),
          actions: <AndroidNotificationAction>[
            const AndroidNotificationAction(
              'prev',
              'Previous',
              cancelNotification: false,
              showsUserInterface: false,
            ),
            AndroidNotificationAction(
              'play_pause',
              isPlaying ? 'Pause' : 'Play',
              cancelNotification: false,
              showsUserInterface: false,
            ),
            const AndroidNotificationAction(
              'next',
              'Next',
              cancelNotification: false,
              showsUserInterface: false,
            ),
          ],
        );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      9999,
      '$animeTitle - EP $episodeNumber',
      episodeTitle,
      platformChannelSpecifics,
    );
  }

  Future<void> hidePlaybackNotification() async {
    await flutterLocalNotificationsPlugin.cancel(9999);
  }
}
