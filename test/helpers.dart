import 'package:little_ears/services/playback_engine.dart';
import 'package:little_ears/models/track.dart';

class FakeEngine extends PlaybackEngine {
  bool isPlaying = false;
  bool failNextLoad = false;
  int currentIndex = 0;
  Duration currentPosition = Duration.zero;
  List<Track> loaded = [];
  RepeatSetting repeat = RepeatSetting.off;
  double currentVolume = 1;
  @override
  bool get playing => isPlaying;
  @override
  bool get loading => false;
  @override
  bool get completed => false;
  @override
  int get index => currentIndex;
  @override
  Duration get position => currentPosition;
  @override
  Duration? get duration => loaded.isEmpty ? null : loaded[index].duration;
  @override
  String? get error => null;
  @override
  double get volume => currentVolume;
  @override
  Future<void> prepare(List<Track> tracks, int initialIndex) async {
    if (failNextLoad) {
      failNextLoad = false;
      throw StateError('decoder unavailable');
    }
    loaded = tracks;
    currentIndex = initialIndex;
    currentPosition = Duration.zero;
    notifyListeners();
  }

  @override
  Future<void> play() async {
    isPlaying = true;
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
    notifyListeners();
  }

  @override
  Future<void> seek(Duration position, {int? index}) async {
    if (index != null) currentIndex = index;
    currentPosition = position;
    notifyListeners();
  }

  @override
  Future<void> setRepeat(RepeatSetting repeat) async {
    this.repeat = repeat;
  }

  @override
  Future<void> setVolume(double volume) async {
    currentVolume = volume.clamp(0, 1);
  }
}
