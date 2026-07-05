import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/settings_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final darkMode = ref.watch(darkModeProvider);
    final notificationsEnabled = ref.watch(notificationsEnabledProvider);
    final soundEnabled = ref.watch(soundEnabledProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pengaturan',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF000072),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionTitle(icon: Icons.palette_outlined, title: 'Tampilan'),
          _SettingsCard(
            children: [
              _SettingTile(
                icon: Icons.dark_mode_outlined,
                title: 'Mode Gelap',
                subtitle: darkMode ? 'Aktif' : 'Nonaktif',
                trailing: Switch(
                  value: darkMode,
                  activeColor: const Color(0xFF000072),
                  onChanged: (value) {
                    ref.read(darkModeProvider.notifier).setDarkMode(value);
                    ref.read(themeModeProvider.notifier).toggleTheme();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          _SectionTitle(icon: Icons.notifications_outlined, title: 'Notifikasi'),
          _SettingsCard(
            children: [
              _SettingTile(
                icon: Icons.notifications_active_outlined,
                title: 'Notifikasi',
                subtitle: notificationsEnabled ? 'Aktif' : 'Nonaktif',
                trailing: Switch(
                  value: notificationsEnabled,
                  activeColor: const Color(0xFF000072),
                  onChanged: (value) {
                    ref.read(notificationsEnabledProvider.notifier).setNotificationsEnabled(value);
                  },
                ),
              ),
              const Divider(height: 1, indent: 60),
              _SettingTile(
                icon: Icons.volume_up_outlined,
                title: 'Suara',
                subtitle: soundEnabled ? 'Aktif' : 'Nonaktif',
                trailing: Switch(
                  value: soundEnabled,
                  activeColor: const Color(0xFF000072),
                  onChanged: (value) {
                    ref.read(soundEnabledProvider.notifier).setSoundEnabled(value);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF000072)),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: Color(0xFF000072),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).cardColor,
      child: Column(children: children),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget trailing;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.trailing,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF000072).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF000072), size: 22),
      ),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: subtitle != null
          ? Text(subtitle!, style: TextStyle(fontSize: 12, color: AppTheme.textSubtle(context)))
          : null,
      trailing: trailing,
    );
  }
}