import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/dashboard_user_widget.dart';
import '../widgets/dashboard_admin_widget.dart';
import '../widgets/dashboard_helpdesk_widget.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);

    if (currentUser == null) {
      return const Center(child: Text('Not authenticated'));
    }

    // Trigger refresh when user changes
    if (currentUser.role.name == 'admin') {
      ref.listen(adminDashboardStatsProvider, (previous, next) {});
    } else {
      ref.listen(userDashboardStatsProvider(currentUser.idUser), (previous, next) {});
    }

    // Return widget based on role
    switch (currentUser.role.name) {
      case 'admin':
        return const DashboardAdminWidget();
      case 'helpdesk':
        return const DashboardHelpdeskWidget();
      case 'user':
      default:
        return const DashboardUserWidget();
    }
  }
}
