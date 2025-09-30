// lib/providers/user_provider.dart
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/auth_service.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UserRole { normal, manager, doctor, mixed }

class UserProvider with ChangeNotifier {
  final fcm = FirebaseMessaging.instance;
  final AuthService _authService = AuthService();
  UserRole? _role;
  String? _userName;
  String? _userUuid;
  String? _errorMessage;

  UserRole? get userRole => _role;
  String? get userName => _userName;
  String? get userUuid => _userUuid;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _userUuid != null;


  Future<bool> tryAutoLogin() async {
    final userData = await _authService.verifyToken();
    if (userData != null) {
      _setUserData(userData);
      return true;
    }
    return false;
  }

  Future<void> logoutUser() async {
    await _authService.deleteToken();
    _userUuid = null;
    _userName = null;
    _role = null;
    notifyListeners();
  }


  Future<GoogleSignInAccount?> signInWithGoogleUI() async {
    _setError(null);
    try {
      return await _authService.signInWithGoogleUI();
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  Future<bool> loginUser(String email, String password) async {
    _setError(null);
    try {
      final userData = await _authService.login(email, password);
      _setUserData(userData);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  Future<bool> loginWithGoogle(String providerUserId) async {
    _setError(null);
    try {
      final userData = await _authService.loginWithGoogle(providerUserId);
      if (userData != null) {
        _setUserData(userData);
        return true;
      }
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  Future<bool> registerWithEmail({
    required String username,
    required String email,
    required String displayName,
    required String password,
    required String role,
  }) async {
    _setError(null);
    try {
      final responseData = await _authService.register(
        username: username,
        email: email,
        displayName: displayName,
        password: password,
        role: _getRoleId(role),
      );
      _setUserData(responseData['user']);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  Future<bool> completeGoogleRegistration({
    required GoogleSignInAccount googleUser,
    required String nickname,
    required String role,
  }) async {
    _setError(null);
    try {
      final userData = await _authService.registerWithGoogle(
        googleUser: googleUser,
        roleId: _getRoleId(role),
        username: nickname,
      );
      _setUserData(userData);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  void startAndSetupService(String userUuid) {
    final service = FlutterBackgroundService();
    service.invoke('setUserUuid', {'userUuid': userUuid});
  }


  void _setUserData(Map<String, dynamic> userData) {
    _userUuid = userData['user_uuid'];
    _userName = userData['displayName'];
    int roleId = userData['role'];
    switch (roleId) {
      case 1:
        _role = UserRole.normal;
        break;
      case 2:
        _role = UserRole.manager;
        break;
      case 3:
        _role = UserRole.doctor;
        break;
      case 4:
        _role = UserRole.mixed;
        break;
      default:
        _role = null;
    }
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error?.replaceFirst('Exception: ', '');
    notifyListeners();
  }

  int _getRoleId(String role) {
    const Map<String, int> roleMap = {
      'Normal': 1,
      'Manager': 2,
      'Doctor': 3,
      'Mixed': 4,
    };
    return roleMap[role]!;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_token');
    await prefs.remove('user_uuid');

    _userUuid = null;

    notifyListeners();
  }
}
