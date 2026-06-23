import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'notification_service.dart';

const _taskName = 'checkForUpdateTask';
const _taskUniqueName = 'nowaUpdateCheck';
const _lastNotifiedKey = 'last_notified_version';

// This runs in a separate isolate — no Flutter UI, no BuildContext
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != _taskName) return Future.value(true);

    try {
      await NotificationService.init();

      final response = await http.get(
        Uri.parse('https://api.github.com/repos/AjaxNova/Nowa-Video-Player-Releases/releases/latest'),
      );

      if (response.statusCode != 200) return Future.value(true);

      final data = jsonDecode(response.body);
      final latestVersion = (data['tag_name'] as String).replaceAll('v', '').trim();

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version.split('+')[0];

      // Version compare (simple)
      final currentParts = currentVersion.split('.').map(int.parse).toList();
      final latestParts = latestVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      bool isNewer = false;
      for (int i = 0; i < 3; i++) {
        final c = i < currentParts.length ? currentParts[i] : 0;
        final l = i < latestParts.length ? latestParts[i] : 0;
        if (l > c) { isNewer = true; break; }
        if (l < c) break;
      }

      if (isNewer) {
        // Don't spam — only notify once per version
        final prefs = await SharedPreferences.getInstance();
        final lastNotified = prefs.getString(_lastNotifiedKey) ?? '';
        if (lastNotified != latestVersion) {
          await NotificationService.showUpdateAvailable(latestVersion);
          await prefs.setString(_lastNotifiedKey, latestVersion);
        }
      }
    } catch (_) {}

    return Future.value(true);
  });
}

class BackgroundUpdateChecker {
  static Future<void> init() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  }

  // Call once at app start — schedules a check every 6 hours
  static Future<void> schedulePeriodicCheck() async {
    await Workmanager().registerPeriodicTask(
      _taskUniqueName,
      _taskName,
      frequency: const Duration(hours: 6),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep, // don't re-register if already scheduled
    );
  }
}
