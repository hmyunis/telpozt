import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/datetime_utils.dart';
import '../../shared/models/source_channel.dart';
import '../../shared/widgets/custom_switch.dart';
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
    final sourcesAsync = ref.watch(sourcesProvider(workspaceId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.folder_outlined,
                    size: 14, color: AppColors.textMutedOf(context)),
                const SizedBox(width: 6),
                Text('WORKSPACE',
                    style: AppTextStyles.labelSm
                        .copyWith(color: AppColors.textMutedOf(context))),
              ],
            ),
            const SizedBox(height: 2),
            const Text('Source Channels', style: AppTextStyles.heading1),
          ],
        ),
      ),
      body: sourcesAsync.when(
        loading: () => const LoadingView(),
        error: (err, _) => ErrorView(
            message: err.toString(),
            onRetry: () => ref.invalidate(sourcesProvider(workspaceId))),
        data: (list) {
          if (list.isEmpty) {
            return RefreshableEmptyState(
              onRefresh: () async =>
                  ref.invalidate(sourcesProvider(workspaceId)),
              child: const Center(
                child: EmptyStateView(
                  icon: Icons.rss_feed,
                  title: 'No Sources',
                  subtitle:
                      'Add source channels to scrape and process automation entries.',
                ),
              ),
            );
          }

          return PullToRefresh(
            onRefresh: () async => ref.invalidate(sourcesProvider(workspaceId)),
            child: ListView.builder(
              padding: const EdgeInsets.all(24.0),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final src = list[index];
                final isHigh = src.priority.toLowerCase() == 'high';

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceOf(context),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: AppColors.borderSubtleOf(context)),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 4,
                          decoration: BoxDecoration(
                            color: isHigh
                                ? AppColors.brandOrange
                                : Colors.transparent,
                            borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                bottomLeft: Radius.circular(12)),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(src.displayName ?? src.channelId,
                                              style: AppTextStyles.heading3),
                                          if (isHigh) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                  color: AppColors.brandOrange,
                                                  borderRadius:
                                                      BorderRadius.circular(4)),
                                              child: Text('HIGH',
                                                  style: AppTextStyles.labelSm
                                                      .copyWith(
                                                          color: AppColors
                                                              .pureBlack)),
                                            )
                                          ]
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(Icons.alternate_email,
                                              size: 14,
                                              color: AppColors.textMutedOf(
                                                  context)),
                                          const SizedBox(width: 4),
                                          Text(
                                              src.channelId.replaceAll('@', ''),
                                              style: AppTextStyles.bodySm
                                                  .copyWith(
                                                      color:
                                                          AppColors.textMutedOf(
                                                              context))),
                                          const SizedBox(width: 12),
                                          Icon(Icons.history,
                                              size: 14,
                                              color: AppColors.textMutedOf(
                                                  context)),
                                          const SizedBox(width: 4),
                                          Text(
                                              DateTimeUtils.formatRelativeTime(
                                                  src.lastScrapedAt),
                                              style: AppTextStyles.bodySm
                                                  .copyWith(
                                                      color:
                                                          AppColors.textMutedOf(
                                                              context))),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        _buildScrapeRuleLabel(src),
                                        style: AppTextStyles.bodySm.copyWith(
                                            color: AppColors.textSecondaryOf(
                                                context)),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          onPressed: () async {
                                            final result = await context.push(
                                              '/workspaces/$workspaceId/sources/${src.id}/edit',
                                            );
                                            if (result == 'deleted') {
                                              ref.invalidate(
                                                sourcesProvider(workspaceId),
                                              );
                                            }
                                          },
                                          icon: Icon(Icons.edit_outlined,
                                              size: 20),
                                          color: AppColors.textMutedOf(context),
                                          tooltip: 'Edit source',
                                        ),
                                      ],
                                    ),
                                    CustomSwitch(
                                      value: src.isActive,
                                      onChanged: (val) async {
                                        await ref
                                            .read(sourcesRepositoryProvider)
                                            .updateSource(
                                              workspaceId: workspaceId,
                                              sourceId: src.id,
                                              priority: src.priority,
                                              isActive: val,
                                              displayName: src.displayName ??
                                                  src.channelId,
                                              defaultScrapeMessageCount:
                                                  src.defaultScrapeMessageCount,
                                              defaultLookbackDays:
                                                  src.defaultLookbackDays,
                                            );
                                        ref.invalidate(
                                            sourcesProvider(workspaceId));
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/workspaces/$workspaceId/sources/new'),
        backgroundColor: AppColors.brandOrange,
        elevation: 10,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        child:
            Icon(Icons.add, color: AppColors.textOnBrandOf(context), size: 28),
      ),
    );
  }

  String _buildScrapeRuleLabel(SourceChannel src) {
    final parts = <String>[];
    if (src.defaultScrapeMessageCount != null) {
      parts.add('${src.defaultScrapeMessageCount} msgs');
    }
    if (src.defaultLookbackDays != null) {
      parts.add('${src.defaultLookbackDays} day range');
    }
    if (parts.isEmpty) {
      return 'Default scrape rule: system default';
    }
    return 'Default scrape rule: ${parts.join(' · ')}';
  }
}
