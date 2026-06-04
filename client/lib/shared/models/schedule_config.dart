import 'dart:convert';

class ScheduleConfig {
  final int id;
  final int workspaceId;
  final List<String> timeSlots;
  final String timezone;
  final bool isEnabled;

  ScheduleConfig({required this.id, required this.workspaceId, required this.timeSlots, required this.timezone, required this.isEnabled});

  factory ScheduleConfig.fromJson(Map<String, dynamic> json) {
    final rawSlots = json['time_slots'];
    List<String> parsedSlots = [];
    if (rawSlots is String) {
      try {
        parsedSlots = (jsonDecode(rawSlots) as List).map((e) => e.toString()).toList();
      } catch (_) {}
    } else if (rawSlots is List) {
      parsedSlots = rawSlots.map((e) => e.toString()).toList();
    }
    return ScheduleConfig(
      id: json['id'] as int? ?? 0,
      workspaceId: json['workspace_id'] as int,
      timeSlots: parsedSlots,
      timezone: json['timezone'] as String? ?? 'UTC',
      isEnabled: (json['is_enabled'] as int? ?? 1) == 1,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'workspace_id': workspaceId, 'time_slots': jsonEncode(timeSlots), 'timezone': timezone, 'is_enabled': isEnabled ? 1 : 0};
}
