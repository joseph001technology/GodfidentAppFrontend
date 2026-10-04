import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_response.dart';
import '../core/dio_client.dart';
import '../models/scheduled_focus.dart';

/// Offline-first storage for scheduled Focus sessions. The phone copy is what
/// rings (so it works with no internet); the account copy means the schedule
/// comes back after clearing the app's data or signing in on a new phone.
class ScheduledFocusStore {
  ScheduledFocusStore._();
  static final ScheduledFocusStore instance = ScheduledFocusStore._();

  static const _kList = 'scheduled_focus_v1';
  static const _kDelete = 'scheduled_focus_delete_v1';
  static const _kNextId = 'scheduled_focus_next_id_v1';
  static const _path = '/api/focus/schedules/';

  Future<List<ScheduledFocus>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kList);
    if (raw == null) return [];
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => ScheduledFocus.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      list.sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(List<ScheduledFocus> v) async =>
      (await SharedPreferences.getInstance()).setString(_kList, jsonEncode(v.map((e) => e.toJson()).toList()));

  Future<int> newId() async {
    final p = await SharedPreferences.getInstance();
    final id = (p.getInt(_kNextId) ?? 0) + 1;
    await p.setInt(_kNextId, id);
    return id;
  }

  /// Adds or replaces (by [ScheduledFocus.id]) and returns the saved copy.
  Future<ScheduledFocus> upsert(ScheduledFocus f) async {
    final list = await load();
    final i = list.indexWhere((x) => x.id == f.id);
    final saved = f.copyWith(dirty: true);
    if (i == -1) {
      list.add(saved);
    } else {
      list[i] = saved;
    }
    await _save(list);
    return saved;
  }

  Future<void> remove(int id) async {
    final list = await load();
    final gone = list.where((x) => x.id == id).toList();
    final p = await SharedPreferences.getInstance();
    for (final g in gone) {
      if (g.backendId != null) {
        final q = p.getStringList(_kDelete) ?? [];
        if (!q.contains('${g.backendId}')) q.add('${g.backendId}');
        await p.setStringList(_kDelete, q);
      }
    }
    await _save(list.where((x) => x.id != id).toList());
  }

  /// Best-effort two-way sync. Never throws. True when the account is up to date.
  Future<bool> sync() async {
    final dio = DioClient.instance;
    final p = await SharedPreferences.getInstance();
    try {
      final pending = List<String>.from(p.getStringList(_kDelete) ?? []);
      for (final id in pending.toList()) {
        try {
          await dio.delete('$_path$id/');
          pending.remove(id);
        } on DioException catch (e) {
          if (e.response?.statusCode == 404) {
            pending.remove(id);
          } else {
            rethrow;
          }
        }
      }
      await p.setStringList(_kDelete, pending);

      var list = await load();
      for (var i = 0; i < list.length; i++) {
        final f = list[i];
        if (!f.dirty) continue;
        if (f.backendId == null) {
          final r = await dio.post(_path, data: f.toApi());
          final m = readDataMap(r.data);
          list[i] = f.copyWith(backendId: (m['id'] as num?)?.toInt(), dirty: false);
        } else {
          await dio.patch('$_path${f.backendId}/', data: f.toApi());
          list[i] = f.copyWith(dirty: false);
        }
      }
      await _save(list);

      // Fresh install / cleared data: bring the account's schedule back.
      if (list.isEmpty) {
        final r = await dio.get(_path);
        for (final j in readList(r.data)) {
          if (j is! Map) continue;
          list.add(ScheduledFocus.fromApi(Map<String, dynamic>.from(j), await newId()));
        }
        if (list.isNotEmpty) await _save(list);
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
