import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/ticket_log_repository.dart';

final ticketLogRepositoryProvider = Provider<TicketLogRepository>((ref) {
  return TicketLogRepository();
});

final ticketLogsProvider = FutureProvider.family<List<TicketLog>, int>((ref, idTicket) async {
  final repo = ref.watch(ticketLogRepositoryProvider);
  return repo.getLogsByTicket(idTicket);
});

/// Date filter state provider
final dateFilterProvider = StateProvider<DateFilter>((ref) => DateFilter.all);