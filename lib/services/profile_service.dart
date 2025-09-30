// lib/services/profile_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/profile_model.dart';
import '../utils/constants.dart';

class ProfileService {
  final String _apiUrl = '$kBaseUrl/api';

  Future<UserProfile> getProfile(String userUuid) async {
    final response = await http.get(Uri.parse('$_apiUrl/profile/$userUuid'));
    if (response.statusCode == 200) {
      return UserProfile.fromJson(jsonDecode(response.body)['profile']);
    } else {
      throw Exception('Failed to load profile.');
    }
  }

  Future<bool> updateProfile({
    required String userUuid,
    String? displayName,
    String? avatarUrl,
  }) async {
    final response = await http.patch(
      Uri.parse('$_apiUrl/profile/$userUuid'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'displayName': displayName, 'avatarUrl': avatarUrl}),
    );
    return response.statusCode == 200;
  }

  Future<Map<String, String>?> getUploadUrl() async {
    final response = await http.get(
      Uri.parse('$_apiUrl/profile/avatar/upload-url'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {'uploadUrl': data['uploadUrl'], 'blobName': data['blobName']};
    }
    return null;
  }

  Future<bool> uploadImageToAzure(String uploadUrl, Uint8List imageData) async {
    final response = await http.put(
      Uri.parse(uploadUrl),
      headers: {'x-ms-blob-type': 'BlockBlob', 'Content-Type': 'image/jpeg'},
      body: imageData,
    );
    return response.statusCode == 201;
  }
}
