import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nova_videoplayer/functions/global_variables.dart';
import 'package:nova_videoplayer/functions/app_logger.dart';

class AppLogsScreen extends StatelessWidget {
  const AppLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorBlack,
      appBar: AppBar(
        backgroundColor: colorBlack,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('App Logs', style: TextStyle(color: Colors.white, fontFamily: 'poppins')),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_rounded),
            tooltip: 'Copy All Logs',
            onPressed: () async {
              final box = Hive.box<String>('appLogs');
              if (box.isEmpty) return;
              final logs = box.values.toList().reversed.join('\n\n');
              await Clipboard.setData(ClipboardData(text: logs));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All logs copied to clipboard'), duration: Duration(seconds: 2)),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            tooltip: 'Clear Logs',
            onPressed: () {
              AppLogger.clearLogs();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ValueListenableBuilder<Box<String>>(
          valueListenable: Hive.box<String>('appLogs').listenable(),
          builder: (context, box, _) {
            if (box.isEmpty) {
              return Center(
                child: Text(
                  'No logs recorded yet.',
                  style: TextStyle(color: Colors.white54, fontSize: 16.sp),
                ),
              );
            }

            // Show newest logs at the top
            final logs = box.values.toList().reversed.toList();

            return ListView.separated(
              padding: EdgeInsets.all(12.w),
              itemCount: logs.length,
              separatorBuilder: (context, index) => Divider(color: Colors.white10, height: 24.h),
              itemBuilder: (context, index) {
                final log = logs[index];
                Color textColor = Colors.white70;
                if (log.contains('[ERROR]')) textColor = Colors.redAccent;
                if (log.contains('[WARNING]')) textColor = Colors.orangeAccent;
                
                return SelectableText(
                  log,
                  style: TextStyle(
                    color: textColor,
                    fontFamily: 'monospace',
                    fontSize: 11.sp,
                    height: 1.4,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
