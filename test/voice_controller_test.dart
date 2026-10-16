import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_ears/controllers/library_controller.dart';
import 'package:little_ears/controllers/voice_controller.dart';
import 'package:little_ears/models/track.dart';
import 'package:little_ears/services/speech_input.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers.dart';

class FakeSpeechInput implements SpeechInput {
  bool available = true;
  void Function(String, bool)? result;
  Completer<void>? stopGate;
  @override
  Future<bool> initialize({
    required void Function(String) onStatus,
    required void Function(String) onError,
  }) async => available;
  @override
  Future<List<String>> locales() async => ['zh_CN'];
  @override
  Future<void> listen({
    required String locale,
    required void Function(String, bool) onResult,
  }) async {
    result = onResult;
  }

  @override
  Future<void> stop() async {
    await stopGate?.future;
  }

  @override
  Future<void> cancel() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LibraryController library;
  late VoiceController voice;
  late FakeSpeechInput speech;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    library = LibraryController(
      tracks: await loadCatalog(),
      engine: FakeEngine(),
      preferences: await SharedPreferences.getInstance(),
    );
    speech = FakeSpeechInput();
    voice = VoiceController(library, input: speech);
    await library.playTrack(library.tracks.first);
  });
  tearDown(() {
    voice.dispose();
    library.dispose();
  });
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('pause command keeps playback paused after recognition', () async {
    await voice.start();
    expect(library.playing, isFalse);
    speech.result!('暂停', true);
    await settle();
    expect(library.playing, isFalse);
    expect(voice.phase, VoicePhase.finished);
  });
  test('duplicate final results skip only one track', () async {
    await voice.start();
    speech.result!('下一首', true);
    speech.result!('下一首', true);
    await settle();
    expect(library.current.id, library.tracks[1].id);
    expect(library.playing, isTrue);
  });
  test(
    'unavailable recognition restores the previously playing audio',
    () async {
      speech.available = false;
      await voice.start();
      expect(voice.phase, VoicePhase.unavailable);
      expect(library.playing, isTrue);
    },
  );
  test(
    'closing voice panel during processing discards late commands',
    () async {
      await voice.start();
      speech.stopGate = Completer<void>();
      speech.result!('下一首', true);
      await voice.cancel();
      speech.stopGate!.complete();
      await settle();
      expect(library.current.id, library.tracks.first.id);
      expect(library.playing, isTrue);
      expect(voice.phase, VoicePhase.ready);
    },
  );
  test(
    'non-playback commands restore audio and preserve timer choice',
    () async {
      await voice.start();
      speech.result!('定时十分钟', true);
      await settle();
      expect(library.playing, isTrue);
      expect(library.sleepAt, isNotNull);
      expect(voice.feedback, '10分钟后停止播放');
    },
  );
}
