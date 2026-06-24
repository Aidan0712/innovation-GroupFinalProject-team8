import 'dart:convert';

class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.email,
    required this.avatarUrl,
    required this.role,
    required this.createdAt,
  });

  final int id;
  final String username;
  final String? email;
  final String? avatarUrl;
  final String role;
  final DateTime createdAt;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      username: json['username'] as String? ?? '',
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String? ?? json['avatar'] as String?,
      role: json['role'] as String? ?? 'user',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'username': username,
      'email': email,
      'avatar_url': avatarUrl,
      'role': role,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String toJsonString() => jsonEncode(toJson());

  static AppUser? fromJsonString(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return AppUser.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }
}
