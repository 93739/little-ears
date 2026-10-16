import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/library_controller.dart';
import '../controllers/voice_controller.dart';
import '../models/track.dart';
import 'library_page.dart';
import 'player_screen.dart';
import 'sheets.dart';
import 'settings_page.dart';
import 'theme.dart';
import 'widgets/illustration.dart';

class LittleEarsApp extends StatefulWidget {
  const LittleEarsApp({super.key, required this.library, required this.voice});
  final LibraryController library;
  final VoiceController voice;
  @override
  State<LittleEarsApp> createState() => _LittleEarsAppState();
}

class _LittleEarsAppState extends State<LittleEarsApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(widget.voice.setForeground(true));
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(widget.voice.setForeground(false));
        break;
      case AppLifecycleState.inactive:
        // A microphone permission dialog also briefly makes the app inactive.
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.voice.dispose();
    widget.library.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: '小耳朵英语',
    theme: buildTheme(),
    builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
      value: appSystemUiStyle,
      child: ColoredBox(color: paper, child: child ?? const SizedBox.shrink()),
    ),
    home: HomeScreen(library: widget.library, voice: widget.voice),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.library, required this.voice});
  final LibraryController library;
  final VoiceController voice;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTab = 0;
  LibraryController get library => widget.library;

  void _openPlayer() => Navigator.of(
    context,
  ).push(PlayerPageRoute(library: library, voice: widget.voice));

  Future<void> _continueListening() async {
    if (library.busy) return;
    if (!library.playing) await library.resume();
    if (!mounted) return;
    if (library.message != null) {
      _showPlaybackMessage();
    } else {
      _openPlayer();
    }
  }

  void _showPlaybackMessage() => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(library.message ?? '请稍后再试')));

  Future<void> _play(Track track, List<Track> queue) async {
    final ok = await library.playTrack(track, within: queue);
    if (!mounted) return;
    if (ok) {
      _openPlayer();
    } else {
      _showPlaybackMessage();
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([library, widget.voice]),
    builder: (context, _) => Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                _PageHeader(tab: _selectedTab, voice: widget.voice),
                Expanded(
                  child: IndexedStack(
                    index: _selectedTab,
                    children: [
                      LibraryPage(
                        key: const ValueKey('home-page'),
                        library: library,
                        voice: widget.voice,
                        onPlay: _play,
                        onContinue: () => unawaited(_continueListening()),
                        onBrowseHome: () => setState(() => _selectedTab = 0),
                      ),
                      LibraryPage(
                        key: const ValueKey('favorites-page'),
                        library: library,
                        voice: widget.voice,
                        favoritesOnly: true,
                        onPlay: _play,
                        onContinue: () => unawaited(_continueListening()),
                        onBrowseHome: () => setState(() => _selectedTab = 0),
                      ),
                      SettingsPage(library: library, voice: widget.voice),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: ColoredBox(
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MiniPlayer(library: library, onOpen: _openPlayer),
                  NavigationBar(
                    selectedIndex: _selectedTab,
                    onDestinationSelected: (index) =>
                        setState(() => _selectedTab = index),
                    destinations: const [
                      NavigationDestination(
                        key: Key('tab-home'),
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home_rounded),
                        label: '首页',
                      ),
                      NavigationDestination(
                        key: Key('favorites'),
                        icon: Icon(Icons.favorite_border_rounded),
                        selectedIcon: Icon(Icons.favorite_rounded),
                        label: '收藏',
                      ),
                      NavigationDestination(
                        key: Key('tab-settings'),
                        icon: Icon(Icons.settings_outlined),
                        selectedIcon: Icon(Icons.settings_rounded),
                        label: '设置',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.tab, required this.voice});
  final int tab;
  final VoiceController voice;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: coral,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            switch (tab) {
              1 => Icons.favorite_rounded,
              2 => Icons.tune_rounded,
              _ => Icons.headphones_rounded,
            },
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                switch (tab) {
                  1 => '我的收藏',
                  2 => '家长设置',
                  _ => '小耳朵',
                },
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(switch (tab) {
                1 => '喜欢的儿歌与故事',
                2 => '让陪伴更简单',
                _ => '好听的儿歌，温柔的小故事',
              }, style: const TextStyle(fontSize: 11, color: muted)),
            ],
          ),
        ),
        if (tab == 0)
          IconButton(
            key: const Key('voice-open'),
            tooltip: '小耳朵语音助手',
            onPressed: () => showVoiceSheet(context, voice),
            style: IconButton.styleFrom(backgroundColor: Colors.white),
            icon: Icon(
              voice.waitingForWakeWord
                  ? Icons.hearing_rounded
                  : Icons.mic_none_rounded,
              color: coral,
              size: 22,
            ),
          ),
      ],
    ),
  );
}

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer({required this.library, required this.onOpen});
  final LibraryController library;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final track = library.current;
    final duration = library.duration.inMilliseconds;
    final progress = duration > 0
        ? (library.position.inMilliseconds / duration).clamp(0.0, 1.0)
        : 0.0;
    return Material(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1, color: line),
          InkWell(
            key: const Key('mini-player'),
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 9),
              child: Row(
                children: [
                  SizedBox(
                    width: 42,
                    height: 42,
                    child: CoverArt(
                      scene: track.art,
                      color: Color(track.color),
                      radius: 12,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          library.playing
                              ? '正在播放 · ${track.title}'
                              : '点开播放器，听一听',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, color: muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('mini-play'),
                    tooltip: library.playing ? '暂停' : '播放',
                    onPressed: library.busy ? null : library.togglePlay,
                    icon: library.busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: coral,
                            ),
                          )
                        : Icon(
                            library.playing
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_fill_rounded,
                            size: 36,
                            color: coral,
                          ),
                  ),
                  IconButton(
                    tooltip: '播放列表',
                    onPressed: () => showQueueSheet(context, library),
                    icon: const Icon(
                      Icons.queue_music_rounded,
                      size: 23,
                      color: ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
          LinearProgressIndicator(
            value: progress,
            minHeight: 2,
            color: coral,
            backgroundColor: sage,
            borderRadius: BorderRadius.zero,
          ),
        ],
      ),
    );
  }
}
