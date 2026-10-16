import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/library_controller.dart';
import '../controllers/voice_controller.dart';
import '../models/track.dart';
import 'player_screen.dart';
import 'sheets.dart';
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
  TrackCategory? _category;
  bool _favoritesOnly = false;
  LibraryController get library => widget.library;

  void _openPlayer() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PlayerScreen(library: library, voice: widget.voice),
    ),
  );

  Future<void> _play(Track track, List<Track> queue) async {
    final ok = await library.playTrack(track, within: queue);
    if (!mounted) return;
    if (ok) {
      _openPlayer();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(library.message ?? '请稍后再试')));
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([library, widget.voice]),
    builder: (context, _) {
      final visible = library.tracks
          .where(
            (track) =>
                (_category == null || track.category == _category) &&
                (!_favoritesOnly || library.favorites.contains(track.id)),
          )
          .toList();
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 14, 16, 4),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: coral,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(
                            Icons.headphones_rounded,
                            color: Colors.white,
                            size: 27,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '小耳朵',
                                style: TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w800,
                                  color: ink,
                                  letterSpacing: 1,
                                ),
                              ),
                              Text(
                                'L I T T L E   E A R S',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          key: const Key('favorites'),
                          tooltip: _favoritesOnly ? '查看全部' : '我的收藏',
                          onPressed: () =>
                              setState(() => _favoritesOnly = !_favoritesOnly),
                          icon: Icon(
                            _favoritesOnly
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: _favoritesOnly ? coral : ink,
                          ),
                        ),
                        IconButton(
                          tooltip: '家长设置',
                          onPressed: () => showParentSheet(context, library),
                          icon: const Icon(Icons.tune_rounded),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!_favoritesOnly) ...[
                            _HeroCard(
                              onPlay: library.busy
                                  ? null
                                  : () =>
                                        _play(library.current, library.tracks),
                            ),
                            const SizedBox(height: 18),
                            Material(
                              color: sage,
                              borderRadius: BorderRadius.circular(22),
                              child: InkWell(
                                key: const Key('voice-open'),
                                borderRadius: BorderRadius.circular(22),
                                onTap: () =>
                                    showVoiceSheet(context, widget.voice),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: Colors.white,
                                        radius: 23,
                                        child: Icon(
                                          widget.voice.waitingForWakeWord
                                              ? Icons.hearing_rounded
                                              : Icons.mic_rounded,
                                          color: ink,
                                        ),
                                      ),
                                      const SizedBox(width: 13),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              '小耳朵语音助手',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              widget.voice.assistantStatus,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF71806D),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: Color(0xFF71806D),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 30),
                            const Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '今天，从这里听起',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: ink,
                                    ),
                                  ),
                                ),
                                Text(
                                  'FOR LITTLE YOU',
                                  style: TextStyle(
                                    fontSize: 9,
                                    letterSpacing: 1,
                                    color: muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _FeatureCard(
                                    track: library.tracks.first,
                                    onTap: () => _play(
                                      library.tracks.first,
                                      library.tracks,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: _FeatureCard(
                                    track: library.tracks.firstWhere(
                                      (t) => t.id == 'good_night',
                                    ),
                                    onTap: () => _play(
                                      library.tracks.firstWhere(
                                        (t) => t.id == 'good_night',
                                      ),
                                      library.tracks,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 30),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _favoritesOnly ? '我的小收藏' : '慢慢听，慢慢长大',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: ink,
                                  ),
                                ),
                              ),
                              Text(
                                '${visible.length} 段音频',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: muted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _CategoryChip(
                                  label: '全部',
                                  selected: _category == null,
                                  onTap: () => setState(() => _category = null),
                                ),
                                for (final category in TrackCategory.values)
                                  _CategoryChip(
                                    label: category.label,
                                    selected: _category == category,
                                    onTap: () =>
                                        setState(() => _category = category),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (visible.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 45),
                              child: Center(
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.favorite_border_rounded,
                                      size: 42,
                                      color: coral,
                                    ),
                                    const SizedBox(height: 14),
                                    const Text(
                                      '把喜欢的声音留在这里',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    const Text(
                                      '播放时点一下爱心，就能收藏。',
                                      style: TextStyle(color: muted),
                                    ),
                                    TextButton(
                                      onPressed: () => setState(() {
                                        _favoritesOnly = false;
                                        _category = null;
                                      }),
                                      child: const Text('去听一听'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          for (final track in visible)
                            _TrackRow(
                              track: track,
                              selected:
                                  track.id == library.current.id &&
                                  library.playing,
                              favorite: library.favorites.contains(track.id),
                              onTap: library.busy
                                  ? null
                                  : () => _play(track, visible),
                              onFavorite: () => library.toggleFavorite(track),
                            ),
                          if (library.message != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                library.message!,
                                style: const TextStyle(
                                  color: coral,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          const SizedBox(height: 20),
                          const Center(
                            child: Text(
                              '小小的声音，陪伴每一天。',
                              style: TextStyle(
                                color: muted,
                                fontSize: 12,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Center(
                            child: Text(
                              '离线可听 · 童谣为朗读版',
                              style: TextStyle(color: muted, fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _MiniPlayer(library: library, onOpen: _openPlayer),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({this.onPlay});
  final VoidCallback? onPlay;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 400;
      final showArt =
          constraints.maxWidth >= 320 &&
          MediaQuery.textScalerOf(context).scale(1) <= 1.2;
      return Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFFF1EBD9),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Stack(
          children: [
            if (showArt)
              Positioned(
                right: compact ? -5 : -10,
                bottom: -13,
                width: compact ? 160 : 210,
                height: 230,
                child: const CoverArt(color: Colors.transparent, hero: true),
              ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'HELLO, LITTLE WORLD',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: Color(0xFF8F9378),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '小耳朵，\n听见大世界。',
                    style: TextStyle(
                      fontSize: compact ? 25 : 31,
                      height: 1.4,
                      fontWeight: FontWeight.w800,
                      color: ink,
                      letterSpacing: -.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '一点英语，一点小欢喜。',
                    style: TextStyle(fontSize: 12, color: Color(0xFF7D856E)),
                  ),
                  const SizedBox(height: 21),
                  FilledButton.icon(
                    onPressed: onPlay,
                    icon: const Icon(Icons.play_arrow_rounded, size: 22),
                    label: const Text('开始听一听'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 17),
                      minimumSize: const Size(0, 45),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 9),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      backgroundColor: Colors.transparent,
      selectedColor: ink,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: selected ? Colors.white : muted,
      ),
      side: BorderSide(color: selected ? ink : const Color(0xFFE7E8DF)),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    ),
  );
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.track, required this.onTap});
  final Track track;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '播放${track.subtitle}',
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.32,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CoverArt(
                      scene: track.art,
                      color: Color(track.color),
                      radius: 22,
                    ),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        size: 23,
                        color: ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              track.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 3),
            Text(
              '${track.subtitle} · ${clockLabel(track.duration)}',
              style: const TextStyle(fontSize: 11, color: muted),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TrackRow extends StatelessWidget {
  const _TrackRow({
    required this.track,
    required this.selected,
    required this.favorite,
    required this.onTap,
    required this.onFavorite,
  });
  final Track track;
  final bool selected, favorite;
  final VoidCallback? onTap;
  final VoidCallback onFavorite;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Material(
      color: selected ? sage.withValues(alpha: .6) : Colors.transparent,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(7, 8, 0, 8),
          child: Row(
            children: [
              SizedBox(
                width: 58,
                height: 58,
                child: CoverArt(
                  scene: track.art,
                  color: Color(track.color),
                  radius: 15,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${track.subtitle} · ${clockLabel(track.duration)}',
                      style: const TextStyle(fontSize: 11, color: muted),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.graphic_eq_rounded, size: 20, color: coral),
              IconButton(
                tooltip: favorite ? '取消收藏' : '收藏${track.subtitle}',
                onPressed: onFavorite,
                icon: Icon(
                  favorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 20,
                  color: favorite ? coral : muted,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer({required this.library, required this.onOpen});
  final LibraryController library;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: paper,
      boxShadow: [
        BoxShadow(
          color: ink.withValues(alpha: .04),
          blurRadius: 16,
          offset: const Offset(0, -5),
        ),
      ],
    ),
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
    child: Material(
      color: ink,
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        key: const Key('mini-player'),
        onTap: onOpen,
        borderRadius: BorderRadius.circular(21),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 7, 8),
          child: Row(
            children: [
              SizedBox(
                width: 46,
                height: 46,
                child: CoverArt(
                  scene: library.current.art,
                  color: Color(library.current.color),
                  radius: 13,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      library.current.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      library.playing
                          ? '正在播放 · ${library.current.subtitle}'
                          : '准备好了，听一听吧',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFB7C6B7),
                        fontSize: 10,
                      ),
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
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        library.playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 31,
                      ),
              ),
              IconButton(
                tooltip: '下一首',
                onPressed: library.busy ? null : () => library.skip(1),
                icon: const Icon(
                  Icons.skip_next_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
