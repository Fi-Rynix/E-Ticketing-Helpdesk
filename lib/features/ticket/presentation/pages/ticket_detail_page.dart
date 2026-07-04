import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/ticket_model.dart';
import '../../data/models/comment_model.dart';
import '../../data/repositories/ticket_repository.dart';
import '../providers/ticket_provider.dart';
import '../providers/comment_provider.dart';
import '../providers/helpdesk_provider.dart';
import '../../data/repositories/helpdesk_repository.dart';

class TicketDetailPage extends ConsumerStatefulWidget {
  final int ticketId;

  const TicketDetailPage({super.key, required this.ticketId});

  @override
  ConsumerState<TicketDetailPage> createState() => _TicketDetailPageState();
}

class _TicketDetailPageState extends ConsumerState<TicketDetailPage> {
  final _commentController = TextEditingController();
  
  String? _creatorName;
  String? _helpdeskName;

  @override
  void initState() {
    super.initState();
    _loadNames();
  }

  void _loadNames() async {
    final ticketRepo = ref.read(ticketRepositoryProvider);
    final ticket = await ticketRepo.getTicketById(widget.ticketId);
    if (ticket != null && mounted) {
      final creatorName = await ticketRepo.getUsernameById(ticket.idUser);
      String? hdName;
      if (ticket.idHelpdesk != null) {
        hdName = await ticketRepo.getHelpdeskNameById(ticket.idHelpdesk!);
      }
      if (mounted) {
        setState(() {
          _creatorName = creatorName;
          _helpdeskName = hdName;
        });
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final ticketAsync = ref.watch(ticketDetailProvider(widget.ticketId));
    final commentsAsync = ref.watch(ticketCommentsProvider(widget.ticketId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Ticket #${widget.ticketId}',
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF000072),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ticketAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (ticket) {
          if (ticket == null) {
            return const Center(child: Text('Ticket not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '#${ticket.idTicket}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    _StatusBadge(status: ticket.status),
                  ],
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  ticket.title,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Description
                _SectionCard(
                  title: 'Description',
                  child: Text(ticket.description),
                ),
                const SizedBox(height: 16),

                // Info rows
                _InfoRow(
                  label: 'Created by',
                  value: _creatorName ?? 'Loading...',
                ),
                _InfoRow(
                  label: 'Created at',
                  value: _formatDate(ticket.createdAt),
                ),
                if (ticket.idHelpdesk != null)
                  _InfoRow(
                    label: 'Assigned to',
                    value: _helpdeskName ?? 'Loading...',
                  ),

                const SizedBox(height: 16),

                // Admin section
                if (currentUser?.role.name == 'admin') ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Admin Actions',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _AdminActionsSection(ticket: ticket),
                  const SizedBox(height: 16),
                ],

                // Helpdesk section
                if (currentUser?.role.name == 'helpdesk') ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Helpdesk Actions',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _HelpdeskActionsSection(ticket: ticket),
                  const SizedBox(height: 16),
                ],

                // User cancel/edit section
                if (currentUser?.role.name == 'user' && ticket.status == TicketStatus.open) ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  _UserActionsSection(ticket: ticket),
                  const SizedBox(height: 16),
                ],

                // Status tracking
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Tracking',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _StatusTracking(ticket: ticket),

                const SizedBox(height: 16),

                // Comments section
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Comments',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                commentsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Text('Error loading comments: $e'),
                  data: (comments) {
                    if (comments.isEmpty) {
                      return const Text('No comments yet');
                    }
                    return Column(
                      children: comments.map((c) => _CommentCard(comment: c, currentUserId: currentUser?.idUser)).toList(),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Add comment
                TextField(
                  controller: _commentController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Add a comment...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _addComment(ticket.idTicket, currentUser?.idUser),
                    child: const Text('Post Comment'),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  void _addComment(int idTicket, int? idUser) async {
    if (_commentController.text.isEmpty || idUser == null) return;

    final commentRepo = ref.read(commentRepositoryProvider);
    await commentRepo.addComment(
      idTicket: idTicket,
      idUser: idUser,
      message: _commentController.text,
    );

    _commentController.clear();
    ref.invalidate(ticketCommentsProvider(idTicket));
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final TicketStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getColor(),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getColor() {
    switch (status) {
      case TicketStatus.open: return Colors.red;
      case TicketStatus.assigned: return Colors.orange;
      case TicketStatus.inProgress: return Colors.blue;
      case TicketStatus.pendingUnassign: return Colors.purple;
      case TicketStatus.done: return Colors.green;
      case TicketStatus.cancelled: return Colors.grey;
    }
  }
}

class _StatusTracking extends StatelessWidget {
  final Ticket ticket;

  const _StatusTracking({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final List<String> flow;
    if (ticket.status == TicketStatus.cancelled) {
      flow = ['open', 'cancelled'];
    } else {
      flow = ['open', 'assigned', 'in_progress', 'done'];
    }

    final currentIndex = flow.indexOf(ticket.status.value);
    const activeColor = Color(0xFF000072);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(flow.length, (index) {
          final status = flow[index];
          final isCompleted = index < currentIndex;
          final isCurrent = index == currentIndex;

          return Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted || isCurrent ? activeColor : Colors.grey[300],
                      border: isCurrent ? Border.all(color: Colors.black, width: 2) : null,
                    ),
                    child: Center(
                      child: Text(
                        index == flow.length - 1 ? '✓' : '${index + 1}',
                        style: TextStyle(
                          color: isCompleted || isCurrent ? Colors.white : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getStatusLabel(status),
                    style: TextStyle(fontSize: 9, color: isCurrent ? Colors.black : Colors.grey),
                  ),
                ],
              ),
              if (index < flow.length - 1)
                Container(width: 20, height: 2, margin: const EdgeInsets.symmetric(horizontal: 4), color: isCompleted ? activeColor : Colors.grey[300]),
            ],
          );
        }),
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'open': return 'OPEN';
      case 'assigned': return 'ASSIGNED';
      case 'in_progress': return 'IN PROGRESS';
      case 'done': return 'DONE';
      case 'cancelled': return 'CANCELLED';
      default: return status.toUpperCase();
    }
  }
}

class _AdminActionsSection extends ConsumerWidget {
  final Ticket ticket;
  final TicketRepository ticketRepo;

  _AdminActionsSection({required this.ticket})
      : ticketRepo = TicketRepository();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final helpdesksAsync = ref.watch(availableHelpdesksProvider);

    return Column(
      children: [
        helpdesksAsync.when(
          loading: () => const CircularProgressIndicator(),
          error: (e, s) => Text('Error: $e'),
          data: (helpdesks) {
            return DropdownButtonFormField<int>(
              decoration: const InputDecoration(
                labelText: 'Assign Helpdesk',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Unassigned')),
                ...helpdesks.map((h) => DropdownMenuItem(
                  value: h.idHelpdesk,
                  child: Text(h.name),
                )),
              ],
              onChanged: ticket.status == TicketStatus.open ? (idHelpdesk) async {
                if (idHelpdesk != null) {
                  await ticketRepo.assignTicket(idTicket: ticket.idTicket, idHelpdesk: idHelpdesk);
                  ref.invalidate(ticketDetailProvider(ticket.idTicket));
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket assigned')));
                }
              } : null,
            );
          },
        ),
        const SizedBox(height: 12),

        if (ticket.status == TicketStatus.pendingUnassign) ...[
          const Text('Unassign Request:', style: TextStyle(fontWeight: FontWeight.bold)),
          Text('Reason: ${ticket.unassignReason ?? '-'}'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: ElevatedButton(
                onPressed: () => _approveUnassign(context, ref),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Approve'),
              )),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(
                onPressed: () => _showRejectDialog(context, ref),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Reject'),
              )),
            ],
          ),
        ],
      ],
    );
  }

  void _approveUnassign(BuildContext context, WidgetRef ref) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    await ticketRepo.approveUnassign(idTicket: ticket.idTicket, idAdmin: currentUser.idUser);
    ref.invalidate(ticketDetailProvider(ticket.idTicket));
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unassign approved')));
  }

