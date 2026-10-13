import 'package:permission_handler/permission_handler.dart';
import 'focus_blocking_service.dart';
import 'native_session.dart';
import 'website_protection_service.dart';

/// One thing Android needs the user to allow, with a plain-language reason.
class PermissionItem {
  final String id;
  final String title;
  final String why;
  final String feature; // which part of Godfident needs it
  final bool granted;
  final bool required;
  const PermissionItem({
    required this.id,
    required this.title,
    required this.why,
    required this.feature,
    required this.granted,
    this.required = true,
  });
}

/// Reads the REAL state of every permission Godfident needs and asks for them.
/// Nothing is reported as granted unless Android says so.
class PermissionsService {
  PermissionsService._();
  static final PermissionsService instance = PermissionsService._();

  final _focus = FocusBlockingService.instance;
  final _web = WebsiteProtectionService.instance;

  Future<Permission> _audioPermission() async =>
      (await _focus.sdkInt()) >= 33 ? Permission.audio : Permission.storage;

  Future<List<PermissionItem>> snapshot() async {
    final audio = await _audioPermission();
    return [
      PermissionItem(
        id: 'accessibility',
        title: 'Accessibility service',
        why: 'Lets Godfident notice the instant a blocked app opens and send you Home. It cannot read your screen or what you type.',
        feature: 'App restrictions',
        granted: await _focus.isAccessibilityEnabled(),
      ),
      PermissionItem(
        id: 'usage',
        title: 'Usage access',
        why: 'Counts how long each app is used, which Daily app limits need. Also a backup way to see which app is open if the accessibility service is switched off.',
        feature: 'App restrictions & daily limits',
        granted: await _focus.hasUsageAccess(),
        required: false,
      ),
      PermissionItem(
        id: 'vpn',
        title: 'VPN connection',
        why: 'Safe Browsing runs as a local VPN on your phone. Nothing is sent anywhere - it only refuses lookups for the sites you chose.',
        feature: 'Safe Browsing',
        granted: (await _web.status()).vpnPermissionGranted,
      ),
      PermissionItem(
        id: 'notifications',
        title: 'Notifications',
        why: 'Needed to show your reminders and the Focus status.',
        feature: 'Reminders',
        granted: await Permission.notification.isGranted,
      ),
      PermissionItem(
        id: 'alarms',
        title: 'Alarms & reminders',
        why: 'Lets Android deliver reminders at the exact minute. Without it they can arrive late.',
        feature: 'Reminders',
        granted: await Permission.scheduleExactAlarm.isGranted,
      ),
      PermissionItem(
        id: 'battery',
        title: 'Run in background',
        why: 'Stops the battery saver from delaying reminders and Focus protection.',
        feature: 'Reminders & Focus',
        granted: await Permission.ignoreBatteryOptimizations.isGranted,
        required: false,
      ),
      PermissionItem(
        id: 'autostart',
        title: 'Auto-start / background activity',
        why: 'Many phones (Tecno, Infinix, Xiaomi, Oppo, Vivo, Huawei, Samsung) stop apps that are not open. Allow Godfident to auto-start and run in the background so your reminders, alarms and Focus sessions work without opening the app.',
        feature: 'Reminders & Focus',
        granted: false, // Android cannot tell us; the button opens the right page
        required: false,
      ),
      PermissionItem(
        id: 'audio',
        title: 'Music on this phone',
        why: 'Lets Godfident list and play the songs stored on your phone.',
        feature: 'Music',
        granted: await audio.isGranted,
        required: false,
      ),
    ];
  }

  /// Triggers the right Android prompt/settings page for [id].
  /// The caller must re-read [snapshot] afterwards (the user may have said no).
  /// Returns a short hint to show the person afterwards, or null.
  Future<String?> request(String id) async {
    switch (id) {
      case 'accessibility':
        await _focus.openAccessibilitySettings();
        break;
      case 'usage':
        await _focus.requestUsageAccess();
        break;
      case 'vpn':
        await _web.requestVpnPermission();
        break;
      case 'notifications':
        final s = await Permission.notification.request();
        if (s.isPermanentlyDenied) await openAppSettings();
        break;
      case 'alarms':
        await Permission.scheduleExactAlarm.request();
        break;
      case 'battery':
        await Permission.ignoreBatteryOptimizations.request();
        break;
      case 'autostart':
        await NativeSession.ensureGuardian();
        final where = await NativeSession.openAutostartSettings();
        if (where == 1) {
          return 'Your phone has no separate auto-start page. In this list choose All apps \u2192 Godfident \u2192 Don\u2019t optimise (or Unrestricted).';
        }
        if (where == 0) {
          return 'Opened Godfident\u2019s App info. Open Battery (or Battery usage) and choose Unrestricted. Your phone keeps auto-start inside its own Phone Manager / Security app.';
        }
        return 'Find Godfident in the list and switch it ON.';
      case 'audio':
        final p = await _audioPermission();
        final s = await p.request();
        if (s.isPermanentlyDenied) await openAppSettings();
        break;
    }
    return null;
  }

  Future<bool> audioGranted() async => (await _audioPermission()).isGranted;
  Future<PermissionStatus> audioRequest() async => (await _audioPermission()).request();
  Future<bool> audioPermanentlyDenied() async => (await _audioPermission()).isPermanentlyDenied;
}
