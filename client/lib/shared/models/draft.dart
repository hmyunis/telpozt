import 'scrape_candidate.dart';

class Draft {
  final int id;
  final int workspaceId;
  final String rawSourceText;
  final String? generatedText;
  final String? lastGenerationInstruction;
  final String generationStatus;
  final String state;
  final String status;
  final String? scheduledAtUtc;
  final String? postedAtUtc;
  final String? failureReason;
  final int retryCount;
  final List<int> selectedSourceIds;
  final List<ScrapeCandidate> selectedSources;
  final String createdAt;
  final String updatedAt;

  const Draft({
    required this.id,
    required this.workspaceId,
    required this.rawSourceText,
    required this.generatedText,
    required this.lastGenerationInstruction,
    required this.generationStatus,
    required this.state,
    required this.status,
    required this.scheduledAtUtc,
    required this.postedAtUtc,
    required this.failureReason,
    required this.retryCount,
    required this.selectedSourceIds,
    required this.selectedSources,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Draft.fromJson(Map<String, dynamic> json) {
    final sourceIds =
        (json['selected_source_ids'] as List<dynamic>? ?? const [])
            .map((value) => (value as num).toInt())
            .toList();
    final sourceRows = (json['selected_sources'] as List<dynamic>? ?? const [])
        .map((row) => ScrapeCandidate.fromJson({
              'id': row['scraped_post_id'],
              'raw_text': row['raw_text'],
              'source_channel': row['source_channel_id'],
              'source_label': row['source_label'],
              'dedup_status': row['dedup_status'],
            }))
        .toList();

    return Draft(
      id: (json['id'] as num).toInt(),
      workspaceId: (json['workspace_id'] as num).toInt(),
      rawSourceText: json['raw_source_text'] as String? ?? '',
      generatedText: json['generated_text'] as String?,
      lastGenerationInstruction: json['last_generation_instruction'] as String?,
      generationStatus: json['generation_status'] as String? ?? 'pending',
      state: json['state'] as String? ?? 'draft',
      status: json['status'] as String? ?? 'draft',
      scheduledAtUtc: json['scheduled_at_utc'] as String?,
      postedAtUtc: json['posted_at_utc'] as String?,
      failureReason: json['failure_reason'] as String?,
      retryCount: (json['retry_count'] as num?)?.toInt() ?? 0,
      selectedSourceIds: sourceIds,
      selectedSources: sourceRows,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }
}
