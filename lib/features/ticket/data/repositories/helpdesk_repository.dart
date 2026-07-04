import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/helpdesk_model.dart';

class HelpdeskRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// Get all helpdesks
  Future<List<Helpdesk>> getAllHelpdesks() async {
    final response = await _client
        .from('helpdesks')
        .select()
        .order('name');

    return (response as List)
        .map((json) => Helpdesk.fromJson(json))
        .toList();
  }

  /// Get available helpdesks
  Future<List<Helpdesk>> getAvailableHelpdesks() async {
    final response = await _client
        .from('helpdesks')
        .select()
        .eq('is_available', true)
        .order('name');

    return (response as List)
        .map((json) => Helpdesk.fromJson(json))
        .toList();
  }

  /// Get helpdesk by user ID
  Future<Helpdesk?> getHelpdeskByUserId(int idUser) async {
    final response = await _client
        .from('helpdesks')
        .select()
        .eq('id_user', idUser)
        .maybeSingle();

    if (response == null) return null;
    return Helpdesk.fromJson(response);
  }

  /// Toggle helpdesk availability
  Future<Helpdesk?> toggleAvailability({
    required int idHelpdesk,
    required bool isAvailable,
  }) async {
    final response = await _client
        .from('helpdesks')
        .update({'is_available': isAvailable})
        .eq('id_helpdesk', idHelpdesk)
        .select()
        .maybeSingle();

    if (response == null) return null;
    return Helpdesk.fromJson(response);
  }
}
