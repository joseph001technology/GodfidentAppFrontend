import 'dart:convert';
import 'dart:typed_data';

class UserProfile {
  final String preferredTranslation;
  final String bio;
  final String? avatar;
  final String avatarData; // small data: URI photo
  final String church;
  final String location;
  final String favoriteVerse;
  final String phone;
  final String timezone;
  final bool dailyDevotionalReminder;
  final bool readingReminder;
  final bool prayerReminder;
  final String reminderTime;

  const UserProfile({
    this.preferredTranslation = 'KJV',
    this.bio = '',
    this.avatar,
    this.avatarData = '',
    this.church = '',
    this.location = '',
    this.favoriteVerse = '',
    this.phone = '',
    this.timezone = 'UTC',
    this.dailyDevotionalReminder = true,
    this.readingReminder = true,
    this.prayerReminder = true,
    this.reminderTime = '08:00',
  });

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        preferredTranslation: j['preferred_translation'] ?? 'KJV',
        bio: j['bio'] ?? '',
        avatar: j['avatar'],
        avatarData: (j['avatar_data'] ?? '').toString(),
        church: (j['church'] ?? '').toString(),
        location: (j['location'] ?? '').toString(),
        favoriteVerse: (j['favorite_verse'] ?? '').toString(),
        phone: (j['phone'] ?? '').toString(),
        timezone: j['timezone'] ?? 'UTC',
        dailyDevotionalReminder: j['daily_devotional_reminder'] ?? true,
        readingReminder: j['reading_reminder'] ?? true,
        prayerReminder: j['prayer_reminder'] ?? true,
        reminderTime: j['reminder_time'] ?? '08:00',
      );

  Map<String, dynamic> toJson() => {
        'preferred_translation': preferredTranslation,
        'bio': bio,
        'avatar_data': avatarData,
        'church': church,
        'location': location,
        'favorite_verse': favoriteVerse,
        'phone': phone,
        if (avatar != null) 'avatar': avatar,
        'timezone': timezone,
        'daily_devotional_reminder': dailyDevotionalReminder,
        'reading_reminder': readingReminder,
        'prayer_reminder': prayerReminder,
        'reminder_time': reminderTime,
      };

  UserProfile copyWith({
    String? preferredTranslation,
    String? bio,
    String? avatar,
    String? avatarData,
    String? church,
    String? location,
    String? favoriteVerse,
    String? phone,
    String? timezone,
    bool? dailyDevotionalReminder,
    bool? readingReminder,
    bool? prayerReminder,
    String? reminderTime,
  }) =>
      UserProfile(
        preferredTranslation: preferredTranslation ?? this.preferredTranslation,
        bio: bio ?? this.bio,
        avatar: avatar ?? this.avatar,
        avatarData: avatarData ?? this.avatarData,
        church: church ?? this.church,
        location: location ?? this.location,
        favoriteVerse: favoriteVerse ?? this.favoriteVerse,
        phone: phone ?? this.phone,
        timezone: timezone ?? this.timezone,
        dailyDevotionalReminder: dailyDevotionalReminder ?? this.dailyDevotionalReminder,
        readingReminder: readingReminder ?? this.readingReminder,
        prayerReminder: prayerReminder ?? this.prayerReminder,
        reminderTime: reminderTime ?? this.reminderTime,
      );
}

class User {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String fullName;
  final bool isEmailVerified;
  final String dateJoined;
  final UserProfile? profile;

  const User({
    required this.id,
    required this.email,
    this.firstName = '',
    this.lastName = '',
    this.fullName = '',
    this.isEmailVerified = false,
    this.dateJoined = '',
    this.profile,
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'] ?? '',
        email: j['email'] ?? '',
        firstName: j['first_name'] ?? '',
        lastName: j['last_name'] ?? '',
        fullName: j['full_name'] ?? j['email'] ?? '',
        isEmailVerified: j['is_email_verified'] ?? false,
        dateJoined: j['date_joined'] ?? '',
        profile: j['profile'] != null ? UserProfile.fromJson(j['profile']) : null,
      );

  /// Decoded profile photo, or null.
  Uint8List? get avatarBytes {
    final d = profile?.avatarData ?? '';
    final i = d.indexOf('base64,');
    if (i < 0) return null;
    try {
      return base64Decode(d.substring(i + 7));
    } catch (_) {
      return null;
    }
  }

  String get displayName => fullName.isNotEmpty ? fullName : email;
  String get initials {
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '${firstName[0]}${lastName[0]}'.toUpperCase();
    }
    return email.isNotEmpty ? email[0].toUpperCase() : 'G';
  }
}
