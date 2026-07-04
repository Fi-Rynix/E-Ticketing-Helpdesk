import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/notification_model.dart';
import '../../data/repositories/notification_repository.dart';

final notificationRepositoryProvider = Provider((ref) => NotificationRepository());

// Provider untuk fetch notifications by user
final userNotificationsProvider = FutureProvider.family<List<Notification>, int>((ref, idUser) async {
  final repo = ref.watch(notificationRepositoryProvider);
  return await repo.getNotifications(idUser);
});

// Provider untuk mark as read
final markAsReadProvider = FutureProvider.family<void, int>((ref, idNotification) async {
  final repo = ref.watch(notificationRepositoryProvider);
  await repo.markAsRead(idNotification);
});

// Provider untuk unread count
final unreadCountProvider = FutureProvider.family<int, int>((ref, idUser) async {
  final repo = ref.watch(notificationRepositoryProvider);
  return await repo.getUnreadCount(idUser);
});
