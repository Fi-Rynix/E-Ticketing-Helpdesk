import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../auth/data/models/user_model.dart';

class UserRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// Get all users
  Future<List<AppUser>> getAllUsers() async {
    try {
      final response = await _client
          .from('users')
          .select()
          .order('created_at', ascending: false);
      return (response as List).map((json) => AppUser.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching users: $e');
      rethrow;
    }
  }

  /// Get users by role
  Future<List<AppUser>> getUsersByRole(String role) async {
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('role', role)
          .order('username', ascending: true);
      return (response as List).map((json) => AppUser.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching users by role: $e');
      rethrow;
    }
  }

  /// Update user (username, role, is_active)
  Future<AppUser?> updateUser({
    required int idUser,
    String? username,
    String? role,
    bool? isActive,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (username != null) updates['username'] = username;
      if (role != null) updates['role'] = role;
      if (isActive != null) updates['is_active'] = isActive;

      if (updates.isEmpty) return null;

      final response = await _client
          .from('users')
          .update(updates)
          .eq('id_user', idUser)
          .select()
          .maybeSingle();

      if (response == null) return null;
      return AppUser.fromJson(response);
    } catch (e) {
      print('Error updating user: $e');
      rethrow;
    }
  }

  /// Toggle user active status
  Future<AppUser?> toggleUserActive(int idUser, bool isActive) async {
    return updateUser(idUser: idUser, isActive: isActive);
  }

  /// Search users by username
  Future<List<AppUser>> searchUsers(String query) async {
    try {
      final response = await _client
          .from('users')
          .select()
          .ilike('username', '%$query%')
          .order('username', ascending: true);
      return (response as List).map((json) => AppUser.fromJson(json)).toList();
    } catch (e) {
      print('Error searching users: $e');
      rethrow;
    }
  }
}