import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme.dart';
import 'core/router.dart';
import 'core/dio_client.dart';
import 'providers/auth_provider.dart';
import 'providers/remaining_providers.dart';
import 'providers/restriction_provider.dart';
import 'providers/scheduled_focus_provider.dart';
import 'services/native_alarm.dart';
import 'services/focus_session_manager.dart';

/// Opens the page a reminder points to. Routes carrying `focus=1` first start a
/// quick normal Focus session (reading -> Bible tab, both -> Home).
Future<void> handleReminderRoute(GoRouter router, String route) async {
  try {
    NativeAlarm.stopSound();
  } catch (_) {}
  try {
    final uri = Uri.parse(route);
    if (uri.queryParameters['focus'] == '1') {
      final sm = SessionManager.instance;
      if (!(await sm.info()).active) {
        final prefs = await SharedPreferences.getInstance();
        final mins = prefs.getInt('sm_minutes') ?? 0;
        await sm.start(
          minutes: mins > 0 ? mins : 30,
          purpose: uri.queryParameters['purpose'] ?? '',
          requireBlocking: false,
        );
      }
      router.go(uri.path);
      return;
    }
    router.go(route);
  } catch (_) {}
}

// Global scaffold messenger key used for app-wide snackbars (e.g., session expired)
final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class GodfidentApp extends ConsumerWidget {
  const GodfidentApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Initialize notification service once and hook navigation callback
    // Also register a global auth-expired handler to handle 401 token expirations
    // Use a microtask so build completes synchronously
    Future.microtask(() {
      ref.read(notificationServiceProvider).init(onNotificationTap: (payload) {
        try {
          if (payload != null && payload.isNotEmpty) {
            handleReminderRoute(ref.read(routerProvider), payload);
          }
        } catch (e) {
          // ignore navigation errors
        }
      });

      // Register auth-expired handler

      // Set DioClient.onAuthExpired to perform logout + navigation
      // (We capture ref and context so the closure can perform UI actions)
      Future.microtask(() {
        Future<void> handler() async {
          try {
            await ref.read(authActionProvider).logout();
          } catch (_) {}
          try {
            ref.read(routerProvider).go('/login');
          } catch (_) {}
          try {
            appScaffoldMessengerKey.currentState?.showSnackBar(
              const SnackBar(content: Text('Your session has expired. Please sign in again.'), backgroundColor: Colors.orange),
            );
          } catch (_) {}
        }

        DioClient.onAuthExpired = handler;
      });
    });


    return MaterialApp.router(
      title: 'Godfident',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(), // dark() is now just a shim that calls light() — see theme.dart
      themeMode: ThemeMode.light, // was ThemeMode.dark — this line is the actual reason the old dark palette was rendering at all; theme.dart's color values were never the only thing controlling it
      routerConfig: router,
      scaffoldMessengerKey: appScaffoldMessengerKey,
      builder: (context, child) => _SessionKeeper(child: child ?? const SizedBox.shrink()),
    );
  }
}

/// Renews the login in the background while the app is open, so a session
/// never lapses mid-use. If the server rejects it, the user is signed out.
class _SessionKeeper extends ConsumerStatefulWidget {
  final Widget child;
  const _SessionKeeper({required this.child});
  @override
  ConsumerState<_SessionKeeper> createState() => _SessionKeeperState();
}

class _SessionKeeperState extends ConsumerState<_SessionKeeper> with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 2), (_) {
      DioClient.ensureSession();
      _guardWebsites();
    });
    // Website protection is always on: load the saved list (from the phone,
    // then from the account) and make sure Android is enforcing it.
    Future.microtask(() => ref.read(restrictedSitesProvider.notifier).load());
    // Opened by tapping/pressing Start on a ringing scheduled-session alarm
    // while the app was closed: go straight to that session.
    Future.microtask(() => ref.read(scheduledFocusProvider.notifier).load());
    Future.microtask(() async {
      final payload = await ref.read(notificationServiceProvider).launchPayload();
      if (payload != null && payload.isNotEmpty) {
        handleReminderRoute(ref.read(routerProvider), payload);
      }
      final alarmRoute = await NativeAlarm.launchRoute();
      if (alarmRoute != null && alarmRoute.isNotEmpty) {
        handleReminderRoute(ref.read(routerProvider), alarmRoute);
      }
      NativeAlarm.listen((r) => handleReminderRoute(ref.read(routerProvider), r));
      SessionManager.instance.reconcile();
    });
  }

  void _guardWebsites() {
    try {
      ref.read(restrictedSitesProvider.notifier).guard();
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SessionManager.instance.reconcile();
      DioClient.ensureSession();
      _guardWebsites();
    }
  }

  @override
  Widget build(BuildContext context) {
    // After signing in (for example after clearing the app's data), pull the
    // protected sites and apps back from the account and switch protection on.
    ref.listen<AsyncValue<bool>>(authStateProvider, (prev, next) {
      if (next.valueOrNull == true && prev?.valueOrNull != true) {
        ref.read(restrictedSitesProvider.notifier).load();
        ref.read(restrictedAppsProvider.notifier).load();
        ref.read(scheduledFocusProvider.notifier).load();
      }
    });
    return widget.child;
  }
}
