import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/comment_model.dart';

class CommentRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// Get comments by ticket ID
  Future<List<Comment>> getCommentsByTicket(int idTicket) async {
    final response = await _client
        .from('comments')
        .select()
        .eq('id_ticket', idTicket)
        .order('created_at', ascending: true);

    final comments = (response as List).map((json) => Comment.fromJson(json)).toList();
    
    // Fetch usernames separately
    if (comments.isEmpty) return comments;
    
    final userIds = comments.map((c) => c.idUser).toSet().toList();
    final usersResponse = await _client
        .from('users')
        .select('id_user, username')
        .filter('id_user', 'in', '(${userIds.join(",")})');
    
    final userMap = <int, String>{};
    for (final user in (usersResponse as List)) {
      userMap[user['id_user'] as int] = user['username'] as String;
    }
    
    return comments.map((c) => c.copyWith(username: userMap[c.idUser])).toList();
  }

  /// Add comment
  Future<Comment?> addComment({
    required int idTicket,
    required int idUser,
    required String message,
  }) async {
    final response = await _client
        .from('comments')
        .insert({
          'id_ticket': idTicket,
          'id_user': idUser,
          'message': message,
        })
        .select()
        .single();

    return Comment.fromJson(response);
  }

  /// Edit comment (only by author)
  Future<Comment?> editComment({
    required int idComment,
    required int idUser,
    required String message,
  }) async {
    final response = await _client
        .from('comments')
        .update({
          'message': message,
          'is_edited': true,
        })
        .eq('id_comment', idComment)
        .eq('id_user', idUser)
        .select()
        .maybeSingle();

    if (response == null) return null;
    return Comment.fromJson(response);
  }

  /// Delete comment (only by author)
  Future<bool> deleteComment({
    required int idComment,
    required int idUser,
  }) async {
    final response = await _client
        .from('comments')
        .delete()
        .eq('id_comment', idComment)
        .eq('id_user', idUser)
        .select()
        .maybeSingle();

    return response != null;
  }
}
