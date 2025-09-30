// lib/services/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../utils/constants.dart';

class AuthService {
  final String _apiUrl = '$kBaseUrl/api/auth';
  final String _apiFCM = '$kBaseUrl/api/fcm';
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId:
        '1053674822608-2h4s7ph7mp5k9drdhqbphvftqcnnro3n.apps.googleusercontent.com',
  );

  Future<void> setupFirebaseMessaging() async {
    if (kIsWeb) return;
    final fcm = FirebaseMessaging.instance;
    await fcm.requestPermission();
    final token = await fcm.getToken();
    print("FCM Token: $token");
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
      }
    });
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<void> deleteToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }

  Future<Map<String, dynamic>?> verifyToken() async {
    final token = await getToken();
    if (token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$_apiUrl/verify'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body)['user'];
        await updateFCMToken(userData['user_uuid']);
        print("User data: $userData");
        return userData;
      } else {
        await deleteToken();
        return null;
      }
    } catch (e) {
      print("Error verifying token: $e");
      await deleteToken();
      return null;
    }
  }

  Future<void> updateFCMToken(String userUuid) async {
    if (kIsWeb) {
      print("FCM is not supported on web, skipping token update.");
      return;
    }
    final jwt = await getToken();
    if (jwt == null) return;

    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken == null) return;

    try {
      await http.post(
        Uri.parse('$_apiFCM/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwt',
        },
        body: jsonEncode({'user_uuid': userUuid, 'fcmToken': fcmToken}),
      );
      print("✅ FCM Token updated on server.");
    } catch (e) {
      print("❌ Failed to update FCM token: $e");
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_apiUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final responseBody = jsonDecode(response.body);
    if (response.statusCode == 200 && responseBody['success'] == true) {
      await saveToken(responseBody['token']);
      await updateFCMToken(responseBody['user']['user_uuid']);
      return responseBody['user'];
    } else {
      throw Exception(responseBody['message'] ?? 'Login failed.');
    }
  }

  Future<Map<String, dynamic>?> loginWithGoogle(String providerUserId) async {
    final response = await http.post(
      Uri.parse('$_apiUrl/google-login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'providerUserId': providerUserId}),
    );
    if (response.statusCode == 200) {
      final responseBody = jsonDecode(response.body);
      await saveToken(responseBody['token']);
      await updateFCMToken(responseBody['user']['user_uuid']);
      return responseBody['user'];
    }
    return null;
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String displayName,
    required String password,
    required int role,
  }) async {
    String? fcmToken;
    if (!kIsWeb) {
      fcmToken = await FirebaseMessaging.instance.getToken();
    }
    final response = await http.post(
      Uri.parse('$_apiUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'displayName': displayName,
        'password': password,
        'role': role,
        'fcmToken': fcmToken,
      }),
    );
    final responseBody = jsonDecode(response.body);
    if (response.statusCode == 201) {
      await saveToken(responseBody['token']);
      return responseBody;
    } else {
      throw Exception(responseBody['message'] ?? 'Registration failed.');
    }
  }

  Future<Map<String, dynamic>> registerWithGoogle({
    required GoogleSignInAccount googleUser,
    required int roleId,
    required String username,
  }) async {
    String? fcmToken;
    if (!kIsWeb) {
      fcmToken = await FirebaseMessaging.instance.getToken();
    }
    final response = await http.post(
      Uri.parse('$_apiUrl/google-register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': googleUser.email,
        'displayName': googleUser.displayName,
        'providerUserId': googleUser.id,
        'role': roleId,
        'username': username,
        'fcmToken': fcmToken,
      }),
    );
    final responseBody = jsonDecode(response.body);
    if (response.statusCode == 201 || response.statusCode == 200) {
      await saveToken(responseBody['token']);
      return responseBody['user'];
    } else {
      throw Exception(responseBody['message'] ?? 'Google Registration failed.');
    }
  }

  Future<GoogleSignInAccount?> signInWithGoogleUI() async {
    try {
      return await _googleSignIn.signIn();
    } catch (error) {
      print('Error during Google Sign-In UI: $error');
      return null;
    }
  }

  Future<bool> isUsernameTaken(String username) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiUrl/check-username/$username'),
      );
      return response.statusCode == 200 && jsonDecode(response.body)['isTaken'];
    } catch (e) {
      return false;
    }
  }
}
