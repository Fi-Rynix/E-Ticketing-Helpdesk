import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// Get notifications for user
  Future<List<Notification>> getNotifications(int idUser) async {
    final response = await _client
        .from('notifications')
        .select()
        .eq('id_user', idUser)
        .order('created_at', ascending: false)
        .limit(50);

    return (response as List)
        .map((json) => Notification.fromJson(json))
        .toList();
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
