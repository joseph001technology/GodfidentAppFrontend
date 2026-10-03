import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// A reminder sound: one of the tones bundled with Godfident, or a song from
/// the user's phone ([uri] is its content:// address).
class Ringtone {
  final String id; // bell | chime | harp | dawn | device
  final String title;
  final String? uri;
  const Ringtone(this.id, this.title, {this.uri});

  bool get isDevice => uri != null;

  Map<String, dynamic> toJson() => {'id': id, 'title': title, if (uri != null) 'uri': uri};
  factory Ringtone.fromJson(Map<String, dynamic> j) =>
      Ringtone(j['id'] as String? ?? 'bell', j['title'] as String? ?? 'Temple Bell', uri: j['uri'] as String?);

  /// Tones shipped inside the app (res/raw for notifications, assets for preview).
  static const builtIn = <Ringtone>[
    Ringtone('bell', 'Temple Bell'),
    Ringtone('chime', 'Morning Chime'),
    Ringtone('harp', 'Harp'),
    Ringtone('dawn', 'Dawn'),
  ];
  static const fallback = Ringtone('bell', 'Temple Bell');
}

/// Remembers which ringtone each reminder uses (kept on the phone, so it works offline).
class RingtoneStore {
  RingtoneStore._();
  static final RingtoneStore instance = RingtoneStore._();

  static String _key(int reminderId) => 'ringtone_$reminderId';

  Future<Ringtone> load(int reminderId) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key(reminderId)) ?? p.getString('ringtone_default');
    if (raw == null) return Ringtone.fallback;
    try {
      return Ringtone.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return Ringtone.fallback;
    }
  }

  Future<void> save(int reminderId, Ringtone r) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key(reminderId), jsonEncode(r.toJson()));
    await p.setString('ringtone_default', jsonEncode(r.toJson())); // next new reminder starts with it
  }

  Future<void> move(int fromId, int toId) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key(fromId));
    if (raw != null) {
      await p.setString(_key(toId), raw);
      await p.remove(_key(fromId));
    }
  }

  Future<void> remove(int reminderId) async =>
      (await SharedPreferences.getInstance()).remove(_key(reminderId));
}
