import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:ota_update/ota_update.dart';
import 'global_variables.dart';
import 'notification_service.dart';

enum UpdateStatus {
  idle,
  checking,
  available,
  downloading,
  installing,
  error,
  noUpdate,
}

class UpdateProgress {
  final UpdateStatus status;
  final double percentage; // 0.0 to 100.0
  final String errorMessage;

  const UpdateProgress({
    required this.status,
    required this.percentage,
    this.errorMessage = '',
  });
}

class AppUpdateService {
  static final AppUpdateService instance = AppUpdateService._internal();
  AppUpdateService._internal();

  final ValueNotifier<UpdateProgress> progressNotifier = ValueNotifier<UpdateProgress>(
    const UpdateProgress(status: UpdateStatus.idle, percentage: 0.0),
  );

  bool _isChecking = false;

  /// Compares SemVer versions (e.g. 1.0.0 and 1.0.1)
  bool _isNewerVersion(String currentVersion, String latestVersion) {
    String cleanCurrent = currentVersion.replaceAll('v', '').trim();
    String cleanLatest = latestVersion.replaceAll('v', '').trim();

    if (cleanCurrent.contains('+')) {
      cleanCurrent = cleanCurrent.split('+')[0];
    }
    if (cleanLatest.contains('+')) {
      cleanLatest = cleanLatest.split('+')[0];
    }

    final currentParts = cleanCurrent.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final latestParts = cleanLatest.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final maxLen = currentParts.length > latestParts.length ? currentParts.length : latestParts.length;

    for (int i = 0; i < maxLen; i++) {
      final currentPart = i < currentParts.length ? currentParts[i] : 0;
      final latestPart = i < latestParts.length ? latestParts[i] : 0;
      if (latestPart > currentPart) return true;
      if (latestPart < currentPart) return false;
    }
    return false;
  }

  /// Detects the target device ABI/architecture to fetch the correct split APK asset
  Future<String> _getApkNameForArchitecture() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final supportedAbis = androidInfo.supportedAbis;
      
