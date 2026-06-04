class PostHistory {
  final int id;
  final int queueId;
  final int workspaceId;
  final String finalText;
  final String? sourceChannel;
  final String? telegramMessageId;
  final String postedAtUtc;

  PostHistory({required this.id, required this.queueId, required this.workspaceId, required this.finalText, this.sourceChannel, this.telegramMessageId, required this.postedAtUtc});

  factory PostHistory.fromJson(Map<String, dynamic> json) => PostHistory(
        id: json['id'] as int,
        queueId: json['queue_id'] as int,
        workspaceId: json['workspace_id'] as int,
        finalText: json['final_text'] as String,
        sourceChannel: json['source_channel'] as String?,
        telegramMessageId: json['telegram_message_id'] as String?,
        postedAtUtc: json['posted_at_utc'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'queue_id': queueId, 'workspace_id': workspaceId, 'final_text': finalText, 'source_channel': sourceChannel, 'telegram_message_id': telegramMessageId, 'posted_at_utc': postedAtUtc};
}
