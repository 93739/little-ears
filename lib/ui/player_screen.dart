import 'package:flutter/material.dart';
import '../controllers/library_controller.dart';
import '../controllers/voice_controller.dart';
import '../models/track.dart';
import '../services/playback_engine.dart';
import 'sheets.dart';
import 'theme.dart';
import 'widgets/illustration.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key, required this.library, required this.voice});
  final LibraryController library;
  final VoiceController voice;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([library, voice]),
    builder: (context, _) {
      final track = library.current;
      final caption = track.captionAt(library.position);
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: '返回',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 32,
                          ),
                        ),
                        const Expanded(
                          child: Column(
                            children: [
                              Text(
                                '正在听',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'A LITTLE MOMENT OF ENGLISH',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: muted,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          key: const Key('player-favorite'),
                          tooltip: library.favorites.contains(track.id)
                              ? '取消收藏'
                              : '收藏',
                          onPressed: () => library.toggleFavorite(track),
                          icon: Icon(
                            library.favorites.contains(track.id)
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: library.favorites.contains(track.id)
                                ? coral
                                : ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(30, 12, 30, 16),
                        child: Column(
                          children: [
                            SizedBox(
                              width: constraints.maxHeight < 800 ? 195 : 270,
                              height: constraints.maxHeight < 800 ? 175 : 250,
                              child: CoverArt(
                                scene: track.art,
                                color: Color(track.color),
                                radius: 36,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              track.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w800,
                                color: ink,
                                letterSpacing: -.5,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${track.subtitle} · ${track.category.label}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: muted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: Container(
                                key: ValueKey('${track.id}-${caption.english}'),
                                width: double.infinity,
                                constraints: const BoxConstraints(
                                  minHeight: 68,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      caption.english,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 19,
                                        height: 1.5,
                                        fontWeight: FontWeight.w600,
                                        color: ink,
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    Text(
                                      caption.chinese,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Slider(
                              key: const Key('seek'),
                              value: library.position.inMilliseconds
                                  .toDouble()
                                  .clamp(
                                    0,
                                    library.duration.inMilliseconds.toDouble(),
                                  ),
                              max: library.duration.inMilliseconds
                                  .toDouble()
                                  .clamp(1, double.infinity),
                              onChanged: library.busy
                                  ? null
                                  : (value) => library.seek(
                                      Duration(milliseconds: value.round()),
                                    ),
                              semanticFormatterCallback: (value) => clockLabel(
                                Duration(milliseconds: value.round()),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    clockLabel(library.position),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: muted,
                                    ),
                                  ),
                                  Text(
                                    clockLabel(library.duration),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  key: const Key('player-previous'),
                                  tooltip: '上一首',
                                  onPressed: library.busy
                                      ? null
                                      : () => library.skip(-1),
                                  icon: const Icon(
                                    Icons.skip_previous_rounded,
                                    size: 36,
                                  ),
                                ),
                                const SizedBox(width: 26),
                                SizedBox(
                                  width: 70,
                                  height: 70,
                                  child: FilledButton(
                                    key: const Key('player-play'),
                                    style: FilledButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      shape: const CircleBorder(),
                                    ),
                                    onPressed: library.busy
                                        ? null
                                        : library.togglePlay,
                                    child: library.busy
                                        ? const CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: ink,
                                          )
                                        : Icon(
                                            library.playing
                                                ? Icons.pause_rounded
                                                : Icons.play_arrow_rounded,
                                            size: 43,
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 26),
                                IconButton(
                                  key: const Key('player-next'),
                                  tooltip: '下一首',
                                  onPressed: library.busy
                                      ? null
                                      : () => library.skip(1),
                                  icon: const Icon(
                                    Icons.skip_next_rounded,
                                    size: 36,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 15,
                              runSpacing: 10,
                              children: [
                                _PlayerOption(
                                  icon: library.repeat == RepeatSetting.one
                                      ? Icons.repeat_one_rounded
                                      : Icons.repeat_rounded,
                                  label: switch (library.repeat) {
                                    RepeatSetting.off => '顺序播放',
                                    RepeatSetting.all => '列表循环',
                                    RepeatSetting.one => '单曲循环',
                                  },
                                  selected: library.repeat != RepeatSetting.off,
                                  onTap: () => library.setRepeat(
                                    RepeatSetting.values[(library.repeat.index +
                                            1) %
                                        RepeatSetting.values.length],
                                  ),
                                ),
                                _PlayerOption(
                                  icon: Icons.timer_outlined,
                                  label: library.remaining == null
                                      ? '定时关闭'
                                      : clockLabel(library.remaining!),
                                  selected: library.remaining != null,
                                  onTap: () => showTimerSheet(context, library),
                                ),
                                _PlayerOption(
                                  icon: Icons.queue_music_rounded,
                                  label: '播放列表',
                                  onTap: () => showQueueSheet(context, library),
                                ),
                              ],
                            ),
                            if (library.message != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 15),
                                child: Text(
                                  library.message!,
                                  style: const TextStyle(
                                    color: coral,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(30, 4, 30, 20),
                    child: OutlinedButton.icon(
                      onPressed: () => showVoiceSheet(context, voice),
                      icon: Icon(
                        voice.waitingForWakeWord
                            ? Icons.hearing_rounded
                            : Icons.mic_none_rounded,
                      ),
                      label: Text(
                        voice.assistantEnabled
                            ? voice.assistantStatus
                            : '小耳朵语音助手',
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        foregroundColor: ink,
                        side: const BorderSide(color: Color(0xFFDDE4D8)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _PlayerOption extends StatelessWidget {
  const _PlayerOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      foregroundColor: selected ? coral : muted,
      minimumSize: const Size(62, 64),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    ),
    child: Column(
      children: [
        Icon(icon, size: 23),
        const SizedBox(height: 7),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    ),
  );
}
