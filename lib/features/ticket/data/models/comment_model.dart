class Comment {
  final int idComment;
  final int idTicket;
  final int idUser;
  final String message;
  final bool isEdited;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Joined data
  final String? username;

  Comment({
    required this.idComment,
    required this.idTicket,
    required this.idUser,
    required this.message,
    required this.isEdited,
    required this.createdAt,
    required this.updatedAt,
    this.username,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      idComment: json['id_comment'] as int,
      idTicket: json['id_ticket'] as int,
      idUser: json['id_user'] as int,
      message: json['message'] as String,
      isEdited: json['is_edited'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      username: json['username'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_comment': idComment,
      'id_ticket': idTicket,
      'id_user': idUser,
      'message': message,
      'is_edited': isEdited,
    };
  }

  Comment copyWith({
    int? idComment,
    int? idTicket,
    int? idUser,
    String? message,
    bool? isEdited,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? username,
  }) {
    return Comment(
      idComment: idComment ?? this.idComment,
      idTicket: idTicket ?? this.idTicket,
      idUser: idUser ?? this.idUser,
      message: message ?? this.message,
      isEdited: isEdited ?? this.isEdited,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      username: username ?? this.username,
    );
  }
}
