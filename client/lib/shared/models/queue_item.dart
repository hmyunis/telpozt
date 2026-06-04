class QueueItem {
  final int id;
  final int workspaceId;
  final int? scrapedPostId;
  final String rawSourceText;
  final String? generatedText;
  final String generationStatus;
  final String state;
  final String? scheduledAtUtc;
  final String? postedAtUtc;
  final String? failureReason;
  final int retryCount;
  final String createdAt;
  final String updatedAt;

  QueueItem({required this.id, required this.workspaceId, this.scrapedPostId, required this.rawSourceText, this.generatedText, required this.generationStatus, required this.state, this.scheduledAtUtc, this.postedAtUtc, this.failureReason, required this.retryCount, required this.createdAt, required this.updatedAt});

  factory QueueItem.fromJson(Map<String, dynamic> json) => QueueItem(
        id: json['id'] as int,
        workspaceId: json['workspace_id'] as int,
        scrapedPostId: json['scraped_post_id'] as int?,
        rawSourceText: json['raw_source_text'] as String,
        generatedText: json['generated_text'] as String?,
        generationStatus: json['generation_status'] as String? ?? 'pending',
        state: json['state'] as String? ?? 'draft',
        scheduledAtUtc: json['scheduled_at_utc'] as String?,
        postedAtUtc: json['posted_at_utc'] as String?,
        failureReason: json['failure_reason'] as String?,
        retryCount: json['retry_count'] as int? ?? 0,
        createdAt: json['created_at'] as String,
        updatedAt: json['updated_at'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'workspace_id': workspaceId, 'scraped_post_id': scrapedPostId, 'raw_source_text': rawSourceText, 'generated_text': generatedText, 'generation_status': generationStatus, 'state': state, 'scheduled_at_utc': scheduledAtUtc, 'posted_at_utc': postedAtUtc, 'failure_reason': failureReason, 'retry_count': retryCount, 'created_at': createdAt, 'updated_at': updatedAt};
}
