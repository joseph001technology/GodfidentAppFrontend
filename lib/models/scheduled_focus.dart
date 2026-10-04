/// A pre-set ("scheduled") Focus session: "6:00, 30 minutes, Bible + prayer".
/// At the start time the phone rings until you press Start.
class ScheduledFocus {
  /// Identity on this phone (always positive). [backendId] is set once the
  /// server has a copy.
  final int id;
  final int? backendId;
  final String title;
  final String purpose; // bible | prayer | both
  final int hour;
  final int minute;
  final int durationMinutes;

  /// Weekdays it repeats on, 1 = Monday ... 7 = Sunday. Empty = once (next time the clock hits).
  final List<int> days;
  final bool enabled;
  final bool dirty; // changed on the phone, not yet uploaded

  const ScheduledFocus({
    required this.id,
    this.backendId,
    this.title = '',
    this.purpose = 'both',
    required this.hour,
    required this.minute,
    this.durationMinutes = 30,
    this.days = const [],
    this.enabled = true,
    this.dirty = true,
  });

  static const purposes = {'bible': 'Bible reading', 'prayer': 'Prayer', 'both': 'Bible + prayer'};
  static const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  String get purposeLabel => purposes[purpose] ?? 'Bible + prayer';
  String get displayTitle => title.trim().isEmpty ? 'Time with God' : title.trim();

  String get timeLabel {
    final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$h12:${minute.toString().padLeft(2, '0')} ${hour >= 12 ? 'PM' : 'AM'}';
  }

  String get endLabel {
    final t = (hour * 60 + minute + durationMinutes) % (24 * 60);
    final h = t ~/ 60, m = t % 60;
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:${m.toString().padLeft(2, '0')} ${h >= 12 ? 'PM' : 'AM'}';
  }

  String get durationLabel =>
      durationMinutes < 60 ? '$durationMinutes min' : (durationMinutes % 60 == 0 ? '${durationMinutes ~/ 60} hr' : '${durationMinutes ~/ 60} hr ${durationMinutes % 60} min');

  String get repeatLabel {
    if (days.isEmpty) return 'Once';
    if (days.length == 7) return 'Every day';
    if (days.length == 5 && !days.contains(6) && !days.contains(7)) return 'Weekdays';
    return days.map((d) => dayNames[d - 1]).join(' · ');
  }

  ScheduledFocus copyWith({
    int? backendId,
    String? title,
    String? purpose,
    int? hour,
    int? minute,
    int? durationMinutes,
    List<int>? days,
    bool? enabled,
    bool? dirty,
  }) =>
      ScheduledFocus(
        id: id,
        backendId: backendId ?? this.backendId,
        title: title ?? this.title,
        purpose: purpose ?? this.purpose,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        days: days ?? this.days,
        enabled: enabled ?? this.enabled,
        dirty: dirty ?? this.dirty,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'bid': backendId,
        't': title,
        'p': purpose,
        'h': hour,
        'm': minute,
        'd': durationMinutes,
        'days': days,
        'on': enabled,
        'dirty': dirty,
      };

  factory ScheduledFocus.fromJson(Map<String, dynamic> j) => ScheduledFocus(
        id: j['id'] as int,
        backendId: j['bid'] as int?,
        title: j['t'] as String? ?? '',
        purpose: j['p'] as String? ?? 'both',
        hour: j['h'] as int? ?? 6,
        minute: j['m'] as int? ?? 0,
        durationMinutes: j['d'] as int? ?? 30,
        days: List<int>.from(j['days'] as List? ?? const []),
        enabled: j['on'] as bool? ?? true,
        dirty: j['dirty'] as bool? ?? false,
      );

  /// Payload for POST/PATCH /api/focus/schedules/.
  Map<String, dynamic> toApi() => {
        'title': title,
        'purpose': purpose,
        'days': days,
        'start_time': '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00',
        'duration_minutes': durationMinutes,
        'is_active': enabled,
      };

  factory ScheduledFocus.fromApi(Map<String, dynamic> j, int localId) {
    final parts = '${j['start_time'] ?? '06:00:00'}'.split(':');
    var days = List<int>.from((j['days'] as List? ?? const []).map((e) => (e as num).toInt()));
    if (days.isEmpty && j['day_of_week'] is num) days = [((j['day_of_week'] as num).toInt()) + 1]; // legacy rows
    return ScheduledFocus(
      id: localId,
      backendId: (j['id'] as num?)?.toInt(),
      title: '${j['title'] ?? ''}',
      purpose: '${j['purpose'] ?? 'both'}',
      hour: int.tryParse(parts[0]) ?? 6,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      durationMinutes: (j['duration_minutes'] as num?)?.toInt() ?? 30,
      days: days,
      enabled: j['is_active'] as bool? ?? true,
      dirty: false,
    );
  }
}
