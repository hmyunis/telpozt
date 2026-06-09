import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../shared/models/schedule_config.dart';

final scheduleProvider =
    FutureProvider.family<ScheduleConfig, int>((ref, workspaceId) async {
  final client = ref.read(apiClientProvider);
  final response = await client.get('/workspaces/$workspaceId/schedule');
  return ScheduleConfig.fromJson(response.data['data'] as Map<String, dynamic>);
});

class ScheduleRepository {
  final Ref ref;
  ScheduleRepository(this.ref);

  Future<void> updateSchedule(
      int workspaceId, List<String> timeSlots, bool isEnabled) async {
    final client = ref.read(apiClientProvider);
    await client.put('/workspaces/$workspaceId/schedule', data: {
      'time_slots': timeSlots,
      'is_enabled': isEnabled,
    });
  }
}

final scheduleRepositoryProvider = Provider((ref) => ScheduleRepository(ref));
