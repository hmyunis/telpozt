import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/pull_to_refresh.dart';

class ScheduleScreen extends StatelessWidget {
  final int workspaceId;
  const ScheduleScreen({super.key, required this.workspaceId});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    return Scaffold(
      backgroundColor: colors.bgApp,
      appBar: AppBar(
        title: Text('SCHEDULE',
            style: AppTextStyles.heading2.copyWith(color: colors.textPrimary)),
      ),
      body: RefreshableEmptyState(
        onRefresh: () async {},
        child: Center(
          child: Text('Schedule configuration for workspace $workspaceId',
              style:
                  AppTextStyles.bodyLg.copyWith(color: colors.textSecondary)),
        ),
      ),
    );
  }
}
