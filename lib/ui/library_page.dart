import 'package:flutter/material.dart';
import '../controllers/library_controller.dart';
import '../controllers/voice_controller.dart';
import '../models/track.dart';
import 'sheets.dart';
import 'theme.dart';
import 'widgets/illustration.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({
    super.key,
    required this.library,
    required this.voice,
    required this.onPlay,
    required this.onContinue,
    required this.onBrowseHome,
    this.favoritesOnly = false,
  });
  final LibraryController library;
  final VoiceController voice;
  final Future<void> Function(Track, List<Track>) onPlay;
  final VoidCallback onContinue;
  final VoidCallback onBrowseHome;
  final bool favoritesOnly;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  late TrackCategory? _category = widget.favoritesOnly
      ? null
      : TrackCategory.rhymes;

  @override
  Widget build(BuildContext context) {
    final library = widget.library;
    final tracks = library.tracks
        .where(
          (track) =>
              (_category == null || track.category == _category) &&
              (!widget.favoritesOnly || library.favorites.contains(track.id)),
        )
        .toList();
    return CustomScrollView(
      key: PageStorageKey(
        widget.favoritesOnly ? 'favorites-scroll' : 'home-scroll',
      ),
      primary: false,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!widget.favoritesOnly) ...[
                  _ContinueCard(library: library, onTap: widget.onContinue),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _CategoryCard(
                          title: '听儿歌',
                          subtitle: '英文童谣',
                          icon: Icons.music_note_rounded,
                          selected: _category == TrackCategory.rhymes,
                          color: warm,
                          onTap: () =>
                              setState(() => _category = TrackCategory.rhymes),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _CategoryCard(
                          title: '听故事',
                          subtitle: '晚安小故事',
                          icon: Icons.auto_stories_rounded,
                          selected: _category == TrackCategory.stories,
                          color: blue,
                          onTap: () =>
                              setState(() => _category = TrackCategory.stories),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                ],
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.favoritesOnly
                            ? '我的小收藏'
                            : switch (_category) {
                                TrackCategory.stories => '故事时间',
                                TrackCategory.daily => '生活英语',
                                _ => '英文儿歌',
                              },
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (!widget.favoritesOnly)
                      TextButton(
                        onPressed: () => setState(
                          () => _category = _category == TrackCategory.daily
                              ? TrackCategory.rhymes
                              : TrackCategory.daily,
                        ),
                        style: TextButton.styleFrom(foregroundColor: muted),
                        child: Text(
                          _category == TrackCategory.daily ? '返回儿歌' : '生活英语',
                          style: const TextStyle(fontSize: 12),
                        ),
                      )
                    else
                      Text(
                        '${tracks.length} 段音频',
                        style: const TextStyle(fontSize: 12, color: muted),
                      ),
                  ],
                ),
                if (widget.favoritesOnly) ...[
                  const SizedBox(height: 6),
                  const Text(
                    '把喜欢的儿歌和故事，留在这里。',
                    style: TextStyle(color: muted, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final category in <TrackCategory?>[
                          null,
                          TrackCategory.rhymes,
                          TrackCategory.stories,
                          TrackCategory.daily,
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              selected: _category == category,
                              showCheckmark: false,
                              label: Text(switch (category) {
                                null => '全部',
                                TrackCategory.rhymes => '儿歌',
                                TrackCategory.stories => '故事',
                                TrackCategory.daily => '生活英语',
                              }),
                              onSelected: (_) =>
                                  setState(() => _category = category),
                            ),
                          ),
                      ],
                    ),
                  ),
                ] else
                  Text(
                    _category == TrackCategory.rhymes
                        ? '简单的英文词句，反复听更熟悉 · 当前为朗读版'
                        : _category == TrackCategory.stories
                        ? '玩耍时、睡觉前，听一个英文小故事。'
                        : '从问好到晚安，听懂生活里的英语。',
                    style: const TextStyle(
                      color: muted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        if (tracks.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 34,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.favorite_border_rounded,
                      size: 42,
                      color: coral,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      library.favorites.isEmpty ? '还没有收藏的声音' : '这个分类还没有收藏',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '听到喜欢的儿歌或故事，点一下爱心。',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: library.favorites.isEmpty
                          ? widget.onBrowseHome
                          : () => setState(() => _category = null),
                      child: Text(
                        library.favorites.isEmpty ? '去首页听一听' : '查看全部收藏',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.crossAxisExtent;
                final scale = MediaQuery.textScalerOf(context).scale(1);
                final columns = width >= 560
                    ? 3
                    : width < 290 || scale > 1.35
                    ? 1
                    : 2;
                final cardWidth = (width - (columns - 1) * 14) / columns;
                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 16,
                    mainAxisExtent:
                        cardWidth * .72 + 98 * scale.clamp(1.0, 2.0),
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final track = tracks[index];
                    return _AudioCard(
                      track: track,
                      favorite: library.favorites.contains(track.id),
                      playing:
                          library.playing && library.current.id == track.id,
                      onPlay: library.busy
                          ? null
                          : () => widget.onPlay(track, tracks),
                      onFavorite: () => library.toggleFavorite(track),
                    );
                  }, childCount: tracks.length),
                );
              },
            ),
          ),
        if (library.message != null)
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverToBoxAdapter(
              child: Text(
                library.message!,
                style: const TextStyle(color: coral),
              ),
            ),
          ),
        if (!widget.favoritesOnly)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            sliver: SliverToBoxAdapter(
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                child: ListTile(
                  key: const Key('library-voice'),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 3,
                  ),
                  leading: const Icon(Icons.mic_none_rounded, color: coral),
                  title: const Text(
                    '小耳朵语音助手',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    widget.voice.assistantStatus,
                    style: const TextStyle(color: muted, fontSize: 11),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: muted,
                    size: 20,
                  ),
                  onTap: () => showVoiceSheet(context, widget.voice),
                ),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
      ],
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.library, required this.onTap});
  final LibraryController library;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final track = library.current;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: library.busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.headphones_rounded, size: 15, color: coral),
                  const SizedBox(width: 7),
                  Text(
                    library.queue.isEmpty ? '从这一首开始' : '接着上次听',
                    style: const TextStyle(
                      fontSize: 12,
                      color: muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    '离线可听',
                    style: TextStyle(fontSize: 10, color: muted),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  SizedBox(
                    width: 78,
                    height: 78,
                    child: CoverArt(
                      scene: track.art,
                      color: Color(track.color),
                      radius: 18,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: muted),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: library.busy ? null : onTap,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 34),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          icon: Icon(
                            library.playing
                                ? Icons.graphic_eq_rounded
                                : Icons.play_arrow_rounded,
                            size: 18,
                          ),
                          label: Text(
                            library.playing
                                ? '正在播放'
                                : library.queue.isEmpty
                                ? '开始听一听'
                                : '继续听一听',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  final String title, subtitle;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: color,
    borderRadius: BorderRadius.circular(20),
    child: Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? ink.withValues(alpha: .22) : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: ink, size: 24),
                  const Spacer(),
                  if (selected)
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 17,
                      color: ink,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 10, color: muted),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _AudioCard extends StatelessWidget {
  const _AudioCard({
    required this.track,
    required this.favorite,
    required this.playing,
    required this.onPlay,
    required this.onFavorite,
  });
  final Track track;
  final bool favorite, playing;
  final VoidCallback? onPlay;
  final VoidCallback onFavorite;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onPlay,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1 / .72,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CoverArt(
                    scene: track.art,
                    color: Color(track.color),
                    radius: 0,
                  ),
                ),
                Positioned(
                  right: 9,
                  bottom: 9,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      playing
                          ? Icons.graphic_eq_rounded
                          : Icons.play_arrow_rounded,
                      color: ink,
                      size: 21,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          track.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          track.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            height: 1.4,
                            color: muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          clockLabel(track.duration),
                          style: const TextStyle(fontSize: 10, color: muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: favorite ? '取消收藏' : '收藏${track.subtitle}',
                    onPressed: onFavorite,
                    icon: Icon(
                      favorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: favorite ? coral : muted,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
