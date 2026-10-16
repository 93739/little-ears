import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart' show TickerCanceled;
import '../controllers/library_controller.dart';
import '../controllers/voice_controller.dart';
import '../models/track.dart';
import '../services/playback_engine.dart';
import 'sheets.dart';
import 'theme.dart';
import 'widgets/illustration.dart';

/// Remains opaque during normal playback; only a pull exposes the library.
class PlayerPageRoute extends PageRoute<void> {
  PlayerPageRoute({required this.library, required this.voice})
    : super(fullscreenDialog: true, allowSnapshotting: false);
  final LibraryController library;
  final VoiceController voice;
  bool _pulling = false;

  void _setPulling(bool value) {
    if (_pulling == value) return;
    _pulling = value;
    if (overlayEntries.isNotEmpty) {
      // TransitionRoute normally updates this only when its animation changes.
      overlayEntries.first.opaque =
          !_pulling && animation?.status == AnimationStatus.completed;
    }
    changedInternalState();
  }

  @override
  bool get opaque => !_pulling;
  @override
  bool get maintainState => true;
  @override
  Color? get barrierColor => null;
  @override
  String? get barrierLabel => null;
  @override
  Duration get transitionDuration => const Duration(milliseconds: 260);
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 220);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => PlayerScreen(library: library, voice: voice);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation),
    child: child,
  );
}

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.library, required this.voice});
  final LibraryController library;
  final VoiceController voice;
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pull = AnimationController.unbounded(
    vsync: this,
  );
  final ScrollController _contentScroll = ScrollController();
  int? _pointer;
  Offset _origin = Offset.zero;
  double _startOffset = 0;
  VelocityTracker? _velocity;
  bool _fromContent = false;
  bool _dragging = false;
  bool _closing = false;

  bool get _contentAtTop => _contentScroll.positions.every(
    (position) => position.pixels <= position.minScrollExtent + .5,
  );

  void _setRoutePulling(bool value) {
    final route = ModalRoute.of(context);
    if (route is PlayerPageRoute) route._setPulling(value);
  }

  void _pointerDown(PointerDownEvent event, {required bool content}) {
    if (_closing || ModalRoute.of(context)?.isCurrent != true) return;
    if (_pointer != null) {
      _resetPull();
      return;
    }
    if (content && !_contentAtTop) return;
    _pull.stop();
    _pointer = event.pointer;
    _origin = event.position;
    _startOffset = _pull.value;
    _fromContent = content;
    _velocity = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.position);
  }

  void _pointerMove(PointerMoveEvent event) {
    if (_pointer != event.pointer || _closing) return;
    _velocity?.addPosition(event.timeStamp, event.position);
    final distance = event.position - _origin;
    if (!_dragging) {
      if (distance.distance < kTouchSlop) return;
      // Upward/horizontal gestures belong to the existing scroll and controls.
      if (distance.dy <= 0 ||
          distance.dy < distance.dx.abs() * 1.2 ||
          (_fromContent && !_contentAtTop)) {
        _pointer = null;
        _velocity = null;
        if (_pull.value > 0) _resetPull();
        return;
      }
      _setRoutePulling(true);
      setState(() => _dragging = true);
    }
    _pull.value = (_startOffset + distance.dy - kTouchSlop).clamp(
      0.0,
      MediaQuery.sizeOf(context).height,
    );
  }

  void _pointerUp(PointerUpEvent event) {
    if (_pointer != event.pointer) return;
    _velocity?.addPosition(event.timeStamp, event.position);
    final speed = _velocity?.getVelocity().pixelsPerSecond.dy ?? 0;
    _pointer = null;
    _velocity = null;
    final threshold = (MediaQuery.sizeOf(context).height * .15).clamp(
      80.0,
      130.0,
    );
    final dismiss =
        _dragging &&
        speed > -300 &&
        (_pull.value >= threshold || (_pull.value >= 24 && speed > 700));
    if (dismiss &&
        ModalRoute.of(context)?.isCurrent == true &&
        Navigator.of(context).canPop()) {
      _closing = true;
      Navigator.of(context).pop();
    } else {
      _resetPull();
    }
  }

  void _pointerCancel(PointerCancelEvent event) {
    if (_pointer == event.pointer) _resetPull();
  }

  void _resetPull() {
    _pointer = null;
    _velocity = null;
    if (_closing) return;
    if (_dragging) setState(() => _dragging = false);
    unawaited(_settleBack());
  }

  Future<void> _settleBack() async {
    try {
      await _pull
          .animateTo(
            0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
          )
          .orCancel;
      if (mounted && !_dragging && !_closing) _setRoutePulling(false);
    } on TickerCanceled {
      // A new gesture or route disposal takes over this animation.
    }
  }

  Widget _dismissRegion(Widget child, {bool content = false}) => Listener(
    behavior: HitTestBehavior.opaque,
    onPointerDown: (event) => _pointerDown(event, content: content),
    onPointerMove: _pointerMove,
    onPointerUp: _pointerUp,
    onPointerCancel: _pointerCancel,
    child: child,
  );

  @override
  void dispose() {
    _pull.dispose();
    _contentScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _pull,
    builder: (context, child) => Transform.translate(
      offset: Offset(0, _pull.value),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(_pull.value > 0 ? 24 : 0),
        ),
        child: child,
      ),
    ),
    child: AnimatedBuilder(
      animation: Listenable.merge([widget.library, widget.voice]),
      builder: (context, _) {
        final library = widget.library;
        final track = library.current;
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide =
                    constraints.maxWidth > 600 &&
                    constraints.maxWidth > constraints.maxHeight;
                final listening = _dismissRegion(
                  _ListeningBody(
                    track: track,
                    library: library,
                    scrollController: _contentScroll,
                    dismissDragging: _dragging,
                  ),
                  content: true,
                );
                final controls = _PlaybackPanel(
                  library: library,
                  voice: widget.voice,
                );
                return Column(
                  children: [
                    _dismissRegion(_PlayerHeader(library: library)),
                    Expanded(
                      child: wide
                          ? Row(
                              children: [
                                Expanded(child: listening),
                                Expanded(
                                  child: SingleChildScrollView(child: controls),
                                ),
                              ],
                            )
                          : listening,
                    ),
                    if (!wide) controls,
                  ],
                );
              },
            ),
          ),
        );
      },
    ),
  );
}

