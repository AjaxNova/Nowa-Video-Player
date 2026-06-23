import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:media_kit/media_kit.dart';
import 'package:nova_videoplayer/provider/video_data_provider.dart';
import 'package:nova_videoplayer/screen/splash_screen.dart';
import 'package:provider/provider.dart';

import 'functions/new_playlist_class.dart';
import 'functions/global_variables.dart';
import 'functions/notification_service.dart';
import 'functions/background_update_checker.dart';

main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  await NotificationService.requestPermission();
  await BackgroundUpdateChecker.init();
  await BackgroundUpdateChecker.schedulePeriodicCheck();
  MediaKit.ensureInitialized();
  await Hive.initFlutter();

  if (!Hive.isAdapterRegistered(NovaPlaylistAdapter().typeId)) {
    Hive.registerAdapter(NovaPlaylistAdapter());
  }

  await Future.wait([
    Hive.openBox<String>('videoHistory'),
    Hive.openBox<String>('FavoriteDB'),
    Hive.openBox<NovaPlaylist>('playlistDb'),
    Hive.openBox<String>('appLogs'),
    Hive.openBox<dynamic>('appSettings'),
  ]);

  await checkHardwareCapability();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => VideoDataProvider()),
      ],
      child: const Nova(),
    ),
  );
}

class Nova extends StatelessWidget {
  const Nova({super.key});
  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primaryColor: Colors.black,
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}
