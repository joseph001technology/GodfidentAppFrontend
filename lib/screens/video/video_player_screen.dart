import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme.dart';
import '../../models/local_video.dart';
import '../../providers/video_provider.dart';
import '../../services/video/random_video_service.dart';

/// Full-screen player for a local video.
///
/// * `/video-player/<id>?preview=1` plays one library video (not counted in the
///   random history).
/// * `/video-player/random` asks the random service for a video, skips any that
///   fail to open, and shows a friendly screen when none is available. This is
///   the route the blocking code will open.
class VideoPlayerScreen extends ConsumerStatefulWidget {
  final String videoId;
  final bool preview;

  /// `rules` or `bible`: where to go instead when no video can be shown (random mode only).
  final String? fallback;

  const VideoPlayerScreen({super.key, required this.videoId, this.preview = false, this.fallback});

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> with WidgetsBindingObserver {
  VideoPlayerController? _c;
  LocalVideo? _video;
  bool _loading = true;
  String? _error;
  NoVideoReason? _noVideo;
  bool _confirmed = false;
  bool _controls = true;
  Timer? _hide;
  final _failed = <String>{};

  bool get _random => widget.videoId == 'random';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hide?.cancel();
    _c?.removeListener(_tick);
    _c?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) _c?.pause();
  }

  Future<void> _start() async {
    final store = ref.read(videoLibraryStoreProvider);
    final svc = ref.read(randomVideoServiceProvider);
    setState(() {
      _loading = true;
      _error = null;
      _noVideo = null;
    });

    // Every failure adds the video to _failed, so this loop always ends.
    while (mounted) {
      LocalVideo? v;
      if (_random) {
        final pick = await svc.next(skip: _failed);
        if (!mounted) return;
        if (!pick.found) {
          final fb = widget.fallback;
          if (fb != null) {
            // Nothing to play: keep the old behaviour (Rules or Bible).
            final messenger = ScaffoldMessenger.maybeOf(context);
            final rules = fb == 'rules';
            context.go(rules ? '/rules' : '/bible');
            messenger?.showSnackBar(SnackBar(
              content: Text(rules
                  ? 'That was blocked. Here are your rules \u2014 spend this moment with God.'
                  : 'That was blocked. Here is the Bible \u2014 spend this moment with God.'),
            ));
            return;
          }
          setState(() {
            _loading = false;
            _noVideo = pick.reason;
          });
          return;
        }
        v = pick.video;
      } else {
        if (store.byId(widget.videoId) == null) await store.load();
        v = store.byId(widget.videoId);
        if (!mounted) return;
        if (v == null || !v.available || v.uri == null) {
          setState(() {
            _loading = false;
            _error = 'This video is no longer in your Godfident folder.';
          });
          return;
        }
      }

      if (await _open(v!)) return;
      if (!mounted) return;
      if (!_random) {
        await svc.reportFailure(v.id);
        setState(() {
          _loading = false;
          _error = 'This video could not be played. Its format may not be supported.';
        });
        return;
      }
      _failed.add(v.id);
      await svc.reportFailure(v.id);
    }
  }

  Future<bool> _open(LocalVideo v) async {
    _c?.removeListener(_tick);
    await _c?.dispose();
    _c = null;
    final c = VideoPlayerController.contentUri(Uri.parse(v.uri!));
    try {
      await c.initialize().timeout(const Duration(seconds: 12));
    } catch (_) {
      await c.dispose();
      return false;
    }
    if (!mounted) {
      await c.dispose();
      return true;
    }
    _confirmed = false;
    _c = c;
    _video = v;
    c.addListener(_tick);
    await c.setLooping(false);
    await c.play();
    setState(() => _loading = false);
    _scheduleHide();
    return true;
  }

  /// Playback really started -> count it once in the random history.
  void _tick() {
    final c = _c;
    if (c == null || !mounted) return;
    if (!_confirmed && c.value.isPlaying && c.value.position > Duration.zero) {
      _confirmed = true;
      final id = _video?.id;
      if (id != null && !widget.preview) ref.read(randomVideoServiceProvider).confirmPlayed(id);
    }
    if (c.value.hasError && _error == null) {
      setState(() => _error = 'Playback stopped unexpectedly.');
    } else {
      setState(() {});
    }
  }

  void _scheduleHide() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 3), () {
      if (mounted && (_c?.value.isPlaying ?? false)) setState(() => _controls = false);
    });
  }

  void _toggleControls() {
    setState(() => _controls = !_controls);
    if (_controls) _scheduleHide();
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_noVideo != null) return _message(_noVideo == NoVideoReason.folderNotConnected ? 'Connect your video folder' : 'No videos yet',
        _noVideo == NoVideoReason.folderNotConnected
            ? 'Godfident needs access to your video folder before it can play something for you.'
            : 'Add a few videos and Godfident will play one here whenever something blocked is opened.',
        action: 'Open Videos', onAction: () => context.go('/videos'));
    if (_error != null) return _message('Could not play this video', _error!);
    final c = _c;
    if (_loading || c == null) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.gold));
    }
    final v = c.value;
    final pos = v.position;
    final dur = v.duration;
    final ended = dur > Duration.zero && pos >= dur;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleControls,
      child: Stack(children: [
        Center(child: AspectRatio(aspectRatio: v.aspectRatio == 0 ? 16 / 9 : v.aspectRatio, child: VideoPlayer(c))),
        if (_controls || ended)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xAA000000), Color(0x00000000), Color(0xCC000000)],
                ),
              ),
              child: Column(children: [
                Row(children: [
                  IconButton(icon: const Icon(Icons.close, color: Colors.white), tooltip: 'Close', onPressed: _close),
                  Expanded(
                    child: Text(_video?.title ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ]),
                const Spacer(),
                IconButton(
                  iconSize: 64,
                  color: Colors.white,
                  icon: Icon(ended ? Icons.replay : (v.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill)),
                  onPressed: () async {
                    if (ended) {
                      await c.seekTo(Duration.zero);
                    }
                    v.isPlaying && !ended ? await c.pause() : await c.play();
                    _scheduleHide();
                  },
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Row(children: [
                    Text(_fmt(pos), style: const TextStyle(color: Colors.white, fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: dur.inMilliseconds == 0 ? 0 : pos.inMilliseconds.clamp(0, dur.inMilliseconds).toDouble(),
                        max: dur.inMilliseconds == 0 ? 1 : dur.inMilliseconds.toDouble(),
                        activeColor: AppTheme.gold,
                        inactiveColor: Colors.white24,
                        onChanged: (x) => c.seekTo(Duration(milliseconds: x.toInt())),
                        onChangeEnd: (_) => _scheduleHide(),
                      ),
                    ),
                    Text(_fmt(dur), style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ]),
                ),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _message(String title, String body, {String? action, VoidCallback? onAction}) => Stack(children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.video_library_outlined, color: AppTheme.gold, size: 52),
              const SizedBox(height: 14),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(body, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, height: 1.4)),
              if (action != null) ...[
                const SizedBox(height: 18),
                FilledButton(onPressed: onAction, child: Text(action)),
              ],
            ]),
          ),
        ),
        Positioned(top: 4, left: 4, child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: _close)),
      ]);
}
