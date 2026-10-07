import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/theme.dart';
import '../../services/music_controller.dart';
import '../../services/music_service.dart';

/// The music player shown INSIDE a Focus / Prayer session: song name,
/// previous / play-pause / next, and a button to pick a different song.
/// Uses the app's single player, so it is the same music as the mini player.
class SessionMusicCard extends StatelessWidget {
  const SessionMusicCard({super.key});

  @override
  Widget build(BuildContext context) {
    final m = MusicController.instance;
    return ListenableBuilder(
      listenable: m,
      builder: (context, _) {
        final song = m.current;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          decoration: BoxDecoration(
            color: AppTheme.navyVariant,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.navyOutline),
          ),
          child: Row(children: [
            const Icon(Icons.music_note_rounded, color: AppTheme.goldDark),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(song?.title ?? 'No music playing',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                Text(song == null ? 'Tap play to start' : song.artist,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ]),
            ),
            IconButton(
              tooltip: 'Previous',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.skip_previous),
              onPressed: song == null ? null : m.previous,
            ),
            StreamBuilder<PlayerState>(
              stream: m.player.playerStateStream,
              builder: (_, snap) {
                final playing = snap.data?.playing ?? m.isPlaying;
                return IconButton(
                  tooltip: playing ? 'Pause' : 'Play',
                  visualDensity: VisualDensity.compact,
                  iconSize: 34,
                  color: AppTheme.goldDark,
                  icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_filled),
                  onPressed: () => song == null ? m.startForSession() : m.toggle(),
                );
              },
            ),
            IconButton(
              tooltip: 'Next',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.skip_next),
              onPressed: m.hasNext ? m.next : null,
            ),
            IconButton(
              tooltip: 'Change song',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.queue_music_rounded),
              onPressed: () => _pick(context),
            ),
          ]),
        );
      },
    );
  }

  Future<void> _pick(BuildContext context) async {
    List<Song> device = const [];
    try {
      device = await DeviceMusicService.instance.loadSongs();
    } catch (_) {}
    if (!context.mounted) return;
    final m = MusicController.instance;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.navySurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) {
        Widget tile(List<Song> list, Song s) => ListTile(
              dense: true,
              leading: Icon(s.isDevice ? Icons.smartphone : Icons.music_note, color: AppTheme.goldDark),
              title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(s.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: m.current?.id == s.id ? const Icon(Icons.graphic_eq, color: AppTheme.gold) : null,
              onTap: () {
                Navigator.pop(sheet);
                m.playList(list, list.indexWhere((x) => x.id == s.id), loopAll: true);
              },
            );
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
            child: ListView(shrinkWrap: true, padding: const EdgeInsets.only(top: 12, bottom: 12), children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text('Choose music', style: TextStyle(fontFamily: 'Lora', fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              for (final s in bundledSongs) tile(bundledSongs, s),
              if (device.isNotEmpty) ...[
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Text('ON THIS PHONE',
                      style: TextStyle(fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w700, color: AppTheme.textMuted)),
                ),
                for (final s in device) tile(device, s),
              ],
            ]),
          ),
        );
      },
    );
  }
}
