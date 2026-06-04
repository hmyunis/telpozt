// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/datetime_utils.dart';
import '../../shared/widgets/empty_state_view.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/pull_to_refresh.dart';
import '../../shared/widgets/status_badge.dart';
import 'history_provider.dart';

class HistoryScreen extends ConsumerWidget {
  final int workspaceId;
  const HistoryScreen({super.key, required this.workspaceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    final historyAsync = ref.watch(historyProvider(workspaceId));

    return Scaffold(
      backgroundColor: colors.bgApp,
      appBar: AppBar(title: Text('HISTORY', style: AppTextStyles.heading2.copyWith(color: colors.textPrimary))),
      body: historyAsync.when(
        loading: () => const LoadingView(),
        error: (err, _) => ErrorView(message: err.toString(), onRetry: () => ref.invalidate(historyProvider(workspaceId))),
        data: (list) {
          if (list.isEmpty) {
            return RefreshableEmptyState(
              onRefresh: () async => ref.invalidate(historyProvider(workspaceId)),
              child: const Center(
                child: EmptyStateView(
                icon: Icons.history,
                title: 'No History Yet',
                subtitle: 'Posted items will appear here once the queue publishes.',
              ),
              ),
            );
          }
          return PullToRefresh(
            onRefresh: () async => ref.invalidate(historyProvider(workspaceId)),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              itemCount: list.length,
              separatorBuilder: (_, __) => Divider(color: colors.borderDefault),
              itemBuilder: (context, index) {
                final item = list[index];
                return ListTile(
                  title: Text(item.finalText, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodyMd.copyWith(color: colors.textPrimary)),
                  subtitle: Text(DateTimeUtils.formatRelativeTime(item.postedAtUtc), style: AppTextStyles.labelSm.copyWith(color: colors.textMuted)),
                  trailing: StatusBadge(state: 'posted'),
                  onTap: () => context.push('/workspaces/$workspaceId/history/${item.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
