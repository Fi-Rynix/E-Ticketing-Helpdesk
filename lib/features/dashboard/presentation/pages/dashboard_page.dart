import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/dashboard_user_widget.dart';
import '../widgets/dashboard_admin_widget.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);

    if (currentUser == null) {
      return const Center(child: Text('Not authenticated'));
    }

    // Trigger fetch stats when user changes
    if (currentUser.role == 'admin') {
      ref.listen(adminDashboardStatsProvider, (previous, next) {});
    } else {
      ref.listen(userDashboardStatsProvider(currentUser.username), (previous, next) {});
    }

    return currentUser.role == 'admin'
        ? const DashboardAdminWidget()
        : const DashboardUserWidget();
  }
}
