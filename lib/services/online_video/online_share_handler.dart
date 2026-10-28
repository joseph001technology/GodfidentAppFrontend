import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'online_video_gateway.dart';
import 'online_video_store.dart';

/// Receives links shared to Godfident from Android's share menu.
///
/// How a share reaches Dart (see OnlineVideoPlugin.kt):
///  - the plugin keeps the shared text until Dart asks for it (takePendingShare), so
///    nothing is lost when Godfident is closed and starts because of the share;
///  - when Godfident is already open the plugin also "pokes" Dart, which then asks.
///
/// The link is SAVED FIRST, locally, before any screen is opened: saving never
/// depends on the person being signed in, on a thumbnail, or on the network.
class OnlineShareHandler {
  OnlineShareHandler({
    required this.gateway,
    required this.store,
    required this.router,
    required this.authStatus,
    required this.messenger,
  });

  final OnlineVideoGateway gateway;
  final OnlineVideoStore store;
  final GoRouter Function() router;

  /// true = signed in, false = not signed in, null = still being checked.
  final bool? Function() authStatus;
  final ScaffoldMessengerState? Function() messenger;

  StreamSubscription<void>? _sub;
  bool _busy = false;

  void start() {
    _sub ??= gateway.sharePokes.listen((_) => consume());
    consume(); // Godfident was opened by a share while it was closed
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  /// Reads and saves everything that is waiting. Safe to call at any time.
  Future<void> consume() async {
    if (_busy) return;
    _busy = true;
    try {
      // Loop: two shares in a row must both be handled.
      for (var i = 0; i < 5; i++) {
        final c = await gateway.takePendingShare();
        if (c == null) break;
        await _handle(c);
      }
    } catch (_) {
      // A broken share must never crash the app.
    } finally {
      _busy = false;
    }
  }

  Future<void> _handle(SharedContent c) async {
    final out = await store.addFromText(c.text, subject: c.subject);
    if (!out.ok) {
      _say(OnlineVideoStore.message(out)); // helpful error, nothing invalid is saved
      return;
    }

    // Wait (briefly) for the sign-in check on a cold start, so the screen below is not
    // thrown away by the login redirect.
    for (var i = 0; i < 50 && authStatus() == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    if (authStatus() != true) {
      _say('${OnlineVideoStore.message(out)} Sign in to see your Online videos.');
      return;
    }

    final r = router();
    final dup = out.kind == AddKind.duplicate ? 1 : 0;
    final target = '/online-videos?added=${out.video!.id}&dup=$dup';
    final here = r.routerDelegate.currentConfiguration.uri.path;
    if (here.startsWith('/online-videos')) {
      r.go(target); // already there: refresh it with the new link
    } else {
      r.push(target); // Back returns to where the person was
    }
  }

  void _say(String text) {
    try {
      messenger()?.showSnackBar(SnackBar(content: Text(text)));
    } catch (_) {}
  }
}
