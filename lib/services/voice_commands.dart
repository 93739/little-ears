import '../models/track.dart';

enum CommandType {
  play,
  pause,
  next,
  previous,
  category,
  track,
  favorite,
  timer,
  cancelTimer,
  repeatOne,
  repeatAll,
  volumeUp,
  volumeDown,
  unknown,
}

class VoiceCommand {
  const VoiceCommand(this.type, {this.category, this.trackId, this.minutes});
  final CommandType type;
  final TrackCategory? category;
  final String? trackId;
  final int? minutes;
}

VoiceCommand parseVoiceCommand(String input, List<Track> tracks) {
  final text = _normalize(input);
  if (text.isEmpty || RegExp(r'不要|不想|别|不需要|don.?t|donot').hasMatch(text)) {
    return const VoiceCommand(CommandType.unknown);
  }
  if (RegExp(r'取消定时|关闭定时|取消计时|canceltimer').hasMatch(text)) {
    return const VoiceCommand(CommandType.cancelTimer);
  }
  if (RegExp(r'定时|分钟后|minutes?|计时').hasMatch(text)) {
    final match = RegExp(
      r'(\d+|[零一二两三四五六七八九十半]+)(?:个)?(?:分钟|minutes?)',
    ).firstMatch(text);
    if (match != null) {
      final raw = match.group(1)!;
      final minutes = int.tryParse(raw) ?? _chineseNumber(raw);
      if (minutes != null && minutes >= 1 && minutes <= 120) {
        return VoiceCommand(CommandType.timer, minutes: minutes);
      }
    }
    return const VoiceCommand(CommandType.unknown);
  }
  if (RegExp(r'下一首|下一个|下一曲|next').hasMatch(text)) {
    return const VoiceCommand(CommandType.next);
  }
  if (RegExp(r'上一首|上一个|上一曲|previous').hasMatch(text)) {
    return const VoiceCommand(CommandType.previous);
  }
  if (RegExp(r'单曲循环|repeatone').hasMatch(text)) {
    return const VoiceCommand(CommandType.repeatOne);
  }
  if (RegExp(r'列表循环|全部循环|repeatall').hasMatch(text)) {
    return const VoiceCommand(CommandType.repeatAll);
  }
  if (RegExp(r'大声|大点|调大|大一点|volumeup|louder').hasMatch(text)) {
    return const VoiceCommand(CommandType.volumeUp);
  }
  if (RegExp(r'小声|小点|调小|小一点|volumedown|quieter').hasMatch(text)) {
    return const VoiceCommand(CommandType.volumeDown);
  }
  if (RegExp(r'收藏|favorite').hasMatch(text)) {
    return const VoiceCommand(CommandType.favorite);
  }
  if (RegExp(r'暂停|停止播放|停止|停一下|pause|stop').hasMatch(text)) {
    return const VoiceCommand(CommandType.pause);
  }
  for (final track in tracks) {
    final title = _normalize(track.title);
    if (text.contains(_normalize(track.subtitle)) || text.contains(title)) {
      return VoiceCommand(CommandType.track, trackId: track.id);
    }
  }
  if (RegExp(r'儿歌|童谣|rhymes|songs').hasMatch(text)) {
    return const VoiceCommand(
      CommandType.category,
      category: TrackCategory.rhymes,
    );
  }
  if (RegExp(r'故事|stories|story').hasMatch(text)) {
    return const VoiceCommand(
      CommandType.category,
      category: TrackCategory.stories,
    );
  }
  if (RegExp(r'生活英语|短句|日常英语|daily').hasMatch(text)) {
    return const VoiceCommand(
      CommandType.category,
      category: TrackCategory.daily,
    );
  }
  final simple = text.replaceAll(RegExp(r'小耳朵|请|帮我|给我|我要|我想|一下|吧|please'), '');
  if (RegExp(
    r'^(播放|继续播放|开始播放|继续|开始听|播放音乐|play|playmusic|resume)$',
  ).hasMatch(simple)) {
    return const VoiceCommand(CommandType.play);
  }
  return const VoiceCommand(CommandType.unknown);
}

String _normalize(String text) =>
    text.toLowerCase().replaceAll(RegExp(r'[\s，。！？、,.!?\-]'), '');

int? _chineseNumber(String text) {
  const digits = {
    '零': 0,
    '一': 1,
    '二': 2,
    '两': 2,
    '三': 3,
    '四': 4,
    '五': 5,
    '六': 6,
    '七': 7,
    '八': 8,
    '九': 9,
  };
  if (digits.containsKey(text)) return digits[text];
  if (text.contains('十')) {
    final parts = text.split('十');
    if (parts.length != 2) return null;
    final tens = parts[0].isEmpty ? 1 : digits[parts[0]];
    final units = parts[1].isEmpty ? 0 : digits[parts[1]];
    if (tens != null && units != null) return tens * 10 + units;
  }
  return null;
}
