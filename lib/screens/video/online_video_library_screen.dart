import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/online_video.dart';
import '../../providers/online_video_provider.dart';
import '../../services/online_video/online_video_store.dart';
import '../../services/online_video/video_link.dart';
import 'online_video_card.dart';

/// Online videos: links to Christian videos saved from Instagram, TikTok, Facebook,
/// YouTube and others. They stay on their own platform - Godfident stores only the
/// link (in a database on this phone, never on the Godfident server) and shows them
/// as a calm gallery. There is no feed, no suggestions and nothing plays by itself
/// after the video the person chose.
///
/// The clips stored ON the phone are a separate section: Videos (/videos).
class OnlineVideoLibraryScreen extends ConsumerStatefulWidget {
  /// Set when opened right after a link was saved from the share menu.
  final String? addedId;
  final bool wasDuplicate;

  const OnlineVideoLibraryScreen({super.key, this.addedId, this.wasDuplicate = false});

  @override
  ConsumerState<OnlineVideoLibraryScreen> createState() => _OnlineVideoLibraryScreenState();
}

class _OnlineVideoLibraryScreenState extends ConsumerState<OnlineVideoLibraryScreen> with WidgetsBindingObserver {
  final _scroll = ScrollController();

  OnlineLibraryController get _ctrl => ref.read(onlineLibraryProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
    Future.microtask(() async {
      await _ctrl.init();
      if (!mounted) return;
      final id = widget.addedId;
      if (id != null) {
        final v = await ref.read(onlineVideoGatewayProvider).get(id);
        if (mounted && v != null) await _afterSave(v, duplicate: widget.wasDuplicate);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    // Back from another app: re-check the connection so the banner and retries are right.
    if (s == AppLifecycleState.resumed) {
      _ctrl.refreshConnectivity();
    }
  }

  void _onScroll() {
    // Ordinary pagination of the person's OWN saved list: the next 24 records are read
    // from the phone's database when the end of what is shown comes near.
    if (_scroll.hasClients && _scroll.position.pixels > _scroll.position.maxScrollExtent - 500) {
      _ctrl.loadMore();
    }
  }

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // ------------------------------------------------------------------ opening

  Future<void> _open(OnlineVideo v) async {
    final gw = ref.read(onlineVideoGatewayProvider);
    // Playing needs internet. Asked at the moment of playing, not from a stale value.
    if (!await gw.isOnline()) {
      _say('An internet connection is required to play online videos. Your saved videos are still here.');
      return;
    }
    // In-app playback only where the platform documents an embed for this link.
    final embed = VideoLinkParser.parse(v.url).link?.embedUrl;
    if (embed != null) {
      final ok = await gw.play(
        embedUrl: embed,
        originalUrl: v.url,
        title: v.displayTitle,
        platform: v.platform.label,
      );
      if (ok) return;
    }
    await _openOriginal(v, because: embed == null ? "This one can't play inside Godfident." : null);
  }

  Future<void> _openOriginal(OnlineVideo v, {String? because}) async {
    final gw = ref.read(onlineVideoGatewayProvider);
    if (!await gw.isOnline()) {
      _say('An internet connection is required to play online videos. Your saved videos are still here.');
      return;
    }
    if (because != null) _say('$because Opening it in ${v.platform.label}.');
    final ok = await gw.openExternal(v.url);
    if (!ok) _say("Couldn't open this link. It may have been removed, or no app can open it.");
  }

  // ------------------------------------------------------------------ menu

  Future<void> _menu(String action, OnlineVideo v) async {
    switch (action) {
      case 'open':
        await _open(v);
      case 'original':
        await _openOriginal(v);
      case 'move':
        await _collectionSheet(v, title: 'Move to a collection');
      case 'rename':
        await _rename(v);
      case 'refresh':
        if (!ref.read(onlineLibraryProvider).online) {
          _say('Connect to the internet to refresh the preview.');
        } else {
          await _ctrl.refreshPreview(v);
        }
      case 'remove':
        if (await _confirm('Remove this video?', 'Only the saved link is removed from Godfident. The video stays where it is online.', 'Remove')) {
          await _ctrl.remove(v.id);
          _say('Removed.');
        }
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
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action, style: const TextStyle(color: AppTheme.danger))),
        ],
      ),
    );
    return r == true;
  }

  Future<String?> _askText(String title, {String initial = '', String hint = '', String action = 'Save'}) async {
    final c = TextEditingController(text: initial);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
        ],
      ),
    );
    final text = c.text;
    c.dispose();
    return ok == true ? text : null;
  }

  Future<void> _rename(OnlineVideo v) async {
    final t = await _askText('Rename', initial: v.title ?? '', hint: v.displayTitle);
    if (t != null) await _ctrl.rename(v.id, t);
  }

  // ------------------------------------------------------------------ adding

  /// Paste-a-link dialog. Stays open and explains the problem when the text has no usable link.
  Future<void> _addDialog() async {
    final c = TextEditingController();
    String? error;
    final saved = await showDialog<AddOutcome>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Add a video link'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: c,
              autofocus: true,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: 'Paste a link',
                suffixIcon: IconButton(
                  tooltip: 'Paste',
                  icon: const Icon(Icons.content_paste),
                  onPressed: () async {
                    final d = await Clipboard.getData(Clipboard.kTextPlain);
                    if (d?.text != null) setD(() => c.text = d!.text!.trim());
                  },
                ),
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(error!, style: const TextStyle(color: AppTheme.danger, fontSize: 12.5)),
              ),
            const SizedBox(height: 8),
            Text(
              'Tip: in Instagram, TikTok, Facebook or YouTube tap Share and choose Godfident.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                final out = await _ctrl.addFromText(c.text);
                if (out.ok) {
                  if (ctx.mounted) Navigator.pop(ctx, out);
                } else {
                  setD(() => error = OnlineVideoStore.message(out));
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    c.dispose();
    if (saved != null && saved.video != null && mounted) {
      await _afterSave(saved.video!, duplicate: saved.kind == AddKind.duplicate);
    }
  }

  /// After a link was saved (here or from the share menu): say so, and offer - never force - a collection.
  Future<void> _afterSave(OnlineVideo v, {required bool duplicate}) async {
    await _collectionSheet(
      v,
      title: duplicate ? 'Already in your Online videos' : 'Saved to Online videos',
      subtitle: v.collectionId == null ? 'Add it to a collection? (optional)' : 'It is already in a collection. Move it?',
      skipLabel: 'Done',
    );
  }

  Future<void> _collectionSheet(OnlineVideo v, {required String title, String? subtitle, String skipLabel = 'Cancel'}) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.navySurface,
      isScrollControlled: true,
      builder: (ctx) => Consumer(builder: (ctx, ref, _) {
        final st = ref.watch(onlineLibraryProvider);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
            child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 16, 16, 12), children: [
              Text(title, style: const TextStyle(fontFamily: 'Lora', fontSize: 18, fontWeight: FontWeight.bold)),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(subtitle, style: TextStyle(color: AppTheme.textSecondary)),
                ),
              const SizedBox(height: 8),
              for (final c in st.collections)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(v.collectionId == c.id ? Icons.folder : Icons.folder_outlined, color: AppTheme.goldDark),
                  title: Text(c.name),
                  trailing: Text('${c.count}', style: TextStyle(color: AppTheme.textMuted)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _ctrl.move(v.id, c.id);
                    _say('Added to ${c.name}.');
                  },
                ),
              if (v.collectionId != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.folder_off_outlined, color: AppTheme.textMuted),
                  title: const Text('Take out of its collection'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _ctrl.move(v.id, null);
                  },
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.create_new_folder_outlined, color: AppTheme.goldDark),
                title: const Text('New collection…'),
                onTap: () async {
                  final name = await _askText('New collection', hint: 'e.g. Sermons, Worship, Testimonies', action: 'Create');
                  if (name == null || name.trim().isEmpty) return;
                  final made = await _ctrl.createCollection(name);
                  if (made == null) {
                    _say('Could not create that collection.');
                    return;
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _ctrl.move(v.id, made.id);
                  _say('Added to ${made.name}.');
                },
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => Navigator.pop(ctx), child: Text(skipLabel)),
              ),
            ]),
          ),
        );
      }),
    );
  }

  Future<void> _manageCollection(OnlineCollection c) async {
    final act = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.navySurface,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700))),
          ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Rename'), onTap: () => Navigator.pop(ctx, 'rename')),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: AppTheme.danger),
            title: const Text('Delete collection'),
            subtitle: const Text('The videos stay saved.'),
            onTap: () => Navigator.pop(ctx, 'delete'),
          ),
        ]),
      ),
    );
    if (act == 'rename') {
      final name = await _askText('Rename collection', initial: c.name);
      if (name != null && name.trim().isNotEmpty) {
        final ok = await _ctrl.renameCollection(c.id, name);
        if (!ok) _say('A collection with that name already exists.');
      }
    } else if (act == 'delete') {
      if (await _confirm('Delete "${c.name}"?', 'The videos stay in your Online videos. Only the collection is removed.', 'Delete')) {
        await _ctrl.deleteCollection(c.id);
      }
    }
  }

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(onlineLibraryProvider);
    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        title: const Text('Online videos'),
        backgroundColor: AppTheme.navy,
        foregroundColor: AppTheme.ink,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Videos on this phone',
            icon: const Icon(Icons.smartphone_outlined),
            onPressed: () => context.push('/videos'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.gold,
        foregroundColor: AppTheme.inkNavy,
        shape: const StadiumBorder(),
        onPressed: _addDialog,
        icon: const Icon(Icons.add_link),
        label: const Text('Add link', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Column(children: [
        if (!st.online) _offlineBanner(),
        _collectionBar(st),
        Expanded(child: _content(st)),
      ]),
    );
  }

  Widget _offlineBanner() => Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.navyVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.navyOutline),
        ),
        child: Row(children: [
          Icon(Icons.cloud_off_outlined, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'You are offline. Your saved videos are here, but playing them needs the internet.',
              style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
            ),
          ),
        ]),
      );

  Widget _collectionBar(OnlineLibraryState st) {
    Widget chip(String label, bool selected, VoidCallback onTap, {VoidCallback? onLong}) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onLongPress: onLong,
            child: ChoiceChip(
              label: Text(label),
              selected: selected,
              showCheckmark: false,
              selectedColor: AppTheme.goldLight,
              backgroundColor: AppTheme.navySurface,
              side: BorderSide(color: selected ? AppTheme.goldLight : AppTheme.navyOutline),
              labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? AppTheme.inkNavy : AppTheme.textPrimary),
              onSelected: (_) => onTap(),
            ),
          ),
        );
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
        children: [
          chip('All (${st.totalAll})', st.scope == 'all', () => _ctrl.setFilter('all')),
          if (st.collections.isNotEmpty) chip('Not sorted (${st.unsorted})', st.scope == 'none', () => _ctrl.setFilter('none')),
          for (final c in st.collections)
            chip('${c.name} (${c.count})', st.scope == 'collection' && st.collectionId == c.id,
                () => _ctrl.setFilter('collection', collectionId: c.id),
                onLong: () => _manageCollection(c)),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: const Text('Collection'),
              backgroundColor: AppTheme.navySurface,
              side: BorderSide(color: AppTheme.navyOutline),
              labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              onPressed: () async {
                final name = await _askText('New collection', hint: 'e.g. Sermons, Worship, Testimonies', action: 'Create');
                if (name != null && name.trim().isNotEmpty) {
                  final made = await _ctrl.createCollection(name);
                  if (made == null) _say('Could not create that collection.');
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(OnlineLibraryState st) {
    if (st.loading && st.items.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.gold));
    }
    if (st.error != null && st.items.isEmpty) {
      return _message(
        icon: Icons.error_outline,
        title: 'Could not open your videos',
        body: st.error!,
        action: OutlinedButton(onPressed: _ctrl.reload, child: const Text('Try again')),
      );
    }
    if (st.items.isEmpty) {
      return st.totalAll == 0 ? _emptyLibrary() : _emptyFilter();
    }
    return RefreshIndicator(
      color: AppTheme.gold,
      onRefresh: _ctrl.reload,
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        cacheExtent: 200, // build only slightly beyond the screen: cards load their picture when built
        slivers: [
          SliverToBoxAdapter(child: _header()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 240,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.84,
              ),
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final v = st.items[i];
                  return OnlineVideoCard(
                    key: ValueKey(v.id),
                    video: v,
                    onOpen: () => _open(v),
                    onMenu: (a) => _menu(a, v),
                  );
                },
                childCount: st.items.length,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              child: Center(
                child: st.loadingMore
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.gold))
                    : st.hasMore
                        ? TextButton(onPressed: _ctrl.loadMore, child: const Text('Show more'))
                        : Text('${st.total} saved', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Text(
          'Links to videos on their own platforms. Nothing is downloaded, and nothing plays after the one you choose.',
          style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.35),
        ),
      );

  Widget _emptyLibrary() => _message(
        icon: Icons.ondemand_video_outlined,
        title: 'Save videos worth coming back to',
        body: 'Found something good on Instagram, TikTok, Facebook or YouTube? Tap Share, choose Godfident, and it is kept here '
            '— without the feed. You can also paste a link.',
        action: FilledButton.icon(onPressed: _addDialog, icon: const Icon(Icons.add_link), label: const Text('Paste a link')),
      );

  Widget _emptyFilter() => _message(
        icon: Icons.folder_open_outlined,
        title: 'Nothing here yet',
        body: 'No videos in this collection. Use a video’s menu to move it here.',
        action: OutlinedButton(onPressed: () => _ctrl.setFilter('all'), child: const Text('Show all')),
      );

  Widget _message({required IconData icon, required String title, required String body, Widget? action}) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 40),
          Icon(icon, size: 52, color: AppTheme.goldDark),
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Lora', fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.ink)),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary, height: 1.4)),
          if (action != null) ...[const SizedBox(height: 18), Center(child: action)],
        ],
      );
}
