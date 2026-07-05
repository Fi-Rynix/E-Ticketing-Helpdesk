import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/ticket_model.dart';
import '../../data/repositories/ticket_log_repository.dart';
import '../providers/tracking_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class TrackingTicketPage extends ConsumerWidget {
  final Ticket ticket;

  const TrackingTicketPage({super.key, required this.ticket});

  String _getStatusLabel(TicketStatus status) {
    switch (status) {
      case TicketStatus.open:
        return 'OPEN';
      case TicketStatus.assigned:
        return 'ASSIGNED';
      case TicketStatus.inProgress:
        return 'IN PROGRESS';
      case TicketStatus.pendingUnassign:
        return 'PENDING UNASSIGN';
      case TicketStatus.done:
        return 'DONE';
      case TicketStatus.cancelled:
        return 'CANCELLED';
    }
  }

  Color _getStatusColor(TicketStatus status) {
    switch (status) {
      case TicketStatus.open:
        return const Color(0xFF000072);
      case TicketStatus.assigned:
        return const Color(0xFF1E40AF);
      case TicketStatus.inProgress:
        return const Color(0xFF3B82F6);
      case TicketStatus.pendingUnassign:
        return const Color(0xFF60A5FA);
      case TicketStatus.done:
        return const Color(0xFF10B981);
      case TicketStatus.cancelled:
        return const Color(0xFF6B7280);
    }
  }

  IconData _getEventIcon(String eventType) {
    if (eventType.startsWith('ticket.created')) return Icons.add_circle_outline;
    if (eventType.startsWith('ticket.assigned')) return Icons.assignment_ind;
    if (eventType.startsWith('ticket.unassigned')) return Icons.assignment_returned;
    if (eventType.startsWith('ticket.unassign')) return Icons.exit_to_app;
    if (eventType.startsWith('ticket.cancelled')) return Icons.cancel;
    if (eventType.startsWith('ticket.photo_updated')) return Icons.image;
    if (eventType.startsWith('ticket.completed')) return Icons.check_circle;
    if (eventType.startsWith('ticket.status_changed')) return Icons.swap_horiz;
    if (eventType.startsWith('ticket.updated')) return Icons.edit;
    if (eventType.startsWith('comment.')) return Icons.comment_outlined;
    return Icons.history;
  }

  Color _getEventColor(String eventType) {
    if (eventType.contains('created')) return Colors.blue;
    if (eventType.contains('assigned') || eventType.contains('reassigned')) return Colors.orange;
    if (eventType.contains('completed')) return Colors.green;
    if (eventType.contains('cancelled')) return Colors.grey;
    if (eventType.contains('unassign')) return Colors.purple;
    if (eventType.startsWith('comment.')) return Colors.teal;
    return Colors.indigo;
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _getRelativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
    if (diff.inHours < 24) return '${diff.inHours}j lalu';
    if (diff.inDays < 7) return '${diff.inDays}h lalu';
    return _formatDateTime(dt);
  }

  /// Detect if a payload entry is an image URL worth rendering as image
  bool _isImageUrl(String key, String value) {
    if (!value.startsWith('http')) return false;
    final lowerKey = key.toLowerCase();
    return lowerKey.contains('photo') ||
        lowerKey.contains('image') ||
        lowerKey.contains('attachment') ||
        lowerKey.contains('avatar');
  }

  /// Show full-screen image viewer
  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(
                imageUrl,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image,
                  color: Colors.white,
                  size: 64,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(ticketLogsProvider(ticket.idTicket));
    final filter = ref.watch(dateFilterProvider);
    final repo = ref.watch(ticketLogRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Tracking #${ticket.idTicket}', style: const TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: const Color(0xFF000072),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Header info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ticket.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(ticket.status),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getStatusLabel(ticket.status),
                        style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (ticket.creatorUsername != null)
                      Text('oleh: ${ticket.creatorUsername}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),

          // Date filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Text('Filter: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterButton(
                          label: 'Hari Ini',
                          isSelected: filter == DateFilter.today,
                          onTap: () => ref.read(dateFilterProvider.notifier).state = DateFilter.today,
                        ),
                        const SizedBox(width: 6),
                        _FilterButton(
                          label: '7 Hari',
                          isSelected: filter == DateFilter.last7Days,
                          onTap: () => ref.read(dateFilterProvider.notifier).state = DateFilter.last7Days,
                        ),
                        const SizedBox(width: 6),
                        _FilterButton(
                          label: 'Semua',
                          isSelected: filter == DateFilter.all,
                          onTap: () => ref.read(dateFilterProvider.notifier).state = DateFilter.all,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Timeline
          Expanded(
            child: logsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                      const SizedBox(height: 8),
                      Text('Belum ada log history', style: TextStyle(color: Colors.grey[600])),
                      const SizedBox(height: 4),
                      Text(
                        'Log akan muncul otomatis saat ada aktivitas',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              data: (logs) {
                final filtered = repo.filterByDateRange(logs, filter);

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text('Tidak ada aktivitas', style: TextStyle(color: Colors.grey[600])),
                        const SizedBox(height: 4),
                        Text(
                          'Coba ubah filter untuk melihat lebih banyak',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(ticketLogsProvider(ticket.idTicket));
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final log = filtered[i];
                      final isLast = i == filtered.length - 1;
                      final color = _getEventColor(log.eventType);

                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Timeline indicator
                            Column(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: color, width: 2),
                                  ),
                                  child: Icon(_getEventIcon(log.eventType), size: 16, color: color),
                                ),
                                if (!isLast)
                                  Expanded(
                                    child: Container(
                                      width: 2,
                                      color: Colors.grey[300],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 12),

                            // Content
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                                child: Card(
                                  elevation: 0,
                                  margin: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(color: Colors.grey.shade200),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                log.displayText,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                              ),
                                            ),
                                            Text(
                                              _getRelativeTime(log.createdAt),
                                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.grey[200],
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                log.actorRole.toUpperCase(),
                                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              _formatDateTime(log.createdAt),
                                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                        // Payload details
                                        if (log.payload.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          _buildPayloadDetails(context, log.payload),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
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

  Widget _buildPayloadDetails(BuildContext context, Map<String, dynamic> payload) {
    final entries = payload.entries.where((e) => e.value != null).toList();
    if (entries.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: entries.map((e) {
          final key = e.key.toString();
          final value = e.value?.toString() ?? '';

          // Detect URL fields (photo, attachment, image) → render as image
          if (_isImageUrl(key, value)) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$key:',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: GestureDetector(
                      onTap: () => _showFullScreenImage(context, value),
                      child: Image.network(
                        value,
                        width: double.infinity,
                        height: 150,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            height: 150,
                            alignment: Alignment.center,
                            child: const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          height: 150,
                          color: Colors.grey[200],
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.broken_image, color: Colors.grey, size: 32),
                              const SizedBox(height: 4),
                              Text(
                                'Failed to load image',
                                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // Regular text field
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Text(
              '$key: $value',
              style: const TextStyle(fontSize: 11, color: Colors.black87),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterButton({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF000072) : Colors.transparent,
          border: Border.all(color: const Color(0xFF000072)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF000072),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}