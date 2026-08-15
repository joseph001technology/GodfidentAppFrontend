import 'dart:async';

/// Global event broadcaster for authentication events (e.g. token expiration).
class AuthEventService {
  static final AuthEventService _instance = AuthEventService._();
  factory AuthEventService() => _instance;
  AuthEventService._();

  final _unauthorizedController = StreamController<String>.broadcast();

  /// Stream emitting events whenever a 401 occurs and token cannot be refreshed.
  Stream<String> get onUnauthorized => _unauthorizedController.stream;

  /// Notify all listeners that the current user token has expired / is unauthorized.
  void notifyUnauthorized([String message = 'Your session has expired. Please sign in again.']) {
    _unauthorizedController.add(message);
  }
}
