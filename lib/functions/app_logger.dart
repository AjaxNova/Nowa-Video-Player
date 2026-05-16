import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';

class AppLogger {
  static const String _boxName = 'appLogs';
  
  static void log(String message) {
    _writeLog('INFO', message);
  }

  static void logError(String message, [dynamic error, StackTrace? stackTrace]) {
    String fullMessage = message;
    if (error != null) {
      fullMessage += '\nError: $error';
    }
    if (stackTrace != null) {
      fullMessage += '\nStackTrace: $stackTrace';
    }
    _writeLog('ERROR', fullMessage);
  }

  static void logWarning(String message) {
    _writeLog('WARNING', message);
  }

  static void _writeLog(String level, String message) {
    final now = DateTime.now();
    final String timestamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    
    final formattedMessage = '[$timestamp] [$level] $message';
    
    // Print to console in debug mode
    debugPrint(formattedMessage);
    
    // Save to Hive persistent storage
    try {
      if (Hive.isBoxOpen(_boxName)) {
        final box = Hive.box<String>(_boxName);
        box.add(formattedMessage);
      }
    } catch (e) {
      debugPrint('Failed to write log to Hive: $e');
    }
  }

  static void clearLogs() {
    try {
      if (Hive.isBoxOpen(_boxName)) {
        Hive.box<String>(_boxName).clear();
      }
    } catch (e) {
      debugPrint('Failed to clear logs: $e');
    }
  }
}
