enum UserRole { user, admin, helpdesk }

class AppUser {
  final int idUser;
  final String authUserId;
  final String username;
  final UserRole role;
  final String? avatarUrl;
  final DateTime createdAt;

  AppUser({
    required this.idUser,
    required this.authUserId,
    required this.username,
    required this.role,
    this.avatarUrl,
    required this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      idUser: json['id_user'] as int,
      authUserId: json['auth_user_id'] as String,
      username: json['username'] as String,
      role: UserRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => UserRole.user,
      ),
      avatarUrl: json['avatar_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_user': idUser,
      'auth_user_id': authUserId,
      'username': username,
      'role': role.name,
      'avatar_url': avatarUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get roleString => role.name;
}
