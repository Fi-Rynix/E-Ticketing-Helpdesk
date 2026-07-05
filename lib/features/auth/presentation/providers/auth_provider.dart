import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';

final authRepositoryProvider = Provider((ref) => AuthRepository());

// Provider untuk track user yang sedang login
final currentUserProvider = StateProvider<AppUser?>((ref) => null);

// Credentials class untuk login
class LoginCredentials {
  final String email;
  final String password;

  LoginCredentials(this.email, this.password);
}

// Provider untuk login
final loginProvider = FutureProvider.family<AppUser?, LoginCredentials>((ref, credentials) async {
  final authRepo = ref.watch(authRepositoryProvider);
  final user = await authRepo.login(credentials.email, credentials.password);

  if (user != null) {
    ref.read(currentUserProvider.notifier).state = user;
  }

  return user;
});

// Provider untuk logout
final logoutProvider = FutureProvider((ref) async {
  final authRepo = ref.watch(authRepositoryProvider);
  await authRepo.logout();
  ref.read(currentUserProvider.notifier).state = null;
});

// Register credentials class
class RegisterCredentials {
  final String username;
  final String email;
  final String password;

  RegisterCredentials({
    required this.username,
    required this.email,
    required this.password,
  });
}

// Provider untuk register
final registerProvider = FutureProvider.family<AppUser?, RegisterCredentials>((ref, credentials) async {
  final authRepo = ref.watch(authRepositoryProvider);
  final user = await authRepo.register(
    credentials.email,
    credentials.password,
    credentials.username,
  );

  if (user != null) {
    // Auto-login setelah register
    ref.read(currentUserProvider.notifier).state = user;
  }

  return user;
});

// Provider untuk check apakah user sudah login
final isAuthenticatedProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user != null;
});

// Provider untuk role user saat ini
final userRoleProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.role;
});

// Provider untuk auth state listener
final authStateProvider = StreamProvider<AuthState>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.authStateChanges;
});

// Auto-restore session on app start
final initAuthProvider = FutureProvider<AppUser?>((ref) async {
  final authRepo = ref.watch(authRepositoryProvider);
  final session = authRepo.currentSession;

  if (session != null) {
    final user = await authRepo.getUserProfile(session.user.id);
    if (user != null) {
      ref.read(currentUserProvider.notifier).state = user;
    }
    return user;
  }

  return null;
});
