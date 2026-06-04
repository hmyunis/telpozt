class SourceChannel {
  final int id;
  final int workspaceId;
  final String channelId;
  final String? displayName;
  final String priority;
  final bool isActive;
  final String? lastScrapedAt;

  SourceChannel({required this.id, required this.workspaceId, required this.channelId, this.displayName, required this.priority, required this.isActive, this.lastScrapedAt});

  factory SourceChannel.fromJson(Map<String, dynamic> json) => SourceChannel(
        id: json['id'] as int,
        workspaceId: json['workspace_id'] as int,
        channelId: json['channel_id'] as String,
        displayName: json['display_name'] as String?,
        priority: json['priority'] as String? ?? 'normal',
        isActive: (json['is_active'] as int? ?? 1) == 1,
        lastScrapedAt: json['last_scraped_at'] as String?,
      );

  Map<String, dynamic> toJson() => {'id': id, 'workspace_id': workspaceId, 'channel_id': channelId, 'display_name': displayName, 'priority': priority, 'is_active': isActive ? 1 : 0, 'last_scraped_at': lastScrapedAt};
}
