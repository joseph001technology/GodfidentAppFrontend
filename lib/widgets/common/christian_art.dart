import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';

/// Pictures for the app. The built-in ones are painted in code (so they ship
/// with no extra files, scale to any size and can move); people can also
/// choose a photo of their own. All built-in scenes have a Christian theme.
const artScenes = <String, String>{
  'sunrise': 'Sunrise',
  'cross': 'The Cross',
  'waters': 'Still waters',
  'dove': 'Dove of peace',
  'star': 'Star of Bethlehem',
  'wheat': 'Harvest field',
  'scroll': 'The open Word',
};

List<String> get artSceneIds => artScenes.keys.toList();

/// A scene id that fits a reminder type when the person has not chosen one.
String defaultSceneForType(String type) {
  switch (type) {
    case 'prayer':
      return 'dove';
    case 'reading':
      return 'scroll';
    case 'both':
      return 'sunrise';
    case 'fasting':
      return 'wheat';
    default:
      return 'star';
  }
}

String sceneForId(int id) => artSceneIds[id.abs() % artSceneIds.length];

// ── painting helpers ───────────────────────────────────────────────────
void _fillSky(Canvas c, Size s, List<Color> colors, [List<double>? stops]) {
  final r = Offset.zero & s;
  c.drawRect(
    r,
    Paint()
      ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors, stops: stops).createShader(r),
  );
}

void _glow(Canvas c, Offset o, double radius, Color color, [double a = 0.9]) {
  c.drawCircle(
    o,
    radius,
    Paint()
      ..shader = RadialGradient(colors: [color.withValues(alpha: a), color.withValues(alpha: 0)])
          .createShader(Rect.fromCircle(center: o, radius: radius)),
  );
}

void _rays(Canvas c, Offset o, double len, double rot, Color color, {int n = 14, double alpha = 0.16}) {
  final p = Paint()..color = color.withValues(alpha: alpha);
  for (var i = 0; i < n; i++) {
    final a = rot + i * 2 * math.pi / n;
    final w = math.pi / n * 0.55;
    final path = Path()
      ..moveTo(o.dx, o.dy)
      ..lineTo(o.dx + len * math.cos(a - w), o.dy + len * math.sin(a - w))
      ..lineTo(o.dx + len * math.cos(a + w), o.dy + len * math.sin(a + w))
      ..close();
    c.drawPath(path, p);
  }
}

void _hills(Canvas c, Size s, Color col, double base, double amp, double phase, [double freq = 1.0]) {
  final path = Path()..moveTo(0, s.height);
  for (double x = 0; x <= s.width + 4; x += 4) {
    path.lineTo(x, s.height * base + amp * math.sin(x / s.width * 2 * math.pi * freq + phase));
  }
  path
    ..lineTo(s.width + 4, s.height)
    ..close();
  c.drawPath(path, Paint()..color = col);
}

void _crossShape(Canvas c, Offset base, double h, Color col) {
  final w = h * 0.14;
  final p = Paint()..color = col;
  c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(base.dx - w / 2, base.dy - h, w, h), Radius.circular(w * 0.2)), p);
  c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(base.dx - h * 0.3, base.dy - h * 0.72, h * 0.6, w), Radius.circular(w * 0.2)), p);
}

void _star4(Canvas c, Offset o, double r, Color col) {
  final p = Path();
  for (var i = 0; i < 8; i++) {
    final rad = i.isEven ? r : r * 0.28;
    final a = i * math.pi / 4 - math.pi / 2;
    final pt = Offset(o.dx + rad * math.cos(a), o.dy + rad * math.sin(a));
    if (i == 0) {
      p.moveTo(pt.dx, pt.dy);
    } else {
      p.lineTo(pt.dx, pt.dy);
    }
  }
  p.close();
  c.drawPath(p, Paint()..color = col);
}

