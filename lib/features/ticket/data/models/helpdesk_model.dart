class Helpdesk {
  final int idHelpdesk;
  final int idUser;
  final String name;
  final String? phone;
  final bool isAvailable;
  final DateTime createdAt;
  
  // Joined data
  final String? username;

  Helpdesk({
    required this.idHelpdesk,
    required this.idUser,
    required this.name,
    this.phone,
    required this.isAvailable,
    required this.createdAt,
    this.username,
  });

  factory Helpdesk.fromJson(Map<String, dynamic> json) {
    return Helpdesk(
      idHelpdesk: json['id_helpdesk'] as int,
      idUser: json['id_user'] as int,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      isAvailable: json['is_available'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      username: json['username'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_helpdesk': idHelpdesk,
      'id_user': idUser,
      'name': name,
      'phone': phone,
      'is_available': isAvailable,
    };
  }

  Helpdesk copyWith({
    int? idHelpdesk,
    int? idUser,
    String? name,
    String? phone,
    bool? isAvailable,
    DateTime? createdAt,
    String? username,
  }) {
    return Helpdesk(
      idHelpdesk: idHelpdesk ?? this.idHelpdesk,
      idUser: idUser ?? this.idUser,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      isAvailable: isAvailable ?? this.isAvailable,
      createdAt: createdAt ?? this.createdAt,
      username: username ?? this.username,
    );
  }
}