  void _showRejectDialog(BuildContext context, WidgetRef ref) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Unassign'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: 'Reason'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.isNotEmpty) {
                final currentUser = ref.read(currentUserProvider);
                if (currentUser != null) {
                  await ticketRepo.rejectUnassign(
                    idTicket: ticket.idTicket,
                    idAdmin: currentUser.idUser,
                    reason: reasonController.text,
                  );
                  ref.invalidate(ticketDetailProvider(ticket.idTicket));
                }
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unassign rejected')));
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}

class _HelpdeskActionsSection extends ConsumerWidget {
  final Ticket ticket;

  const _HelpdeskActionsSection({required this.ticket});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketRepo = TicketRepository();
    final currentUser = ref.watch(currentUserProvider);

    if (ticket.status == TicketStatus.assigned) {
      return ElevatedButton.icon(
        onPressed: () async {
          // Get helpdesk ID from user
          final helpdeskRepo = HelpdeskRepository();
          final helpdesk = await helpdeskRepo.getHelpdeskByUserId(currentUser!.idUser);
          if (helpdesk != null) {
            await ticketRepo.startTicket(idTicket: ticket.idTicket, idHelpdesk: helpdesk.idHelpdesk);
            ref.invalidate(ticketDetailProvider(ticket.idTicket));
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Started working on ticket')));
          }
        },
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start Working'),
      );
    }

