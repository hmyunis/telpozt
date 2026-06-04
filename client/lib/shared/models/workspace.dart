class Workspace {
  final int id;
  final int? userId;
  final String name;
  final String targetChannelId;
  final String botToken;
  final int? styleProfileId;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  Workspace({
    required this.id,
    this.userId,
    required this.name,
    required this.targetChannelId,
    required this.botToken,
    this.styleProfileId,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Workspace.fromJson(Map<String, dynamic> json) => Workspace(
        id: _asInt(json['id']) ?? 0,
        userId: _asInt(json['user_id']),
        name: json['name'] as String? ?? '',
        targetChannelId: json['target_channel_id'] as String? ?? '',
        botToken: json['bot_token'] as String? ?? '',
        styleProfileId: _asInt(json['style_profile_id']),
        isActive: _asBool(json['is_active']),
        createdAt: json['created_at'] as String? ?? '',
        updatedAt: json['updated_at'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'id': id, 'user_id': userId, 'name': name, 'target_channel_id': targetChannelId, 'bot_token': botToken, 'style_profile_id': styleProfileId, 'is_active': isActive ? 1 : 0, 'created_at': createdAt, 'updated_at': updatedAt};

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return true;
  }
}
