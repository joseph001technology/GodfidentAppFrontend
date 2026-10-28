import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/online_video.dart';
import '../../providers/online_video_provider.dart';
import '../../services/online_video/thumbnail_cache.dart';

IconData platformIcon(VideoPlatform p) => switch (p) {
      VideoPlatform.youtube => Icons.smart_display_outlined,
      VideoPlatform.instagram => Icons.photo_camera_outlined,
      VideoPlatform.tiktok => Icons.music_note,
      VideoPlatform.facebook => Icons.thumb_up_alt_outlined,
      VideoPlatform.vimeo => Icons.movie_outlined,
      VideoPlatform.other => Icons.link,
    };

/// One gallery card for a saved online video.
///
/// LAZY: a card only does anything when the grid actually builds it (i.e. it is
/// on screen or about to be). It then waits a moment ([_settle]) so that cards a
/// fast scroll flies past never cause a request, asks for its one-time title /
/// thumbnail lookup if still needed, and finally asks the thumbnail cache for
/// the picture. When the card is removed from the tree its claim is released,
/// which cancels a download nobody wants any more.
class OnlineVideoCard extends ConsumerStatefulWidget {
  final OnlineVideo video;
  final VoidCallback onOpen;
  final void Function(String action) onMenu;

  const OnlineVideoCard({super.key, required this.video, required this.onOpen, required this.onMenu});

  @override
  ConsumerState<OnlineVideoCard> createState() => _OnlineVideoCardState();
}

class _OnlineVideoCardState extends ConsumerState<OnlineVideoCard> {
  static const _settle = Duration(milliseconds: 180);

  Timer? _timer;
  ThumbHandle? _handle;
  Uint8List? _bytes;
  String? _bytesFor; // the thumbnail address _bytes belongs to

  @override
  void initState() {
    super.initState();
    _begin();
  }

  @override
  void didUpdateWidget(covariant OnlineVideoCard old) {
    super.didUpdateWidget(old);
    if (old.video.thumbUrl != widget.video.thumbUrl || old.video.id != widget.video.id) {
      _bytes = null;
      _bytesFor = null;
      _begin();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _handle?.release(); // cancels the download if nobody else wants it
    super.dispose();
  }

  void _begin() {
    _timer?.cancel();
    _handle?.release();
    _handle = null;
    final url = widget.video.thumbUrl;

    // Already in memory: show it at once, no waiting, no request.
    if (url != null) {
      final hit = OnlineThumbnailCache.instance.peek(url);
      if (hit != null) {
        _bytes = hit;
        _bytesFor = url;
      }
    }
    final needsMeta = widget.video.metaState == MetaState.pending;
    if (_bytes != null && !needsMeta) return;
    _timer = Timer(_settle, _start);
  }

  void _start() {
    if (!mounted) return;
    final v = widget.video;
    final ctrl = ref.read(onlineLibraryProvider.notifier);
    if (v.metaState == MetaState.pending) ctrl.ensureMeta(v); // once; the answer is saved locally
    final url = v.thumbUrl;
    if (url == null || (_bytes != null && _bytesFor == url)) return;

    final online = ref.read(onlineLibraryProvider).online;
    final h = OnlineThumbnailCache.instance.request(url, allowNetwork: online);
    _handle = h;
    h.future.then((r) {
      if (!mounted || !identical(_handle, h)) return;
      if (r.ok) {
        setState(() {
          _bytes = r.bytes;
          _bytesFor = url;
        });
      } else if (r.failure == ThumbFailure.gone) {
        ctrl.thumbnailGone(v); // expired address: ask the platform for a fresh one (once)
      }
      // network: the placeholder stays; the card retries when internet returns (see build)
    });
  }

  @override
  Widget build(BuildContext context) {
    // Internet came back: a card still without its picture tries again.
    ref.listen<int>(onlineLibraryProvider.select((s) => s.retryTick), (prev, next) {
      if (_bytes == null) _begin();
    });
    final online = ref.watch(onlineLibraryProvider.select((s) => s.online));
    final v = widget.video;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: widget.onOpen,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.navySurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.navyOutline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(fit: StackFit.expand, children: [
              _picture(v, online),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0x66000000)],
                  ),
                ),
              ),
              const Center(child: Icon(Icons.play_circle_outline, color: Colors.white70, size: 36)),
              // The badge says this is an ONLINE video (a link), unlike the clips stored on the phone.
              Positioned(
                left: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.cloud_outlined, size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(v.platform.label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: PopupMenuButton<String>(
                  iconSize: 20,
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: widget.onMenu,
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'open', child: Text('Watch')),
                    PopupMenuItem(value: 'original', child: Text('Open original')),
                    PopupMenuItem(value: 'move', child: Text('Move to collection…')),
                    PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(value: 'refresh', child: Text('Refresh preview')),
                    PopupMenuItem(value: 'remove', child: Text('Remove')),
                  ],
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Text(
              v.displayTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.25, color: AppTheme.textPrimary),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _picture(OnlineVideo v, bool online) {
    final b = _bytes;
    if (b != null) {
      return Image.memory(
        b,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        cacheWidth: 480, // decode small: this is a card, not a full picture
        errorBuilder: (_, __, ___) => _placeholder(v, online),
      );
    }
    return _placeholder(v, online);
  }

  /// Clean placeholder: used while loading, when the platform gives no picture
  /// (Instagram / Facebook), when it expired, and when offline.
  Widget _placeholder(OnlineVideo v, bool online) => Container(
        color: AppTheme.navyVariant,
        alignment: Alignment.center,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(platformIcon(v.platform), size: 30, color: AppTheme.textMuted),
          if (!online && v.thumbUrl != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Icon(Icons.cloud_off_outlined, size: 14, color: AppTheme.textMuted),
            ),
        ]),
      );
}
