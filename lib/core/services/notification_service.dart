import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ani_dash/core/utils/app_logger.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _iconName = '@drawable/ic_launcher_foreground';
  static const String _largeIconName = '@mipmap/ic_launcher';
  static const Color _brandColor = Color(0xFF4CAF50);

  Future<void> initialize() async {
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
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        AppLogger.infoPair('Notification tapped', response.payload);
      },
    );

    await _createNotificationChannels();
  }

  Future<void> _createNotificationChannels() async {
    final androidImplementation = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    const AndroidNotificationChannel newsChannel = AndroidNotificationChannel(
      'AniDash_news_channel',
      'AniDash News',
      description: 'Notifications for latest anime news',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    const AndroidNotificationChannel episodeChannel = AndroidNotificationChannel(
      'AniDash_episodes_channel',
      'Episode Releases',
      description: 'Notifications when new Sub or Dub episodes are released',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    const AndroidNotificationChannel downloadChannel = AndroidNotificationChannel(
      'AniDash_downloads_channel',
      'Downloads',
      description: 'Download progress and completed status',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
      showBadge: false,
    );

    const AndroidNotificationChannel reminderChannel = AndroidNotificationChannel(
      'AniDash_reminders_channel',
      'Continue Watching Reminders',
      description: 'Reminders to continue watching your paused anime',
      importance: Importance.defaultImportance,
      playSound: true,
      enableVibration: true,
    );

    await androidImplementation?.createNotificationChannel(newsChannel);
    await androidImplementation?.createNotificationChannel(episodeChannel);
    await androidImplementation?.createNotificationChannel(downloadChannel);
    await androidImplementation?.createNotificationChannel(reminderChannel);
  }

  Future<void> showNewsNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'AniDash_news_channel',
          'AniDash News',
          channelDescription: 'Notifications for latest anime news',
          importance: Importance.high,
          priority: Priority.high,
          icon: _iconName,
          largeIcon: DrawableResourceAndroidBitmap(_largeIconName),
          color: _brandColor,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      1000,
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

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
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
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'AniDash_episodes_channel',
          'Episode Releases',
          channelDescription: 'Notifications when new Sub or Dub episodes are released',
          importance: Importance.high,
          priority: Priority.high,
          icon: _iconName,
          largeIcon: DrawableResourceAndroidBitmap(_largeIconName),
          color: _brandColor,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    final type = isDub ? 'dub ' : '';
    await flutterLocalNotificationsPlugin.show(
      animeTitle.hashCode ^ episodeNumber,
      'New ${type.toUpperCase()}Episode Released!',
      'New ${type}episode $episodeNumber of $animeTitle has been released. You can watch on AniDash.',
      platformChannelSpecifics,
    );
  }

  Future<void> showContinueWatchingNotification({
    required String animeTitle,
    required int episodeNumber,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'AniDash_reminders_channel',
          'Continue Watching Reminders',
          channelDescription: 'Reminders to continue watching your paused anime',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: _iconName,
          largeIcon: DrawableResourceAndroidBitmap(_largeIconName),
          color: _brandColor,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      animeTitle.hashCode,
      'Continue Watching',
      'You stopped at Episode $episodeNumber of $animeTitle. Watch more on AniDash!',
      platformChannelSpecifics,
    );
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }
}
