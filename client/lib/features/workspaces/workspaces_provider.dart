import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../shared/models/workspace.dart';

final activeWorkspaceIdProvider = StateProvider<int?>((ref) => null);

class WorkspacesNotifier extends AsyncNotifier<List<Workspace>> {
  @override
  Future<List<Workspace>> build() async => _fetchWorkspaces();

  Future<List<Workspace>> _fetchWorkspaces() async {
    final client = ref.read(apiClientProvider);
    final response = await client.get('/workspaces');
    final list = response.data['data'] as List;
    return list
        .map((json) => Workspace.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> createWorkspace({
    required String name,
    required String targetChannelId,
    required String botToken,
    int? styleProfileId,
  }) async {
    final client = ref.read(apiClientProvider);
    await client.post('/workspaces', data: {
      'name': name,
      'target_channel_id': targetChannelId,
      'bot_token': botToken,
      'style_profile_id': styleProfileId,
    });
    ref.invalidateSelf();
  }

  Future<void> updateWorkspace({
    required int id,
    required String name,
    required String targetChannelId,
    required String botToken,
    required bool isActive,
    int? styleProfileId,
  }) async {
    final client = ref.read(apiClientProvider);
    await client.put('/workspaces/$id', data: {
      'name': name,
      'target_channel_id': targetChannelId,
      'bot_token': botToken,
      'is_active': isActive ? 1 : 0,
      'style_profile_id': styleProfileId,
    });
    ref.invalidateSelf();
    ref.invalidate(workspaceDetailProvider(id));
  }

  Future<void> deleteWorkspace(int id) async {
    final client = ref.read(apiClientProvider);
    await client.delete('/workspaces/$id');
    ref.invalidateSelf();
    if (ref.read(activeWorkspaceIdProvider) == id) {
      ref.read(activeWorkspaceIdProvider.notifier).state = null;
    }
  }

  Future<void> toggleWorkspaceStatus(int id, bool isActive) async {
    final client = ref.read(apiClientProvider);
    await client.put('/workspaces/$id', data: {
      'is_active': isActive ? 1 : 0,
    });
    ref.invalidateSelf();
    ref.invalidate(workspaceDetailProvider(id));
  }
}

final workspacesNotifierProvider =
    AsyncNotifierProvider<WorkspacesNotifier, List<Workspace>>(
        WorkspacesNotifier.new);

class WorkspaceDetails {
  final Workspace workspace;
  final int draftsNeedingAttention;
  final int postsToday;
  final int totalPosted;
  final String? nextScheduledAtUtc;
  final String? styleProfileName;

  WorkspaceDetails({
    required this.workspace,
    required this.draftsNeedingAttention,
    required this.postsToday,
    required this.totalPosted,
    this.nextScheduledAtUtc,
    this.styleProfileName,
  });
}

Future<WorkspaceDetails> fetchWorkspaceDetails(Ref ref, int id) async {
  final client = ref.read(apiClientProvider);
  final response = await client.get('/workspaces/$id');
  final data = response.data['data'] as Map<String, dynamic>;
  final workspace = Workspace.fromJson(data);

  var draftsNeedingAttention = 0;
  var postsToday = 0;
  var totalPosted = 0;
  String? nextScheduledAtUtc;
  String? styleProfileName;

  try {
    final statsResponse = await client.get('/workspaces/$id/drafts');
    final draftList = statsResponse.data['data']['items'] as List;
    draftsNeedingAttention = draftList
        .where((e) => e['status'] == 'ready' || e['status'] == 'failed')
        .length;
    final scheduledDrafts = draftList
        .where(
            (e) => e['status'] == 'scheduled' && e['scheduled_at_utc'] != null)
        .toList()
      ..sort((a, b) => (a['scheduled_at_utc'] as String)
          .compareTo(b['scheduled_at_utc'] as String));
    if (scheduledDrafts.isNotEmpty) {
      nextScheduledAtUtc = scheduledDrafts.first['scheduled_at_utc'] as String?;
    }
  } catch (_) {}

  try {
    final historyResponse = await client.get('/workspaces/$id/history');
    final historyList = historyResponse.data['data']['items'] as List;
    totalPosted = historyResponse.data['data']['meta']['total_items'] ?? 0;
    final todayString =
        DateTime.now().toUtc().toIso8601String().substring(0, 10);
    postsToday = historyList
        .where((e) => (e['posted_at_utc'] as String).startsWith(todayString))
        .length;
  } catch (_) {}

  if (workspace.styleProfileId != null) {
    try {
      final profileResponse =
          await client.get('/style-profiles/${workspace.styleProfileId}');
      styleProfileName = profileResponse.data['data']['name'] as String?;
    } catch (_) {}
  }

  return WorkspaceDetails(
    workspace: workspace,
    draftsNeedingAttention: draftsNeedingAttention,
    postsToday: postsToday,
    totalPosted: totalPosted,
    nextScheduledAtUtc: nextScheduledAtUtc,
    styleProfileName: styleProfileName,
  );
}

final workspaceDetailProvider =
    FutureProvider.family<WorkspaceDetails, int>((ref, id) async {
  return fetchWorkspaceDetails(ref, id);
});

Future<List<Map<String, dynamic>>> triggerManualScrape(
  WidgetRef ref,
  int workspaceId, {
  int? messageCount,
  String? fromDateUtc,
  String? toDateUtc,
}) async {
  final client = ref.read(apiClientProvider);
  final response = await client.post('/workspaces/$workspaceId/scrape', data: {
    if (messageCount != null) 'message_count': messageCount,
    if (fromDateUtc != null) 'from_date_utc': fromDateUtc,
    if (toDateUtc != null) 'to_date_utc': toDateUtc,
  });
  final data = response.data['data'];
  return List<Map<String, dynamic>>.from(data['new_posts'] ?? []);
}
