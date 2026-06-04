class User {
  final int id;
  final String username;
  final String telegramChatId;
  final String timezone;
  final String? createdAt;

  User({
    required this.id,
    required this.username,
    required this.telegramChatId,
    required this.timezone,
    this.createdAt,
  });

  User copyWith({
    int? id,
    String? username,
    String? telegramChatId,
    String? timezone,
    String? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      telegramChatId: telegramChatId ?? this.telegramChatId,
      timezone: timezone ?? this.timezone,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      username: json['username'] as String,
      telegramChatId: json['telegram_chat_id'] as String,
      timezone: json['timezone'] as String? ?? 'UTC',
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'telegram_chat_id': telegramChatId,
      'timezone': timezone,
      'created_at': createdAt,
    };
  }
}
