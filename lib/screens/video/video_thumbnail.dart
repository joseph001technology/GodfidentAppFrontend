import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/local_video.dart';
import '../../providers/video_provider.dart';

/// A preview picture of a video (a frame about one second in), like the Gallery.
/// Made on the phone, kept only in memory, never uploaded.
class VideoThumbnail extends ConsumerStatefulWidget {
  final LocalVideo video;

  const VideoThumbnail({super.key, required this.video});

  @override
  ConsumerState<VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends ConsumerState<VideoThumbnail> {
  static final _cache = <String, Uint8List>{};
  static const _maxCached = 120;

  Uint8List? _bytes;

  String get _key => '${widget.video.id}:${widget.video.fileSize}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant VideoThumbnail old) {
    super.didUpdateWidget(old);
    final oldKey = '${old.video.id}:${old.video.fileSize}';
    if (oldKey != _key || (old.video.available != widget.video.available)) _load();
  }

  Future<void> _load() async {
    final key = _key;
    final cached = _cache[key];
    if (cached != null) {
      setState(() => _bytes = cached);
      return;
    }
    if (!widget.video.available || widget.video.uri == null) {
      setState(() => _bytes = null);
      return;
    }
    final bytes = await ref.read(videoLibraryStoreProvider).thumbnail(widget.video);
    if (!mounted || key != _key) return;
    if (bytes != null && bytes.isNotEmpty) {
      if (_cache.length >= _maxCached) _cache.remove(_cache.keys.first);
      _cache[key] = bytes;
      setState(() => _bytes = bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _bytes;
    if (b != null) return Image.memory(b, fit: BoxFit.cover, gaplessPlayback: true);
    return Container(
      color: AppTheme.navyVariant,
      alignment: Alignment.center,
      child: Icon(Icons.movie_outlined, color: AppTheme.textMuted, size: 30),
    );
  }
}
