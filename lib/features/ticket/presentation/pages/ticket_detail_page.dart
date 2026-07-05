import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/ticket_model.dart';
import '../../data/models/comment_model.dart';
import '../../data/repositories/ticket_repository.dart';
import '../../data/repositories/comment_repository.dart';
import '../../data/repositories/helpdesk_repository.dart';
import '../providers/ticket_provider.dart';
import '../providers/comment_provider.dart';
import '../providers/helpdesk_provider.dart';
import 'create_ticket_page.dart';
import '../../../../core/constants/app_constants.dart';

class TicketDetailPage extends ConsumerStatefulWidget {
  final int ticketId;

  const TicketDetailPage({super.key, required this.ticketId});

  @override
  ConsumerState<TicketDetailPage> createState() => _TicketDetailPageState();
}

class _TicketDetailPageState extends ConsumerState<TicketDetailPage> {
  final _commentController = TextEditingController();
  final _commentRepo = CommentRepository();
  String? _creatorName;
  String? _helpdeskName;
  bool _isSubmittingComment = false;
  List<File> _attachedImages = []; // Changed: List instead of single File
  final _imagePicker = ImagePicker();
  static const int _maxAttachments = 3; // Maximum attachments per comment

  @override
  void initState() {
    super.initState();
    _loadNames();
  }

  void _loadNames() async {
    final ticketRepo = TicketRepository();
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

  Future<void> _pickImage() async {
    // Validate max limit before opening picker
    if (_attachedImages.length >= _maxAttachments) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maksimal $_maxAttachments foto per komentar')),
      );
      return;
    }

    try {
      // Use pickMultiImage for multiple selection
      final List<XFile> images = await _imagePicker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (images.isEmpty) return;

      // Calculate how many we can still add
      final remaining = _maxAttachments - _attachedImages.length;
      final toAdd = images.take(remaining).map((x) => File(x.path)).toList();

      if (toAdd.length < images.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hanya ${toAdd.length} foto yang ditambahkan (max $_maxAttachments)')),
        );
      }

