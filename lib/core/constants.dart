class AppConstants {
  static const String baseUrl = 'https://godfidentappbackend.onrender.com';
  static const String appName = 'Godfident';

  // Storage keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey = 'user_id';

  // Translations
  static const List<String> translations = ['KJV', 'NIV', 'ESV', 'NKJV', 'NLT'];

  // Prayer types
  static const List<String> prayerTypes = [
    'request',
    'praise',
    'intercession',
    'thanksgiving',
  ];

  // Highlight colors
  static const List<String> highlightColors = [
    'yellow',
    'green',
    'blue',
    'pink',
    'orange',
  ];
}