class _PlayerHeader extends StatelessWidget {
  const _PlayerHeader({required this.library});
  final LibraryController library;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
    child: Row(
      children: [
        Tooltip(
          message: '返回',
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: ink,
              minimumSize: const Size(76, 48),
            ),
            icon: const Icon(Icons.arrow_back_rounded, size: 21),
            label: const Text('返回', style: TextStyle(fontSize: 13)),
          ),
        ),
        Expanded(
          child: Text(
            library.playing ? '正在播放' : '听一听',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(
          width: 76,
          child: IconButton(
            key: const Key('player-favorite'),
            tooltip: library.favorites.contains(library.current.id)
                ? '取消收藏'
                : '收藏',
            onPressed: () => library.toggleFavorite(library.current),
            icon: Icon(
              library.favorites.contains(library.current.id)
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: coral,
              size: 24,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ListeningBody extends StatelessWidget {
  const _ListeningBody({
    required this.track,
    required this.library,
    required this.scrollController,
    required this.dismissDragging,
  });
  final Track track;
  final LibraryController library;
  final ScrollController scrollController;
  final bool dismissDragging;
  double _textHeight(
    BuildContext context,
    String text,
    TextStyle style,
    double width, {
    int? maxLines,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: DefaultTextStyle.of(context).style.merge(style),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: maxLines,
      ellipsis: maxLines == null ? null : '…',
    )..layout(maxWidth: width);
    final height = painter.height;
    painter.dispose();
    return height;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final caption = track.captionAt(library.position);
      final width = (constraints.maxWidth - 48).clamp(1.0, 440.0);
      final captionWidth = (width - 38).clamp(1.0, double.infinity);
      final titleHeight =
          _textHeight(
            context,
            track.title,
            const TextStyle(
              fontSize: 25,
              height: 1.25,
              fontWeight: FontWeight.w800,
              letterSpacing: -.4,
            ),
            width,
            maxLines: 2,
          ) +
          _textHeight(
            context,
            track.subtitle,
            const TextStyle(fontSize: 13),
            width,
          ) +
          MediaQuery.textScalerOf(context).scale(10) * 1.5 +
          23;
      // Reserve the longest sentence so covers stay still as subtitles change.
      final captionHeight = track.captions.fold<double>(0, (height, item) {
        final next =
            _textHeight(
              context,
              item.english,
              const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
              captionWidth,
            ) +
            _textHeight(
              context,
              item.chinese,
              const TextStyle(fontSize: 12, height: 1.5),
              captionWidth,
            ) +
            39;
        return next > height ? next : height;
      });
      final availableCover =
          constraints.maxHeight - titleHeight - captionHeight - 78;
      final horizontalCover =
          availableCover < 140 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.2;
      final coverSize = horizontalCover
          ? 90.0
          : availableCover.clamp(140.0, 250.0);
      final cover = Container(
        width: coverSize,
        height: coverSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Color(track.color).withValues(alpha: .45),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: CoverArt(
          scene: track.art,
          color: Color(track.color),
          radius: 26,
        ),
      );
      final title = Column(
        crossAxisAlignment: horizontalCover
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Text(
            track.title,
            textAlign: horizontalCover ? TextAlign.left : TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: horizontalCover ? 21 : 25,
              height: 1.25,
              fontWeight: FontWeight.w800,
              letterSpacing: -.4,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            track.subtitle,
            textAlign: horizontalCover ? TextAlign.left : TextAlign.center,
            style: const TextStyle(fontSize: 13, color: muted),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              track.category == TrackCategory.rhymes
                  ? '英文儿歌 · 朗读版'
                  : track.category.label,
              style: const TextStyle(fontSize: 10, color: muted),
            ),
          ),
        ],
      );
      return SingleChildScrollView(
        key: const PageStorageKey('player-content'),
        controller: scrollController,
        primary: false,
        physics: dismissDragging
            ? const NeverScrollableScrollPhysics()
            : const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - 32).clamp(0.0, double.infinity),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (horizontalCover)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        cover,
                        const SizedBox(width: 18),
                        Expanded(child: title),
                      ],
                    )
                  else ...[
                    cover,
                    const SizedBox(height: 20),
                    title,
                  ],
                  SizedBox(height: horizontalCover ? 16 : 22),
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(minHeight: captionHeight),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 15,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: line),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Column(
                        key: ValueKey('${track.id}-${caption.english}'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            caption.english,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            caption.chinese,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: muted,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (library.message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        library.message!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: coral, fontSize: 12),
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

class _PlaybackPanel extends StatelessWidget {
  const _PlaybackPanel({required this.library, required this.voice});
  final LibraryController library;
  final VoiceController voice;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      border: Border.all(color: line),
    ),
    child: SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SeekBar(key: ValueKey(library.current.id), library: library),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      key: const Key('player-previous'),
                      tooltip: '上一首',
                      onPressed: library.busy ? null : () => library.skip(-1),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(56, 56),
                      ),
                      icon: const Icon(Icons.skip_previous_rounded, size: 35),
                    ),
                    const SizedBox(width: 28),
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: FilledButton(
                        key: const Key('player-play'),
                        style: FilledButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: const CircleBorder(),
                        ),
                        onPressed: library.busy ? null : library.togglePlay,
                        child: library.busy
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                library.playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                size: 43,
                              ),
                      ),
                    ),
                    const SizedBox(width: 28),
                    IconButton(
                      key: const Key('player-next'),
                      tooltip: '下一首',
                      onPressed: library.busy ? null : () => library.skip(1),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(56, 56),
                      ),
                      icon: const Icon(Icons.skip_next_rounded, size: 35),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ControlAction(
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
                          RepeatSetting.values[(library.repeat.index + 1) %
                              RepeatSetting.values.length],
                        ),
                      ),
                    ),
                    Expanded(
                      child: _ControlAction(
                        icon: Icons.bedtime_outlined,
                        label: library.remaining == null
                            ? '睡前定时'
                            : clockLabel(library.remaining!),
                        selected: library.remaining != null,
                        onTap: () => showTimerSheet(context, library),
                      ),
                    ),
                    Expanded(
                      child: _ControlAction(
                        icon: voice.waitingForWakeWord
                            ? Icons.hearing_rounded
                            : Icons.mic_none_rounded,
                        label: voice.assistantEnabled ? '语音已开启' : '语音助手',
                        selected: voice.assistantEnabled,
                        onTap: () => showVoiceSheet(context, voice),
                      ),
                    ),
                    Expanded(
                      child: _ControlAction(
                        icon: Icons.queue_music_rounded,
                        label: '播放列表',
                        onTap: () => showQueueSheet(context, library),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _SeekBar extends StatefulWidget {
  const _SeekBar({super.key, required this.library});
  final LibraryController library;
  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _dragValue;
  int _seekGeneration = 0;

  Future<void> _seek(double value) async {
    final generation = ++_seekGeneration;
    try {
      await widget.library.seek(Duration(milliseconds: value.round()));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('进度调整未成功，请再试一次。')));
      }
    } finally {
      if (mounted && generation == _seekGeneration) {
        setState(() => _dragValue = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = widget.library;
    final duration = library.duration.inMilliseconds.toDouble().clamp(
      1.0,
      double.infinity,
    );
    final value = (_dragValue ?? library.position.inMilliseconds.toDouble())
        .clamp(0.0, duration);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            key: const Key('seek'),
            value: value,
            max: duration,
            onChangeStart: library.busy
                ? null
                : (value) {
                    _seekGeneration++;
                    setState(() => _dragValue = value);
                  },
            onChanged: library.busy
                ? null
                : (value) => setState(() => _dragValue = value),
            onChangeEnd: library.busy
                ? null
                : (value) {
                    setState(() => _dragValue = value);
                    unawaited(_seek(value));
                  },
            semanticFormatterCallback: (value) =>
                clockLabel(Duration(milliseconds: value.round())),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                clockLabel(Duration(milliseconds: value.round())),
                style: const TextStyle(fontSize: 10, color: muted),
              ),
              Text(
                clockLabel(library.duration),
                style: const TextStyle(fontSize: 10, color: muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ControlAction extends StatelessWidget {
  const _ControlAction({
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
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: selected ? coral : muted,
        minimumSize: const Size(48, 54),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    ),
  );
}
