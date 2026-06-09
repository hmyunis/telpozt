import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../shared/models/post_history.dart';

class HistoryRepository {
  final Ref ref;
  HistoryRepository(this.ref);

  Future<List<PostHistory>> fetchHistory(int workspaceId) async {
    final client = ref.read(apiClientProvider);
    final response = await client.get('/workspaces/$workspaceId/history');
    final list = response.data['data']['items'] as List;
    return list
        .map((json) => PostHistory.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<PostHistory> fetchHistoryItem(int workspaceId, int historyId) async {
    final client = ref.read(apiClientProvider);
    final response =
        await client.get('/workspaces/$workspaceId/history/$historyId');
    return PostHistory.fromJson(response.data['data'] as Map<String, dynamic>);
  }
}

final historyRepositoryProvider =
    Provider<HistoryRepository>((ref) => HistoryRepository(ref));
final historyProvider = FutureProvider.family<List<PostHistory>, int>(
    (ref, workspaceId) =>
        ref.read(historyRepositoryProvider).fetchHistory(workspaceId));
final historyItemProvider =
    FutureProvider.family<PostHistory, ({int workspaceId, int historyId})>(
        (ref, args) => ref
            .read(historyRepositoryProvider)
            .fetchHistoryItem(args.workspaceId, args.historyId));
