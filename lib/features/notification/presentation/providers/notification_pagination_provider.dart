import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/notification_model.dart';
import '../../data/repositories/notification_repository.dart';
import 'notification_provider.dart';
import '../../../ticket/presentation/providers/ticket_pagination.dart';

class PaginatedNotificationsNotifier extends PaginationNotifier<Notification> {
  final Ref ref;

  PaginatedNotificationsNotifier(this.ref) : super(
    fetcher: ({cursor, limit = 20}) async {
      final user = ref.read(currentUserProvider);
      if (user == null) return [];
      final repo = ref.read(notificationRepositoryProvider);
      return repo.getNotifications(user.idUser, cursor: cursor, limit: limit);
    },
  );
}

final paginatedNotificationsProvider = StateNotifierProvider<
    PaginatedNotificationsNotifier, PaginationState<Notification>>((ref) {
  return PaginatedNotificationsNotifier(ref);
});