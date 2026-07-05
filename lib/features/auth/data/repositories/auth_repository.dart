import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

class AuthRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// Login dengan email dan password via Supabase Auth
  /// Returns AppUser profile jika login berhasil, null jika gagal
  Future<AppUser?> login(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user == null) return null;

    // Fetch user profile dari tabel users
    final profile = await getUserProfile(response.user!.id);
    return profile;
  }

  /// Get user profile dari Supabase berdasarkan auth_user_id
  Future<AppUser?> getUserProfile(String authUserId) async {
    final response = await _client
        .from('users')
        .select()
        .eq('auth_user_id', authUserId)
        .maybeSingle();

    if (response == null) return null;
    return AppUser.fromJson(response);
  }

  /// Register user baru
  Future<AppUser?> register(String email, String password, String username) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'username': username},
    );

    if (response.user == null) return null;

    // Fetch profile yang baru dibuat via trigger
    return getUserProfile(response.user!.id);
  }

  /// Logout
  Future<void> logout() async {
    await _client.auth.signOut();
  }

  /// Reset password - kirim email dengan link reset ke user
  /// Returns true jika berhasil (email valid), false jika gagal
  Future<bool> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'utsmobile://reset-callback',
      );
      return true;
    } on AuthException catch (e) {
      print('Reset password error: ${e.message}');
      return false;
    } catch (e) {
      print('Unexpected error: $e');
      return false;
    }
  }

  /// Update password untuk user yang sedang login (setelah klik link reset)
  Future<bool> updatePassword(String newPassword) async {
    try {
      final response = await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return response.user != null;
    } catch (e) {
      print('Update password error: $e');
      return false;
    }
  }

  /// Get current session
  Session? get currentSession => _client.auth.currentSession;

  /// Get current user
  User? get currentAuthUser => _client.auth.currentUser;

  /// Listen to auth state changes
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}
