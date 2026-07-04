import '../../../ticket/data/models/ticket_model.dart';

class DashboardStats {
  final int totalTickets;
  final int openTickets;
  final int assignedTickets;
  final int inProgressTickets;
  final int doneTickets;
  final int cancelledTickets;
  final int activeTickets;
  final int completedTickets;

  DashboardStats({
    required this.totalTickets,
    required this.openTickets,
    required this.assignedTickets,
    required this.inProgressTickets,
    required this.doneTickets,
    required this.cancelledTickets,
    required this.activeTickets,
    required this.completedTickets,
  });

  // Factory constructor untuk user dashboard
  factory DashboardStats.fromUserTickets(List<Ticket> tickets) {
    final total = tickets.length;
    final active = tickets.where((t) => t.status != TicketStatus.done && t.status != TicketStatus.cancelled).length;
    final completed = tickets.where((t) => t.status == TicketStatus.done).length;

    return DashboardStats(
      totalTickets: total,
      openTickets: 0,
      assignedTickets: 0,
      inProgressTickets: 0,
      doneTickets: 0,
      cancelledTickets: 0,
      activeTickets: active,
      completedTickets: completed,
    );
  }

  // Factory constructor untuk admin dashboard
  factory DashboardStats.fromAllTickets(List<Ticket> tickets) {
    final total = tickets.length;
    final open = tickets.where((t) => t.status == TicketStatus.open).length;
    final assigned = tickets.where((t) => t.status == TicketStatus.assigned).length;
    final inProgress = tickets.where((t) => t.status == TicketStatus.inProgress).length;
    final done = tickets.where((t) => t.status == TicketStatus.done).length;
    final cancelled = tickets.where((t) => t.status == TicketStatus.cancelled).length;

    return DashboardStats(
      totalTickets: total,
      openTickets: open,
      assignedTickets: assigned,
      inProgressTickets: inProgress,
      doneTickets: done,
      cancelledTickets: cancelled,
      activeTickets: open + assigned + inProgress,
      completedTickets: done,
    );
  }
}
