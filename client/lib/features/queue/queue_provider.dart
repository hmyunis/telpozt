import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../shared/models/queue_item.dart';

class QueueRepository {
  final Ref ref;
  QueueRepository(this.ref);

  Future<List<QueueItem>> fetchQueue(int workspaceId) async {
    final client = ref.read(apiClientProvider);
    final response = await client.get('/workspaces/$workspaceId/queue', queryParameters: {'page': 1, 'per_page': 100});
    final list = response.data['data']['items'] as List;
    return list.map((json) => QueueItem.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<void> createQueueItem(int workspaceId, String rawText) async {
    final client = ref.read(apiClientProvider);
    await client.post('/workspaces/$workspaceId/queue', data: {'raw_text': rawText});
  }

  Future<void> updateItemState(int workspaceId, {required int queueId, required String action, String? scheduledAt}) async {
    final client = ref.read(apiClientProvider);
    await client.patch('/workspaces/$workspaceId/queue/$queueId', data: {
      'action': action,
      if (scheduledAt != null) 'scheduled_at': scheduledAt,
    });
  }

  Future<void> deleteQueueItem(int workspaceId, int queueId) async {
    final client = ref.read(apiClientProvider);
    await client.delete('/workspaces/$workspaceId/queue/$queueId');
  }

  Future<void> saveManualText(int workspaceId, {required int queueId, required String generatedText}) async {
    final client = ref.read(apiClientProvider);
    await client.patch('/workspaces/$workspaceId/queue/$queueId/text', data: {'generated_text': generatedText});
  }

  Future<void> triggerPreview(int workspaceId, int queueId) async {
    final client = ref.read(apiClientProvider);
    await client.post('/workspaces/$workspaceId/queue/$queueId/preview');
  }

  Future<QueueItem> fetchQueueItem(int workspaceId, int queueId) async {
    final client = ref.read(apiClientProvider);
    final response = await client.get('/workspaces/$workspaceId/queue/$queueId');
    return QueueItem.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<Map<String, String>> fetchPromptDetails(int workspaceId, int queueId) async {
    final client = ref.read(apiClientProvider);
    final response = await client.get('/workspaces/$workspaceId/queue/$queueId/prompt');
    final data = response.data['data'] as Map<String, dynamic>;
    return {
      'prompt': data['prompt'] as String? ?? '',
      'raw_text': data['raw_text'] as String? ?? '',
    };
  }
}

final queueRepositoryProvider = Provider<QueueRepository>((ref) => QueueRepository(ref));

final queueProvider = FutureProvider.family<List<QueueItem>, int>((ref, workspaceId) {
  return ref.read(queueRepositoryProvider).fetchQueue(workspaceId);
});

final queueItemProvider = FutureProvider.family<QueueItem, ({int workspaceId, int queueId})>((ref, args) {
  return ref.read(queueRepositoryProvider).fetchQueueItem(args.workspaceId, args.queueId);
});

final queuePromptProvider = FutureProvider.family<Map<String, String>, ({int workspaceId, int queueId})>((ref, args) {
  return ref.read(queueRepositoryProvider).fetchPromptDetails(args.workspaceId, args.queueId);
});
