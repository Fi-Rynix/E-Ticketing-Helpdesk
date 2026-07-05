import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  File? _selectedImage;
  String? _currentAvatarUrl;
  bool _isUploading = false;
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _currentAvatarUrl = ref.read(currentUserProvider)?.avatarUrl;
  }

  Future<void> _pickImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() => _selectedImage = File(image.path));
    }
  }

  Future<void> _saveAvatar() async {
    if (_selectedImage == null) return;
    setState(() => _isUploading = true);

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;

      // Upload to Supabase Storage
      final fileName = 'avatar_${user.idUser}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storagePath = 'avatars/$fileName';

      final supabase = Supabase.instance.client;
      await supabase.storage.from('avatars').upload(storagePath, _selectedImage!);
      final publicUrl = supabase.storage.from('avatars').getPublicUrl(storagePath);

      // Update users.avatar_url
      await supabase
          .from('users')
          .update({'avatar_url': publicUrl})
          .eq('id_user', user.idUser);

      // Update current user provider
      final updatedUser = user.copyWith(avatarUrl: publicUrl);
      ref.read(currentUserProvider.notifier).state = updatedUser;

      setState(() {
        _currentAvatarUrl = publicUrl;
        _selectedImage = null;
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto profil berhasil diperbarui')),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal upload: $e')),
        );
      }
    }
  }

  void _cancelSelection() {
    setState(() => _selectedImage = null);
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return const Color(0xFF000072);
      case 'helpdesk':
        return const Color(0xFFF97316);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'admin':
        return 'Administrator';
      case 'helpdesk':
        return 'Helpdesk';
      default:
        return 'Pengguna';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    if (currentUser == null) {
      return const Center(child: Text('Not authenticated'));
    }

    final ImageProvider? avatarSource = _selectedImage != null
        ? FileImage(_selectedImage!)
        : (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty
            ? NetworkImage(_currentAvatarUrl!)
            : null);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          // Refresh user data from server
          final authRepo = ref.read(authRepositoryProvider);
          final fresh = await authRepo.getUserProfile(currentUser.authUserId);
          if (fresh != null) {
            ref.read(currentUserProvider.notifier).state = fresh;
            setState(() => _currentAvatarUrl = fresh.avatarUrl);
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 16),
              // Avatar section
              _buildAvatarSection(avatarSource, currentUser),
              const SizedBox(height: 12),
              // User info
              Text(
                currentUser.username,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getRoleColor(currentUser.role).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getRoleDisplayName(currentUser.role),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _getRoleColor(currentUser.role),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Menu items
              _MenuCard(
                items: [
                  _MenuItem(
                    icon: Icons.tune,
                    label: 'Pengaturan',
                    subtitle: 'Appearance, notifikasi',
                    onTap: () => Navigator.of(context).pushNamed(AppConstants.routeSettings),
                  ),
                  _MenuItem(
                    icon: Icons.info_outline,
                    label: 'Tentang Aplikasi',
                    subtitle: 'Versi 1.0.0',
                    onTap: () => _showAboutDialog(context),
                  ),
                  _MenuItem(
                    icon: Icons.logout,
                    label: 'Keluar',
                    subtitle: 'Logout dari akun',
                    isDestructive: true,
                    onTap: () => _handleLogout(context),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection(ImageProvider? source, AppUser user) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _getRoleColor(user.role).withValues(alpha: 0.1),
            border: Border.all(color: _getRoleColor(user.role), width: 3),
            image: source != null
                ? DecorationImage(image: source, fit: BoxFit.cover)
                : null,
          ),
          child: source == null
              ? Center(
                  child: Text(
                    user.username[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: _getRoleColor(user.role),
                    ),
                  ),
                )
              : null,
        ),
        if (_selectedImage == null)
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF000072),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
            ),
          ),
      ],
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tentang Aplikasi'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('E-Ticketing Helpdesk', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('Versi 1.0.0'),
            SizedBox(height: 12),
            Text('Aplikasi helpdesk untuk mengelola tiket gangguan internal dengan 3 role: pengguna, helpdesk, dan admin.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
        ],
      ),
    );
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Logout'),
        content: const Text('Yakin ingin keluar dari akun?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              ref.read(logoutProvider);
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final List<_MenuItem> items;
  const _MenuCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).cardColor,
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            items[i],
            if (i < items.length - 1) const Divider(height: 1, indent: 60),
          ],
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red : const Color(0xFF000072);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDestructive ? Colors.red : null,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle!, style: TextStyle(fontSize: 12, color: AppTheme.textSubtle(context)))
          : null,
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}