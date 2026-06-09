class ScrapeCandidate {
  final int id;
  final String rawText;
  final String sourceChannel;
  final String dedupStatus;
  final String? sourceLabel;
  final String? originalPostedAtUtc;
  final int? viewCount;
  final bool isUsable;

  const ScrapeCandidate({
    required this.id,
    required this.rawText,
    required this.sourceChannel,
    required this.dedupStatus,
    this.sourceLabel,
    this.originalPostedAtUtc,
    this.viewCount,
    required this.isUsable,
  });

  factory ScrapeCandidate.fromJson(Map<String, dynamic> json) {
    final dedupStatus = json['dedup_status'] as String? ?? 'pending';
    return ScrapeCandidate(
      id: (json['id'] as num).toInt(),
      rawText: json['raw_text'] as String? ?? '',
      sourceChannel: json['source_channel'] as String? ?? 'Unknown',
      dedupStatus: dedupStatus,
      sourceLabel: json['source_label'] as String?,
      originalPostedAtUtc: json['original_posted_at_utc'] as String?,
      viewCount: (json['view_count'] as num?)?.toInt(),
      isUsable: dedupStatus != 'duplicate',
    );
  }
}
