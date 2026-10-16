import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:little_ears/main.dart' as app;
import 'package:little_ears/ui/app.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android real audio playback and controls', (tester) async {
    await app.main();
    await tester.pumpAndSettle();
    expect(find.text('小耳朵'), findsOneWidget);
    final library = tester
        .widget<LittleEarsApp>(find.byType(LittleEarsApp))
        .library;
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    final home = await binding.takeScreenshot('android-home');
    await File(
      '/data/data/com.littleears.little_ears/files/qa-home.png',
    ).writeAsBytes(home);
    await tester.tap(find.text('Hello, Sunshine').first);
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    expect(library.playing, isTrue);
    expect(library.position.inMilliseconds, greaterThan(500));
    final player = await binding.takeScreenshot('android-player');
    await File(
      '/data/data/com.littleears.little_ears/files/qa-player.png',
    ).writeAsBytes(player);
    final before = library.position;
    debugPrint('ANDROID_AUDIO_PLAYING_BACKGROUND_CHECK');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 15)),
    );
    expect(library.playing, isTrue);
    expect(library.position, greaterThan(before));
    await tester.tap(find.byKey(const Key('player-next')));
    await tester.pumpAndSettle();
    expect(library.current.id, 'color_day');
    await tester.tap(find.byKey(const Key('player-play')));
    await tester.pumpAndSettle();
    expect(library.playing, isFalse);
    final wasFavorite = library.favorites.contains('color_day');
    await tester.tap(find.byKey(const Key('player-favorite')));
    expect(library.favorites.contains('color_day'), !wasFavorite);
    await tester.tap(find.byKey(const Key('player-favorite')));
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('voice-open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('voice-start')), findsOneWidget);
  });
}
