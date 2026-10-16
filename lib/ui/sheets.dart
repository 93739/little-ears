import 'dart:async';
import 'package:flutter/material.dart';
import '../controllers/library_controller.dart';
import '../controllers/voice_controller.dart';
import 'theme.dart';

Future<void> showTimerSheet(BuildContext context, LibraryController library) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '听一会儿，就休息',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text('到时间自动暂停播放。', style: TextStyle(color: muted)),
              const SizedBox(height: 20),
              for (final minutes in [5, 10, 15, 30, 60])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.timer_outlined),
                  title: Text('$minutes 分钟'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    library.setSleepTimer(minutes);
                    Navigator.of(context).pop();
                  },
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.timer_off_outlined),
                title: const Text('关闭定时'),
                onTap: () {
                  library.setSleepTimer(null);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );

Future<void> showParentSheet(
  BuildContext context,
  LibraryController library,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (sheetContext) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '陪小耳朵听一听',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text('简单一点，和孩子一起享受英语。', style: TextStyle(color: muted)),
          const SizedBox(height: 22),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.timer_outlined),
            title: const Text('设置定时停止'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.of(sheetContext).pop();
              showTimerSheet(context, library);
            },
          ),
          const Divider(color: sage),
          const SizedBox(height: 12),
          const Text(
            '可以这样说',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 10),
          const Text(
            '“播放儿歌”  “播放生活英语”  “播放故事”\n“暂停”  “继续播放”  “上一首”  “下一首”\n“收藏这首”  “声音小一点”\n“定时十分钟”  “取消定时”',
            style: TextStyle(height: 2, color: muted),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: sage,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text(
              '音频已内置，可以离线播放。在语音助手中开启“喊名字唤醒”后，先喊“小耳朵”，听到回应再说指令。离开 App 后停止监听；指令识别在部分设备上需要联网。',
              style: TextStyle(fontSize: 12, height: 1.8),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '小耳朵英语 · 试听版 1.0\n原创文本 / 合成朗读',
            style: TextStyle(color: muted, fontSize: 11, height: 1.8),
          ),
        ],
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
      height: MediaQuery.sizeOf(context).height * .6,
      child: AnimatedBuilder(
        animation: library,
        builder: (context, _) {
          final queue = library.queue.isEmpty ? library.tracks : library.queue;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 15),
                child: Text(
                  '播放列表 · ${queue.length}',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: queue.length,
                  itemBuilder: (context, index) {
                    final track = queue[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                      ),
                      leading: Text(
                        '${index + 1}'.padLeft(2, '0'),
                        style: const TextStyle(color: muted),
                      ),
                      title: Text(
                        track.title,
                        style: TextStyle(
                          color: track.id == library.current.id ? coral : ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        track.subtitle,
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                      trailing: track.id == library.current.id
                          ? const Icon(Icons.graphic_eq_rounded, color: coral)
                          : null,
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
                color: sage,
                borderRadius: BorderRadius.circular(20),
              ),
              child: SwitchListTile.adaptive(
                key: const Key('assistant-toggle'),
                title: const Text(
                  '喊名字唤醒',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  '在 App 内等你呼唤',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                value: voice.assistantEnabled,
                activeTrackColor: ink,
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
