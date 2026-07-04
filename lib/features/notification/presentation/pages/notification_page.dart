import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../ticket/presentation/pages/ticket_detail_page.dart';
import '../providers/notification_provider.dart';

class NotificationPage extends ConsumerWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);

    if (currentUser == null) {
      return const Center(child: Text('Not authenticated'));
    }

    final notificationsAsync = ref.watch(userNotificationsProvider(currentUser.idUser));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: const Color(0xFF000072),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No notifications', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: notification.isRead ? Colors.grey[200] : Colors.blue[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getIcon(notification.type),
                      color: notification.isRead ? Colors.grey : Colors.blue,
                    ),
                  ),
                  title: Text(
                    notification.title,
                    style: TextStyle(
                      fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                      color: notification.isRead ? Colors.grey[600] : Colors.black,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(notification.body),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(notification.createdAt),
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                  onTap: () {
                    // Mark as read
                    if (!notification.isRead) {
                      ref.read(markAsReadProvider(notification.idNotification));
                    }
                    // Navigate to ticket detail if idTicket exists
                    if (notification.idTicket != null) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => TicketDetailPage(ticketId: notification.idTicket!),
                        ),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'ticket_created':
        return Icons.add_circle;
      case 'ticket_assigned':
        return Icons.person_add;
      case 'ticket_in_progress':
        return Icons.play_circle;
      case 'ticket_done':
        return Icons.check_circle;
      case 'ticket_cancelled':
        return Icons.cancel;
      case 'comment_added':
        return Icons.comment;
      default:
        return Icons.notifications;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
