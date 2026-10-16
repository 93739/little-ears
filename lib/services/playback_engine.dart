import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../models/track.dart';

enum RepeatSetting { off, all, one }

abstract class PlaybackEngine extends ChangeNotifier {
  bool get playing;
  bool get loading;
  bool get completed;
  int get index;
  Duration get position;
  Duration? get duration;
  String? get error;
  double get volume;
  Future<void> prepare(List<Track> tracks, int initialIndex);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position, {int? index});
  Future<void> setRepeat(RepeatSetting repeat);
  Future<void> setVolume(double volume);
}

class JustAudioEngine extends PlaybackEngine {
  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  String? _error;
  bool _disposed = false;

  JustAudioEngine() {
    _subscriptions.addAll([
      _player.playerStateStream.listen((_) => _changed()),
      _player.positionStream.listen((_) => _changed()),
      _player.currentIndexStream.listen((_) => _changed()),
      _player.durationStream.listen((_) => _changed()),
      _player.errorStream.listen((_) {
        _error = '音频暂时无法播放，请再试一次。';
        unawaited(_player.pause());
        _changed();
      }),
    ]);
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  bool get playing => _player.playing && !completed;
  @override
  bool get completed => _player.processingState == ProcessingState.completed;
  @override
  bool get loading =>
      _player.processingState == ProcessingState.loading ||
      _player.processingState == ProcessingState.buffering;
  @override
  int get index => _player.currentIndex ?? 0;
  @override
  Duration get position => _player.position;
  @override
  Duration? get duration => _player.duration;
  @override
  String? get error => _error;
  @override
  double get volume => _player.volume;

  @override
  Future<void> prepare(List<Track> tracks, int initialIndex) async {
    _error = null;
    await _player.setAudioSources(
      tracks
          .map(
            (track) => AudioSource.asset(
              track.asset,
              tag: MediaItem(
                id: track.id,
                title: track.title,
                artist: '小耳朵英语',
                album: track.category.label,
                duration: track.duration,
              ),
            ),
          )
          .toList(),
      initialIndex: initialIndex,
    );
  }

  @override
  Future<void> play() async {
    _error = null;
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    if (completed) await _player.seek(Duration.zero, index: index);
    // play() completes only after playback stops; do not block the UI on it.
    unawaited(
      _player.play().catchError((Object _) {
        _error = '播放未能开始，请点击播放重试。';
        _changed();
      }),
    );
  }

  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> seek(Duration position, {int? index}) =>
      _player.seek(position, index: index);
  @override
  Future<void> setRepeat(RepeatSetting repeat) =>
      _player.setLoopMode(switch (repeat) {
        RepeatSetting.off => LoopMode.off,
        RepeatSetting.all => LoopMode.all,
        RepeatSetting.one => LoopMode.one,
      });
  @override
  Future<void> setVolume(double volume) =>
      _player.setVolume(volume.clamp(0.0, 1.0));
  @override
  void dispose() {
    _disposed = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_player.dispose());
    super.dispose();
  }
}
