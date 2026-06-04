import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../shared/models/source_channel.dart';

class SourcesRepository {
  final Ref ref;
  SourcesRepository(this.ref);

  Future<List<SourceChannel>> fetchSources(int workspaceId) async {
    final client = ref.read(apiClientProvider);
    final response =
        await client.get('/workspaces/$workspaceId/source-channels');
    final list = response.data['data'] as List;
    return list
        .map((json) => SourceChannel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> addSource({
    required int workspaceId,
    required String channelId,
    required String displayName,
    required String priority,
  }) async {
    final client = ref.read(apiClientProvider);
    await client.post('/workspaces/$workspaceId/source-channels', data: {
      'channel_id': channelId,
      'display_name': displayName,
      'priority': priority,
    });
  }

  Future<void> updateSource({
    required int workspaceId,
    required int sourceId,
    required String priority,
    required bool isActive,
    required String displayName,
  }) async {
    final client = ref.read(apiClientProvider);
    await client
        .put('/workspaces/$workspaceId/source-channels/$sourceId', data: {
      'priority': priority,
      'is_active': isActive ? 1 : 0,
      'display_name': displayName,
    });
  }

  Future<void> deleteSource({
    required int workspaceId,
    required int sourceId,
  }) async {
    final client = ref.read(apiClientProvider);
    await client.delete('/workspaces/$workspaceId/source-channels/$sourceId');
  }
}

final sourcesRepositoryProvider =
    Provider<SourcesRepository>((ref) => SourcesRepository(ref));

final sourcesProvider =
    FutureProvider.family<List<SourceChannel>, int>((ref, workspaceId) {
  return ref.read(sourcesRepositoryProvider).fetchSources(workspaceId);
});
