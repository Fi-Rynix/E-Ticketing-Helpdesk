enum TicketStatus {
  open,
  assigned,
  inProgress,
  pendingUnassign,
  done,
  cancelled;

  String get value {
    switch (this) {
      case TicketStatus.open:
        return 'open';
      case TicketStatus.assigned:
        return 'assigned';
      case TicketStatus.inProgress:
        return 'in_progress';
      case TicketStatus.pendingUnassign:
        return 'pending_unassign';
      case TicketStatus.done:
        return 'done';
      case TicketStatus.cancelled:
        return 'cancelled';
    }
  }

  static TicketStatus fromString(String value) {
    switch (value) {
      case 'open':
        return TicketStatus.open;
      case 'assigned':
        return TicketStatus.assigned;
      case 'in_progress':
        return TicketStatus.inProgress;
      case 'pending_unassign':
        return TicketStatus.pendingUnassign;
      case 'done':
        return TicketStatus.done;
      case 'cancelled':
        return TicketStatus.cancelled;
      default:
        return TicketStatus.open;
    }
  }

  String get label {
    switch (this) {
      case TicketStatus.open:
        return 'OPEN';
      case TicketStatus.assigned:
        return 'ASSIGNED';
      case TicketStatus.inProgress:
        return 'IN PROGRESS';
      case TicketStatus.pendingUnassign:
        return 'PENDING UNASSIGN';
      case TicketStatus.done:
        return 'DONE';
      case TicketStatus.cancelled:
        return 'CANCELLED';
    }
  }
}

class Ticket {
  final int idTicket;
  final String title;
  final String description;
  final TicketStatus status;
  final int idUser; // creator
  final int? idHelpdesk; // assigned helpdesk
  final String? photoPath;
  
  // Unassign fields
  final int? unassignIdHelpdesk;
  final DateTime? unassignRequestedAt;
  final String? unassignReason;
  final int? unassignIdUser;
  final DateTime? unassignDecidedAt;
  final String? unassignRejectReason;
  
  // Timestamps
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancelledReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined data (optional, populated when needed)
  final String? creatorUsername;
  final String? helpdeskName;

  Ticket({
    required this.idTicket,
    required this.title,
    required this.description,
    required this.status,
    required this.idUser,
    this.idHelpdesk,
    this.photoPath,
    this.unassignIdHelpdesk,
    this.unassignRequestedAt,
    this.unassignReason,
    this.unassignIdUser,
    this.unassignDecidedAt,
    this.unassignRejectReason,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
    this.cancelledReason,
    required this.createdAt,
    required this.updatedAt,
    this.creatorUsername,
    this.helpdeskName,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      idTicket: json['id_ticket'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      status: TicketStatus.fromString(json['status'] as String),
      idUser: json['id_user'] as int,
      idHelpdesk: json['id_helpdesk'] as int?,
      photoPath: json['photo_path'] as String?,
      unassignIdHelpdesk: json['unassign_id_helpdesk'] as int?,
      unassignRequestedAt: json['unassign_requested_at'] != null
          ? DateTime.parse(json['unassign_requested_at'] as String)
          : null,
      unassignReason: json['unassign_reason'] as String?,
      unassignIdUser: json['unassign_id_user'] as int?,
      unassignDecidedAt: json['unassign_decided_at'] != null
          ? DateTime.parse(json['unassign_decided_at'] as String)
          : null,
      unassignRejectReason: json['unassign_reject_reason'] as String?,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'] as String)
          : null,
      cancelledReason: json['cancelled_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      creatorUsername: json['creator_username'] as String?,
      helpdeskName: json['helpdesk_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_ticket': idTicket,
      'title': title,
      'description': description,
      'status': status.value,
      'id_user': idUser,
      'id_helpdesk': idHelpdesk,
      'photo_path': photoPath,
    };
  }

  Ticket copyWith({
    int? idTicket,
    String? title,
    String? description,
    TicketStatus? status,
    int? idUser,
    int? idHelpdesk,
    String? photoPath,
    int? unassignIdHelpdesk,
    DateTime? unassignRequestedAt,
    String? unassignReason,
    int? unassignIdUser,
    DateTime? unassignDecidedAt,
    String? unassignRejectReason,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    String? cancelledReason,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? creatorUsername,
    String? helpdeskName,
  }) {
    return Ticket(
      idTicket: idTicket ?? this.idTicket,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      idUser: idUser ?? this.idUser,
      idHelpdesk: idHelpdesk ?? this.idHelpdesk,
      photoPath: photoPath ?? this.photoPath,
      unassignIdHelpdesk: unassignIdHelpdesk ?? this.unassignIdHelpdesk,
      unassignRequestedAt: unassignRequestedAt ?? this.unassignRequestedAt,
      unassignReason: unassignReason ?? this.unassignReason,
      unassignIdUser: unassignIdUser ?? this.unassignIdUser,
      unassignDecidedAt: unassignDecidedAt ?? this.unassignDecidedAt,
      unassignRejectReason: unassignRejectReason ?? this.unassignRejectReason,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelledReason: cancelledReason ?? this.cancelledReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      creatorUsername: creatorUsername ?? this.creatorUsername,
      helpdeskName: helpdeskName ?? this.helpdeskName,
    );
  }

  String get statusString => status.value;
}
