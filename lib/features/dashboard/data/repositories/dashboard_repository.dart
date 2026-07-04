import '../../data/models/dashboard_model.dart';
import '../../../ticket/data/models/ticket_model.dart';

class DashboardRepository {
  /// Get dashboard stats for a specific user by ID
  Future<DashboardStats> getUserDashboardStats(int idUser, Future<List<Ticket>> Function(int) getTicketsByUser) async {
    try {
      final userTickets = await getTicketsByUser(idUser);
      return DashboardStats.fromUserTickets(userTickets);
    } catch (e) {
      return DashboardStats(
        totalTickets: 0,
        openTickets: 0,
        assignedTickets: 0,
        inProgressTickets: 0,
        doneTickets: 0,
        cancelledTickets: 0,
        activeTickets: 0,
        completedTickets: 0,
      );
    }
  }

  /// Get dashboard stats for admin (all tickets)
  Future<DashboardStats> getAdminDashboardStats(List<Ticket> allTickets) async {
    try {
      return DashboardStats.fromAllTickets(allTickets);
    } catch (e) {
      return DashboardStats(
        totalTickets: 0,
        openTickets: 0,
        assignedTickets: 0,
        inProgressTickets: 0,
        doneTickets: 0,
        cancelledTickets: 0,
        activeTickets: 0,
        completedTickets: 0,
      );
    }
  }
}
