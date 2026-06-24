import '../../../core/constants/app_constants.dart';
import '../../../core/models/app_user.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/local_storage_service.dart';
import 'package:flutter/foundation.dart';

class AuthProvider extends ChangeNotifier {
  final LocalStorageService _storage = LocalStorageService.instance;
  final ApiClient _api = ApiClient.instance;

  AppUser? _user;
  bool _isLoading = false;
  bool _isReady = false;

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  bool get isReady => _isReady;
  bool get isAuthenticated =>
      (_storage.getString(AppConstants.accessTokenKey)?.isNotEmpty ?? false) &&
      _user != null;

  void restoreSession() {
    final cachedUser = AppUser.fromJsonString(
      _storage.getString(AppConstants.userKey),
    );
    _user = cachedUser;
    _isReady = true;
    notifyListeners();
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    _setLoading(true);
    try {
      final response = await _api.postJson(
        '/api/v1/auth/login',
        authenticated: false,
        body: <String, dynamic>{
          'username': username,
          'password': password,
        },
      );
      final data = response['data'] as Map<String, dynamic>;
      final user = AppUser.fromJson(data['user'] as Map<String, dynamic>);
      await _persistSession(
        accessToken: data['access_token'] as String? ?? '',
        refreshToken: data['refresh_token'] as String? ?? '',
        user: user,
      );
    } finally {
      _setLoading(false);
    }
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    try {
      await _api.postJson(
        '/api/v1/auth/register',
        authenticated: false,
        body: <String, dynamic>{
          'username': username,
          'email': email,
          'password': password,
        },
      );
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    _user = null;
    await _storage.remove(AppConstants.accessTokenKey);
    await _storage.remove(AppConstants.refreshTokenKey);
    await _storage.remove(AppConstants.userKey);
    notifyListeners();
  }

  Future<void> _persistSession({
    required String accessToken,
    required String refreshToken,
    required AppUser user,
  }) async {
    await _storage.setString(AppConstants.accessTokenKey, accessToken);
    await _storage.setString(AppConstants.refreshTokenKey, refreshToken);
    await _storage.setString(AppConstants.userKey, user.toJsonString());
    _user = user;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
