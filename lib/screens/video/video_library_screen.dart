import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';
import '../../models/local_video.dart';
import '../../providers/video_provider.dart';
import '../../services/video/video_folder_gateway.dart';
import '../../services/video/video_library_store.dart';
import 'video_thumbnail.dart';

/// Videos: the clips Godfident shows when you try to open something blocked.
/// They live in Movies/Godfident on this phone (visible in Gallery) and are
/// never uploaded anywhere.
class VideoLibraryScreen extends ConsumerStatefulWidget {
  const VideoLibraryScreen({super.key});

  @override
  ConsumerState<VideoLibraryScreen> createState() => _VideoLibraryScreenState();
}

class _VideoLibraryScreenState extends ConsumerState<VideoLibraryScreen> {
  LibraryState? _state;
  bool _busy = true;
  String? _note;

  VideoLibraryStore get _store => ref.read(videoLibraryStoreProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool recheck = false}) async {
    setState(() => _busy = true);
    final s = await _store.load(recheck: recheck);
    if (!mounted) return;
    setState(() {
      _state = s;
      _busy = false;
      if (s.manifestRebuilt) {
        _note = 'Found ${s.videos.length} video(s) in your Godfident folder and added them to the library.';
      }
    });
  }

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _connect() async {
    setState(() => _busy = true);
    final out = await _store.connectFolder();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (out.state != null) _state = out.state;
    });
    switch (out.pick.error) {
      case null:
        _say('Folder connected: ${out.state?.folder.folderPath ?? 'Movies/Godfident'}');
      case 'cancelled':
        break;
      case 'wrong_folder':
        _say('Please open the "Movies" folder and tap "Use this folder". Godfident keeps its videos in Movies/Godfident.');
      default:
        _say('Could not open that folder. Please try again.');
    }
  }

  Future<void> _importAll(List<String> uris, {VideoSource source = VideoSource.imported, List<String?>? names}) async {
    if (uris.isEmpty) return;
    setState(() => _busy = true);
    var added = 0;
    var already = 0;
    final problems = <String>{};
    for (var i = 0; i < uris.length; i++) {
      final o = await _store.importVideo(uris[i], source: source, name: names?[i]);
      if (o.ok) {
        o.duplicate ? already++ : added++;
      } else {
        problems.add(switch (o.error) {
          ImportError.notVideo => 'not a video',
          ImportError.noSpace => 'not enough storage',
          ImportError.unsupported => 'format not supported',
          ImportError.folderNotConnected => 'folder not connected',
          _ => 'could not be copied',
        });
      }
    }
    await _load();
    final parts = <String>[
      if (added > 0) 'Added $added',
      if (already > 0) '$already already in library',
      if (problems.isNotEmpty) 'Skipped: ${problems.join(', ')}',
    ];
    _say(parts.join(' · '));
  }

  Future<void> _add() async {
    final uris = await _store.pickVideoFiles();
    await _importAll(uris);
  }

  Future<void> _record() async {
    try {
      final x = await ImagePicker().pickVideo(source: ImageSource.camera);
      if (x == null) return;
      await _importAll([Uri.file(x.path).toString()], source: VideoSource.recorded, names: [x.name]);
    } catch (_) {
      _say('Could not open the camera. Check that Godfident is allowed to use it.');
    }
  }

  Future<void> _rename(LocalVideo v) async {
    final c = TextEditingController(text: v.title);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(controller: c, autofocus: true, textCapitalization: TextCapitalization.sentences),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    final text = c.text;
    c.dispose();
    if (ok == true) {
      await _store.rename(v.id, text);
      await _load();
    }
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action, style: const TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    return r == true;
  }

  Future<void> _menu(String action, LocalVideo v) async {
    switch (action) {
      case 'rename':
        await _rename(v);
      case 'exclude':
        await _store.setExcluded(v.id, !v.excluded);
        await _load();
      case 'remove':
        if (await _confirm('Remove from Godfident?', 'The file stays in Movies/Godfident on your phone. Godfident just stops listing it.', 'Remove')) {
          await _store.removeFromLibrary(v.id);
          await _load();
        }
      case 'delete':
        if (await _confirm('Delete the file?', '"${v.title}" will be permanently deleted from your phone. This cannot be undone.', 'Delete file')) {
          final ok = await _store.deleteFilePermanently(v.id);
          await _load();
          if (!ok) _say('Android did not allow deleting that file.');
        }
    }
  }

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    final s = _state;
    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        title: const Text('Videos'),
        backgroundColor: AppTheme.navy,
        foregroundColor: AppTheme.inkNavy,
        elevation: 0,
        actions: [
          // Saved links to videos on Instagram / TikTok / Facebook / YouTube: a separate section.
          IconButton(
            tooltip: 'Online videos',
            icon: const Icon(Icons.cloud_outlined),
            onPressed: () => context.push('/online-videos'),
          ),
          if (s?.folder.connected == true)
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: _busy ? null : () => _load(recheck: true),
            ),
        ],
      ),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : !s.folder.connected
              ? _connectView(s.folder)
              : _libraryView(s),
    );
  }

  Widget _connectView(FolderStatus f) {
    final why = switch (f.problem) {
      FolderProblem.accessLost => 'Android no longer lets Godfident use your video folder (this happens after a reinstall). Choose it again and everything comes back.',
      FolderProblem.folderMissing => 'The Godfident video folder was moved or deleted. Choose it again to continue.',
      _ => 'Godfident keeps your videos in a folder on your phone, so they stay yours even if you reinstall the app.',
    };
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 12),
        const Icon(Icons.video_library_outlined, size: 56, color: AppTheme.goldDark),
        const SizedBox(height: 16),
        Text('Your video folder',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Lora', fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.ink)),
        const SizedBox(height: 10),
        Text(why, textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary, height: 1.4)),
        const SizedBox(height: 18),
        _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('How to connect', style: TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          Text('1. Tap the button below.\n2. Open the "Movies" folder.\n3. Tap "Use this folder", then "Allow".\n\nGodfident uses Movies/Godfident, creating it only if it does not exist yet. If you used Godfident videos before, pick the same place and your library returns as it was.',
              style: TextStyle(color: AppTheme.textSecondary, height: 1.45)),
        ])),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _busy ? null : _connect,
          icon: const Icon(Icons.folder_open),
          label: const Text('Choose the Godfident folder'),
        ),
        const SizedBox(height: 14),
        Text('Nothing is uploaded. Videos never leave your phone.',
            textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
      ],
    );
  }

  Widget _libraryView(LibraryState s) {
    final videos = s.videos;
    return Column(children: [
      Expanded(
        child: RefreshIndicator(
          onRefresh: () => _load(recheck: true),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              _panel(Row(children: [
                const Icon(Icons.shield_outlined, color: AppTheme.goldDark),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      s.eligibleCount == 0
                          ? 'No videos ready yet'
                          : '${s.eligibleCount} video${s.eligibleCount == 1 ? '' : 's'} ready',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'When something blocked is opened, Godfident plays one of these at random. Saved in ${s.folder.folderPath} on your phone.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5, height: 1.35),
                    ),
                  ]),
                ),
              ])),
              if (_note != null) ...[
                const SizedBox(height: 10),
                _panel(Text(_note!, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5))),
              ],
              const SizedBox(height: 12),
              if (videos.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(children: [
                    Icon(Icons.movie_creation_outlined, size: 48, color: AppTheme.textMuted),
                    SizedBox(height: 10),
                    Text('Add your first video', style: TextStyle(fontWeight: FontWeight.w700)),
                    SizedBox(height: 4),
                    Text('Pick videos from your phone or record one.', style: TextStyle(color: AppTheme.textSecondary)),
                  ]),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: videos.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 0.78,
                  ),
                  itemBuilder: (_, i) => _tile(videos[i]),
                ),
            ],
          ),
        ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : _add,
                icon: _busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.add),
                label: const Text('Add videos'),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: _busy ? null : _record,
              icon: const Icon(Icons.videocam_outlined),
              label: const Text('Record'),
            ),
          ]),
        ),
      ),
    ]);
  }

  /// One Gallery-style tile: the video's own picture, its length, and its name.
  Widget _tile(LocalVideo v) {
    final playable = v.available && v.playable;
    final note = !v.available
        ? 'Missing'
        : !v.playable
            ? "Can't play"
            : v.excluded
                ? 'Not used\nfor redirects'
                : null;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: playable ? () => context.push('/video-player/${v.id}?preview=1') : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(fit: StackFit.expand, children: [
          VideoThumbnail(video: v),
          // Darken the bottom so the name is readable on any picture.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0xB3000000)],
              ),
            ),
          ),
          if (note != null)
            Container(
              color: const Color(0x99000000),
              alignment: Alignment.center,
              child: Text(note,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            )
          else
            const Center(child: Icon(Icons.play_circle_outline, color: Colors.white70, size: 34)),
          Positioned(
            left: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(8)),
              child: Text(_duration(v.durationMs), style: const TextStyle(color: Colors.white, fontSize: 11)),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: PopupMenuButton<String>(
              iconSize: 20,
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (a) => _menu(a, v),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'rename', child: Text('Rename')),
                PopupMenuItem(value: 'exclude', child: Text(v.excluded ? 'Use for redirects' : 'Do not use for redirects')),
                const PopupMenuItem(value: 'remove', child: Text('Remove from Godfident')),
                const PopupMenuItem(value: 'delete', child: Text('Delete file from phone\u2026')),
              ],
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 6,
            child: Text(v.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }

  Widget _panel(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.navySurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.navyOutline),
        ),
        child: child,
      );

  static String _duration(int ms) {
    if (ms <= 0) return '--:--';
    final t = Duration(milliseconds: ms);
    final m = t.inMinutes;
    final s = (t.inSeconds % 60).toString().padLeft(2, '0');
    return t.inHours > 0 ? '${t.inHours}:${(m % 60).toString().padLeft(2, '0')}:$s' : '$m:$s';
  }
}
