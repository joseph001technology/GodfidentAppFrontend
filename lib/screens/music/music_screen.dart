import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme.dart';
import '../../services/music_controller.dart';
import '../../services/music_service.dart';
import '../../services/permissions_service.dart';

enum _DeviceState { loading, needsPermission, denied, empty, ready, error }

/// Music: chants and hymns bundled with Godfident, songs you pinned, and every
/// audio file on the phone (newest first). Opening this screen while something
/// plays takes you straight to that song, which is highlighted and animated.
class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});
  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _rowHeight = 72.0;

  final _music = MusicController.instance;
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _scroll = [ScrollController(), ScrollController()];

  _DeviceState _state = _DeviceState.loading;
  List<Song> _device = const [];
  List<Song> _pinned = const [];
  String _query = '';
  String? _lastRevealedId;
  Song? get _current => _music.current;
  String? get _playError => _music.error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) _reveal();
    });
    _music.addListener(_onMusic);
    _init();
  }

  Future<void> _init() async {
    _pinned = await PinnedSongs.instance.load();
    if (!mounted) return;
    final cur = _current;
    if (cur != null && cur.isDevice && !_pinned.any((p) => p.id == cur.id)) _tabs.index = 1;
    setState(() {});
    _reveal();
    await _loadDevice();
  }

  void _onMusic() {
    if (!mounted) return;
    setState(() {});
    final id = _current?.id;
    if (id != null && id != _lastRevealedId) _reveal(animate: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // The player is NOT disposed: it belongs to the app, so music goes on
    // when you leave this screen.
    _music.removeListener(_onMusic);
    _tabs.dispose();
    for (final c in _scroll) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    // Returning from Android's permission settings: re-check for real.
    if (s == AppLifecycleState.resumed && (_state == _DeviceState.denied || _state == _DeviceState.needsPermission)) {
      _loadDevice();
    }
  }

  List<Song> get _godfidentList => [..._pinned, ...bundledSongs];

  List<Song> get _deviceShown {
    final q = _query.toLowerCase();
    return _device.where((s) => q.isEmpty || s.title.toLowerCase().contains(q) || s.artist.toLowerCase().contains(q)).toList();
  }

  /// Scrolls the visible list so the song that is playing sits near the top.
  void _reveal({bool animate = false}) {
    final cur = _current;
    if (cur == null) return;
    _lastRevealedId = cur.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final tab = _tabs.index;
      final list = tab == 0 ? _godfidentList : _deviceShown;
      final i = list.indexWhere((s) => s.id == cur.id);
      final c = _scroll[tab];
      if (i < 0 || !c.hasClients) return;
      final target = (i * _rowHeight - _rowHeight * 1.5).clamp(0.0, c.position.maxScrollExtent);
      if (animate) {
        c.animateTo(target, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
      } else {
        c.jumpTo(target);
      }
    });
  }

  Future<void> _loadDevice({bool ask = false}) async {
    setState(() => _state = _DeviceState.loading);
    final perms = PermissionsService.instance;
    try {
      var granted = await perms.audioGranted();
      if (!granted && ask) {
        final st = await perms.audioRequest();
        granted = st.isGranted;
        if (!granted) {
          if (mounted) setState(() => _state = st.isPermanentlyDenied ? _DeviceState.denied : _DeviceState.needsPermission);
          return;
        }
      }
      if (!granted) {
        if (mounted) setState(() => _state = (_state == _DeviceState.denied) ? _DeviceState.denied : _DeviceState.needsPermission);
        if (!ask && await perms.audioPermanentlyDenied()) {
          if (mounted) setState(() => _state = _DeviceState.denied);
        }
        return;
      }
      final songs = await DeviceMusicService.instance.loadSongs(); // newest first
      if (!mounted) return;
      setState(() {
        _device = songs;
        _state = songs.isEmpty ? _DeviceState.empty : _DeviceState.ready;
      });
      if (_tabs.index == 1) _reveal();
    } catch (_) {
      if (mounted) setState(() => _state = _DeviceState.error);
    }
  }

  Future<void> _play(List<Song> list, Song song) =>
      _music.playList(list, list.indexWhere((s) => s.id == song.id));

  Future<void> _addFromPhone() async {
    final n = await PinnedSongs.instance.pickAndPin();
    _pinned = await PinnedSongs.instance.load();
    if (!mounted) return;
    setState(() {});
    if (n > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$n song${n == 1 ? '' : 's'} pinned beside the Godfident music')));
    }
  }

  Future<void> _togglePin(Song s) async {
    final isPinned = _pinned.any((p) => p.id == s.id || p.uri == s.uri);
    if (isPinned) {
      await PinnedSongs.instance.unpin(s);
    } else {
      await PinnedSongs.instance.pin(s);
    }
    _pinned = await PinnedSongs.instance.load();
    if (mounted) setState(() {});
  }

  String _fmt(Duration d) => d == Duration.zero ? '' : '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        title: const Text('Music'),
        backgroundColor: AppTheme.navy,
        foregroundColor: AppTheme.inkNavy,
        elevation: 0,
        bottom: TabBar(
          controller: _tabs,
          onTap: (_) => setState(() {}),
          labelColor: AppTheme.goldDark,
          indicatorColor: AppTheme.gold,
          unselectedLabelColor: AppTheme.textMuted,
          tabs: const [Tab(text: 'Godfident'), Tab(text: 'On this phone')],
        ),
      ),
      body: Column(children: [
        Expanded(
          child: TabBarView(controller: _tabs, physics: const NeverScrollableScrollPhysics(), children: [
            _godfidentTab(),
            _deviceTab(),
          ]),
        ),
        if (_playError != null)
          Container(
            width: double.infinity,
            color: AppTheme.danger.withValues(alpha: 0.1),
            padding: const EdgeInsets.all(10),
            child: Text(_playError!, style: const TextStyle(color: AppTheme.danger, fontSize: 12)),
          ),
      ]),
    );
  }

  Widget _godfidentTab() {
    final list = _godfidentList;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _addFromPhone,
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
            icon: const Icon(Icons.push_pin_outlined, size: 18),
            label: const Text('Pin songs from this phone'),
          ),
        ),
      ),
      Expanded(child: _songList(list, 0, pinnedRemovable: true)),
    ]);
  }

  Widget _deviceTab() {
    switch (_state) {
      case _DeviceState.loading:
        return const Center(child: CircularProgressIndicator(color: AppTheme.gold));
      case _DeviceState.needsPermission:
        return _message(Icons.library_music_outlined, 'Allow access to your music',
            'Godfident needs permission to see the songs stored on your phone.', 'Allow', () => _loadDevice(ask: true));
      case _DeviceState.denied:
        return _message(Icons.lock_outline, 'Music access is turned off',
            'Open Android settings → Permissions → Music and audio, and allow Godfident.', 'Open settings', () => openAppSettings());
      case _DeviceState.empty:
        return _message(Icons.music_off_outlined, 'No songs found',
            'There are no music files on this phone yet. Add some and pull to refresh.', 'Refresh', () => _loadDevice());
      case _DeviceState.error:
        return _message(Icons.error_outline, 'Couldn’t read your music',
            'Android did not return your song list.', 'Try again', () => _loadDevice());
      case _DeviceState.ready:
        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search songs (newest first)'),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(child: _songList(_deviceShown, 1)),
        ]);
    }
  }

  Widget _message(IconData icon, String title, String body, String action, VoidCallback onTap) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 44, color: AppTheme.goldDark),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontFamily: 'Lora', fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(body, textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold, foregroundColor: AppTheme.inkNavy),
              child: Text(action),
            ),
          ]),
        ),
      );

  Widget _songList(List<Song> songs, int tab, {bool pinnedRemovable = false}) {
    final isPlaying = _music.isPlaying;
    return ListView.builder(
      controller: _scroll[tab],
      padding: const EdgeInsets.only(bottom: 12),
      itemExtent: _rowHeight,
      itemCount: songs.length,
      itemBuilder: (_, i) {
        final s = songs[i];
        final playing = _current?.id == s.id;
        final pinned = _pinned.any((p) => p.id == s.id || (p.uri != null && p.uri == s.uri));
        Widget? trailing;
        if (pinnedRemovable) {
          trailing = pinned
              ? IconButton(
                  tooltip: 'Unpin',
                  icon: Icon(Icons.push_pin, color: AppTheme.goldDark, size: 20),
                  onPressed: () => _togglePin(s),
                )
              : Text(_fmt(s.duration), style: TextStyle(fontSize: 12, color: AppTheme.textMuted));
        } else if (s.isDevice) {
          trailing = IconButton(
            tooltip: pinned ? 'Unpin' : 'Pin beside the Godfident music',
            icon: Icon(pinned ? Icons.push_pin : Icons.push_pin_outlined, color: pinned ? AppTheme.goldDark : AppTheme.textMuted, size: 20),
            onPressed: () => _togglePin(s),
          );
        }
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: playing ? AppTheme.gold.withValues(alpha: 0.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: playing ? AppTheme.gold : Colors.transparent, width: 1.2),
          ),
          child: ListTile(
            leading: _Art(song: s, playing: playing, animating: playing && isPlaying),
            title: Text(s.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: playing ? FontWeight.w800 : FontWeight.w600, color: playing ? AppTheme.goldDark : AppTheme.textPrimary)),
            subtitle: Text(
                playing
                    ? (isPlaying ? 'Now playing' : 'Paused') + ' · ${s.artist}'
                    : '${s.artist}${s.album.isEmpty ? '' : ' · ${s.album}'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: playing ? AppTheme.goldDark : null)),
            trailing: trailing,
            onTap: () => _play(songs, s),
          ),
        );
      },
    );
  }
}

