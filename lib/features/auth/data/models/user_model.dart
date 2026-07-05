enum UserRole { user, admin, helpdesk }

class AppUser {
  final int idUser;
  final String authUserId;
  final String username;
  final String role; // Store as String, not enum
  final String? avatarUrl;
  final DateTime createdAt;
  final bool isActive;

  AppUser({
    required this.idUser,
    required this.authUserId,
    required this.username,
    required this.role,
    this.avatarUrl,
    required this.createdAt,
    this.isActive = true,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    // Parse role from string (handle PostgreSQL enum format)
    String roleStr = 'user';
    final rawRole = json['role'];
    if (rawRole != null) {
      // Handle both plain string and PostgreSQL enum format "user_role::user"
      roleStr = rawRole.toString().split('::').last.split("'").last;
    }

    return AppUser(
      idUser: json['id_user'] as int,
      authUserId: json['auth_user_id'] as String,
      username: json['username'] as String,
      role: roleStr,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_user': idUser,
      'auth_user_id': authUserId,
      'username': username,
      'role': role,
      'avatar_url': avatarUrl,
      'created_at': createdAt.toIso8601String(),
      'is_active': isActive,
    };
  }

  AppUser copyWith({
    int? idUser,
    String? authUserId,
    String? username,
    String? role,
    String? avatarUrl,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return AppUser(
      idUser: idUser ?? this.idUser,
      authUserId: authUserId ?? this.authUserId,
      username: username ?? this.username,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }

  bool get isAdmin => role == 'admin';
  bool get isHelpdesk => role == 'helpdesk';
  bool get isUser => role == 'user';
}