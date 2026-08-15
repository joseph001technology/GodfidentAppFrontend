import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/secure_storage.dart';
import '../core/auth_event_service.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';

final authRepositoryProvider = Provider((_) => AuthRepository());

final sessionExpiredMessageProvider = StateProvider<String?>((ref) => null);

// Is the user logged in?
final authStateProvider = StateNotifierProvider<AuthStateNotifier, AsyncValue<bool>>((ref) {
  return AuthStateNotifier(ref);
});

class AuthStateNotifier extends StateNotifier<AsyncValue<bool>> {
  final Ref _ref;
  StreamSubscription? _unauthorizedSub;

  AuthStateNotifier(this._ref) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    _unauthorizedSub = AuthEventService().onUnauthorized.listen((msg) {
      _ref.read(sessionExpiredMessageProvider.notifier).state = msg;
      setUnauthenticated();
    });
    await checkAuth();
  }

  Future<void> checkAuth() async {
    final token = await SecureStorage.getAccessToken();
    state = AsyncValue.data(token != null);
  }

  void setUnauthenticated() {
    state = const AsyncValue.data(false);
    _ref.read(currentUserProvider.notifier).clear();
  }

  @override
  void dispose() {
    _unauthorizedSub?.cancel();
    super.dispose();
  }
}

// Current user object
final currentUserProvider = StateNotifierProvider<CurrentUserNotifier, AsyncValue<User?>>((ref) {
  return CurrentUserNotifier(ref.read(authRepositoryProvider));
});

class CurrentUserNotifier extends StateNotifier<AsyncValue<User?>> {
  final AuthRepository _repo;
  CurrentUserNotifier(this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    try {
      final user = await _repo.getMe();
      state = AsyncValue.data(user);
    } catch (_) {
      state = const AsyncValue.data(null);
    }
  }

  Future<void> refresh() => load();

  void clear() => state = const AsyncValue.data(null);
}

// Auth actions notifier
final authActionProvider = Provider((ref) => AuthActions(ref));

class AuthActions {
  final Ref _ref;
  AuthActions(this._ref);

  AuthRepository get _repo => _ref.read(authRepositoryProvider);

  Future<void> login(String email, String password) async {
    await _repo.login(email, password);
    await _ref.read(currentUserProvider.notifier).load();
    await _ref.read(authStateProvider.notifier).checkAuth();
  }

  Future<void> logout() async {
    await _repo.logout();
    _ref.read(authStateProvider.notifier).setUnauthenticated();
  }

  Future<void> register({
    required String email,
    required String password,
    required String passwordConfirm,
    String firstName = '',
    String lastName = '',
  }) async {
    await _repo.register(
      email: email,
      password: password,
      passwordConfirm: passwordConfirm,
      firstName: firstName,
      lastName: lastName,
    );
  }
}