      setState(() {
        _attachedImages = [..._attachedImages, ...toAdd];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  void _removeImageAt(int index) {
    setState(() {
      _attachedImages = List.from(_attachedImages)..removeAt(index);
    });
  }

  void _addComment(int idTicket, int? idUser) async {
    if (_commentController.text.isEmpty && _attachedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message or attach an image')),
      );
      return;
    }

    if (idUser == null) return;

    setState(() => _isSubmittingComment = true);

    try {
      // Create comment
      final comment = await _commentRepo.addComment(
        idTicket: idTicket,
        idUser: idUser,
        message: _commentController.text.isEmpty ? '(image)' : _commentController.text,
      );

      // Upload all attached images
      if (comment != null && _attachedImages.isNotEmpty) {
        for (final image in _attachedImages) {
          try {
            final fileSize = await image.length();
            await _commentRepo.uploadAttachment(
              idComment: comment.idComment,
              filePath: image.path,
              mimeType: 'image/jpeg',
              fileSize: fileSize,
            );
          } catch (e) {
            print('Failed to upload attachment: $e');
            // Continue with other uploads
          }
        }
      }

      // Clear inputs
      _commentController.clear();
      setState(() {
        _attachedImages = [];
        _isSubmittingComment = false;
      });

      // Refresh comments
      ref.invalidate(ticketCommentsProvider(idTicket));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment posted')),
        );
      }
    } catch (e) {
      setState(() => _isSubmittingComment = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post comment: $e')),
        );
      }
    }
  }

  void _showEditCommentDialog(BuildContext context, Comment comment) {
    final editController = TextEditingController(text: comment.message);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Comment'),
        content: TextField(controller: editController, maxLines: 3, decoration: const InputDecoration(hintText: 'Edit your comment...', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (editController.text.isNotEmpty) {
                try {
                  final currentUser = ref.read(currentUserProvider);
                  await _commentRepo.editComment(idComment: comment.idComment, idUser: currentUser!.idUser, message: editController.text);
                  ref.invalidate(ticketCommentsProvider(widget.ticketId));
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comment updated')));
                } catch (e) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, Comment comment) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                final currentUser = ref.read(currentUserProvider);
                await _commentRepo.deleteComment(idComment: comment.idComment, idUser: currentUser!.idUser);
                ref.invalidate(ticketCommentsProvider(widget.ticketId));
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comment deleted')));
              } catch (e) {
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(imageUrl),
            ),
          ),
        ),
      ),
    );
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('#${ticket.idTicket}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    _StatusBadge(status: ticket.status),
                  ],
                ),
                const SizedBox(height: 16),
                Text(ticket.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                // Tracking button
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pushNamed(
                    AppConstants.routeTrackingTicket,
                    arguments: ticket,
                  ),
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('Lihat Tracking Lengkap'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF000072),
                    side: const BorderSide(color: Color(0xFF000072)),
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(title: 'Description', child: Text(ticket.description)),
                const SizedBox(height: 16),

                // Photo section (if exists)
                if (ticket.photoPath != null && ticket.photoPath!.isNotEmpty) ...[
                  const Text('Photo', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _showFullScreenImage(context, ticket.photoPath!),
                    child: Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: NetworkImage(ticket.photoPath!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _InfoRow(label: 'Created by', value: _creatorName ?? 'Loading...'),
                _InfoRow(label: 'Created at', value: _formatDate(ticket.createdAt)),
                if (ticket.idHelpdesk != null)
                  _InfoRow(label: 'Assigned to', value: _helpdeskName ?? 'Loading...'),
                const SizedBox(height: 16),

                // Role-based sections
                if (currentUser?.role == 'admin') ...[
                  const Divider(), const SizedBox(height: 8),
                  const Text('Admin Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _AdminActionsSection(ticket: ticket),
                  const SizedBox(height: 16),
                ],

                if (currentUser?.role == 'helpdesk') ...[
                  const Divider(), const SizedBox(height: 8),
                  const Text('Helpdesk Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _HelpdeskActionsSection(ticket: ticket),
                  const SizedBox(height: 16),
                ],

                if (currentUser?.role == 'user' && ticket.status == TicketStatus.open) ...[
                  const Divider(), const SizedBox(height: 8),
                  _UserActionsSection(ticket: ticket),
                  const SizedBox(height: 16),
                ],

                const Divider(), const SizedBox(height: 8),
                const Text('Comments', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                commentsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(
                    child: Column(
                      children: [
                        Text('Error loading comments: $e', style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => ref.invalidate(ticketCommentsProvider(widget.ticketId)),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                  data: (comments) {
                    if (comments.isEmpty) return const Text('No comments yet');
                    return Column(
                      children: comments.map((c) => _CommentCard(
                        comment: c,
                        currentUserId: currentUser?.idUser,
                        onEdit: () => _showEditCommentDialog(context, c),
                        onDelete: () => _showDeleteConfirmDialog(context, c),
                      )).toList(),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Comment input with image attachment
                TextField(
                  controller: _commentController,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: 'Add a comment...', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),

                // Image attachment preview (multiple, max 3)
                if (_attachedImages.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Lampiran (${_attachedImages.length}/$_maxAttachments)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                      ),
                      if (_attachedImages.length >= _maxAttachments)
                        const Text(
                          'MAX tercapai',
                          style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 90,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _attachedImages.length,
                      itemBuilder: (_, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  _attachedImages[index],
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () => _removeImageAt(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    child: const Icon(Icons.close, color: Colors.white, size: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Action buttons
                Row(
                  children: [
                    IconButton(
                      onPressed: _attachedImages.length >= _maxAttachments ? null : _pickImage,
                      icon: const Icon(Icons.image),
                      tooltip: _attachedImages.length >= _maxAttachments
                          ? 'Maks $_maxAttachments foto tercapai'
                          : 'Attach image (max $_maxAttachments)',
                    ),
                    if (_attachedImages.isNotEmpty)
                      Text(
                        '${_attachedImages.length}/$_maxAttachments',
                        style: TextStyle(fontSize: 12, color: _attachedImages.length >= _maxAttachments ? Colors.red : Colors.grey),
                      ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: _isSubmittingComment
                          ? null
                          : () => _addComment(ticket.idTicket, currentUser?.idUser),
                      child: _isSubmittingComment
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Post Comment'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ================ Helper Widgets ================

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        child,
      ]),
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
      decoration: BoxDecoration(color: _getColor(), borderRadius: BorderRadius.circular(6)),
      child: Text(status.label, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
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
    final flow = ticket.status == TicketStatus.cancelled ? ['open', 'cancelled'] : ['open', 'assigned', 'in_progress', 'done'];
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
                        style: TextStyle(color: isCompleted || isCurrent ? Colors.white : Colors.grey, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(_getStatusLabel(status), style: TextStyle(fontSize: 9, color: isCurrent ? Colors.black : Colors.grey)),
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

// ================ Admin Actions ================

class _AdminActionsSection extends ConsumerWidget {
  final Ticket ticket;
  const _AdminActionsSection({required this.ticket});

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
              decoration: const InputDecoration(labelText: 'Assign Helpdesk', border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem(value: null, child: Text('Unassigned')),
                ...helpdesks.map((h) => DropdownMenuItem(value: h.idHelpdesk, child: Text(h.name))),
              ],
              onChanged: ticket.status == TicketStatus.open ? (idHelpdesk) async {
                if (idHelpdesk != null) {
                  try {
                    final ticketRepo = TicketRepository();
                    await ticketRepo.assignTicket(idTicket: ticket.idTicket, idHelpdesk: idHelpdesk);
                    ref.invalidate(ticketDetailProvider(ticket.idTicket));
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket assigned')));
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              } : null,
            );
          },
        ),
        const SizedBox(height: 12),
        if (ticket.status == TicketStatus.pendingUnassign) ...[
          Text('Unassign Request:', style: TextStyle(fontWeight: FontWeight.bold)),
          Text('Reason: ${ticket.unassignReason ?? '-'}'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: ElevatedButton(
                onPressed: () async {
                  try {
                    final currentUser = ref.read(currentUserProvider);
                    final ticketRepo = TicketRepository();
                    await ticketRepo.approveUnassign(idTicket: ticket.idTicket, idAdmin: currentUser!.idUser);
                    ref.invalidate(ticketDetailProvider(ticket.idTicket));
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unassign approved')));
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
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

  void _showRejectDialog(BuildContext context, WidgetRef ref) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Unassign'),
        content: TextField(controller: reasonController, decoration: const InputDecoration(labelText: 'Reason')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.isNotEmpty) {
                try {
                  final currentUser = ref.read(currentUserProvider);
                  final ticketRepo = TicketRepository();
                  await ticketRepo.rejectUnassign(idTicket: ticket.idTicket, idAdmin: currentUser!.idUser, reason: reasonController.text);
                  ref.invalidate(ticketDetailProvider(ticket.idTicket));
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unassign rejected')));
                } catch (e) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}

// ================ Helpdesk Actions ================

class _HelpdeskActionsSection extends ConsumerWidget {
  final Ticket ticket;
  const _HelpdeskActionsSection({required this.ticket});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);

    if (ticket.status == TicketStatus.assigned) {
      return ElevatedButton.icon(
        onPressed: () async {
          try {
            final helpdeskRepo = HelpdeskRepository();
            final helpdesk = await helpdeskRepo.getHelpdeskByUserId(currentUser!.idUser);
            if (helpdesk != null) {
              final ticketRepo = TicketRepository();
              await ticketRepo.startTicket(idTicket: ticket.idTicket, idHelpdesk: helpdesk.idHelpdesk);
              ref.invalidate(ticketDetailProvider(ticket.idTicket));
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Started working on ticket')));
            }
          } catch (e) {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
          }
        },
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start Working'),
      );
    }

    if (ticket.status == TicketStatus.inProgress) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: ElevatedButton.icon(
                onPressed: () async {
                  try {
                    final helpdeskRepo = HelpdeskRepository();
                    final helpdesk = await helpdeskRepo.getHelpdeskByUserId(currentUser!.idUser);
                    if (helpdesk != null) {
                      final ticketRepo = TicketRepository();
                      await ticketRepo.completeTicket(idTicket: ticket.idTicket, idHelpdesk: helpdesk.idHelpdesk);
                      ref.invalidate(ticketDetailProvider(ticket.idTicket));
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket marked as done')));
                    }
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                icon: const Icon(Icons.check),
                label: const Text('Mark Done'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              )),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(
                onPressed: () => _showUnassignDialog(context, ref),
                icon: const Icon(Icons.exit_to_app),
                label: const Text('Request Unassign'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
              )),
            ],
          ),
        ],
      );
    }

    return const Text('No actions available');
  }

  void _showUnassignDialog(BuildContext context, WidgetRef ref) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request Unassign'),
        content: TextField(controller: reasonController, decoration: const InputDecoration(labelText: 'Reason')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.isNotEmpty) {
                try {
                  final currentUser = ref.read(currentUserProvider);
                  final helpdeskRepo = HelpdeskRepository();
                  final helpdesk = await helpdeskRepo.getHelpdeskByUserId(currentUser!.idUser);
                  if (helpdesk != null) {
                    final ticketRepo = TicketRepository();
                    await ticketRepo.requestUnassign(idTicket: ticket.idTicket, idHelpdesk: helpdesk.idHelpdesk, reason: reasonController.text);
                    ref.invalidate(ticketDetailProvider(ticket.idTicket));
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unassign requested')));
                } catch (e) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Request'),
          ),
        ],
      ),
    );
  }
}

// ================ User Actions ================

class _UserActionsSection extends ConsumerWidget {
  final Ticket ticket;
  const _UserActionsSection({required this.ticket});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              final result = await Navigator.of(context).pushNamed(
                AppConstants.routeEditTicket,
                arguments: ticket,
              );
              if (result == true && context.mounted) {
                // TicketDetailPage will auto-refresh via provider invalidate
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ticket updated')),
                );
              }
            },
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Edit'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: () => _showCancelDialog(context, ref),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Ticket'),
          ),
        ),
      ],
    );
  }

  void _showCancelDialog(BuildContext context, WidgetRef ref) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Ticket'),
        content: TextField(controller: reasonController, decoration: const InputDecoration(labelText: 'Reason for cancellation')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (reasonController.text.isNotEmpty) {
                try {
                  final currentUser = ref.read(currentUserProvider);
                  final ticketRepo = TicketRepository();
                  await ticketRepo.cancelTicket(idTicket: ticket.idTicket, idUser: currentUser!.idUser, reason: reasonController.text);
                  ref.invalidate(ticketDetailProvider(ticket.idTicket));
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket cancelled')));
                } catch (e) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Cancel Ticket'),
          ),
        ],
      ),
    );
  }
}

// ================ Comment Card ================

class _CommentCard extends StatelessWidget {
  final Comment comment;
  final int? currentUserId;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _CommentCard({required this.comment, this.currentUserId, this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isOwnComment = currentUserId == comment.idUser;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
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
                  Text('${comment.createdAt.day}/${comment.createdAt.month}/${comment.createdAt.year}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  if (isOwnComment) ...[
                    const SizedBox(width: 8),
                    GestureDetector(onTap: onEdit, child: Icon(Icons.edit, size: 16, color: Colors.grey[600])),
                    const SizedBox(width: 4),
                    GestureDetector(onTap: onDelete, child: const Icon(Icons.delete, size: 16, color: Colors.red)),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(comment.message),
          
          // Show attachments
          if (comment.attachments != null && comment.attachments!.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: comment.attachments!.length,
                itemBuilder: (context, index) {
                  final attachment = comment.attachments![index];
                  return Container(
                    width: 100,
                    height: 100,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: NetworkImage(attachment.storagePath),
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