void _dove(Canvas c, Offset o, double sc, double flap, Color col) {
  final body = Path()
    ..moveTo(o.dx - 30 * sc, o.dy)
    ..quadraticBezierTo(o.dx - 5 * sc, o.dy - 14 * sc, o.dx + 22 * sc, o.dy - 6 * sc)
    ..quadraticBezierTo(o.dx + 34 * sc, o.dy - 10 * sc, o.dx + 38 * sc, o.dy - 4 * sc)
    ..quadraticBezierTo(o.dx + 24 * sc, o.dy + 4 * sc, o.dx + 8 * sc, o.dy + 10 * sc)
    ..quadraticBezierTo(o.dx - 12 * sc, o.dy + 14 * sc, o.dx - 30 * sc, o.dy)
    ..close();
  final wy = -34 * sc * flap;
  final wing = Path()
    ..moveTo(o.dx - 6 * sc, o.dy - 4 * sc)
    ..quadraticBezierTo(o.dx - 14 * sc, o.dy + wy * 1.2, o.dx - 34 * sc, o.dy + wy)
    ..quadraticBezierTo(o.dx - 14 * sc, o.dy + wy * 0.4 - 2 * sc, o.dx + 12 * sc, o.dy - 2 * sc)
    ..close();
  final tail = Path()
    ..moveTo(o.dx - 26 * sc, o.dy - 1 * sc)
    ..lineTo(o.dx - 46 * sc, o.dy + 6 * sc)
    ..lineTo(o.dx - 28 * sc, o.dy + 5 * sc)
    ..close();
  final p = Paint()..color = col;
  c.drawPath(body, p);
  c.drawPath(wing, p);
  c.drawPath(tail, p);
}

/// Paints one of the built-in scenes. [t] is a loop position from 0 to 1; the
/// motion in every scene is periodic, so the loop is seamless.
class ScenePainter extends CustomPainter {
  final String scene;
  final double t;
  const ScenePainter(this.scene, this.t);

  @override
  void paint(Canvas canvas, Size s) {
    canvas.clipRect(Offset.zero & s);
    switch (scene) {
      case 'cross':
        _paintCross(canvas, s);
        break;
      case 'waters':
        _paintWaters(canvas, s);
        break;
      case 'dove':
        _paintDove(canvas, s);
        break;
      case 'star':
        _paintStar(canvas, s);
        break;
      case 'wheat':
        _paintWheat(canvas, s);
        break;
      case 'scroll':
        _paintScroll(canvas, s);
        break;
      default:
        _paintSunrise(canvas, s);
    }
  }

  void _paintSunrise(Canvas c, Size s) {
    _fillSky(c, s, const [Color(0xFF2B2F6B), Color(0xFFB4607A), Color(0xFFF2A65A), Color(0xFFFBD38D)], const [0, 0.45, 0.75, 1]);
    final sun = Offset(s.width * 0.5, s.height * 0.68);
    _glow(c, sun, s.width * 0.55, const Color(0xFFFFE2A8), 0.85);
    _rays(c, sun, s.width * 0.9, t * 2 * math.pi / 14, const Color(0xFFFFEFC2), n: 14, alpha: 0.15);
    c.drawCircle(sun, s.width * 0.07, Paint()..color = const Color(0xFFFFF1C9));
    _hills(c, s, const Color(0xFF6B4E71), 0.74, s.height * 0.04, 0.8);
    _crossShape(c, Offset(s.width * 0.2, s.height * 0.78), s.height * 0.22, const Color(0xFF241E3A));
    _hills(c, s, const Color(0xFF2F2A4A), 0.84, s.height * 0.05, 2.4, 1.3);
  }

  void _paintCross(Canvas c, Size s) {
    _fillSky(c, s, const [Color(0xFF1B1F4B), Color(0xFF5B3A78), Color(0xFFE0936A)], const [0, 0.6, 1]);
    final o = Offset(s.width * 0.5, s.height * 0.42);
    _glow(c, o, s.height * 0.85, const Color(0xFFFFD98A), 0.7);
    _rays(c, o, s.width, t * 2 * math.pi / 16, const Color(0xFFFFE6B0), n: 16, alpha: 0.14);
    _hills(c, s, const Color(0xFF1A1633), 0.82, s.height * 0.03, 1.0, 0.8);
    _crossShape(c, Offset(s.width * 0.5, s.height * 0.86), s.height * 0.62, const Color(0xFF120F26));
  }

