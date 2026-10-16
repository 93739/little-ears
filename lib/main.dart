import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'controllers/library_controller.dart';
import 'controllers/voice_controller.dart';
import 'models/track.dart';
import 'services/playback_engine.dart';
import 'ui/app.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(appSystemUiStyle);
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.littleears.playback',
      androidNotificationChannelName: '小耳朵英语播放',
      androidNotificationOngoing: true,
      androidNotificationIcon: 'drawable/ic_notification',
    );
    final tracks = await loadCatalog();
    final preferences = await SharedPreferences.getInstance();
    final library = LibraryController(
      tracks: tracks,
      engine: JustAudioEngine(),
      preferences: preferences,
    );
    runApp(LittleEarsApp(library: library, voice: VoiceController(library)));
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('小耳朵暂时未能启动，请关闭后重新打开。'),
            ),
          ),
        ),
      ),
    );
  }
}
