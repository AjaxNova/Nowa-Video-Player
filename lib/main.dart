import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nova_videoplayer/provider/video_data_provider.dart';
import 'package:nova_videoplayer/screen/splash_screen.dart';
import 'package:provider/provider.dart';

import 'functions/new_playlist_class.dart';

main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  if (!Hive.isAdapterRegistered(PlaylistAdapter().typeId)) {
    Hive.registerAdapter(PlaylistAdapter());
  }

  await Hive.openBox<String>('videoHistory');

  await Hive.openBox<String>('FavoriteDB');

  await Hive.openBox<Playlist>('playlistDb');

  runApp(MultiProvider(providers: [
    ChangeNotifierProvider(
      create: (context) => VideoDataProvider(),
    )
  ], child: const Nova()));
}

class Nova extends StatelessWidget {
  const Nova({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.black,
      ),
      home: const SplashScreen(),
    );
  }
}
