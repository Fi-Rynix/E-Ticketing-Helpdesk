import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/ticket_model.dart';
import '../../data/repositories/ticket_repository.dart';

final ticketRepositoryProvider = Provider((ref) => TicketRepository());

// Provider untuk list semua tiket
final allTicketsProvider = StateProvider<List<Ticket>>((ref) => []);

// Provider untuk fetch semua tiket
final fetchAllTicketsProvider = FutureProvider((ref) async {
  final ticketRepo = ref.watch(ticketRepositoryProvider);
  final tickets = await ticketRepo.getAllTickets();
  ref.read(allTicketsProvider.notifier).state = tickets;
  return tickets;
});

// Provider untuk filter tiket berdasarkan user
final userTicketsProvider = FutureProvider.family<List<Ticket>, String>((ref, username) async {
  final ticketRepo = ref.watch(ticketRepositoryProvider);
  return await ticketRepo.getTicketsByUser(username);
});

// Provider untuk filter tiket berdasarkan status
final ticketsByStatusProvider = FutureProvider.family<List<Ticket>, String>((ref, status) async {
  final ticketRepo = ref.watch(ticketRepositoryProvider);
  return await ticketRepo.getTicketsByStatus(status);
});

// Provider untuk get detail tiket
final ticketDetailProvider = FutureProvider.family<Ticket?, String>((ref, ticketId) async {
  final ticketRepo = ref.watch(ticketRepositoryProvider);
  return await ticketRepo.getTicketById(ticketId);
});
