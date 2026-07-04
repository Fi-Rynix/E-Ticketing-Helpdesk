import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/ticket_model.dart';
import '../providers/ticket_provider.dart';
import '../models/ticket_filter_model.dart';
import './ticket_detail_page.dart';
import './create_ticket_page.dart';

class TicketListPage extends ConsumerStatefulWidget {
  const TicketListPage({super.key});

  @override
  ConsumerState<TicketListPage> createState() => _TicketListPageState();
}

class _TicketListPageState extends ConsumerState<TicketListPage> {
  TicketFilter _filter = TicketFilter.all;
  Map<int, String> _userNames = {};
  Map<int, String> _helpdeskNames = {};

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);

    if (currentUser == null) {
      return const Center(child: Text('Not authenticated'));
    }

    final ticketsAsync = currentUser.role.name == 'admin'
        ? ref.watch(fetchAllTicketsProvider)
        : ref.watch(userTicketsProvider(currentUser.idUser));

    return Scaffold(
      body: Column(
        children: [
          // Filter tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  isSelected: _filter == TicketFilter.all,
                  onTap: () => setState(() => _filter = TicketFilter.all),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Open',
                  isSelected: _filter == TicketFilter.open,
                  onTap: () => setState(() => _filter = TicketFilter.open),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Assigned',
                  isSelected: _filter == TicketFilter.assigned,
                  onTap: () => setState(() => _filter = TicketFilter.assigned),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'In Progress',
                  isSelected: _filter == TicketFilter.inProgress,
                  onTap: () => setState(() => _filter = TicketFilter.inProgress),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Done',
                  isSelected: _filter == TicketFilter.done,
                  onTap: () => setState(() => _filter = TicketFilter.done),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Cancelled',
                  isSelected: _filter == TicketFilter.cancelled,
                  onTap: () => setState(() => _filter = TicketFilter.cancelled),
                ),
              ],
            ),
          ),
          // Ticket list
          Expanded(
            child: ticketsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error: $error')),
              data: (tickets) {
                // Filter tickets based on selected filter
                final filteredTickets = _filter == TicketFilter.all
                    ? tickets
                    : tickets.where((t) => t.status.value == _filter.statusValue).toList();

                // Update names cache
                _updateNamesCache(filteredTickets);

                if (filteredTickets.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'No tickets found',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(fetchAllTicketsProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredTickets.length,
                    itemBuilder: (context, index) {
                      final ticket = filteredTickets[index];
                      final isAdmin = currentUser.role.name == 'admin';
                      final creatorName = _userNames[ticket.idUser] ?? 'Loading...';
                      final helpdeskName = ticket.idHelpdesk != null 
                          ? (_helpdeskNames[ticket.idHelpdesk] ?? 'Loading...')
                          : null;

                      return GestureDetector(
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => TicketDetailPage(ticketId: ticket.idTicket),
                            ),
                          );
                          ref.invalidate(fetchAllTicketsProvider);
                        },
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Thumbnail placeholder
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.image,
                                    color: Colors.grey[400],
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: isAdmin
                                      ? _buildAdminView(ticket, creatorName, helpdeskName)
                                      : _buildUserView(ticket),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: currentUser.role.name == 'user'
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const CreateTicketPage(),
                  ),
                );
                ref.invalidate(fetchAllTicketsProvider);
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  void _updateNamesCache(List<Ticket> tickets) async {
    final repo = ref.read(ticketRepositoryProvider);
    
    for (final ticket in tickets) {
      if (!_userNames.containsKey(ticket.idUser)) {
        final name = await repo.getUsernameById(ticket.idUser);
        if (mounted && name != null) {
          setState(() => _userNames[ticket.idUser] = name);
        }
      }
      
      if (ticket.idHelpdesk != null && !_helpdeskNames.containsKey(ticket.idHelpdesk)) {
        final name = await repo.getHelpdeskNameById(ticket.idHelpdesk!);
        if (mounted && name != null) {
          setState(() => _helpdeskNames[ticket.idHelpdesk!] = name);
        }
      }
    }
  }

  Widget _buildAdminView(Ticket ticket, String creatorName, String? helpdeskName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '#${ticket.idTicket}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                fontWeight: FontWeight.w600,
              ),
            ),
            _StatusBadge(status: ticket.status),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          ticket.title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          ticket.description,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'By: $creatorName',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
            if (helpdeskName != null)
              Text(
                'To: $helpdeskName',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.blue,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildUserView(Ticket ticket) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.topRight,
          child: _StatusBadge(status: ticket.status),
        ),
        const SizedBox(height: 8),
        Text(
          ticket.title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          ticket.description,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final TicketStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 10,
          color: _getColor(),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getColor() {
    switch (status) {
      case TicketStatus.open:
        return const Color(0xFFDC2626);
      case TicketStatus.assigned:
        return const Color(0xFFF97316);
      case TicketStatus.inProgress:
        return const Color(0xFF3B82F6);
      case TicketStatus.pendingUnassign:
        return const Color(0xFFA855F7);
      case TicketStatus.done:
        return const Color(0xFF10B981);
      case TicketStatus.cancelled:
        return const Color(0xFF6B7280);
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF000072) : const Color(0xFFE5E5E5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF525252),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
