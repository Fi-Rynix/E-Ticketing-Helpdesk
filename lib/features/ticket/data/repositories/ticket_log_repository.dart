import 'package:supabase_flutter/supabase_flutter.dart';

/// Tracking event structure from ticket_logs table
class TicketLog {
  final int idTicketLog;
  final int idTicket;
  final int? idUser;
  final String actorRole;
  final String eventType;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  TicketLog({
    required this.idTicketLog,
    required this.idTicket,
    this.idUser,
    required this.actorRole,
    required this.eventType,
    required this.payload,
    required this.createdAt,
  });

  factory TicketLog.fromJson(Map<String, dynamic> json) {
    return TicketLog(
      idTicketLog: json['id_ticket_log'] as int,
      idTicket: json['id_ticket'] as int,
      idUser: json['id_user'] as int?,
      actorRole: json['actor_role']?.toString().split('::').last.split("'").last ?? 'user',
      eventType: json['event_type'] as String,
      payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get displayText {
    switch (eventType) {
      case 'ticket.created':
        return 'Tiket dibuat';
      case 'ticket.assigned':
        return 'Tiket ditugaskan ke helpdesk';
      case 'ticket.reassigned':
        return 'Tiket dialihkan ke helpdesk lain';
      case 'ticket.unassigned':
        return 'Tiket dilepas (kembali ke open)';
      case 'ticket.unassign_requested':
        return 'Helpdesk meminta un-assign';
      case 'ticket.unassign_approved':
        return 'Admin menyetujui un-assign';
      case 'ticket.unassign_rejected':
        return 'Admin menolak un-assign';
      case 'ticket.status_changed':
        return 'Status tiket berubah';
      case 'ticket.cancelled':
        return 'Tiket dibatalkan';
      case 'ticket.photo_updated':
        return 'Foto tiket diubah';
      case 'ticket.updated':
        return 'Tiket diupdate';
      case 'ticket.completed':
        return 'Tiket selesai';
      case 'comment.added':
        return 'Komentar ditambahkan';
      case 'comment.edited':
        return 'Komentar diedit';
      case 'comment.deleted':
        return 'Komentar dihapus';
      default:
        return eventType;
    }
  }
}

class TicketLogRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// Get all logs for a ticket
  Future<List<TicketLog>> getLogsByTicket(int idTicket) async {
    try {
      final response = await _client
          .from('ticket_logs')
          .select()
          .eq('id_ticket', idTicket)
          .order('created_at', ascending: false);

      return (response as List).map((json) => TicketLog.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching ticket logs: $e');
      rethrow;
    }
  }

  /// Filter logs by date range
  List<TicketLog> filterByDateRange(
    List<TicketLog> logs,
    DateFilter filter,
  ) {
    final now = DateTime.now();
    switch (filter) {
      case DateFilter.today:
        final startOfDay = DateTime(now.year, now.month, now.day);
        return logs.where((l) => l.createdAt.isAfter(startOfDay)).toList();
      case DateFilter.last7Days:
        final sevenDaysAgo = now.subtract(const Duration(days: 7));
        return logs.where((l) => l.createdAt.isAfter(sevenDaysAgo)).toList();
      case DateFilter.all:
        return logs;
    }
  }
}

enum DateFilter { today, last7Days, all }