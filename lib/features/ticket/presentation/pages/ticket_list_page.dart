import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../ticket/presentation/providers/helpdesk_provider.dart';
import '../../data/models/ticket_model.dart';
import '../providers/ticket_provider.dart';
import '../providers/ticket_pagination.dart';
import '../providers/ticket_pagination_provider.dart';
import '../models/ticket_filter_model.dart';
import './ticket_detail_page.dart';
import './create_ticket_page.dart';
import '../../../../shared/widgets/load_more_button.dart';

class TicketListPage extends ConsumerStatefulWidget {
  const TicketListPage({super.key});

  @override
  ConsumerState<TicketListPage> createState() => _TicketListPageState();
}

class _TicketListPageState extends ConsumerState<TicketListPage> {
  TicketFilter _filter = TicketFilter.assigned; // default for helpdesk; overridden for user/admin
  final Map<int, String> _userNames = {};
  final Map<int, String> _helpdeskNames = {};
  int? _helpdeskId;

  @override
  void initState() {
    super.initState();
    // Load first page after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        if (user.role == 'helpdesk') {
          // Helpdesk default: load 'assigned' tickets (no 'all' filter)
          _filter = TicketFilter.assigned;
          _loadHelpdeskIdAndRefresh(user.idUser);
        } else if (user.role == 'admin') {
          _filter = TicketFilter.all;
          ref.read(paginatedAllTicketsProvider.notifier).loadFirstPage();
        } else {
          _filter = TicketFilter.all;
          ref.read(paginatedUserTicketsProvider.notifier).loadFirstPage();
        }
      }
    });
  }

  Future<void> _loadHelpdeskIdAndRefresh(int idUser) async {
    if (_helpdeskId != null) {
      // Load with current filter (assigned for helpdesk)
      ref.read(paginatedTicketsByStatusProvider(_filter.statusValue).notifier).loadFirstPage();
      return;
    }
    try {
      final helpdeskAsync = await ref.read(helpdeskByUserProvider(idUser).future);
      if (mounted && helpdeskAsync != null) {
        setState(() => _helpdeskId = helpdeskAsync.idHelpdesk);
        // Load with current filter
        ref.read(paginatedTicketsByStatusProvider(_filter.statusValue).notifier).loadFirstPage();
      }
    } catch (e) {
      print('ERROR loading helpdesk: $e');
    }
  }

  void _onFilterChanged(TicketFilter filter) {
    setState(() => _filter = filter);
    final notifier = ref.read(paginatedTicketsByStatusProvider(filter.statusValue).notifier);
    notifier.loadFirstPage();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);

    if (currentUser == null) {
      return const Center(child: Text('Not authenticated'));
    }

    final roleName = currentUser.role;
    final filterOptions = _getFilterOptions(roleName);

    // Watch paginated state based on current filter & role
    // Helpdesk never uses 'all' filter (always specific status)
    final paginationState = (roleName == 'helpdesk' || _filter != TicketFilter.all)
        ? ref.watch(paginatedTicketsByStatusProvider(_filter.statusValue))
        : (roleName == 'admin'
            ? ref.watch(paginatedAllTicketsProvider)
            : ref.watch(paginatedUserTicketsProvider));

    return Scaffold(
      body: Column(
        children: [
          // Filter tabs (role-specific)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              children: filterOptions.map((filter) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FilterChip(
                    label: filter.label,
                    isSelected: _filter == filter,
                    onTap: () => _onFilterChanged(filter),
                  ),
                );
              }).toList(),
            ),
          ),
          // Ticket list with pagination
          Expanded(
            child: _buildTicketList(context, currentUser, roleName, paginationState),
          ),
        ],
      ),
      floatingActionButton: roleName == 'user'
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const CreateTicketPage(),
                  ),
                );
                ref.read(paginatedUserTicketsProvider.notifier).refresh();
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildTicketList(
    BuildContext context,
    dynamic currentUser,
    String roleName,
    PaginationState<Ticket> paginationState,
  ) {
    if (paginationState.isLoading && paginationState.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (paginationState.error != null && paginationState.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: ${paginationState.error}', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _refreshPaginated(roleName),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final tickets = paginationState.items;

    if (tickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No tickets found', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    // Update names cache
    _updateNamesCache(tickets);

    return RefreshIndicator(
      onRefresh: () async => _refreshPaginated(roleName),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: tickets.length + 1, // +1 for Load More button
        itemBuilder: (context, index) {
          if (index == tickets.length) {
            // Load More button at bottom
            return LoadMoreButton(
              isLoading: paginationState.isLoading,
              hasMore: paginationState.hasMore,
              onPressed: () {
                // Helpdesk always uses status filter (no 'all')
                final notifier = (roleName == 'helpdesk' || _filter != TicketFilter.all)
                    ? ref.read(paginatedTicketsByStatusProvider(_filter.statusValue).notifier)
                    : (roleName == 'admin'
                        ? ref.read(paginatedAllTicketsProvider.notifier)
                        : ref.read(paginatedUserTicketsProvider.notifier));
                notifier.loadMore();
              },
              currentCount: tickets.length,
            );
          }

          final ticket = tickets[index];
          final isAdmin = roleName == 'admin';
          final isHelpdesk = roleName == 'helpdesk';
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
              _refreshPaginated(roleName);
            },
            child: Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                        image: ticket.photoPath != null && ticket.photoPath!.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(ticket.photoPath!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: ticket.photoPath == null || ticket.photoPath!.isEmpty
                          ? Icon(Icons.image, color: Colors.grey[400], size: 30)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: isAdmin
                          ? _buildAdminView(ticket, creatorName, helpdeskName)
                          : isHelpdesk
                              ? _buildHelpdeskView(ticket, creatorName)
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
  }

  void _refreshPaginated(String roleName) {
    // Helpdesk always uses status filter (no 'all')
    if (roleName == 'helpdesk' || _filter != TicketFilter.all) {
      ref.read(paginatedTicketsByStatusProvider(_filter.statusValue).notifier).refresh();
    } else if (roleName == 'admin') {
      ref.read(paginatedAllTicketsProvider.notifier).refresh();
    } else {
      ref.read(paginatedUserTicketsProvider.notifier).refresh();
    }
  }

  List<TicketFilter> _getFilterOptions(String role) {
    switch (role) {
      case 'admin':
        return [
          TicketFilter.all,
          TicketFilter.open,
          TicketFilter.assigned,
          TicketFilter.inProgress,
          TicketFilter.done,
          TicketFilter.cancelled,
        ];
      case 'helpdesk':
        return [
          TicketFilter.assigned,
          TicketFilter.inProgress,
          TicketFilter.done,
        ];
      case 'user':
      default:
        return [
          TicketFilter.all,
          TicketFilter.open,
          TicketFilter.assigned,
          TicketFilter.inProgress,
          TicketFilter.done,
          TicketFilter.cancelled,
        ];
    }
  }

  void _updateNamesCache(List<Ticket> tickets) async {
    final repo = ref.read(ticketRepositoryProvider);

    for (final ticket in tickets) {
      if (!_userNames.containsKey(ticket.idUser)) {
        repo.getUsernameById(ticket.idUser).then((name) {
          if (mounted && name != null) {
            setState(() => _userNames[ticket.idUser] = name);
          }
        });
      }

      if (ticket.idHelpdesk != null && !_helpdeskNames.containsKey(ticket.idHelpdesk)) {
        repo.getHelpdeskNameById(ticket.idHelpdesk!).then((name) {
          if (mounted && name != null) {
            setState(() => _helpdeskNames[ticket.idHelpdesk!] = name);
          }
        });
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
            Text('#${ticket.idTicket}', style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600)),
            _StatusBadge(status: ticket.status),
          ],
        ),
        const SizedBox(height: 8),
        Text(ticket.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text(ticket.description, style: TextStyle(fontSize: 13, color: Colors.grey[600]), maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('By: $creatorName', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            if (helpdeskName != null)
              Text('To: $helpdeskName', style: const TextStyle(fontSize: 11, color: Colors.blue)),
          ],
        ),
      ],
    );
  }

  Widget _buildHelpdeskView(Ticket ticket, String creatorName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('#${ticket.idTicket}', style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600)),
            _StatusBadge(status: ticket.status),
          ],
        ),
        const SizedBox(height: 8),
        Text(ticket.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text(ticket.description, style: TextStyle(fontSize: 13, color: Colors.grey[600]), maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
        Text('By: $creatorName', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildUserView(Ticket ticket) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(alignment: Alignment.topRight, child: _StatusBadge(status: ticket.status)),
        const SizedBox(height: 8),
        Text(ticket.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text(ticket.description, style: TextStyle(fontSize: 13, color: Colors.grey[600]), maxLines: 2, overflow: TextOverflow.ellipsis),
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
        color: _getColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label,
        style: TextStyle(fontSize: 10, color: _getColor(), fontWeight: FontWeight.w600),
      ),
    );
  }

  Color _getColor() {
    switch (status) {
      case TicketStatus.open:
        return const Color(0xFF000072);
      case TicketStatus.assigned:
        return const Color(0xFF1E40AF);
      case TicketStatus.inProgress:
        return const Color(0xFF3B82F6);
      case TicketStatus.pendingUnassign:
        return const Color(0xFF60A5FA);
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

  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

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