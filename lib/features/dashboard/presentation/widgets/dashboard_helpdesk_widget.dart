import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../ticket/presentation/providers/ticket_provider.dart';
import '../../../ticket/presentation/providers/helpdesk_provider.dart';
import '../../data/models/dashboard_model.dart';

class DashboardHelpdeskWidget extends ConsumerWidget {
  const DashboardHelpdeskWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final helpdeskAsync = ref.watch(helpdeskByUserProvider(currentUser?.idUser ?? 0));
    final ticketsAsync = ref.watch(fetchAllTicketsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(fetchAllTicketsProvider);
        ref.invalidate(helpdeskByUserProvider(currentUser?.idUser ?? 0));
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
                        currentUser?.username ?? 'Helpdesk',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                      ),
                    ],
                  ),
                ),
                helpdeskAsync.when(
                  data: (helpdesk) {
                    if (helpdesk == null) return const SizedBox();
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: helpdesk.isAvailable ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            helpdesk.isAvailable ? Icons.check_circle : Icons.cancel,
                            size: 14,
                            color: helpdesk.isAvailable ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            helpdesk.isAvailable ? 'Available' : 'Busy',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: helpdesk.isAvailable ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF000072).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'HELPDESK',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF000072),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your assigned tickets overview',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 32),

            // Toggle availability
            helpdeskAsync.when(
              data: (helpdesk) {
                if (helpdesk == null) return const SizedBox();
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  color: helpdesk.isAvailable ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                  child: InkWell(
                    onTap: () async {
                      final repo = ref.read(helpdeskRepositoryProvider);
                      await repo.toggleAvailability(
                        idHelpdesk: helpdesk.idHelpdesk,
                        isAvailable: !helpdesk.isAvailable,
                      );
                      ref.invalidate(helpdeskByUserProvider(currentUser?.idUser ?? 0));
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: helpdesk.isAvailable ? Colors.green : Colors.grey,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              helpdesk.isAvailable ? Icons.check : Icons.pause,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  helpdesk.isAvailable ? 'You are Available' : 'You are Unavailable',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tap to toggle status',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.swap_horiz, color: Colors.grey[400]),
                        ],
                      ),
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox(),
            ),
            const SizedBox(height: 24),

            // Stats
            ticketsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text('Error: $error'),
              data: (allTickets) {
                // Filter tickets assigned to this helpdesk
                final helpdesk = helpdeskAsync.valueOrNull;
                if (helpdesk == null) return const SizedBox();

                final assignedTickets = allTickets.where((t) => t.idHelpdesk == helpdesk.idHelpdesk).toList();
                final open = assignedTickets.where((t) => t.status.value == 'assigned').length;
                final inProgress = assignedTickets.where((t) => t.status.value == 'in_progress').length;
                final pending = assignedTickets.where((t) => t.status.value == 'pending_unassign').length;
                final done = assignedTickets.where((t) => t.status.value == 'done').length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Workload',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[800]),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: 'Assigned',
                            value: open.toString(),
                            icon: Icons.assignment_ind,
                            color: const Color(0xFF000072),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            title: 'In Progress',
                            value: inProgress.toString(),
                            icon: Icons.pending_actions,
                            color: const Color(0xFF1E40AF),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: 'Pending',
                            value: pending.toString(),
                            icon: Icons.hourglass_empty,
                            color: const Color(0xFF3B82F6),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            title: 'Done',
                            value: done.toString(),
                            icon: Icons.task_alt,
                            color: const Color(0xFF60A5FA),
                          ),
                        ),
                      ],
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

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
