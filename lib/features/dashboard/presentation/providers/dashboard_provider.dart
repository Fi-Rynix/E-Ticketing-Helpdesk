import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/dashboard_model.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../../ticket/presentation/providers/ticket_provider.dart';

final dashboardRepositoryProvider = Provider((ref) => DashboardRepository());

// Provider untuk user dashboard stats
final userDashboardStatsProvider = FutureProvider.family<DashboardStats, int>((ref, idUser) async {
  final dashboardRepo = ref.watch(dashboardRepositoryProvider);
  final ticketRepo = ref.watch(ticketRepositoryProvider);
  final tickets = await ticketRepo.getTicketsByUser(idUser);
  return DashboardStats.fromUserTickets(tickets);
});

// Provider untuk admin dashboard stats
final adminDashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final dashboardRepo = ref.watch(dashboardRepositoryProvider);
  final ticketRepo = ref.watch(ticketRepositoryProvider);
  final tickets = await ticketRepo.getAllTickets();
  return DashboardStats.fromAllTickets(tickets);
});
