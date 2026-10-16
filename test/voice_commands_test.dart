import 'package:flutter_test/flutter_test.dart';
import 'package:little_ears/models/track.dart';
import 'package:little_ears/services/voice_commands.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<Track> tracks;
  setUpAll(() async {
    tracks = await loadCatalog();
  });

  test('recognizes category requests and exact track titles', () {
    expect(
      parseVoiceCommand('小耳朵，播放儿歌。', tracks).category,
      TrackCategory.rhymes,
    );
    expect(parseVoiceCommand('请播放生活英语', tracks).category, TrackCategory.daily);
    expect(parseVoiceCommand('我要听故事', tracks).category, TrackCategory.stories);
    expect(parseVoiceCommand('播放早安，好心情', tracks).trackId, 'good_morning');
    expect(
      parseVoiceCommand('Play Good Morning', tracks).trackId,
      'good_morning',
    );
  });
  test('control commands are not confused with general play', () {
    final cases = {
      '暂停播放': CommandType.pause,
      '继续播放': CommandType.play,
      '下一首': CommandType.next,
      '上一首': CommandType.previous,
      '单曲循环': CommandType.repeatOne,
      '列表循环': CommandType.repeatAll,
      '声音小一点': CommandType.volumeDown,
      '声音大一点': CommandType.volumeUp,
      '收藏这首': CommandType.favorite,
      '取消定时': CommandType.cancelTimer,
    };
    for (final entry in cases.entries) {
      expect(
        parseVoiceCommand(entry.key, tracks).type,
        entry.value,
        reason: entry.key,
      );
    }
  });
  test(
    'understands Chinese and Arabic timer values and rejects invalid values',
    () {
      for (final input in ['定时十五分钟', '15分钟后停止', '十五分钟后停止播放']) {
        final command = parseVoiceCommand(input, tracks);
        expect(command.type, CommandType.timer, reason: input);
        expect(command.minutes, 15);
      }
      expect(parseVoiceCommand('定时二十分钟', tracks).minutes, 20);
      expect(parseVoiceCommand('定时两分钟', tracks).minutes, 2);
      expect(parseVoiceCommand('定时0分钟', tracks).type, CommandType.unknown);
      expect(parseVoiceCommand('定时200分钟', tracks).type, CommandType.unknown);
      expect(parseVoiceCommand('定时', tracks).type, CommandType.unknown);
    },
  );
  test('silence, unrelated requests, and negations do not start playback', () {
    for (final input in ['', '今天天气怎么样', '不要播放', '别暂停', '播放天气预报']) {
      expect(
        parseVoiceCommand(input, tracks).type,
        CommandType.unknown,
        reason: input,
      );
    }
  });
}