    if (ticket.status == TicketStatus.inProgress) {
      return Row(
        children: [
          Expanded(child: ElevatedButton.icon(
            onPressed: () async {
              final helpdeskRepo = HelpdeskRepository();
              final helpdesk = await helpdeskRepo.getHelpdeskByUserId(currentUser!.idUser);
              if (helpdesk != null) {
                await ticketRepo.completeTicket(idTicket: ticket.idTicket, idHelpdesk: helpdesk.idHelpdesk);
                ref.invalidate(ticketDetailProvider(ticket.idTicket));
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket marked as done')));
              }
            },
            icon: const Icon(Icons.check),
            label: const Text('Mark Done'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          )),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(
            onPressed: () => _showUnassignDialog(context, ref, ticketRepo),
            icon: const Icon(Icons.exit_to_app),
            label: const Text('Request Unassign'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
          )),
        ],
      );
    }

    return const Text('No actions available');
  }

  void _showUnassignDialog(BuildContext context, WidgetRef ref, TicketRepository ticketRepo) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request Unassign'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: 'Reason'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.isNotEmpty) {
                final currentUser = ref.read(currentUserProvider);
                final helpdeskRepo = HelpdeskRepository();
                final helpdesk = await helpdeskRepo.getHelpdeskByUserId(currentUser!.idUser);
                if (helpdesk != null) {
                  await ticketRepo.requestUnassign(
                    idTicket: ticket.idTicket,
                    idHelpdesk: helpdesk.idHelpdesk,
                    reason: reasonController.text,
                  );
                  ref.invalidate(ticketDetailProvider(ticket.idTicket));
                }
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unassign requested')));
              }
            },
            child: const Text('Request'),
          ),
        ],
      ),
    );
  }
}

class _UserActionsSection extends ConsumerWidget {
  final Ticket ticket;

  const _UserActionsSection({required this.ticket});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketRepo = TicketRepository();
    final currentUser = ref.watch(currentUserProvider);

    return Row(
      children: [
        Expanded(child: OutlinedButton(
          onPressed: () => _showCancelDialog(context, ref, ticketRepo),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Cancel Ticket'),
        )),
      ],
    );
  }

  void _showCancelDialog(BuildContext context, WidgetRef ref, TicketRepository ticketRepo) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Ticket'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: 'Reason for cancellation'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (reasonController.text.isNotEmpty) {
                final currentUser = ref.read(currentUserProvider);
                await ticketRepo.cancelTicket(
                  idTicket: ticket.idTicket,
                  idUser: currentUser!.idUser,
                  reason: reasonController.text,
                );
                ref.invalidate(ticketDetailProvider(ticket.idTicket));
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket cancelled')));
              }
            },
            child: const Text('Cancel Ticket'),
          ),
        ],
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  final Comment comment;
  final int? currentUserId;

  const _CommentCard({required this.comment, this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(comment.username ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  if (comment.isEdited) const Text('(edited) ', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                  Text(_formatDate(comment.createdAt), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(comment.message),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
