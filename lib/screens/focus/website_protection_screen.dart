import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/restriction_provider.dart';
import '../../services/permissions_service.dart';
import '../../services/website_protection_service.dart';

/// Website Protection. The blocked-site list is HIDDEN until the Website
/// Protection Key is entered, and the key is kept only as a salted hash.
class WebsiteProtectionScreen extends ConsumerStatefulWidget {
  const WebsiteProtectionScreen({super.key});
  @override
  ConsumerState<WebsiteProtectionScreen> createState() => _WebsiteProtectionScreenState();
}

class _WebsiteProtectionScreenState extends ConsumerState<WebsiteProtectionScreen> with WidgetsBindingObserver {
  final _svc = WebsiteProtectionService.instance;
  final _keyCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _siteCtrl = TextEditingController();

  bool _loading = true;
  bool? _hasKey; // null = could not check (offline, nothing stored on this phone)
  bool _askingPermission = false; // Android's VPN dialog pauses the app - do not re-lock for it
  bool _unlocked = false; // memory only - leaving the screen locks it again
  bool _busy = false;
  String? _error;
  String? _testResult;
  bool _testing = false;
  int _lockLeft = 0;
  Timer? _lockTimer;
  List<PermissionItem> _perms = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _keyCtrl.dispose();
    _confirmCtrl.dispose();
    _siteCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused && !_askingPermission) {
      // Re-lock whenever the app leaves the foreground.
      if (_unlocked) setState(() => _unlocked = false);
    }
    if (s == AppLifecycleState.resumed) {
      ref.invalidate(websiteStatusProvider);
      _loadPerms();
    }
  }

  /// The permissions always-on protection really depends on. Anything missing
  /// is listed on the unlocked screen with an Allow button.
  static const _needed = {'vpn', 'notifications', 'alarms', 'battery'};

  Future<void> _loadPerms() async {
    final all = await PermissionsService.instance.snapshot();
    if (mounted) setState(() => _perms = all.where((p) => _needed.contains(p.id)).toList());
  }

  Future<void> _allow(String id) async {
    _askingPermission = true; // Android's dialogs pause the app - do not re-lock for them
    await PermissionsService.instance.request(id);
    _askingPermission = false;
    await _loadPerms();
    ref.invalidate(websiteStatusProvider);
    // Permission just granted: switch protection on straight away.
    final domains = (ref.read(restrictedSitesProvider).valueOrNull ?? []).map((x) => x.domain).toList();
    if (domains.isNotEmpty) await ref.read(restrictedSitesProvider.notifier).guard();
    ref.invalidate(websiteStatusProvider);
  }

  Future<void> _init() async {
    final has = await _svc.hasKey(); // local copy, else asks your account
    final locked = await _svc.lockedSeconds();
    if (!mounted) return;
    setState(() {
      _hasKey = has;
      _lockLeft = locked;
      _loading = false;
    });
    if (locked > 0) _startLockTimer();
    _loadPerms();
  }

  void _startLockTimer() {
    _lockTimer?.cancel();
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      final l = await _svc.lockedSeconds();
      if (!mounted) return t.cancel();
      setState(() => _lockLeft = l);
      if (l == 0) t.cancel();
    });
  }

  Future<void> _createKey() async {
    final a = _keyCtrl.text, b = _confirmCtrl.text;
    if (a.length < 4) return setState(() => _error = 'Use at least 4 characters.');
    if (a != b) return setState(() => _error = 'The two keys do not match.');
    setState(() => _busy = true);
    final err = await _svc.createKey(a);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _error = err;
      });
      return;
    }
    _busy = false;
    _keyCtrl.clear();
    _confirmCtrl.clear();
    setState(() {
      _hasKey = true;
      _unlocked = true;
      _error = null;
    });
  }

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() => _busy = true);
    final r = await _svc.verifyKey(_keyCtrl.text);
    _keyCtrl.clear();
    if (!mounted) return;
    if (r.ok) {
      setState(() {
        _busy = false;
        _unlocked = true;
        _error = null;
      });
      // Pull the latest list from the account now that we are in.
      ref.read(restrictedSitesProvider.notifier).load();
      return;
    }
    setState(() {
      _busy = false;
      _lockLeft = r.lockedSeconds;
      _error = r.lockedSeconds > 0
          ? 'Too many wrong attempts.'
          : (r.message ??
              (r.remaining >= 0
                  ? 'Incorrect key. ${r.remaining} attempt${r.remaining == 1 ? '' : 's'} left.'
                  : 'Incorrect key.'));
    });
    if (r.lockedSeconds > 0) _startLockTimer();
  }

  /// Website protection is always on while sites are listed. This asks
  /// Android for the VPN permission if it is missing, then verifies it runs.
  Future<void> _turnOn(List<String> domains) async {
    if (domains.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _askingPermission = true;
    });
    final ok = await _svc.start(domains);
    _askingPermission = false;
    if (!ok && mounted) {
      _error = 'Android did not start website protection. Tap "Turn on protection" and allow the VPN request.';
    }
    ref.invalidate(websiteStatusProvider);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        title: const Text('Website Protection'),
        backgroundColor: AppTheme.navy,
        foregroundColor: AppTheme.inkNavy,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
          : !_svc.supported
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Website protection is only available on Android.'),
                )
              : _hasKey == null
                  ? _offlineView()
                  : _hasKey == false
                      ? _createKeyView()
                      : !_unlocked
                          ? _unlockView()
                          : _unlockedView(),
    );
  }

  Widget _createKeyView() => _pad([
        const Icon(Icons.lock_outline, size: 40, color: AppTheme.gold),
        const SizedBox(height: 12),
        const Text('Create your Website Protection Key',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Lora', fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
          'You will need this key to see, change or switch off your protected websites. Choose something you will not give away to yourself in a weak moment - consider letting a friend set it.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 18),
        TextField(controller: _keyCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'New key')),
        const SizedBox(height: 10),
        TextField(controller: _confirmCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm key')),
        if (_error != null) _err(_error!),
        const SizedBox(height: 16),
        _primary(_busy ? 'Saving\u2026' : 'Save key', _busy ? null : _createKey),
        const SizedBox(height: 8),
        const Text('You only create this once. It is saved to your account as a one-way hash, so clearing the app or signing in on a new phone does not remove it - you just enter it.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
      ]);

  Widget _offlineView() => _pad([
        const Icon(Icons.cloud_off_outlined, size: 40, color: AppTheme.gold),
        const SizedBox(height: 12),
        const Text('Connect to continue',
            style: TextStyle(fontFamily: 'Lora', fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
          'Godfident needs to check your account once to see whether your Website Protection Key already exists. Your protected sites keep blocking in the meantime.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 16),
        _primary('Try again', () {
          setState(() => _loading = true);
          _init();
        }),
      ]);

  Widget _unlockView() {
    final status = ref.watch(websiteStatusProvider).valueOrNull;
    final count = ref.watch(restrictedSitesProvider).valueOrNull?.length ?? 0;
    return _pad([
      const Icon(Icons.lock, size: 40, color: AppTheme.gold),
      const SizedBox(height: 12),
      const Text('Protected settings',
          style: TextStyle(fontFamily: 'Lora', fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      Text(
        '${(status?.running ?? false) ? 'Protection is on' : 'Protection is off'} · $count site${count == 1 ? '' : 's'}',
        style: const TextStyle(color: AppTheme.textSecondary),
      ),
      const SizedBox(height: 18),
      TextField(
        controller: _keyCtrl,
        obscureText: true,
        enabled: _lockLeft == 0,
        decoration: const InputDecoration(labelText: 'Website Protection Key'),
        onSubmitted: (_) => _unlock(),
      ),
      if (_lockLeft > 0)
        _err('Locked for ${_lockLeft ~/ 60}:${(_lockLeft % 60).toString().padLeft(2, '0')}')
      else if (_error != null)
        _err(_error!),
      const SizedBox(height: 16),
      _primary(_busy ? 'Checking\u2026' : 'Unlock', (_lockLeft > 0 || _busy) ? null : _unlock),
    ]);
  }

  Widget _unlockedView() {
    final sites = ref.watch(restrictedSitesProvider);
    final status = ref.watch(websiteStatusProvider).valueOrNull;
    final domains = sites.valueOrNull?.map((s) => s.domain).toList() ?? [];
    final running = status?.running ?? false;

    return ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 40), children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.navySurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: running ? AppTheme.gold : AppTheme.navyOutline),
        ),
        child: Column(children: [
          Row(children: [
            Icon(running ? Icons.shield : Icons.shield_outlined, color: running ? AppTheme.gold : AppTheme.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(running ? 'Protection is ON' : (domains.isEmpty ? 'Nothing to protect yet' : 'Protection is OFF'),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  running
                      ? 'Always on. Android blocks these sites in every browser and app, all day - not only during Focus sessions.'
                      : (domains.isEmpty
                          ? 'Add a website below. Protection then stays on automatically.'
                          : 'Android needs your permission to block websites.'),
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ]),
            ),
          ]),
          if (!running && domains.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy ? null : () => _turnOn(domains),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold, foregroundColor: AppTheme.inkNavy),
                child: Text(_busy ? 'Starting\u2026' : 'Turn on protection'),
              ),
            ),
          ],
          if (status != null && running)
            Align(
              alignment: Alignment.centerLeft,
              child: Text('${status.blockedLookups} blocked request(s) so far',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            ),
          if (status != null && !running && status.wanted)
            _err('Protection was turned off outside Godfident (Android VPN settings). Tap "Turn on protection".'),
          if (status?.privateDnsStrict ?? false)
            _err('Android "Private DNS" is set to a hostname. Blocking may not work until you set it to Off or Automatic.'),
        ]),
      ),
      if (_error != null) _err(_error!),
      ..._permissionCards(),
      if (running) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppTheme.navyVariant, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'Lookups seen: ${status?.totalQueries ?? 0}'
              '${(status?.lastHost ?? '').isEmpty ? '' : '  ·  last: ${status!.lastHost}'}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            if ((status?.lastError ?? '').isNotEmpty)
              Text('Last error: ${status!.lastError}', style: const TextStyle(fontSize: 12, color: AppTheme.danger)),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: (_testing || domains.isEmpty)
                  ? null
                  : () async {
                      setState(() {
                        _testing = true;
                        _testResult = null;
                      });
                      final r = await _svc.selfTest(domains.first);
                      ref.invalidate(websiteStatusProvider);
                      if (mounted) {
                        setState(() {
                          _testing = false;
                          _testResult = r;
                        });
                      }
                    },
              child: Text(_testing ? 'Testing\u2026' : 'Test protection now'),
            ),
            if (_testResult != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_testResult!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _testResult!.startsWith('BLOCKED') ? AppTheme.emerald : AppTheme.danger,
                    )),
              ),
          ]),
        ),
      ],
      const SizedBox(height: 18),
      Row(children: [
        Expanded(
          child: TextField(
            controller: _siteCtrl,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(hintText: 'youtube.com'),
            onSubmitted: (_) => _addSite(),
          ),
        ),
        const SizedBox(width: 10),
        // The app theme gives ElevatedButton an infinite minimum width. Inside a
        // Row that throws a layout error and the button (and the list below it)
        // never worked - so give it a finite size here.
        ElevatedButton(
          onPressed: _addSite,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.gold,
            foregroundColor: AppTheme.inkNavy,
            minimumSize: const Size(84, 52),
          ),
          child: const Text('Add'),
        ),
      ]),
      const SizedBox(height: 14),
      sites.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.gold)),
        error: (_, __) => _err('Could not read the saved list.'),
        data: (list) => list.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No websites yet. Add one above.',
                    textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)),
              )
            : Column(children: [
                for (final s in list)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.navySurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.navyOutline),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.language, color: AppTheme.goldDark),
                      title: Text(s.domain),
                      subtitle: Text(s.backendId == null ? 'Saved on this phone' : 'Saved & backed up',
                          style: const TextStyle(fontSize: 11)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => ref.read(restrictedSitesProvider.notifier).remove(s.domain),
                      ),
                    ),
                  ),
              ]),
      ),
      const SizedBox(height: 14),
      OutlinedButton.icon(
        onPressed: () {
          _askingPermission = true;
          _svc.openVpnSettings();
          Future.delayed(const Duration(seconds: 2), () => _askingPermission = false);
        },
        icon: const Icon(Icons.verified_user_outlined, size: 18),
        label: const Text('Make it unstoppable: Always-on VPN'),
        style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
      ),
      const SizedBox(height: 6),
      const Text(
        'In Android\u2019s VPN settings, tap the gear next to Godfident and switch on "Always-on VPN". Android then restarts protection by itself, even after a crash or reboot.',
        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
      ),
      const SizedBox(height: 10),
      const Text(
        'Subdomains are blocked too (youtube.com also blocks m.youtube.com). Browsers with their own "Secure DNS" setting can bypass this - turn that off in the browser.',
        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
      ),
    ]);
  }

  List<Widget> _permissionCards() {
    final missing = _perms.where((p) => !p.granted).toList();
    if (missing.isEmpty) return const [];
    return [
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.navySurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.danger.withValues(alpha: 0.5)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Needed to keep protection on all day',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final p in missing)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(p.why, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ]),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _allow(p.id),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(72, 36)),
                  child: const Text('Allow'),
                ),
              ]),
            ),
        ]),
      ),
    ];
  }

  Future<void> _addSite() async {
    final err = await ref.read(restrictedSitesProvider.notifier).add(_siteCtrl.text);
    if (err == null) _siteCtrl.clear();
    setState(() => _error = err);
    if (err != null) return;
    // Always-on: start (or keep) protection as soon as a site is added.
    final domains = (ref.read(restrictedSitesProvider).valueOrNull ?? []).map((x) => x.domain).toList();
    final st = await _svc.status();
    if (!st.running) await _turnOn(domains);
    ref.invalidate(websiteStatusProvider);
  }

  Widget _pad(List<Widget> c) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: c),
        ),
      );

  Widget _err(String t) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(t, style: const TextStyle(color: AppTheme.danger, fontSize: 13)),
      );

  Widget _primary(String t, VoidCallback? onTap) => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.gold, foregroundColor: AppTheme.inkNavy, padding: const EdgeInsets.symmetric(vertical: 14)),
          child: Text(t),
        ),
      );
}
