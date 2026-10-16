import 'dart:async';
import 'package:flutter/material.dart';
import '../controllers/library_controller.dart';
import '../controllers/voice_controller.dart';
import '../models/track.dart' show clockLabel;
import 'theme.dart';
import 'widgets/illustration.dart';

Future<void> showTimerSheet(BuildContext context, LibraryController library) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: AnimatedBuilder(
            animation: library,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '睡前定时',
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  library.remaining == null
                      ? '选一个时间，听完这一会儿就休息。'
                      : '将在 ${clockLabel(library.remaining!)} 后暂停播放。',
                  style: const TextStyle(fontSize: 13, color: muted),
                ),
                const SizedBox(height: 22),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final singleColumn =
                        MediaQuery.textScalerOf(context).scale(1) > 1.4;
                    final width = singleColumn
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final minutes in [5, 10, 15, 30, 45, 60])
                          SizedBox(
                            width: width,
                            child: Material(
                              color: sage,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  library.setSleepTimer(minutes);
                                  Navigator.of(context).pop();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 20,
                                    horizontal: 10,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$minutes 分钟',
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      library.setSleepTimer(null);
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.timer_off_outlined, size: 20),
                    label: const Text('关闭定时'),
                    style: TextButton.styleFrom(
                      foregroundColor: muted,
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

Future<void> showQueueSheet(
  BuildContext context,
  LibraryController library,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .65,
      child: AnimatedBuilder(
        animation: library,
        builder: (context, _) {
          final queue = library.queue.isEmpty ? library.tracks : library.queue;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '播放列表',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '${queue.length} 段音频',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (library.message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: Text(
                    library.message!,
                    style: const TextStyle(color: coral, fontSize: 12),
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: queue.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 5),
                  itemBuilder: (context, index) {
                    final track = queue[index];
                    final selected = library.current.id == track.id;
                    return Material(
                      color: selected ? warm : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        leading: SizedBox(
                          width: 46,
                          height: 46,
                          child: CoverArt(
                            scene: track.art,
                            color: Color(track.color),
                            radius: 12,
                          ),
                        ),
                        title: Text(
                          track.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: selected ? coral : ink,
                          ),
                        ),
                        subtitle: Text(
                          '${track.title} · ${clockLabel(track.duration)}',
                          maxLines: 2,
                          style: const TextStyle(fontSize: 11, color: muted),
                        ),
                        trailing: Icon(
                          selected && library.playing
                              ? Icons.graphic_eq_rounded
                              : Icons.play_arrow_rounded,
                          color: selected ? coral : muted,
                          size: 22,
                        ),
                        onTap: library.busy
                            ? null
                            : () async {
                                final ok = await library.playTrack(
                                  track,
                                  within: queue,
                                );
                                if (context.mounted && ok) {
                                  Navigator.of(context).pop();
                                }
                              },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    ),
  ),
);

Future<void> showVoiceSheet(BuildContext context, VoiceController voice) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _VoiceSheet(voice: voice),
  );
  await voice.dismissPanel();
}

class _VoiceSheet extends StatelessWidget {
  const _VoiceSheet({required this.voice});
  final VoiceController voice;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(25, 0, 25, 30),
      child: AnimatedBuilder(
        animation: voice,
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '小耳朵语音助手',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              '先喊“小耳朵”，听到回应后再说指令',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: muted),
            ),
            const SizedBox(height: 22),
            Container(
              decoration: BoxDecoration(
                color: warm,
                borderRadius: BorderRadius.circular(20),
              ),
              child: SwitchListTile.adaptive(
                key: const Key('assistant-toggle'),
                title: const Text(
                  '喊名字唤醒',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  '用声音，选儿歌和故事',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                value: voice.assistantEnabled,
                activeTrackColor: coral,
                onChanged: (enabled) =>
                    unawaited(voice.setAssistantEnabled(enabled)),
              ),
            ),
            const SizedBox(height: 15),
            Semantics(
              liveRegion: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    voice.waitingForWakeWord
                        ? Icons.hearing_rounded
                        : Icons.mic_none_rounded,
                    color: voice.assistantEnabled ? ink : muted,
                    size: 18,
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      voice.assistantStatus,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: muted),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: voice.active ? coral.withValues(alpha: .15) : sage,
              ),
              child: SizedBox(
                width: 85,
                height: 85,
                child: FilledButton(
                  key: const Key('voice-start'),
                  style: FilledButton.styleFrom(
                    backgroundColor: voice.active ? coral : ink,
                    shape: const CircleBorder(),
                  ),
                  onPressed:
                      voice.phase == VoicePhase.processing ||
                          voice.assistantPreparing
                      ? null
                      : () => unawaited(
                          voice.active ? voice.cancel() : voice.start(),
                        ),
                  child: Icon(
                    voice.active ? Icons.stop_rounded : Icons.mic_rounded,
                    size: 36,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              voice.active ? '点一下，结束本次指令' : '也可以点麦克风说指令',
              style: const TextStyle(fontSize: 12, color: muted),
            ),
            const SizedBox(height: 18),
            if (voice.transcript.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  '“${voice.transcript}”',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
              ),
            if (voice.active ||
                voice.phase == VoicePhase.finished ||
                voice.phase == VoicePhase.unavailable)
              Text(
                voice.feedback,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: muted, height: 1.6),
              ),
            const SizedBox(height: 25),
            const Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _Example('播放儿歌'),
                _Example('下一首'),
                _Example('播放故事'),
                _Example('暂停'),
                _Example('声音小一点'),
                _Example('定时十分钟'),
              ],
            ),
            const SizedBox(height: 22),
            const Text(
              '开启后持续使用麦克风，关闭或离开 App 即停止监听。\n唤醒词在本机识别；播放指令使用系统语音服务，可能需要联网。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: muted, height: 1.7),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Example extends StatelessWidget {
  const _Example(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
    decoration: BoxDecoration(
      color: sage,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(text, style: const TextStyle(fontSize: 12, color: ink)),
  );
}
