import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ticket_model.dart';

class TicketRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// Get all tickets (for admin) with cursor-based pagination
  Future<List<Ticket>> getAllTickets({DateTime? cursor, int limit = 20}) async {
    final queryBuilder = _client.from('tickets').select();
    final filtered = cursor != null
        ? queryBuilder.filter('created_at', 'lt', cursor.toIso8601String())
        : queryBuilder;
    final response = await filtered
        .order('created_at', ascending: false)
        .limit(limit);
    return (response as List)
        .map((json) => Ticket.fromJson(json))
        .toList();
  }

  /// Get tickets by user ID with pagination
  Future<List<Ticket>> getTicketsByUser(int idUser, {DateTime? cursor, int limit = 20}) async {
    final queryBuilder = _client.from('tickets').select().eq('id_user', idUser);
    final filtered = cursor != null
        ? queryBuilder.filter('created_at', 'lt', cursor.toIso8601String())
        : queryBuilder;
    final response = await filtered
        .order('created_at', ascending: false)
        .limit(limit);
    return (response as List)
        .map((json) => Ticket.fromJson(json))
        .toList();
  }

  /// Get tickets assigned to helpdesk with pagination
  Future<List<Ticket>> getTicketsByHelpdesk(int idHelpdesk, {DateTime? cursor, int limit = 20}) async {
    final queryBuilder = _client.from('tickets').select().eq('id_helpdesk', idHelpdesk);
    final filtered = cursor != null
        ? queryBuilder.filter('created_at', 'lt', cursor.toIso8601String())
        : queryBuilder;
    final response = await filtered
        .order('created_at', ascending: false)
        .limit(limit);
    return (response as List)
        .map((json) => Ticket.fromJson(json))
        .toList();
  }

  /// Get tickets by status with pagination
  Future<List<Ticket>> getTicketsByStatus(String status, {DateTime? cursor, int limit = 20}) async {
    final queryBuilder = _client.from('tickets').select().eq('status', status);
    final filtered = cursor != null
        ? queryBuilder.filter('created_at', 'lt', cursor.toIso8601String())
        : queryBuilder;
    final response = await filtered
        .order('created_at', ascending: false)
        .limit(limit);
    return (response as List)
        .map((json) => Ticket.fromJson(json))
        .toList();
  }

  /// Count total tickets (for pagination counter)
  Future<int> countAllTickets() async {
    final response = await _client
        .from('tickets')
        .select('id_ticket');
    return (response as List).length;
  }

  /// Count tickets by user
  Future<int> countTicketsByUser(int idUser) async {
    final response = await _client
        .from('tickets')
        .select('id_ticket')
        .eq('id_user', idUser);
    return (response as List).length;
  }

  /// Get ticket by ID
  Future<Ticket?> getTicketById(int idTicket) async {
    final response = await _client
        .from('tickets')
        .select()
        .eq('id_ticket', idTicket)
        .maybeSingle();

    if (response == null) return null;
    return Ticket.fromJson(response);
  }

  /// Create new ticket
  Future<Ticket?> createTicket({
    required String title,
    required String description,
    required int idUser,
    String? photoPath,
  }) async {
    final response = await _client.from('tickets').insert({
      'title': title,
      'description': description,
      'id_user': idUser,
      'photo_path': photoPath,
      'status': 'open',
    }).select().single();

    if (response == null) return null;
    return Ticket.fromJson(response);
  }

  /// Update ticket (edit)
  Future<Ticket?> updateTicket({
    required int idTicket,
    String? title,
    String? description,
    String? photoPath,
  }) async {
    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (photoPath != null) updates['photo_path'] = photoPath;

    if (updates.isEmpty) return await getTicketById(idTicket);

    final response = await _client
        .from('tickets')
        .update(updates)
        .eq('id_ticket', idTicket)
        .select()
        .maybeSingle();

    if (response == null) return null;
    return Ticket.fromJson(response);
  }

  /// Cancel ticket
  Future<Ticket?> cancelTicket({
    required int idTicket,
    required int idUser,
    required String reason,
  }) async {
    final response = await _client
        .from('tickets')
        .update({
          'status': 'cancelled',
          'cancelled_reason': reason,
          'cancelled_at': DateTime.now().toIso8601String(),
        })
        .eq('id_ticket', idTicket)
        .eq('status', 'open')
        .eq('id_user', idUser)
        .select()
        .maybeSingle();

    if (response == null) return null;
    return Ticket.fromJson(response);
  }

  /// Assign ticket to helpdesk (admin)
  Future<Ticket?> assignTicket({
    required int idTicket,
    required int idHelpdesk,
  }) async {
    final response = await _client
        .from('tickets')
        .update({
          'id_helpdesk': idHelpdesk,
          'status': 'assigned',
        })
        .eq('id_ticket', idTicket)
        .eq('status', 'open')
        .select()
        .maybeSingle();

    if (response == null) return null;
    return Ticket.fromJson(response);
  }

  /// Unassign ticket (admin)
  Future<Ticket?> unassignTicket({
    required int idTicket,
  }) async {
    // Try assigned status first
    var response = await _client
        .from('tickets')
        .update({
          'id_helpdesk': null,
          'status': 'open',
        })
        .eq('id_ticket', idTicket)
        .eq('status', 'assigned')
        .select()
        .maybeSingle();

    if (response != null) return Ticket.fromJson(response);

    // Try pending_unassign status
    response = await _client
        .from('tickets')
        .update({
          'id_helpdesk': null,
          'status': 'open',
        })
        .eq('id_ticket', idTicket)
        .eq('status', 'pending_unassign')
        .select()
        .maybeSingle();

    if (response == null) return null;
    return Ticket.fromJson(response);
  }

  /// Start working on ticket (helpdesk)
  Future<Ticket?> startTicket({
    required int idTicket,
    required int idHelpdesk,
  }) async {
    final response = await _client
        .from('tickets')
        .update({
          'status': 'in_progress',
          'started_at': DateTime.now().toIso8601String(),
        })
        .eq('id_ticket', idTicket)
        .eq('status', 'assigned')
        .eq('id_helpdesk', idHelpdesk)
        .select()
        .maybeSingle();

    if (response == null) return null;
    return Ticket.fromJson(response);
  }

  /// Mark ticket as done (helpdesk)
  Future<Ticket?> completeTicket({
    required int idTicket,
    required int idHelpdesk,
  }) async {
    final response = await _client
        .from('tickets')
        .update({
          'status': 'done',
          'completed_at': DateTime.now().toIso8601String(),
        })
        .eq('id_ticket', idTicket)
        .eq('status', 'in_progress')
        .eq('id_helpdesk', idHelpdesk)
        .select()
        .maybeSingle();

    if (response == null) return null;
    return Ticket.fromJson(response);
  }

  /// Request unassign (helpdesk)
  Future<Ticket?> requestUnassign({
    required int idTicket,
    required int idHelpdesk,
    required String reason,
  }) async {
    // Try assigned status
    var response = await _client
        .from('tickets')
        .update({
          'status': 'pending_unassign',
          'unassign_id_helpdesk': idHelpdesk,
          'unassign_requested_at': DateTime.now().toIso8601String(),
          'unassign_reason': reason,
        })
        .eq('id_ticket', idTicket)
        .eq('status', 'assigned')
        .eq('id_helpdesk', idHelpdesk)
        .select()
        .maybeSingle();

    if (response != null) return Ticket.fromJson(response);

    // Try in_progress status
    response = await _client
        .from('tickets')
        .update({
          'status': 'pending_unassign',
          'unassign_id_helpdesk': idHelpdesk,
          'unassign_requested_at': DateTime.now().toIso8601String(),
          'unassign_reason': reason,
        })
        .eq('id_ticket', idTicket)
        .eq('status', 'in_progress')
        .eq('id_helpdesk', idHelpdesk)
        .select()
        .maybeSingle();

    if (response == null) return null;
    return Ticket.fromJson(response);
  }

  /// Approve unassign (admin)
  Future<Ticket?> approveUnassign({
    required int idTicket,
    required int idAdmin,
  }) async {
    final response = await _client
        .from('tickets')
        .update({
          'status': 'open',
          'id_helpdesk': null,
          'unassign_id_user': idAdmin,
          'unassign_decided_at': DateTime.now().toIso8601String(),
        })
        .eq('id_ticket', idTicket)
        .eq('status', 'pending_unassign')
        .select()
        .maybeSingle();

    if (response == null) return null;
    return Ticket.fromJson(response);
  }

  /// Reject unassign (admin)
  Future<Ticket?> rejectUnassign({
    required int idTicket,
    required int idAdmin,
    required String reason,
  }) async {
    final response = await _client
        .from('tickets')
        .update({
          'unassign_id_user': idAdmin,
          'unassign_decided_at': DateTime.now().toIso8601String(),
          'unassign_reject_reason': reason,
          'status': 'assigned',
        })
        .eq('id_ticket', idTicket)
        .eq('status', 'pending_unassign')
        .select()
        .maybeSingle();

    if (response == null) return null;
    return Ticket.fromJson(response);
  }

  /// Upload ticket photo to storage
  Future<String?> uploadPhoto(int idTicket, String filePath, String fileName) async {
    try {
      final file = File(filePath);
      final path = 'tickets/$idTicket/$fileName';
      
      await _client.storage
          .from('ticket-photos')
          .upload(path, file);

      return _client.storage
          .from('ticket-photos')
          .getPublicUrl(path);
    } catch (e) {
      print('Error uploading photo: $e');
      return null;
    }
  }

  /// Get username by user ID
  Future<String?> getUsernameById(int idUser) async {
    final response = await _client
        .from('users')
        .select('username')
        .eq('id_user', idUser)
        .maybeSingle();
    
    if (response == null) return null;
    return response['username'] as String?;
  }

  /// Get helpdesk name by helpdesk ID
  Future<String?> getHelpdeskNameById(int idHelpdesk) async {
    final response = await _client
        .from('helpdesks')
        .select('name')
        .eq('id_helpdesk', idHelpdesk)
        .maybeSingle();
    
    if (response == null) return null;
    return response['name'] as String?;
  }
}
