import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/ticket_model.dart';
import '../../data/repositories/ticket_repository.dart';

final ticketRepositoryProvider = Provider((ref) => TicketRepository());

// Provider untuk list tiket
final ticketListProvider = StateProvider<List<Ticket>>((ref) => []);

// Provider untuk fetch semua tiket (admin)
final fetchAllTicketsProvider = FutureProvider<List<Ticket>>((ref) async {
  final repo = ref.watch(ticketRepositoryProvider);
  final tickets = await repo.getAllTickets();
  ref.read(ticketListProvider.notifier).state = tickets;
  return tickets;
});

// Provider untuk fetch tiket user
final userTicketsProvider = FutureProvider.family<List<Ticket>, int>((ref, idUser) async {
  final repo = ref.watch(ticketRepositoryProvider);
  return await repo.getTicketsByUser(idUser);
});

// Provider untuk fetch tiket helpdesk
final helpdeskTicketsProvider = FutureProvider.family<List<Ticket>, int>((ref, idHelpdesk) async {
  final repo = ref.watch(ticketRepositoryProvider);
  return await repo.getTicketsByHelpdesk(idHelpdesk);
});

// Provider untuk fetch tiket by status
final ticketsByStatusProvider = FutureProvider.family<List<Ticket>, String>((ref, status) async {
  final repo = ref.watch(ticketRepositoryProvider);
  return await repo.getTicketsByStatus(status);
});

// Provider untuk detail tiket
final ticketDetailProvider = FutureProvider.family<Ticket?, int>((ref, idTicket) async {
  final repo = ref.watch(ticketRepositoryProvider);
  return await repo.getTicketById(idTicket);
});

// Refresh helper untuk invalidate providers
void refreshTicketProviders(WidgetRef ref) {
  ref.invalidate(fetchAllTicketsProvider);
}
