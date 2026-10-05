import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme.dart';
import '../../services/music_controller.dart';
import '../../services/music_service.dart';
import '../../services/permissions_service.dart';
import '../../services/ringtone_store.dart';

/// Bottom sheet to choose a reminder ringtone: bundled tones (tap to preview)
/// or any song from this phone.
///
/// [onChanged] fires the moment the user taps a tone or a song, so the choice
/// is kept even if the sheet is swiped away or the Back button is used (before,
/// the choice only counted if "Use this ringtone" was pressed - and that button
/// was broken by the app theme's infinite-width buttons inside a Row).
Future<Ringtone?> showRingtonePicker(
  BuildContext context, {
  required Ringtone current,
  ValueChanged<Ringtone>? onChanged,
}) {
  return showModalBottomSheet<Ringtone>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.navy,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _RingtoneSheet(current: current, onChanged: onChanged),
  );
}

class _RingtoneSheet extends StatefulWidget {
  final Ringtone current;
  final ValueChanged<Ringtone>? onChanged;
  const _RingtoneSheet({required this.current, this.onChanged});
  @override
  State<_RingtoneSheet> createState() => _RingtoneSheetState();
}

class _RingtoneSheetState extends State<_RingtoneSheet> {
  final _music = MusicController.instance;
  late Ringtone _selected = widget.current;
  List<Song>? _songs;
  String? _songsMessage;
  bool _showSongs = false;

  @override
  void initState() {
    super.initState();
    _music.addListener(_onMusic);
  }

  void _onMusic() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _music.removeListener(_onMusic);
    // Closing the sheet in any way (Use, Back, swipe down) stops the sound.
    _music.stopPreview();
    super.dispose();
  }

  void _choose(Ringtone t) {
    setState(() => _selected = t);
    widget.onChanged?.call(t); // keep the choice even if the sheet is dismissed
    _preview(t);
  }

  Future<void> _preview(Ringtone t) async {
    if (t.isDevice) {
      await _music.previewUri(t.uri!, t.title);
    } else {
      await _music.previewAsset('assets/audio/ringtones/${t.id}.mp3', t.title);
    }
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
          if (_music.previewTitle != null || _music.previewError != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
              decoration: BoxDecoration(
                color: (_music.previewError != null ? AppTheme.danger : AppTheme.gold).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Icon(_music.previewError != null ? Icons.error_outline : Icons.graphic_eq,
                    color: _music.previewError != null ? AppTheme.danger : AppTheme.goldDark, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_music.previewError ?? 'Playing: ${_music.previewTitle}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                if (_music.previewError == null)
                  IconButton(
                    tooltip: 'Stop',
                    icon: const Icon(Icons.stop_circle_outlined),
                    onPressed: _music.stopPreview,
                  ),
              ]),
            ),
          Expanded(
            child: _showSongs ? _songList() : ListView(children: [
              for (final t in Ringtone.builtIn)
                ListTile(
                  leading: Icon(_selected.id == t.id && !_selected.isDevice ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: AppTheme.goldDark),
                  title: Text(t.title),
                  trailing: IconButton(icon: const Icon(Icons.play_arrow), onPressed: () => _preview(t)),
                  onTap: () => _choose(t),
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
                TextButton(
                  onPressed: () {
                    _music.stopPreview();
                    setState(() => _showSongs = false);
                  },
                  child: const Text('Back')),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  _music.stopPreview();
                  Navigator.pop(context, _selected);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.gold,
                  foregroundColor: AppTheme.inkNavy,
                  // finite width: the theme's infinite minimum width cannot be laid out inside a Row
                  minimumSize: const Size(180, 48),
                ),
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
          trailing: picked ? const Icon(Icons.check_circle, color: AppTheme.emerald) : null,
          title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(s.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => _choose(Ringtone('device', s.title, uri: s.uri)),
        );
      },
    );
  }
}
