import 'package:flutter/material.dart';
import '../controllers/library_controller.dart';
import '../controllers/voice_controller.dart';
import '../models/track.dart' show clockLabel;
import 'sheets.dart';
import 'theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.library, required this.voice});
  final LibraryController library;
  final VoiceController voice;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: const PageStorageKey('settings-scroll'),
    primary: false,
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: warm,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '给儿歌和故事，留一点时间',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 8),
              Text(
                '设置好定时，让孩子安心听，你也轻松一点。',
                style: TextStyle(fontSize: 13, color: muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        const Text(
          '播放与陪伴',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 12),
        _SettingsCard(
          children: [
            _SettingsRow(
              icon: Icons.bedtime_outlined,
              title: '睡前定时',
              subtitle: library.remaining == null
                  ? '听一会儿，就休息'
                  : '${clockLabel(library.remaining!)} 后停止播放',
              onTap: () => showTimerSheet(context, library),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16, color: sage),
            _SettingsRow(
              icon: voice.waitingForWakeWord
                  ? Icons.hearing_rounded
                  : Icons.mic_none_rounded,
              title: '小耳朵语音助手',
              subtitle: voice.assistantStatus,
              onTap: () => showVoiceSheet(context, voice),
            ),
          ],
        ),
        const SizedBox(height: 26),
        const Text(
          '可以这样说',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 12),
        const _SettingsCard(
          children: [
            Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                '先喊“小耳朵”，听到回应后再说：\n“播放儿歌”  “播放生活英语”  “播放故事”\n“暂停”  “继续播放”  “上一首”  “下一首”\n“声音小一点”  “定时十分钟”  “取消定时”',
                style: TextStyle(height: 2, color: muted, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        const Text(
          '关于小耳朵',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 12),
        const _SettingsCard(
          children: [
            _SettingsRow(
              icon: Icons.offline_pin_outlined,
              title: '音频已内置',
              subtitle: '儿歌、故事与生活短句均可离线听。当前儿歌素材为童谣朗读。',
            ),
            Divider(height: 1, indent: 16, endIndent: 16, color: sage),
            _SettingsRow(
              icon: Icons.privacy_tip_outlined,
              title: '语音使用说明',
              subtitle: '需先开启喊名字唤醒。唤醒词在本机识别，指令识别可能需要联网；关闭开关或离开 App 后停止监听。',
            ),
          ],
        ),
        const SizedBox(height: 22),
        const Center(
          child: Text(
            '小耳朵英语 · 试听版 1.0\n原创文本 / 合成朗读',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 11, height: 1.8),
          ),
        ),
      ],
    ),
  );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: sage,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 21, color: ink),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, height: 1.6, color: muted),
        ),
      ),
      trailing: onTap == null
          ? null
          : const Icon(Icons.chevron_right_rounded, size: 21, color: muted),
      onTap: onTap,
    ),
  );
}
