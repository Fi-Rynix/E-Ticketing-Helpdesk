import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/data/models/user_model.dart';
import '../../data/repositories/user_repository.dart';

/// Repository provider
final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

/// All users provider
final allUsersProvider = FutureProvider<List<AppUser>>((ref) async {
  final repo = ref.watch(userRepositoryProvider);
  return repo.getAllUsers();
});

/// Users by role provider
final usersByRoleProvider =
    FutureProvider.family<List<AppUser>, String>((ref, role) async {
  final repo = ref.watch(userRepositoryProvider);
  if (role == 'all') return repo.getAllUsers();
  return repo.getUsersByRole(role);
});

/// Search users provider
final searchUsersProvider =
    FutureProvider.family<List<AppUser>, String>((ref, query) async {
  final repo = ref.watch(userRepositoryProvider);
  if (query.isEmpty) return repo.getAllUsers();
  return repo.searchUsers(query);
});

/// Update user provider
final updateUserProvider =
    FutureProvider.family<AppUser?, Map<String, dynamic>>((ref, params) async {
  final repo = ref.watch(userRepositoryProvider);
  final updated = await repo.updateUser(
    idUser: params['idUser'] as int,
    username: params['username'] as String?,
    role: params['role'] as String?,
    isActive: params['isActive'] as bool?,
  );
  // Refresh all user providers
  ref.invalidate(allUsersProvider);
  ref.invalidate(usersByRoleProvider);
  return updated;
});

/// Toggle active provider
final toggleUserActiveProvider =
    FutureProvider.family<AppUser?, Map<String, dynamic>>((ref, params) async {
  final repo = ref.watch(userRepositoryProvider);
  final updated = await repo.toggleUserActive(
    params['idUser'] as int,
    params['isActive'] as bool,
  );
  ref.invalidate(allUsersProvider);
  ref.invalidate(usersByRoleProvider);
  return updated;
});