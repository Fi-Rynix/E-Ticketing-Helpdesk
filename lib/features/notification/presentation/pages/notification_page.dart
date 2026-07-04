import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../ticket/presentation/pages/ticket_detail_page.dart';
import '../providers/notification_provider.dart';

class NotificationPage extends ConsumerStatefulWidget {
  const NotificationPage({super.key});

  @override
  ConsumerState<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends ConsumerState<NotificationPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Unread'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: () => _markAllAsRead(currentUser.idUser),
            tooltip: 'Mark all as read',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // All notifications
          notificationsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error: $error')),
            data: (notifications) {
              if (notifications.isEmpty) {
                return _emptyState();
              }
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(userNotificationsProvider(currentUser.idUser));
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return _NotificationCard(
                      notification: notification,
                      onTap: () => _handleNotificationTap(notification),
                    );
                  },
                ),
              );
            },
          ),
          // Unread only
          notificationsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error: $error')),
            data: (notifications) {
              final unread = notifications.where((n) => !n.isRead).toList();
              if (unread.isEmpty) {
                return _emptyState(message: 'No unread notifications');
              }
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(userNotificationsProvider(currentUser.idUser));
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: unread.length,
                  itemBuilder: (context, index) {
                    final notification = unread[index];
                    return _NotificationCard(
                      notification: notification,
                      onTap: () => _handleNotificationTap(notification),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _emptyState({String message = 'No notifications'}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  void _handleNotificationTap(notification) async {
    // Mark as read
    if (!notification.isRead) {
      final repo = ref.read(notificationRepositoryProvider);
      await repo.markAsRead(notification.idNotification);
      ref.invalidate(userNotificationsProvider(ref.read(currentUserProvider)!.idUser));
    }

    // Navigate to ticket if idTicket exists
    if (notification.idTicket != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => TicketDetailPage(ticketId: notification.idTicket!),
        ),
      );
      // Refresh when back
      ref.invalidate(userNotificationsProvider(ref.read(currentUserProvider)!.idUser));
    }
  }

  void _markAllAsRead(int idUser) async {
    final repo = ref.read(notificationRepositoryProvider);
    await repo.markAllAsRead(idUser);
    ref.invalidate(userNotificationsProvider(idUser));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications marked as read')),
      );
    }
  }
}

class _NotificationCard extends StatelessWidget {
  final dynamic notification;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: notification.isRead ? Colors.grey[200] : Colors.blue[100],
            borderRadius: BorderRadius.circular(12),
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
            Text(
              notification.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(notification.createdAt),
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
        trailing: !notification.isRead
            ? Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue,
                ),
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'ticket_created':
        return Icons.add_circle;
      case 'ticket_assigned':
        return Icons.person_add;
      case 'ticket_reassigned':
        return Icons.swap_horiz;
      case 'ticket_unassigned':
        return Icons.person_remove;
      case 'ticket_unassign_requested':
        return Icons.exit_to_app;
      case 'ticket_unassign_approved':
        return Icons.check_circle;
      case 'ticket_unassign_rejected':
        return Icons.cancel;
      case 'ticket_in_progress':
        return Icons.play_circle;
      case 'ticket_done':
        return Icons.check_circle;
      case 'ticket_cancelled':
        return Icons.cancel;
      case 'ticket_edited':
        return Icons.edit;
      case 'comment_added':
        return Icons.comment;
      case 'helpdesk_availability_changed':
        return Icons.event_available;
      default:
        return Icons.notifications;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