  void _paintWaters(Canvas c, Size s) {
    _fillSky(c, s, const [Color(0xFF9AD0E8), Color(0xFFE9F4F1)]);
    _glow(c, Offset(s.width * 0.75, s.height * 0.28), s.height * 0.7, Colors.white, 0.8);
    _hills(c, s, const Color(0xFF7FA6B8), 0.55, s.height * 0.06, 0.5, 1.3);
    _hills(c, s, const Color(0xFF5E8AA0), 0.62, s.height * 0.04, 2.0, 1.8);
    final lake = Rect.fromLTWH(0, s.height * 0.66, s.width, s.height * 0.34);
    c.drawRect(
      lake,
      Paint()
        ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF6BB5CF), Color(0xFF2F7C9C)])
            .createShader(lake),
    );
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final y = s.height * (0.69 + i * 0.038);
      final x = s.width * (0.15 + 0.1 * (i % 3)) + math.sin(t * 2 * math.pi + i) * s.width * 0.03;
      c.drawLine(Offset(x, y), Offset(x + s.width * (0.18 + 0.03 * (i % 2)), y), line);
    }
  }

  void _paintDove(Canvas c, Size s) {
    _fillSky(c, s, const [Color(0xFF8EC5E8), Color(0xFFEAF5FB)]);
    final top = Offset(s.width * 0.5, 0);
    _glow(c, top, s.height * 1.0, Colors.white, 0.8);
    _rays(c, top, s.height * 1.4, t * 2 * math.pi / 12, Colors.white, n: 12, alpha: 0.12);
    final cloud = Paint()..color = Colors.white.withValues(alpha: 0.85);
    for (var i = 0; i < 3; i++) {
      final span = s.width + 220;
      final x = ((i * span / 3 + t * span * 0.5) % span) - 110;
      final y = s.height * (0.62 + 0.12 * i);
      c.drawOval(Rect.fromCenter(center: Offset(x, y), width: 120, height: 28), cloud);
      c.drawOval(Rect.fromCenter(center: Offset(x + 26, y - 10), width: 70, height: 26), cloud);
    }
    final x = -40 + (s.width + 80) * t;
    final y = s.height * 0.42 + math.sin(t * 2 * math.pi * 2) * s.height * 0.06;
    final sc = (s.height / 120).clamp(0.6, 2.0);
    final flap = math.sin(t * 2 * math.pi * 10);
    _dove(c, Offset(x + 3, y + 5), sc, flap, const Color(0x2A2B4A66));
    _dove(c, Offset(x, y), sc, flap, Colors.white);
  }

  void _paintStar(Canvas c, Size s) {
    _fillSky(c, s, const [Color(0xFF0B1230), Color(0xFF1B2A5C), Color(0xFF3B4A86)]);
    final rnd = math.Random(5);
    for (var i = 0; i < 42; i++) {
      final p = Offset(rnd.nextDouble() * s.width, rnd.nextDouble() * s.height * 0.7);
      final a = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(t * 2 * math.pi + i * 1.3));
      c.drawCircle(p, 0.8 + rnd.nextDouble() * 1.2, Paint()..color = Colors.white.withValues(alpha: a));
    }
    final o = Offset(s.width * 0.62, s.height * 0.3);
    _glow(c, o, s.height * 0.75, const Color(0xFFFFE9A8), 0.55);
    _rays(c, o, s.height * 1.1, t * 2 * math.pi / 8, const Color(0xFFFFE9A8), n: 8, alpha: 0.12);
    _star4(c, o, s.height * 0.2 * (1 + 0.06 * math.sin(t * 2 * math.pi * 2)), const Color(0xFFFFF3C8));
    _hills(c, s, const Color(0xFF0A0F24), 0.84, s.height * 0.04, 0.6, 1.2);
  }

  void _paintWheat(Canvas c, Size s) {
    _fillSky(c, s, const [Color(0xFFF6D58A), Color(0xFFF9E8B8)]);
    _glow(c, Offset(s.width * 0.8, s.height * 0.25), s.height * 0.7, const Color(0xFFFFF4CF), 0.9);
    final field = Rect.fromLTWH(0, s.height * 0.55, s.width, s.height * 0.45);
    c.drawRect(
      field,
      Paint()
        ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFD9A441), Color(0xFF8C5E1C)])
            .createShader(field),
    );
    final stalk = Paint()
      ..color = const Color(0xFF7B4F12).withValues(alpha: 0.85)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final head = Paint()..color = const Color(0xFFF0C255);
    for (var r = 0; r < 4; r++) {
      final baseY = s.height * (0.64 + 0.1 * r);
      final len = s.height * 0.15 * (1 + r * 0.25);
      for (double x = (r.isEven ? 0 : 7); x < s.width + 14; x += 14) {
        final lean = math.sin(t * 2 * math.pi + x * 0.05 + r) * 6 * (1 + r * 0.3);
        final tip = Offset(x + lean, baseY - len);
        c.drawLine(Offset(x, baseY), tip, stalk);
        c.drawOval(Rect.fromCenter(center: tip, width: 5, height: 12), head);
      }
    }
  }

  void _paintScroll(Canvas c, Size s) {
    _fillSky(c, s, const [Color(0xFF241B3F), Color(0xFF5A3F72), Color(0xFFE8B66A)], const [0, 0.55, 1]);
    final o = Offset(s.width * 0.5, s.height * 0.58);
    _glow(c, o, s.height * 0.95, const Color(0xFFFFE3A0), 0.75);
    _rays(c, o, s.width, t * 2 * math.pi / 12, const Color(0xFFFFF0C8), n: 12, alpha: 0.15);
    final page = Paint()..color = const Color(0xFFFFF4D6);
    final w = s.width, h = s.height;
    final left = Path()
      ..moveTo(o.dx, o.dy + h * 0.14)
      ..quadraticBezierTo(o.dx - w * 0.12, o.dy + h * 0.05, o.dx - w * 0.26, o.dy + h * 0.12)
      ..lineTo(o.dx - w * 0.26, o.dy - h * 0.12)
      ..quadraticBezierTo(o.dx - w * 0.12, o.dy - h * 0.19, o.dx, o.dy - h * 0.10)
      ..close();
    final right = Path()
      ..moveTo(o.dx, o.dy + h * 0.14)
      ..quadraticBezierTo(o.dx + w * 0.12, o.dy + h * 0.05, o.dx + w * 0.26, o.dy + h * 0.12)
      ..lineTo(o.dx + w * 0.26, o.dy - h * 0.12)
      ..quadraticBezierTo(o.dx + w * 0.12, o.dy - h * 0.19, o.dx, o.dy - h * 0.10)
      ..close();
    c.drawPath(left, page);
    c.drawPath(right, page);
    final ink = Paint()
      ..color = const Color(0xFFC9A66B)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final y = o.dy - h * 0.06 + i * h * 0.035;
      c.drawLine(Offset(o.dx - w * 0.22, y), Offset(o.dx - w * 0.04, y + h * 0.012), ink);
      c.drawLine(Offset(o.dx + w * 0.04, y + h * 0.012), Offset(o.dx + w * 0.22, y), ink);
    }
    c.drawLine(Offset(o.dx, o.dy - h * 0.10), Offset(o.dx, o.dy + h * 0.14), Paint()..color = const Color(0xFFB88B45)..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(ScenePainter o) => o.t != t || o.scene != scene;
}

