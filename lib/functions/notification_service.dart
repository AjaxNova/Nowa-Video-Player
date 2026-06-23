import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    await _plugin.initialize(settings: const InitializationSettings(android: androidSettings));
  }

  static Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // Call this repeatedly during download to show progress in notification bar
  static Future<void> showDownloadProgress(int percent) async {
    await _plugin.show(
      id: 1,
      title: 'Downloading NOWA Update',
      body: '$percent% complete',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'update_download',
          'App Update',
          channelDescription: 'Shows download progress for app updates',
          importance: Importance.low,
          priority: Priority.low,
          showProgress: true,
          maxProgress: 100,
          progress: percent,
          ongoing: true,        // ← this keeps it persistent = keeps foreground alive
          autoCancel: false,
        ),
      ),
    );
  }

  static Future<void> showUpdateReady() async {
    await _plugin.cancel(id: 1);
    await _plugin.show(
      id: 2,
      title: '✅ NOWA Update Ready',
      body: 'Open the app to install the latest version.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'update_ready',
          'Update Ready',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  // Called by WorkManager background check
  static Future<void> showUpdateAvailable(String version) async {
    await _plugin.show(
      id: 3,
      title: '🚀 NOWA $version is available!',
      body: 'Tap to open the app and update.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'update_available',
          'Update Available',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
    );
  }

  static Future<void> cancelDownloadNotification() async {
    await _plugin.cancel(id: 1);
  }
}
