import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// Get notifications for user with cursor-based pagination
  Future<List<Notification>> getNotifications(int idUser, {DateTime? cursor, int limit = 20}) async {
    final queryBuilder = _client.from('notifications').select().eq('id_user', idUser);
    final filtered = cursor != null
        ? queryBuilder.filter('created_at', 'lt', cursor.toIso8601String())
        : queryBuilder;
    final response = await filtered
        .order('created_at', ascending: false)
        .limit(limit);
    return (response as List)
        .map((json) => Notification.fromJson(json))
        .toList();
  }

  /// Count total notifications for user (for pagination counter)
  Future<int> countNotifications(int idUser) async {
    final response = await _client
        .from('notifications')
        .select('id_notification')
        .eq('id_user', idUser);
    return (response as List).length;
  }

  /// Mark notification as read
  Future<bool> markAsRead(int idNotification) async {
    final response = await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id_notification', idNotification)
        .select()
        .maybeSingle();

    return response != null;
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead(int idUser) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id_user', idUser)
        .eq('is_read', false);
  }

  /// Get unread count
  Future<int> getUnreadCount(int idUser) async {
    final response = await _client
        .from('notifications')
        .select('id_notification')
        .eq('id_user', idUser)
        .eq('is_read', false);

    return (response as List).length;
  }
}