/// A scene that moves, quietly and with no sound (used behind a running session).
class AnimatedScene extends StatefulWidget {
  final String scene;
  final Duration period;
  const AnimatedScene({super.key, required this.scene, this.period = const Duration(seconds: 28)});
  @override
  State<AnimatedScene> createState() => _AnimatedSceneState();
}

class _AnimatedSceneState extends State<AnimatedScene> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period)..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(painter: ScenePainter(widget.scene, _c.value), size: Size.infinite),
        ),
      );
}

/// Where the chosen pictures are kept: one entry per thing ("reminder_12",
/// "rule_3"). A value is "scene:<id>" for a built-in picture or "b64:<data>"
/// for a photo the person uploaded (stored small, on the phone).
class ArtStore extends ChangeNotifier {
  ArtStore._();
  static final ArtStore instance = ArtStore._();
  final Map<String, String> _m = {};
  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final p = await SharedPreferences.getInstance();
    for (final k in p.getKeys()) {
      if (k.startsWith('art_')) {
        final v = p.getString(k);
        if (v != null && v.isNotEmpty) _m[k.substring(4)] = v;
      }
    }
    _loaded = true;
    notifyListeners();
  }

  String? of(String key) => _m[key];

  Future<void> set(String key, String? ref) async {
    final p = await SharedPreferences.getInstance();
    if (ref == null || ref.isEmpty) {
      _m.remove(key);
      await p.remove('art_$key');
    } else {
      _m[key] = ref;
      await p.setString('art_$key', ref);
    }
    notifyListeners();
  }
}

