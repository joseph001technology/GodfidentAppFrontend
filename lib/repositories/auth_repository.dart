import 'package:dio/dio.dart';
import '../core/dio_client.dart';
import '../core/secure_storage.dart';
import '../models/user.dart';

class AuthRepository {
  final _dio = DioClient.instance;

  Future<Map<String, String>> login(String email, String password) async {
    final res = await _dio.post('/api/auth/login/', data: {
      'email': email,
      'password': password,
    });
    final access = res.data['access'] as String;
    final refresh = res.data['refresh'] as String;
    await SecureStorage.saveTokens(access: access, refresh: refresh);
    return {'access': access, 'refresh': refresh};
  }

  Future<User> register({
    required String email,
    required String password,
    required String passwordConfirm,
    String firstName = '',
    String lastName = '',
  }) async {
    final res = await _dio.post('/api/auth/register/', data: {
      'email': email,
      'password': password,
      'password_confirm': passwordConfirm,
      if (firstName.isNotEmpty) 'first_name': firstName,
      if (lastName.isNotEmpty) 'last_name': lastName,
    });
    return User.fromJson(res.data['user']);
  }

  Future<void> verifyEmail(String token) async {
    await _dio.post('/api/auth/verify-email/', data: {'token': token});
  }

  Future<void> resendVerification() async {
    await _dio.post('/api/auth/resend-verification/');
  }

  Future<void> forgotPassword(String email) async {
    await _dio.post('/api/auth/forgot-password/', data: {'email': email});
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
    required String newPasswordConfirm,
  }) async {
    await _dio.post('/api/auth/reset-password/', data: {
      'token': token,
      'new_password': newPassword,
      'new_password_confirm': newPasswordConfirm,
    });
  }

  Future<User> getMe() async {
    final res = await _dio.get('/api/auth/me/');
    return User.fromJson(res.data);
  }

  Future<User> updateMe({String? firstName, String? lastName}) async {
    final res = await _dio.patch('/api/auth/me/', data: {
      if (firstName != null) 'first_name': firstName,
      if (lastName != null) 'last_name': lastName,
    });
    return User.fromJson(res.data);
  }

  Future<UserProfile> getProfile() async {
    final res = await _dio.get('/api/auth/profile/');
    return UserProfile.fromJson(res.data);
  }

  Future<UserProfile> updateProfile(Map<String, dynamic> data) async {
    final res = await _dio.patch('/api/auth/profile/', data: data);
    return UserProfile.fromJson(res.data);
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
    required String newPasswordConfirm,
  }) async {
    await _dio.post('/api/auth/change-password/', data: {
      'old_password': oldPassword,
      'new_password': newPassword,
      'new_password_confirm': newPasswordConfirm,
    });
  }

  Future<void> logout() async {
    await SecureStorage.clearAll();
  }
}