      if (supportedAbis.contains('arm64-v8a')) {
        return 'app-arm64-v8a-release.apk';
      } else if (supportedAbis.contains('armeabi-v7a')) {
        return 'app-armeabi-v7a-release.apk';
      } else if (supportedAbis.contains('x86_64')) {
        return 'app-x86_64-release.apk';
      }
    } catch (_) {}
    return 'app-arm64-v8a-release.apk'; // Default fallback
  }

  /// Checks for updates against GitHub Releases.
  /// If [showNoUpdateDialog] is true (for manual settings click), it will notify the user if they're up to date.
  Future<void> checkForUpdates({
    required BuildContext context,
    bool showNoUpdateDialog = false,
  }) async {
    if (_isChecking) return;
    _isChecking = true;

    if (showNoUpdateDialog) {
      progressNotifier.value = const UpdateProgress(status: UpdateStatus.checking, percentage: 0.0);
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await http.get(
        Uri.parse('https://api.github.com/repos/AjaxNova/Nowa-Video-Player-Releases/releases/latest'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final latestVersion = data['tag_name'] as String;
        final changelog = data['body'] as String? ?? 'No release notes available.';

        if (_isNewerVersion(currentVersion, latestVersion)) {
          final targetApkName = await _getApkNameForArchitecture();
          final assets = data['assets'] as List<dynamic>? ?? [];
          
          String? downloadUrl;
          for (final asset in assets) {
            if (asset['name'] == targetApkName) {
              downloadUrl = asset['browser_download_url'] as String;
              break;
            }
          }

          // Fallback to the first asset if exact arch asset isn't found
          if (downloadUrl == null && assets.isNotEmpty) {
            downloadUrl = assets.first['browser_download_url'] as String;
          }

          if (downloadUrl != null && context.mounted) {
            _showUpdateDialog(
              context: context,
              latestVersion: latestVersion,
              currentVersion: currentVersion,
              changelog: changelog,
              downloadUrl: downloadUrl,
              apkName: targetApkName,
            );
          }
        } else {
          if (showNoUpdateDialog && context.mounted) {
            progressNotifier.value = const UpdateProgress(status: UpdateStatus.noUpdate, percentage: 0.0);
            _showSnackBar(context, 'You are on the latest version ($currentVersion).');
          }
        }
      } else {
        if (showNoUpdateDialog && context.mounted) {
          _showSnackBar(context, 'Unable to verify updates from GitHub.');
        }
      }
    } catch (e) {
      if (showNoUpdateDialog && context.mounted) {
        _showSnackBar(context, 'Failed checking updates: $e');
      }
    } finally {
      _isChecking = false;
      if (progressNotifier.value.status == UpdateStatus.checking) {
        progressNotifier.value = const UpdateProgress(status: UpdateStatus.idle, percentage: 0.0);
      }
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontSize: 12.sp, color: Colors.white)),
        backgroundColor: Colors.grey.shade900,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showUpdateDialog({
    required BuildContext context,
    required String latestVersion,
    required String currentVersion,
    required String changelog,
    required String downloadUrl,
    required String apkName,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetContext) {
        return _UpdateModal(
          latestVersion: latestVersion,
          currentVersion: currentVersion,
          changelog: changelog,
          downloadUrl: downloadUrl,
          apkName: apkName,
          service: this,
        );
      },
    );
  }

  /// Initiates OTA update download and install process
  void startUpdate(String downloadUrl, String apkName) {
    if (progressNotifier.value.status == UpdateStatus.downloading) return;

    progressNotifier.value = const UpdateProgress(status: UpdateStatus.downloading, percentage: 0.0);

    try {
      OtaUpdate().execute(
        downloadUrl,
        destinationFilename: apkName,
      ).listen(
        (OtaEvent event) {
          debugPrint('[OTA] Status: ${event.status}, Value: ${event.value}');
          switch (event.status) {
            case OtaStatus.DOWNLOADING:
              final percentage = double.tryParse(event.value ?? '0') ?? 0.0;
              progressNotifier.value = UpdateProgress(
                status: UpdateStatus.downloading,
                percentage: percentage,
              );
              NotificationService.showDownloadProgress(percentage.toInt());
              break;
            case OtaStatus.INSTALLING:
              debugPrint('[OTA] System installer launching...');
              progressNotifier.value = const UpdateProgress(
                status: UpdateStatus.installing,
                percentage: 100.0,
              );
              NotificationService.showUpdateReady();
              break;
            case OtaStatus.INSTALLATION_DONE:
              debugPrint('[OTA] Installation complete!');
              progressNotifier.value = const UpdateProgress(
                status: UpdateStatus.installing,
                percentage: 100.0,
              );
              NotificationService.showUpdateReady();
              break;
            case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
              debugPrint('[OTA] Install permission denied!');
              NotificationService.cancelDownloadNotification();
              progressNotifier.value = const UpdateProgress(
                status: UpdateStatus.error,
                percentage: 0.0,
                errorMessage: 'Install permission denied. Enable "Install unknown apps" for this app in Settings.',
              );
              break;
            case OtaStatus.ALREADY_RUNNING_ERROR:
            case OtaStatus.CHECKSUM_ERROR:
            case OtaStatus.INTERNAL_ERROR:
            case OtaStatus.DOWNLOAD_ERROR:
            case OtaStatus.INSTALLATION_ERROR:
            case OtaStatus.CANCELED:
              debugPrint('[OTA] Error: ${event.status.name}');
              NotificationService.cancelDownloadNotification();
              progressNotifier.value = UpdateProgress(
                status: UpdateStatus.error,
                percentage: 0.0,
                errorMessage: 'Installer state: ${event.status.name}',
              );
              break;
          }
        },
        onError: (err) {
          debugPrint('[OTA] Stream error: $err');
          NotificationService.cancelDownloadNotification();
          progressNotifier.value = UpdateProgress(
            status: UpdateStatus.error,
            percentage: 0.0,
            errorMessage: err.toString(),
          );
        },
      );
    } catch (e) {
      progressNotifier.value = UpdateProgress(
        status: UpdateStatus.error,
        percentage: 0.0,
        errorMessage: e.toString(),
      );
    }
  }
}

