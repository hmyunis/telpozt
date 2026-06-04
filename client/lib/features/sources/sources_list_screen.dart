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
import 'sources_provider.dart';

class SourcesListScreen extends ConsumerWidget {
  final int workspaceId;

  const SourcesListScreen({super.key, required this.workspaceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    final sourcesAsync = ref.watch(sourcesProvider(workspaceId));

    return Scaffold(
      backgroundColor: colors.bgApp,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text('SOURCE CHANNELS', style: AppTextStyles.heading2.copyWith(color: colors.textPrimary)),
      ),
      body: sourcesAsync.when(
        loading: () => const LoadingView(type: LoadingViewType.list),
        error: (err, _) => ErrorView(
          message: err.toString(),
          onRetry: () => ref.invalidate(sourcesProvider(workspaceId)),
        ),
        data: (list) {
          if (list.isEmpty) {
            return RefreshableEmptyState(
              onRefresh: () async => ref.invalidate(sourcesProvider(workspaceId)),
              child: Center(
                child: EmptyStateView(
                icon: Icons.rss_feed,
                title: 'No Sources Configured',
                subtitle: 'Add source channels to scrape and process automation entries.',
                action: OutlinedButton(
                  onPressed: () => context.push('/workspaces/$workspaceId/sources/new'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.luxuryOrange, width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
                  ),
                  child: Text('ADD SOURCE', style: AppTextStyles.labelLg.copyWith(color: AppColors.luxuryOrange)),
                ),
              ),
              ),
            );
          }

          return PullToRefresh(
            onRefresh: () async => ref.invalidate(sourcesProvider(workspaceId)),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: list.length,
              separatorBuilder: (context, idx) => Divider(color: colors.borderDefault, height: 1.0, indent: 24.0),
              itemBuilder: (context, index) {
                final src = list[index];
                return Dismissible(
                  key: Key('src_dismiss_${src.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: AppColors.danger,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: const Icon(Icons.delete_outline, color: AppColors.white, size: 24),
                  ),
                  onDismissed: (_) async {
                    await ref.read(sourcesRepositoryProvider).deleteSource(workspaceId: workspaceId, sourceId: src.id);
                    ref.invalidate(sourcesProvider(workspaceId));
                  },
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(src.displayName ?? src.channelId, style: AppTextStyles.heading3.copyWith(color: colors.textPrimary)),
                        ),
                        _buildPriorityBadge(src.priority),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2.0),
                        Text(src.channelId, style: AppTextStyles.mono.copyWith(color: colors.textSecondary)),
                        const SizedBox(height: 4.0),
                        Row(
                          children: [
                            Icon(Icons.history, color: colors.textMuted, size: 12),
                            const SizedBox(width: 4.0),
                            Text(
                              'Scraped: ${DateTimeUtils.formatRelativeTime(src.lastScrapedAt)}',
                              style: AppTextStyles.labelSm.copyWith(color: colors.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Switch(
                      value: src.isActive,
                      activeThumbColor: AppColors.luxuryOrange,
                      inactiveTrackColor: colors.borderDefault,
                      onChanged: (val) async {
                        await ref.read(sourcesRepositoryProvider).updateSource(
                              workspaceId: workspaceId,
                              sourceId: src.id,
                              priority: src.priority,
                              isActive: val,
                              displayName: src.displayName ?? src.channelId,
                            );
                        ref.invalidate(sourcesProvider(workspaceId));
                      },
                    ),
                    onTap: () => context.push('/workspaces/$workspaceId/sources/${src.id}/edit'),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/workspaces/$workspaceId/sources/new'),
        backgroundColor: AppColors.luxuryOrange,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        child: const Icon(Icons.add, color: AppColors.white, size: 24),
      ),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color bg;
    Color border;
    Color text;

    switch (priority.toLowerCase()) {
      case 'high':
        bg = AppColors.neonOrange.withValues(alpha: 0.15);
        border = AppColors.neonOrange;
        text = AppColors.neonOrange;
        break;
      case 'low':
        bg = AppColors.steelDark.withValues(alpha: 0.5);
        border = AppColors.iron;
        text = AppColors.ash;
        break;
      case 'normal':
      default:
        bg = AppColors.silver.withValues(alpha: 0.10);
        border = AppColors.steelLight;
        text = AppColors.silver;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 8.0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4.0),
        border: Border.all(color: border),
      ),
      child: Text(
        priority.toUpperCase(),
        style: AppTextStyles.labelSm.copyWith(color: text, fontSize: 8.0),
      ),
    );
  }
}
