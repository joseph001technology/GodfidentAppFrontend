import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme.dart';
import '../../services/music_service.dart';
import '../../services/permissions_service.dart';
import '../../services/ringtone_store.dart';

/// Bottom sheet to choose a reminder ringtone: bundled tones (tap to preview)
/// or any song from this phone. Returns the choice, or null if dismissed.
Future<Ringtone?> showRingtonePicker(BuildContext context, {required Ringtone current}) {
  return showModalBottomSheet<Ringtone>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.navy,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _RingtoneSheet(current: current),
  );
}

class _RingtoneSheet extends StatefulWidget {
  final Ringtone current;
  const _RingtoneSheet({required this.current});
  @override
  State<_RingtoneSheet> createState() => _RingtoneSheetState();
}

class _RingtoneSheetState extends State<_RingtoneSheet> {
  final _player = AudioPlayer();
  late Ringtone _selected = widget.current;
  List<Song>? _songs;
  String? _songsMessage;
  bool _showSongs = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _preview(Ringtone t) async {
    try {
      if (t.isDevice) {
        await _player.setAudioSource(AudioSource.uri(Uri.parse(t.uri!)));
      } else {
        await _player.setAsset('assets/audio/ringtones/${t.id}.mp3');
      }
      await _player.play();
    } catch (_) {/* preview is best effort */}
  }

  Future<void> _openSongs() async {
    setState(() {
      _showSongs = true;
      _songsMessage = null;
    });
    final perms = PermissionsService.instance;
    if (!await perms.audioGranted()) {
      final st = await perms.audioRequest();
      if (!st.isGranted) {
        if (mounted) setState(() => _songsMessage = 'Allow access to your music to pick a song as your ringtone.');
        return;
      }
    }
    try {
      final songs = await DeviceMusicService.instance.loadSongs();
      if (mounted) {
        setState(() {
          _songs = songs;
          if (songs.isEmpty) _songsMessage = 'No songs found on this phone.';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _songsMessage = 'Couldn\u2019t read the songs on this phone.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(children: [
          const SizedBox(height: 12),
          Text(_showSongs ? 'Songs on this phone' : 'Choose ringtone',
              style: const TextStyle(fontFamily: 'Lora', fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(
            child: _showSongs ? _songList() : ListView(children: [
              for (final t in Ringtone.builtIn)
                ListTile(
                  leading: Icon(_selected.id == t.id && !_selected.isDevice ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: AppTheme.goldDark),
                  title: Text(t.title),
                  trailing: IconButton(icon: const Icon(Icons.play_arrow), onPressed: () => _preview(t)),
                  onTap: () {
                    setState(() => _selected = t);
                    _preview(t);
                  },
                ),
              ListTile(
                leading: Icon(_selected.isDevice ? Icons.radio_button_checked : Icons.library_music_outlined, color: AppTheme.goldDark),
                title: Text(_selected.isDevice ? _selected.title : 'A song from this phone\u2026'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openSongs,
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              if (_showSongs)
                TextButton(onPressed: () => setState(() => _showSongs = false), child: const Text('Back')),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  _player.stop();
                  Navigator.pop(context, _selected);
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold, foregroundColor: AppTheme.inkNavy),
                child: const Text('Use this ringtone'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _songList() {
    if (_songsMessage != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_songsMessage!, textAlign: TextAlign.center)));
    }
    if (_songs == null) return const Center(child: CircularProgressIndicator(color: AppTheme.gold));
    return ListView.builder(
      itemCount: _songs!.length,
      itemBuilder: (_, i) {
        final s = _songs![i];
        final picked = _selected.uri == s.uri;
        return ListTile(
          leading: Icon(picked ? Icons.radio_button_checked : Icons.music_note, color: AppTheme.goldDark),
          title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(s.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () {
            final r = Ringtone('device', s.title, uri: s.uri);
            setState(() => _selected = r);
            _preview(r);
          },
        );
      },
    );
  }
}
