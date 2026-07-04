import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/helpdesk_model.dart';
import '../../data/repositories/helpdesk_repository.dart';

final helpdeskRepositoryProvider = Provider((ref) => HelpdeskRepository());

// Provider untuk fetch semua helpdesk
final allHelpdesksProvider = FutureProvider<List<Helpdesk>>((ref) async {
  final repo = ref.watch(helpdeskRepositoryProvider);
  return await repo.getAllHelpdesks();
});

// Provider untuk fetch helpdesk available
final availableHelpdesksProvider = FutureProvider<List<Helpdesk>>((ref) async {
  final repo = ref.watch(helpdeskRepositoryProvider);
  return await repo.getAvailableHelpdesks();
});

// Provider untuk fetch helpdesk by user ID
final helpdeskByUserProvider = FutureProvider.family<Helpdesk?, int>((ref, idUser) async {
  final repo = ref.watch(helpdeskRepositoryProvider);
  return await repo.getHelpdeskByUserId(idUser);
});
