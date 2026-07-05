import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../../data/models/dashboard_model.dart';
import '../../../../core/constants/app_constants.dart';

class DashboardAdminWidget extends ConsumerWidget {
  const DashboardAdminWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final dashboardStatsAsync = ref.watch(adminDashboardStatsProvider);

    ref.listen(adminDashboardStatsProvider, (previous, next) {});

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminDashboardStatsProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back,',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentUser?.username ?? 'Admin',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF000072).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'ADMIN',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF000072),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'System overview & analytics',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),

            // Quick action: User Management
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: InkWell(
                onTap: () => Navigator.of(context).pushNamed(AppConstants.routeUserManagement),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF000072).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF000072).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.people_alt_outlined, color: Color(0xFF000072)),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Kelola Pengguna', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            SizedBox(height: 2),
                            Text('Manage users, roles, & status', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Stats section
            dashboardStatsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Column(
                children: [
                  Text('Error: $error', style: TextStyle(color: Colors.red[400])),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(adminDashboardStatsProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
              data: (DashboardStats stats) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main stat - Large card
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: const Color(0xFF000072),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Tickets',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.8)),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  stats.totalTickets.toString(),
                                  style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -1),
                                ),
                              ],
                            ),
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.confirmation_number_outlined, size: 28, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Section title
                    Text(
                      'Status Breakdown',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[800]),
                    ),
                    const SizedBox(height: 16),

                    // Status cards
                    _StatusCard(
                      label: 'Open',
                      count: stats.openTickets,
                      icon: Icons.circle_outlined,
                      color: const Color(0xFFDC2626),
                    ),
                    const SizedBox(height: 12),
                    _StatusCard(
                      label: 'Assigned',
                      count: stats.assignedTickets,
                      icon: Icons.person_outline,
                      color: const Color(0xFFF97316),
                    ),
                    const SizedBox(height: 12),
                    _StatusCard(
                      label: 'In Progress',
                      count: stats.inProgressTickets,
                      icon: Icons.pending_outlined,
                      color: const Color(0xFF3B82F6),
                    ),
                    const SizedBox(height: 12),
                    _StatusCard(
                      label: 'Done',
                      count: stats.doneTickets,
                      icon: Icons.check_circle_outline,
                      color: const Color(0xFF10B981),
                    ),
                    const SizedBox(height: 12),
                    _StatusCard(
                      label: 'Cancelled',
                      count: stats.cancelledTickets,
                      icon: Icons.cancel_outlined,
                      color: const Color(0xFF6B7280),
                    ),
                    const SizedBox(height: 12),
                    _StatusCard(
                      label: 'Active Tickets',
                      count: stats.activeTickets,
                      icon: Icons.access_time,
                      color: const Color(0xFF8B5CF6),
                      isHighlighted: true,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final bool isHighlighted;

  const _StatusCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isHighlighted ? color.withOpacity(0.1) : (isDark ? const Color(0xFF2A2A2A) : Colors.white),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: isHighlighted ? Border.all(color: color) : Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: isHighlighted ? color : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            if (isHighlighted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'ACTIVE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
