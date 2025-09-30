// lib/providers/profile_provider.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/profile_model.dart';
import '../services/profile_service.dart';

const String storageAccountName = "umizoomistorage";

class ProfileProvider with ChangeNotifier {
  final ProfileService _profileService = ProfileService();
  UserProfile? _userProfile;
  bool _isLoading = false;
  bool _isUploading = false;
  String? _errorMessage;

  UserProfile? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  String? get errorMessage => _errorMessage;
  String? _userUuid;
  ProfileProvider(this._userUuid);

  String? _addCacheBuster(String? url) {
    if (url == null || url.isEmpty) return null;
    return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  void updateUser(String? newUserUuid) {
    _userUuid = newUserUuid;
  }

  void clearProfile() {
    _userProfile = null;
    notifyListeners();
  }

  Future<void> loadProfile(String userUuid) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _userProfile = await _profileService.getProfile(userUuid);
      _userProfile?.avatarUrl = _addCacheBuster(_userProfile?.avatarUrl);
    } catch (e) {
      _errorMessage = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> updateDisplayName(String userUuid, String newName) async {
    if (_userProfile == null) return false;
    _isLoading = true;
    notifyListeners();
    try {
      final success = await _profileService.updateProfile(
        userUuid: userUuid,
        displayName: newName,
      );
      if (success) {
        _userProfile!.displayName = newName;
      }
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> uploadNewAvatar(String userUuid) async {
    _isUploading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final picker = ImagePicker();
      final imageFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
        maxWidth: 800,
      );
      if (imageFile == null) {
        _isUploading = false;
        notifyListeners();
        return false;
      }
      final Uint8List imageData = await imageFile.readAsBytes();

      final uploadData = await _profileService.getUploadUrl();
      if (uploadData == null) throw Exception('Could not get upload URL.');

      final uploadUrl = uploadData['uploadUrl']!;
      final blobName = uploadData['blobName']!;

      final uploadSuccess = await _profileService.uploadImageToAzure(
        uploadUrl,
        imageData,
      );
      if (!uploadSuccess) throw Exception('Failed to upload image.');

      final finalAvatarUrl =
          'https://$storageAccountName.blob.core.windows.net/avatars/$blobName';

      final dbSuccess = await _profileService.updateProfile(
        userUuid: userUuid,
        avatarUrl: finalAvatarUrl,
      );
      if (dbSuccess) {
        _userProfile!.avatarUrl = _addCacheBuster(finalAvatarUrl);
      }

      _isUploading = false;
      notifyListeners();
      return dbSuccess;
    } catch (e) {
      _errorMessage = e.toString();
      _isUploading = false;
      notifyListeners();
      return false;
    }
  }
}
