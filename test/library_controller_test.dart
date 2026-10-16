import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_ears/controllers/library_controller.dart';
import 'package:little_ears/models/track.dart';
import 'package:little_ears/services/playback_engine.dart';
import 'package:little_ears/services/voice_commands.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LibraryController library;
  late FakeEngine engine;
  late List<Track> tracks;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tracks = await loadCatalog();
    engine = FakeEngine();
    library = LibraryController(
      tracks: tracks,
      engine: engine,
      preferences: await SharedPreferences.getInstance(),
    );
  });
  tearDown(() => library.dispose());

  test(
    'manual next and previous wrap even when single-track repeat is enabled',
    () async {
      final queue = tracks.take(2).toList();
      await library.playTrack(queue.last, within: queue);
      await library.setRepeat(RepeatSetting.one);
      await library.skip(1);
      expect(library.current.id, queue.first.id);
      await library.skip(-1);
      expect(library.current.id, queue.last.id);
      expect(engine.repeat, RepeatSetting.one);
    },
  );
  test(
    'category voice command changes both track and playback queue',
    () async {
      await library.execute(
        const VoiceCommand(CommandType.category, category: TrackCategory.daily),
      );
      expect(library.queue.length, 4);
      expect(
        library.queue.every((track) => track.category == TrackCategory.daily),
        isTrue,
      );
      expect(library.playing, isTrue);
    },
  );
  test('favorite voice command is idempotent and persists', () async {
    await library.execute(const VoiceCommand(CommandType.favorite));
    await library.execute(const VoiceCommand(CommandType.favorite));
    expect(library.favorites, {tracks.first.id});
    expect(library.preferences.getStringList('favorites'), [tracks.first.id]);
    await library.toggleFavorite(tracks.first);
    expect(library.favorites, isEmpty);
  });
  test(
    'replacing and cancelling sleep timer does not leave a stale deadline',
    () async {
      await library.playTrack(tracks.first);
      fakeAsync((clock) {
        library.setSleepTimer(5);
        clock.elapse(const Duration(minutes: 2));
        library.setSleepTimer(10);
        clock.elapse(const Duration(minutes: 4));
        expect(engine.playing, isTrue);
        library.setSleepTimer(null);
        clock.elapse(const Duration(minutes: 20));
        expect(engine.playing, isTrue);
        expect(library.remaining, isNull);
      });
    },
  );
  test('sleep deadline pauses once and resets the countdown', () async {
    await library.playTrack(tracks.first);
    fakeAsync((clock) {
      library.setSleepTimer(5);
      clock.elapse(const Duration(minutes: 5));
      clock.flushMicrotasks();
      expect(engine.playing, isFalse);
      expect(library.remaining, isNull);
      expect(library.message, contains('定时结束'));
    });
  });
  test('failed load leaves player usable for a retry', () async {
    engine.failNextLoad = true;
    expect(await library.playTrack(tracks.first), isFalse);
    expect(library.message, isNotNull);
    expect(library.busy, isFalse);
    expect(await library.playTrack(tracks.first), isTrue);
    expect(library.playing, isTrue);
  });
  test('bundled content has ordered subtitles within actual durations', () {
    expect(tracks.length, 12);
    expect(tracks.map((track) => track.id).toSet().length, 12);
    for (final track in tracks) {
      expect(track.captions, isNotEmpty);
      var previous = Duration.zero;
      for (final caption in track.captions) {
        expect(caption.at >= previous, isTrue);
        expect(caption.at < track.duration, isTrue);
        expect(caption.english, isNotEmpty);
        previous = caption.at;
      }
      expect(
        track.captionAt(track.duration).english,
        track.captions.last.english,
      );
    }
  });
}
