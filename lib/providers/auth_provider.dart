import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/secure_storage.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';

final authRepositoryProvider = Provider((_) => AuthRepository());

// Is the user logged in?
final authStateProvider = FutureProvider<bool>((ref) async {
  final token = await SecureStorage.getAccessToken();
  return token != null;
});

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
    _ref.invalidate(authStateProvider);
  }

  Future<void> logout() async {
    await _repo.logout();
    _ref.read(currentUserProvider.notifier).clear();
    _ref.invalidate(authStateProvider);
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
