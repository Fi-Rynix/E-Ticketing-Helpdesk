class Notification {
  final int idNotification;
  final int idUser;
  final String type;
  final String title;
  final String body;
  final int? idTicket;
  final bool isRead;
  final DateTime createdAt;

  Notification({
    required this.idNotification,
    required this.idUser,
    required this.type,
    required this.title,
    required this.body,
    this.idTicket,
    required this.isRead,
    required this.createdAt,
  });

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      idNotification: json['id_notification'] as int,
      idUser: json['id_user'] as int,
      type: json['type'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      idTicket: json['id_ticket'] as int?,
      isRead: json['is_read'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Notification copyWith({
    int? idNotification,
    int? idUser,
    String? type,
    String? title,
    String? body,
    int? idTicket,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return Notification(
      idNotification: idNotification ?? this.idNotification,
      idUser: idUser ?? this.idUser,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      idTicket: idTicket ?? this.idTicket,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
