import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/restriction_provider.dart';
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
  bool _hasKey = false;
  bool _unlocked = false; // memory only - leaving the screen locks it again
  bool _busy = false;
  String? _error;
  String? _testResult;
  bool _testing = false;
  int _lockLeft = 0;
  Timer? _lockTimer;

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
    if (s == AppLifecycleState.paused) {
      // Re-lock whenever the app leaves the foreground.
      if (_unlocked) setState(() => _unlocked = false);
    }
    if (s == AppLifecycleState.resumed) ref.invalidate(websiteStatusProvider);
  }

  Future<void> _init() async {
    final has = await _svc.hasKey();
    final locked = await _svc.lockedSeconds();
    if (!mounted) return;
    setState(() {
      _hasKey = has;
      _lockLeft = locked;
      _loading = false;
    });
    if (locked > 0) _startLockTimer();
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
    await _svc.setKey(a);
    _keyCtrl.clear();
    _confirmCtrl.clear();
    setState(() {
      _hasKey = true;
      _unlocked = true;
      _error = null;
    });
  }

  Future<void> _unlock() async {
    final ok = await _svc.verifyKey(_keyCtrl.text);
    _keyCtrl.clear();
    if (ok) {
      setState(() {
        _unlocked = true;
        _error = null;
      });
      return;
    }
    final locked = await _svc.lockedSeconds();
    final left = await _svc.remainingAttempts();
    setState(() {
      _lockLeft = locked;
      _error = locked > 0 ? 'Too many wrong attempts.' : 'Incorrect key. $left attempt${left == 1 ? '' : 's'} left.';
    });
    if (locked > 0) _startLockTimer();
  }

  Future<void> _toggle(bool on, List<String> domains) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    if (on) {
      if (domains.isEmpty) {
        setState(() {
          _busy = false;
          _error = 'Add at least one website first.';
        });
        return;
      }
      final ok = await _svc.start(domains);
      if (!ok) _error = 'Android did not start website protection. Allow the VPN request and try again.';
    } else {
      await _svc.stop();
      await Future<void>.delayed(const Duration(milliseconds: 500));
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
              : !_hasKey
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
        _primary('Save key', _createKey),
        const SizedBox(height: 8),
        const Text('The key is stored only as a one-way hash on this phone. It cannot be recovered - if you forget it, you must reinstall the app.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
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
      _primary('Unlock', _lockLeft > 0 ? null : _unlock),
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
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppTheme.gold,
            title: Text(running ? 'Protection is ON' : 'Protection is OFF',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
              running
                  ? 'Android is blocking these sites in every browser and app.'
                  : 'Sites are not blocked until you switch this on.',
              style: const TextStyle(fontSize: 12),
            ),
            value: running,
            onChanged: _busy ? null : (v) => _toggle(v, domains),
          ),
          if (status != null && running)
            Align(
              alignment: Alignment.centerLeft,
              child: Text('${status.blockedLookups} blocked request(s) so far',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            ),
          if (status != null && !running && status.wanted)
            _err('Protection was turned off outside Godfident (Android VPN settings). Switch it on again.'),
          if (status?.privateDnsStrict ?? false)
            _err('Android "Private DNS" is set to a hostname. Blocking may not work until you set it to Off or Automatic.'),
        ]),
      ),
      if (_error != null) _err(_error!),
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
        ElevatedButton(
          onPressed: _addSite,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold, foregroundColor: AppTheme.inkNavy),
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
      const SizedBox(height: 10),
      const Text(
        'Subdomains are blocked too (youtube.com also blocks m.youtube.com). Browsers with their own "Secure DNS" setting can bypass this - turn that off in the browser.',
        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
      ),
    ]);
  }

  Future<void> _addSite() async {
    final err = await ref.read(restrictedSitesProvider.notifier).add(_siteCtrl.text);
    if (err == null) _siteCtrl.clear();
    setState(() => _error = err);
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
