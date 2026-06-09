import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../shared/models/draft.dart';

class DraftsPage {
  final List<Draft> items;
  final int page;
  final int perPage;
  final int totalItems;
  final int totalPages;

  const DraftsPage({
    required this.items,
    required this.page,
    required this.perPage,
    required this.totalItems,
    required this.totalPages,
  });
}

class DraftRepository {
  final Ref ref;

  DraftRepository(this.ref);

  Future<DraftsPage> fetchDrafts(
    int workspaceId, {
    int page = 1,
    int perPage = 20,
    String? status,
    String? query,
    List<int> sourceChannelIds = const [],
    String? scrapedFromUtc,
    String? scrapedToUtc,
  }) async {
    final client = ref.read(apiClientProvider);
    final response = await client.get(
      '/workspaces/$workspaceId/drafts',
      queryParameters: {
        'page': page,
        'per_page': perPage,
        if (status != null && status.isNotEmpty) 'status': status,
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        if (sourceChannelIds.isNotEmpty)
          'source_channel_ids': sourceChannelIds.join(','),
        if (scrapedFromUtc != null) 'scraped_from_utc': scrapedFromUtc,
        if (scrapedToUtc != null) 'scraped_to_utc': scrapedToUtc,
      },
    );
    final payload = response.data['data'] as Map<String, dynamic>;
    final list = payload['items'] as List<dynamic>;
    final meta = payload['meta'] as Map<String, dynamic>? ?? const {};
    return DraftsPage(
      items: list
          .map((json) => Draft.fromJson(json as Map<String, dynamic>))
          .toList(),
      page: (meta['page'] as num?)?.toInt() ?? page,
      perPage: (meta['per_page'] as num?)?.toInt() ?? perPage,
      totalItems: (meta['total_items'] as num?)?.toInt() ?? list.length,
      totalPages: (meta['total_pages'] as num?)?.toInt() ?? 1,
    );
  }

  Future<Draft> fetchDraft(int workspaceId, int draftId) async {
    final client = ref.read(apiClientProvider);
    final response =
        await client.get('/workspaces/$workspaceId/drafts/$draftId');
    return Draft.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<Draft> createDraft(int workspaceId, List<int> sourcePostIds) async {
    final client = ref.read(apiClientProvider);
    final response = await client.post(
      '/workspaces/$workspaceId/drafts',
      data: {'source_post_ids': sourcePostIds},
    );
    return Draft.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<Draft> regenerateDraft(
    int workspaceId,
    int draftId, {
    String? instruction,
  }) async {
    final client = ref.read(apiClientProvider);
    final response = await client.post(
      '/workspaces/$workspaceId/drafts/$draftId/regenerate',
      data: {'instruction': instruction},
    );
    return Draft.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<Draft> saveDraftText(
    int workspaceId, {
    required int draftId,
    required String generatedText,
  }) async {
    final client = ref.read(apiClientProvider);
    final response = await client.patch(
      '/workspaces/$workspaceId/drafts/$draftId/text',
      data: {'generated_text': generatedText},
    );
    return Draft.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<Draft> publishDraft(int workspaceId, int draftId) async {
    final client = ref.read(apiClientProvider);
    final response =
        await client.post('/workspaces/$workspaceId/drafts/$draftId/publish');
    return Draft.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<Draft> scheduleDraft(
    int workspaceId,
    int draftId,
    String scheduledAtUtc,
  ) async {
    final client = ref.read(apiClientProvider);
    final response = await client.post(
      '/workspaces/$workspaceId/drafts/$draftId/schedule',
      data: {'scheduled_at': scheduledAtUtc},
    );
    return Draft.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> deleteDraft(int workspaceId, int draftId) async {
    final client = ref.read(apiClientProvider);
    await client.delete('/workspaces/$workspaceId/drafts/$draftId');
  }
}

final draftRepositoryProvider =
    Provider<DraftRepository>((ref) => DraftRepository(ref));

final draftsProvider = FutureProvider.family<
    DraftsPage,
    ({
      int workspaceId,
      int page,
      String? status,
      String? query,
      String? sourceChannelIdsCsv,
      String? scrapedFromUtc,
      String? scrapedToUtc,
    })>((ref, args) {
  final sourceChannelIds = (args.sourceChannelIdsCsv == null ||
          args.sourceChannelIdsCsv!.trim().isEmpty)
      ? const <int>[]
      : args.sourceChannelIdsCsv!
          .split(',')
          .map((value) => int.tryParse(value.trim()))
          .whereType<int>()
          .toList(growable: false);
  return ref.read(draftRepositoryProvider).fetchDrafts(
        args.workspaceId,
        page: args.page,
        perPage: 20,
        status: args.status,
        query: args.query,
        sourceChannelIds: sourceChannelIds,
        scrapedFromUtc: args.scrapedFromUtc,
        scrapedToUtc: args.scrapedToUtc,
      );
});

final draftDetailProvider =
    FutureProvider.family<Draft, ({int workspaceId, int draftId})>((ref, args) {
  return ref
      .read(draftRepositoryProvider)
      .fetchDraft(args.workspaceId, args.draftId);
});
