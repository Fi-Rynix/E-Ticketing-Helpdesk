import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/comment_model.dart';
import '../../data/repositories/comment_repository.dart';

final commentRepositoryProvider = Provider((ref) => CommentRepository());

// Provider untuk fetch comments by ticket
final ticketCommentsProvider = FutureProvider.family<List<Comment>, int>((ref, idTicket) async {
  final repo = ref.watch(commentRepositoryProvider);
  return await repo.getCommentsByTicket(idTicket);
});
