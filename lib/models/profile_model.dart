// lib/models/profile_model.dart

class UserProfile {
  final String userUuid;
  final String username;
  final String email;
  String displayName;
  String? avatarUrl;

  UserProfile({
    required this.userUuid,
    required this.username,
    required this.email,
    required this.displayName,
    this.avatarUrl,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userUuid: json['user_uuid'],
      username: json['Username'],
      email: json['Email'],
      displayName: json['DisplayName'],
      avatarUrl: json['avatar_url'],
    );
  }
}