final _bytesCache = <String, Uint8List>{};

/// Draws a picture reference ("scene:..", "b64:..") or, if empty, [fallbackScene].
class ArtImage extends StatelessWidget {
  final String? ref;
  final String fallbackScene;
  final double? height;
  final double? width;
  final double radius;
  final bool animate;
  const ArtImage({
    super.key,
    this.ref,
    required this.fallbackScene,
    this.height,
    this.width,
    this.radius = 16,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget inner;
    final r = ref ?? '';
    if (r.startsWith('b64:')) {
      final bytes = _bytesCache.putIfAbsent(r, () => base64Decode(r.substring(4)));
      inner = Image.memory(bytes, fit: BoxFit.cover, width: width, height: height, gaplessPlayback: true);
    } else {
      final id = r.startsWith('scene:') ? r.substring(6) : fallbackScene;
      inner = animate
          ? AnimatedScene(scene: id)
          : RepaintBoundary(child: CustomPaint(painter: ScenePainter(id, 0.3), size: Size.infinite));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(width: width, height: height, child: inner),
    );
  }
}

/// [ArtImage] for the thing stored under [artKey], kept up to date as it changes.
class KeyedArt extends StatefulWidget {
  final String artKey;
  final String fallbackScene;
  final double? height;
  final double? width;
  final double radius;
  const KeyedArt({super.key, required this.artKey, required this.fallbackScene, this.height, this.width, this.radius = 16});
  @override
  State<KeyedArt> createState() => _KeyedArtState();
}

class _KeyedArtState extends State<KeyedArt> {
  @override
  void initState() {
    super.initState();
    ArtStore.instance.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: ArtStore.instance,
        builder: (_, __) => ArtImage(
          ref: ArtStore.instance.of(widget.artKey),
          fallbackScene: widget.fallbackScene,
          height: widget.height,
          width: widget.width,
          radius: widget.radius,
        ),
      );
}

/// Bottom sheet to pick a built-in picture or upload your own photo.
/// Returns "scene:<id>", "b64:<data>", "" (= go back to the default) or null (cancelled).
Future<String?> showArtPicker(BuildContext context, {String? current, String? fallbackScene}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.navySurface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) {
      Future<void> upload() async {
        try {
          final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 900, maxHeight: 900, imageQuality: 72);
          if (f == null) return;
          final bytes = await f.readAsBytes();
          if (bytes.length > 600 * 1024) {
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('That photo is too large. Choose a smaller one.')));
            }
            return;
          }
          if (ctx.mounted) Navigator.pop(ctx, 'b64:${base64Encode(bytes)}');
        } catch (_) {
          if (ctx.mounted) {
            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Could not open your photos.')));
          }
        }
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Choose a picture', style: TextStyle(fontFamily: 'Lora', fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.15,
              children: [
                for (final e in artScenes.entries)
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx, 'scene:${e.key}'),
                    child: Stack(fit: StackFit.expand, children: [
                      ArtImage(ref: 'scene:${e.key}', fallbackScene: e.key, radius: 12),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                          decoration: const BoxDecoration(
                            color: Color(0x99000000),
                            borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                          ),
                          child: Text(e.value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      if (current == 'scene:${e.key}')
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.gold, width: 3),
                          ),
                        ),
                    ]),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: upload,
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
                icon: const Icon(Icons.upload_outlined),
                label: const Text('Upload my own photo'),
              ),
            ),
            if (current != null && current.isNotEmpty)
              TextButton(onPressed: () => Navigator.pop(ctx, ''), child: const Text('Use the default picture')),
          ]),
        ),
      );
    },
  );
}
