import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/datetime_utils.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/pull_to_refresh.dart';
import '../../shared/widgets/status_badge.dart';
import 'history_provider.dart';

class HistoryScreen extends ConsumerWidget {
  final int workspaceId;
  const HistoryScreen({super.key, required this.workspaceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyProvider(workspaceId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('PUBLISHED POSTS', style: AppTextStyles.heading2),
                Row(
                  children: [
                    Text('${historyAsync.valueOrNull?.length ?? 0} TOTAL',
                        style: AppTextStyles.labelMd
                            .copyWith(color: AppColors.textMutedOf(context))),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: historyAsync.when(
              loading: () => const LoadingView(),
              error: (err, _) => Center(
                  child: Text(err.toString(),
                      style: const TextStyle(color: AppColors.danger))),
              data: (list) {
                return PullToRefresh(
                  onRefresh: () async =>
                      ref.invalidate(historyProvider(workspaceId)),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(24.0),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final item = list[index];
                      return GestureDetector(
                        onTap: () => context.push(
                            '/workspaces/$workspaceId/history/${item.id}'),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceOf(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.borderSubtleOf(context)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.history,
                                          size: 16,
                                          color: AppColors.brandOrange),
                                      const SizedBox(width: 8),
                                      Text(
                                          DateTimeUtils.formatRelativeTime(
                                              item.postedAtUtc),
                                          style: AppTextStyles.labelMd.copyWith(
                                              color: AppColors.brandOrange)),
                                    ],
                                  ),
                                  const StatusBadge(
                                      state: 'published', showDot: true),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                item.finalText,
                                style: AppTextStyles.heading3.copyWith(
                                    color: AppColors.textPrimaryOf(context)),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Icon(Icons.chat_bubble_outline,
                                      size: 16,
                                      color: AppColors.textMutedOf(context)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                        item.sourceChannel ?? '@manual_entry',
                                        style: AppTextStyles.bodySm.copyWith(
                                            color: AppColors.textMutedOf(
                                                context))),
                                  ),
                                  Icon(Icons.arrow_forward,
                                      size: 18,
                                      color: AppColors.textPrimaryOf(context)),
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
