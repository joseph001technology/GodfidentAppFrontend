/// Usage Stats Service - Abstraction for per-app screen time tracking
///
/// This requires device-level usage data:
/// - Android: UsageStatsManager requires user-granted Usage Access permission
/// - iOS: No equivalent API exists for third-party apps
///
/// TODO: Implement Android version using usage_stats package
/// behind a feature flag. Push collected data to
/// POST /api/analytics/log-usage/ when available.
///
/// Until implemented, show honest "grant permission" empty state.
library;

class AppUsageRecord {
  final String appName;
  final String packageName;
  final int usageMinutes;
  final double usagePercent;

  const AppUsageRecord({
    required this.appName,
    required this.packageName,
    this.usageMinutes = 0,
    this.usagePercent = 0.0,
  });
}

abstract class UsageStatsService {
  bool get isPermissionGranted;
  Future<bool> requestPermission();
  Future<List<AppUsageRecord>> getDailyUsage({DateTime? date});
  Future<int> getTotalScreenTimeMinutes({DateTime? date});
  Future<bool> logUsageToServer(List<AppUsageRecord> records);
}

/// Placeholder implementation - returns empty/sample data
/// Replace with real UsageStatsManager integration
class PlaceholderUsageStatsService implements UsageStatsService {
  @override
  bool get isPermissionGranted => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<List<AppUsageRecord>> getDailyUsage({DateTime? date}) async => [];

  @override
  Future<int> getTotalScreenTimeMinutes({DateTime? date}) async => 0;

  @override
  Future<bool> logUsageToServer(List<AppUsageRecord> records) async => false;
}
