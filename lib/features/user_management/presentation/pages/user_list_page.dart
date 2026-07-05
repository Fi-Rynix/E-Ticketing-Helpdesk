import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/data/models/user_model.dart';
import '../providers/user_provider.dart';

class UserListPage extends ConsumerStatefulWidget {
  const UserListPage({super.key});

  @override
  ConsumerState<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends ConsumerState<UserListPage> {
  String _selectedFilter = 'all';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleActive(AppUser user) async {
    final action = user.isActive ? 'Nonaktifkan' : 'Aktifkan';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$action ${user.username}?'),
        content: Text(
          user.isActive
              ? 'User yang dinonaktifkan tidak bisa login.'
              : 'User akan bisa login kembali.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: user.isActive ? Colors.red : Colors.green,
            ),
            child: Text(action),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(toggleUserActiveProvider({
          'idUser': user.idUser,
          'isActive': !user.isActive,
        }).future);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${user.username} berhasil di${user.isActive ? "nonaktifkan" : "aktifkan"}')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  void _editUser(AppUser user) async {
    final result = await showDialog<AppUser>(
      context: context,
      builder: (_) => _EditUserDialog(user: user),
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User ${result.username} berhasil diupdate')),
      );
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.purple;
      case 'helpdesk':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'helpdesk':
        return Icons.support_agent;
      default:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersByRoleProvider(_selectedFilter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Pengguna', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: const Color(0xFF000072),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Cari username...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
            ),
          ),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Semua',
                  isSelected: _selectedFilter == 'all',
                  onTap: () => setState(() => _selectedFilter = 'all'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'User',
                  isSelected: _selectedFilter == 'user',
                  onTap: () => setState(() => _selectedFilter = 'user'),
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Helpdesk',
                  isSelected: _selectedFilter == 'helpdesk',
                  onTap: () => setState(() => _selectedFilter = 'helpdesk'),
                  color: Colors.orange,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Admin',
                  isSelected: _selectedFilter == 'admin',
                  onTap: () => setState(() => _selectedFilter = 'admin'),
                  color: Colors.purple,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // User list
          Expanded(
            child: usersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (users) {
                final filtered = _searchQuery.isEmpty
                    ? users
                    : users.where((u) => u.username.toLowerCase().contains(_searchQuery)).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('Tidak ada user'));
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(usersByRoleProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final u = filtered[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: _getRoleColor(u.role).withOpacity(0.2),
                                child: Icon(_getRoleIcon(u.role), color: _getRoleColor(u.role), size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(u.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _getRoleColor(u.role).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            u.role.toUpperCase(),
                                            style: TextStyle(fontSize: 10, color: _getRoleColor(u.role), fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: u.isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                u.isActive ? Icons.check_circle : Icons.cancel,
                                                size: 10,
                                                color: u.isActive ? Colors.green : Colors.red,
                                              ),
                                              const SizedBox(width: 2),
                                              Text(
                                                u.isActive ? 'Aktif' : 'Nonaktif',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: u.isActive ? Colors.green : Colors.red,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'edit') _editUser(u);
                                  if (v == 'toggle') _toggleActive(u);
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit')])),
                                  PopupMenuItem(
                                    value: 'toggle',
                                    child: Row(
                                      children: [
                                        Icon(u.isActive ? Icons.block : Icons.check_circle, size: 18, color: u.isActive ? Colors.red : Colors.green),
                                        const SizedBox(width: 8),
                                        Text(u.isActive ? 'Nonaktifkan' : 'Aktifkan'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  const _FilterChip({required this.label, required this.isSelected, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF000072);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? c : Colors.transparent,
          border: Border.all(color: c),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(color: isSelected ? Colors.white : c, fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ),
    );
  }
}

class _EditUserDialog extends ConsumerStatefulWidget {
  final AppUser user;
  const _EditUserDialog({required this.user});

  @override
  ConsumerState<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends ConsumerState<_EditUserDialog> {
  late TextEditingController _usernameController;
  late String _selectedRole;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.user.username);
    _selectedRole = widget.user.role;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_usernameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Username tidak boleh kosong')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final updated = await ref.read(updateUserProvider({
        'idUser': widget.user.idUser,
        'username': _usernameController.text,
        'role': _selectedRole,
      }).future);

      if (!mounted) return;
      if (updated != null) {
        Navigator.pop(context, updated);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal update user')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit User'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Username',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedRole,
            decoration: const InputDecoration(
              labelText: 'Role',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'user', child: Text('User')),
              DropdownMenuItem(value: 'helpdesk', child: Text('Helpdesk')),
              DropdownMenuItem(value: 'admin', child: Text('Admin')),
            ],
            onChanged: (v) => setState(() => _selectedRole = v!),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: _isSubmitting ? null : () => Navigator.pop(context), child: const Text('Batal')),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _save,
          child: _isSubmitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Simpan'),
        ),
      ],
    );
  }
}