import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../ticket/presentation/pages/ticket_detail_page.dart';
import '../../../ticket/presentation/providers/ticket_pagination.dart';
import '../providers/notification_provider.dart';
import '../providers/notification_pagination_provider.dart';
import '../../data/models/notification_model.dart';
import '../../../../shared/widgets/load_more_button.dart';

class NotificationPage extends ConsumerStatefulWidget {
  const NotificationPage({super.key});

  @override
  ConsumerState<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends ConsumerState<NotificationPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Load first page after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(paginatedNotificationsProvider.notifier).loadFirstPage();
    });
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

    final paginationState = ref.watch(paginatedNotificationsProvider);

    return Column(
      children: [
        // TabBar
        Material(
          color: const Color(0xFF000072),
          child: SafeArea(
            bottom: false,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Unread'),
              ],
            ),
          ),
        ),
        // Mark all as read button
        Container(
          color: const Color(0xFF000072),
          child: SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _markAllAsRead(currentUser.idUser),
                icon: const Icon(Icons.done_all, color: Colors.white70, size: 18),
                label: const Text('Mark all read', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ),
            ),
          ),
        ),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildAllTab(paginationState),
              _buildUnreadTab(paginationState),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAllTab(PaginationState<Notification> state) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: ${state.error}', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => ref.read(paginatedNotificationsProvider.notifier).refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.items.isEmpty) {
      return _emptyState(message: 'No notifications');
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(paginatedNotificationsProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: state.items.length + 1,
        itemBuilder: (context, index) {
          if (index == state.items.length) {
            return LoadMoreButton(
              isLoading: state.isLoading,
              hasMore: state.hasMore,
              onPressed: () => ref.read(paginatedNotificationsProvider.notifier).loadMore(),
              currentCount: state.items.length,
            );
          }
          return _NotificationCard(
            notification: state.items[index],
            onTap: () => _handleNotificationTap(state.items[index]),
          );
        },
      ),
    );
  }

  Widget _buildUnreadTab(PaginationState<Notification> state) {
    final unread = state.items.where((n) => !n.isRead).toList();

    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (unread.isEmpty) {
      return _emptyState(message: 'No unread notifications');
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(paginatedNotificationsProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: unread.length,
        itemBuilder: (context, index) {
          return _NotificationCard(
            notification: unread[index],
            onTap: () => _handleNotificationTap(unread[index]),
          );
        },
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

  void _handleNotificationTap(Notification notification) async {
    if (!notification.isRead) {
      final repo = ref.read(notificationRepositoryProvider);
      await repo.markAsRead(notification.idNotification);
      ref.invalidate(paginatedNotificationsProvider);
      ref.invalidate(userNotificationsProvider(ref.read(currentUserProvider)!.idUser));
    }

    if (notification.idTicket != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => TicketDetailPage(ticketId: notification.idTicket!),
        ),
      );
      ref.invalidate(paginatedNotificationsProvider);
    }
  }

  void _markAllAsRead(int idUser) async {
    final repo = ref.read(notificationRepositoryProvider);
    await repo.markAllAsRead(idUser);
    ref.invalidate(paginatedNotificationsProvider);
    ref.invalidate(userNotificationsProvider(idUser));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications marked as read')),
      );
    }
  }
}

class _NotificationCard extends StatelessWidget {
  final Notification notification;
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
            Text(notification.body, maxLines: 2, overflow: TextOverflow.ellipsis),
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
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.blue),
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
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}