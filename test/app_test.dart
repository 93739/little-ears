import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_ears/controllers/library_controller.dart';
import 'package:little_ears/controllers/voice_controller.dart';
import 'package:little_ears/models/track.dart';
import 'package:little_ears/ui/app.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers.dart';

void main() {
  late List<Track> tracks;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tracks = await loadCatalog();
  });
  Future<void> launch(
    WidgetTester tester,
    Size size, {
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    SharedPreferences.setMockInitialValues({});
    final library = LibraryController(
      tracks: tracks,
      engine: FakeEngine(),
      preferences: await SharedPreferences.getInstance(),
    );
    await tester.pumpWidget(
      LittleEarsApp(library: library, voice: VoiceController(library)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('small Android screen opens player, favorites and voice help', (
    tester,
  ) async {
    await launch(tester, const Size(360, 780));
    expect(find.text('小耳朵'), findsOneWidget);
    await tester.tap(find.text('开始听一听'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('player-play')), findsOneWidget);
    await tester.tap(find.byKey(const Key('player-favorite')));
    await tester.tap(find.byKey(const Key('player-next')));
    await tester.pumpAndSettle();
    expect(find.text('A Colorful Day'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('favorites')));
    await tester.pumpAndSettle();
    expect(find.text('我的小收藏'), findsOneWidget);
    expect(find.text('1 段音频'), findsOneWidget);
    await tester.tap(find.byKey(const Key('favorites')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('voice-open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('voice-start')), findsOneWidget);
    expect(find.text('播放儿歌'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow display and large system text have no overflow', (
    tester,
  ) async {
    await launch(tester, const Size(320, 640), textScale: 1.5);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('mini-player')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
