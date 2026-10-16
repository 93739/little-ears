import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';
import '../services/playback_engine.dart';
import '../services/voice_commands.dart';

class LibraryController extends ChangeNotifier {
  LibraryController({
    required this.tracks,
    required this.engine,
    required this.preferences,
  }) {
    favorites.addAll(preferences.getStringList('favorites') ?? []);
    favorites.removeWhere((id) => !tracks.any((track) => track.id == id));
    final saved = preferences.getString('lastTrack');
    _preview = tracks.firstWhere(
      (track) => track.id == saved,
      orElse: () => tracks.first,
    );
    repeat = RepeatSetting.values.firstWhere(
      (item) => item.name == preferences.getString('repeat'),
      orElse: () => RepeatSetting.off,
    );
    engine.addListener(_onEngine);
  }
  final List<Track> tracks;
  final PlaybackEngine engine;
  final SharedPreferences preferences;
  final Set<String> favorites = {};
  List<Track> _queue = [];
  late Track _preview;
  bool _disposed = false;
  bool _busy = false;
  String? message;
  RepeatSetting repeat = RepeatSetting.off;
  DateTime? sleepAt;
  Timer? _sleepTimer;
  Timer? _countdown;
  bool get busy => _busy || engine.loading;
  bool get playing => engine.playing;
  List<Track> get queue => List.unmodifiable(_queue);
  Track get current => _queue.isEmpty
      ? _preview
      : _queue[engine.index.clamp(0, _queue.length - 1)];
  Duration get position => _queue.isEmpty ? Duration.zero : engine.position;
  Duration get duration => engine.duration ?? current.duration;
  Duration? get remaining => sleepAt == null
      ? null
      : sleepAt!.difference(DateTime.now()).isNegative
      ? Duration.zero
      : sleepAt!.difference(DateTime.now());

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _onEngine() {
    if (engine.error != null) message = engine.error;
    if (_queue.isNotEmpty && preferences.getString('lastTrack') != current.id) {
      unawaited(preferences.setString('lastTrack', current.id));
    }
    _notify();
  }

  Future<bool> _guard(Future<void> Function() action) async {
    if (_disposed || _busy) return false;
    _busy = true;
    message = null;
    _notify();
    try {
      await action();
      return true;
    } catch (_) {
      message = '暂时无法播放，请再试一次。';
      return false;
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<bool> playTrack(Track track, {List<Track>? within}) =>
      _guard(() async {
        final desired =
            within == null || !within.any((item) => item.id == track.id)
            ? tracks
            : within;
        final index = desired.indexWhere((item) => item.id == track.id);
        final sameQueue =
            _queue.length == desired.length &&
            List.generate(
              desired.length,
              (i) => _queue[i].id == desired[i].id,
            ).every((same) => same);
        if (sameQueue) {
          await engine.seek(Duration.zero, index: index);
        } else {
          await engine.pause();
          // A failed prepare may already have replaced the engine's playlist.
          // Clear our old queue so retry always reloads instead of seeking it.
          _preview = track;
          _queue = [];
          await engine.prepare(desired, index);
          _queue = List.of(desired);
        }
        await engine.setRepeat(repeat);
        await engine.play();
      });

  Future<void> resume() async {
    if (_queue.isEmpty) {
      await playTrack(current);
    } else {
      await _guard(engine.play);
    }
  }

  Future<void> pause() => engine.pause();
  Future<void> togglePlay() => playing ? pause() : resume();
  Future<void> skip(int offset) async {
    if (_queue.isEmpty) {
      await playTrack(
        tracks[(tracks.indexOf(current) + offset) % tracks.length],
      );
      return;
    }
    await _guard(() async {
      await engine.seek(
        Duration.zero,
        index: (engine.index + offset) % _queue.length,
      );
      await engine.play();
    });
  }

  Future<void> seek(Duration value) => engine.seek(
    value < Duration.zero
        ? Duration.zero
        : value > duration
        ? duration
        : value,
  );
  Future<void> toggleFavorite(Track track) async {
    if (!favorites.remove(track.id)) favorites.add(track.id);
    _notify();
    await preferences.setStringList('favorites', favorites.toList());
  }

  Future<void> setRepeat(RepeatSetting value) async {
    repeat = value;
    await engine.setRepeat(value);
    await preferences.setString('repeat', value.name);
    _notify();
  }

  void setSleepTimer(int? minutes) {
    _sleepTimer?.cancel();
    _countdown?.cancel();
    sleepAt = minutes == null
        ? null
        : DateTime.now().add(Duration(minutes: minutes));
    if (minutes != null) {
      _sleepTimer = Timer(Duration(minutes: minutes), () {
        unawaited(pause());
        sleepAt = null;
        _countdown?.cancel();
        message = '定时结束，休息一下吧。';
        _notify();
      });
      _countdown = Timer.periodic(const Duration(seconds: 1), (_) => _notify());
    }
    _notify();
  }

  Future<String> execute(VoiceCommand command) async {
    switch (command.type) {
      case CommandType.play:
        await resume();
        return message ?? '继续播放';
      case CommandType.pause:
        await pause();
        return '已暂停播放';
      case CommandType.next:
        await skip(1);
        return message ?? '播放下一首';
      case CommandType.previous:
        await skip(-1);
        return message ?? '播放上一首';
      case CommandType.category:
        final selection = tracks
            .where((track) => track.category == command.category)
            .toList();
        final ok = await playTrack(selection.first, within: selection);
        return ok ? '播放${command.category!.label}' : message!;
      case CommandType.track:
        final track = tracks.firstWhere((track) => track.id == command.trackId);
        final ok = await playTrack(track);
        return ok ? '播放${track.subtitle}' : message!;
      case CommandType.favorite:
        if (!favorites.contains(current.id)) await toggleFavorite(current);
        return '已收藏${current.subtitle}';
      case CommandType.timer:
        setSleepTimer(command.minutes);
        return '${command.minutes}分钟后停止播放';
      case CommandType.cancelTimer:
        setSleepTimer(null);
        return '已取消定时';
      case CommandType.repeatOne:
        await setRepeat(RepeatSetting.one);
        return '已开启单曲循环';
      case CommandType.repeatAll:
        await setRepeat(RepeatSetting.all);
        return '已开启列表循环';
      case CommandType.volumeUp:
        await engine.setVolume(engine.volume + 0.15);
        return '已调大播放音量';
      case CommandType.volumeDown:
        await engine.setVolume(engine.volume - 0.15);
        return '已调小播放音量';
      case CommandType.unknown:
        return '试试说“播放儿歌”“下一首”或“定时十分钟”';
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _sleepTimer?.cancel();
    _countdown?.cancel();
    engine.removeListener(_onEngine);
    engine.dispose();
    super.dispose();
  }
}