/// Four little bars that dance while a song plays.
class _EqBars extends StatefulWidget {
  final bool animating;
  final Color color;
  const _EqBars({required this.animating, required this.color});
  @override
  State<_EqBars> createState() => _EqBarsState();
}

class _EqBarsState extends State<_EqBars> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    if (widget.animating) _c.repeat();
  }

  @override
  void didUpdateWidget(_EqBars old) {
    super.didUpdateWidget(old);
    if (widget.animating && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.animating && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 4; i++)
            Container(
              width: 4,
              height: 6 + 18 * (widget.animating ? (0.5 + 0.5 * math.sin(_c.value * 2 * math.pi * (1 + i * 0.35) + i * 1.7)) : 0.35),
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(2)),
            ),
        ],
      ),
    );
  }
}

/// Album art if Android has it, otherwise a music-note tile. The playing song
/// shows dancing bars instead.
class _Art extends StatelessWidget {
  final Song song;
  final bool playing;
  final bool animating;
  const _Art({required this.song, required this.playing, required this.animating});

  @override
  Widget build(BuildContext context) {
    if (playing) {
      return Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppTheme.inkNavy, borderRadius: BorderRadius.circular(10)),
        child: _EqBars(animating: animating, color: AppTheme.goldLight),
      );
    }
    final fallback = Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(color: AppTheme.navyVariant, borderRadius: BorderRadius.circular(10)),
      child: Icon(Icons.music_note, color: AppTheme.goldDark),
    );
    if (!song.isDevice) return fallback;
    return FutureBuilder(
      future: DeviceMusicService.instance.artwork(song.uri!),
      builder: (_, snap) {
        final bytes = snap.data;
        if (bytes == null) return fallback;
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(bytes, width: 46, height: 46, fit: BoxFit.cover, gaplessPlayback: true),
        );
      },
    );
  }
}
