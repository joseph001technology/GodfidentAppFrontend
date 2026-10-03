import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme.dart';
import '../../services/music_service.dart';
import '../../services/permissions_service.dart';

enum _DeviceState { loading, needsPermission, denied, empty, ready, error }

/// Music: songs bundled with Godfident + every audio file on the phone.
class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});
  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _player = AudioPlayer();
  late final TabController _tabs = TabController(length: 2, vsync: this);

  _DeviceState _state = _DeviceState.loading;
  List<Song> _device = const [];
  String _query = '';
  Song? _current;
  String? _playError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDevice();
    // When a track ends, move to the next one in the same list.
    _player.processingStateStream.listen((s) {
      if (s == ProcessingState.completed) _next();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _player.dispose();
    _tabs.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    // Returning from Android's permission settings: re-check for real.
    if (s == AppLifecycleState.resumed && (_state == _DeviceState.denied || _state == _DeviceState.needsPermission)) {
      _loadDevice();
    }
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
      final songs = await DeviceMusicService.instance.loadSongs();
      if (!mounted) return;
      setState(() {
        _device = songs;
        _state = songs.isEmpty ? _DeviceState.empty : _DeviceState.ready;
      });
    } catch (_) {
      if (mounted) setState(() => _state = _DeviceState.error);
    }
  }

  List<Song> get _list => _tabs.index == 0 ? bundledSongs : _device;

  Future<void> _play(Song song) async {
    setState(() {
      _current = song;
      _playError = null;
    });
    try {
      if (song.isDevice) {
        await _player.setAudioSource(AudioSource.uri(Uri.parse(song.uri!)));
      } else {
        await _player.setAsset(song.asset!);
      }
      await _player.play();
    } catch (_) {
      // Corrupt / unsupported / deleted file: say so, don't pretend it plays.
      if (mounted) setState(() => _playError = '"${song.title}" could not be played (the file may be damaged or unsupported).');
    }
  }

  Future<void> _next() async {
    final list = _list;
    final i = list.indexWhere((s) => s.id == _current?.id);
    if (i != -1 && i + 1 < list.length) await _play(list[i + 1]);
  }

  String _fmt(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

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
            _songList(bundledSongs),
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
        if (_current != null) _miniPlayer(),
      ]),
    );
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
            'Open Android settings \u2192 Permissions \u2192 Music and audio, and allow Godfident.', 'Open settings', () => openAppSettings());
      case _DeviceState.empty:
        return _message(Icons.music_off_outlined, 'No songs found',
            'There are no music files on this phone yet. Add some and pull to refresh.', 'Refresh', () => _loadDevice());
      case _DeviceState.error:
        return _message(Icons.error_outline, 'Couldn\u2019t read your music',
            'Android did not return your song list.', 'Try again', () => _loadDevice());
      case _DeviceState.ready:
        final q = _query.toLowerCase();
        final shown = _device
            .where((s) => q.isEmpty || s.title.toLowerCase().contains(q) || s.artist.toLowerCase().contains(q))
            .toList();
        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search songs'),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(child: _songList(shown)),
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
            Text(body, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold, foregroundColor: AppTheme.inkNavy),
              child: Text(action),
            ),
          ]),
        ),
      );

  Widget _songList(List<Song> songs) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: songs.length,
      itemBuilder: (_, i) {
        final s = songs[i];
        final playing = _current?.id == s.id;
        return ListTile(
          leading: _Art(song: s, playing: playing),
          title: Text(s.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w600, color: playing ? AppTheme.goldDark : AppTheme.textPrimary)),
          subtitle: Text('${s.artist}${s.album.isEmpty ? '' : ' \u00b7 ${s.album}'}',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
          trailing: Text(_fmt(s.duration), style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          onTap: () => _play(s),
        );
      },
    );
  }

  Widget _miniPlayer() {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.navySurface,
        border: Border(top: BorderSide(color: AppTheme.navyOutline)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_current!.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(_current!.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ]),
            ),
            StreamBuilder<PlayerState>(
              stream: _player.playerStateStream,
              builder: (_, snap) {
                final playing = snap.data?.playing ?? false;
                final loading = snap.data?.processingState == ProcessingState.loading ||
                    snap.data?.processingState == ProcessingState.buffering;
                return IconButton(
                  iconSize: 38,
                  color: AppTheme.goldDark,
                  icon: loading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.gold))
                      : Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_filled),
                  onPressed: () => playing ? _player.pause() : _player.play(),
                );
              },
            ),
            IconButton(icon: const Icon(Icons.skip_next), onPressed: _next),
          ]),
          StreamBuilder<Duration>(
            stream: _player.positionStream,
            builder: (_, snap) {
              final pos = snap.data ?? Duration.zero;
              final dur = _player.duration ?? _current!.duration;
              final max = dur.inMilliseconds <= 0 ? 1.0 : dur.inMilliseconds.toDouble();
              return Row(children: [
                Text(_fmt(pos), style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                Expanded(
                  child: Slider(
                    activeColor: AppTheme.gold,
                    inactiveColor: AppTheme.navyVariant,
                    value: pos.inMilliseconds.toDouble().clamp(0, max),
                    max: max,
                    onChanged: (v) => _player.seek(Duration(milliseconds: v.toInt())),
                  ),
                ),
                Text(_fmt(dur), style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              ]);
            },
          ),
        ]),
      ),
    );
  }
}

/// Album art if Android has it, otherwise a music-note tile.
class _Art extends StatelessWidget {
  final Song song;
  final bool playing;
  const _Art({required this.song, required this.playing});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(color: AppTheme.navyVariant, borderRadius: BorderRadius.circular(10)),
      child: Icon(playing ? Icons.graphic_eq : Icons.music_note, color: AppTheme.goldDark),
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