class _UpdateModal extends StatefulWidget {
  final String latestVersion;
  final String currentVersion;
  final String changelog;
  final String downloadUrl;
  final String apkName;
  final AppUpdateService service;

  const _UpdateModal({
    required this.latestVersion,
    required this.currentVersion,
    required this.changelog,
    required this.downloadUrl,
    required this.apkName,
    required this.service,
  });

  @override
  State<_UpdateModal> createState() => _UpdateModalState();
}

class _UpdateModalState extends State<_UpdateModal> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 36.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36.w,
              height: 3.5.h,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          SizedBox(height: 20.h),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Update Available',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: colorGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: colorGreen.withValues(alpha: 0.3), width: 0.5),
                ),
                child: Text(
                  widget.latestVersion,
                  style: TextStyle(
                    color: colorGreen,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            'Current version: ${widget.currentVersion}',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11.sp,
            ),
          ),
          SizedBox(height: 16.h),
          Divider(color: Colors.white12, thickness: 0.5),
          SizedBox(height: 12.h),

          // Release Notes
          Text(
            'RELEASE NOTES',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.2),
              fontSize: 9.sp,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 8.h),
          Container(
            constraints: BoxConstraints(maxHeight: 180.h),
            width: double.infinity,
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 0.5),
            ),
            child: SingleChildScrollView(
              child: Text(
                widget.changelog,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11.sp,
                  height: 1.5,
                ),
              ),
            ),
          ),
          SizedBox(height: 24.h),

          // Download status & progress handler
          ValueListenableBuilder<UpdateProgress>(
            valueListenable: widget.service.progressNotifier,
            builder: (context, progress, child) {
              final isIdle = progress.status == UpdateStatus.idle || progress.status == UpdateStatus.noUpdate;
              final isDownloading = progress.status == UpdateStatus.downloading;
              final isInstalling = progress.status == UpdateStatus.installing;
              final isError = progress.status == UpdateStatus.error;

              if (isDownloading) {
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Downloading update...',
                          style: TextStyle(color: Colors.white70, fontSize: 12.sp, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${progress.percentage.toStringAsFixed(0)}%',
                          style: TextStyle(color: colorGreen, fontSize: 12.sp, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3.r),
                      child: LinearProgressIndicator(
                        value: progress.percentage / 100.0,
                        color: colorGreen,
                        backgroundColor: Colors.white10,
                        minHeight: 6.h,
                      ),
                    ),
                  ],
                );
              }

              if (isInstalling) {
                return Center(
                  child: Column(
                    children: [
                      SizedBox(
                        width: 20.w,
                        height: 20.w,
                        child: CircularProgressIndicator(color: colorGreen, strokeWidth: 2),
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        'Launching system installer...',
                        style: TextStyle(color: Colors.white70, fontSize: 12.sp, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  if (isError) ...[
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(10.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A0505),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: const Color(0xFF3A1010), width: 0.5),
                      ),
                      child: Text(
                        'Error: ${progress.errorMessage}',
                        style: TextStyle(color: const Color(0xFFE24B4A), fontSize: 11.sp),
                      ),
                    ),
                    SizedBox(height: 16.h),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white10,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 13.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: Text('Not Now', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorGreen,
                            foregroundColor: Colors.black,
                            padding: EdgeInsets.symmetric(vertical: 13.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            elevation: 8,
                            shadowColor: colorGreen.withValues(alpha: 0.4),
                          ),
                          onPressed: () {
                            widget.service.startUpdate(widget.downloadUrl, widget.apkName);
                          },
                          child: Text(
                            isError ? 'Retry Update' : 'Update Now',
                            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
