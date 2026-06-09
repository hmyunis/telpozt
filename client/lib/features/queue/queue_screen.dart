import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/empty_state_view.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/pull_to_refresh.dart';
import '../../shared/widgets/status_badge.dart';
import 'queue_provider.dart';

class QueueScreen extends ConsumerStatefulWidget {
  final int workspaceId;
  const QueueScreen({super.key, required this.workspaceId});

  @override
  ConsumerState<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends ConsumerState<QueueScreen> {
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final queueAsync = ref.watch(queueProvider(widget.workspaceId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: const Text('Queue', style: AppTextStyles.heading1),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: Row(
              children: ['all', 'posting', 'draft', 'approved', 'scheduled']
                  .map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedFilter = filter),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20.0, vertical: 10.0),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.elevatedOf(context)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20.0),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.brandOrange
                              : AppColors.borderHighlightOf(context),
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        filter.toUpperCase(),
                        style: AppTextStyles.labelMd.copyWith(
                          color: isSelected
                              ? AppColors.brandOrange
                              : AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: queueAsync.when(
              loading: () => const LoadingView(),
              error: (err, _) => ErrorView(
                  message: err.toString(),
                  onRetry: () =>
                      ref.invalidate(queueProvider(widget.workspaceId))),
              data: (list) {
                final filteredList = _selectedFilter == 'all'
                    ? list
                    : list
                        .where((item) =>
                            item.state.toLowerCase() == _selectedFilter)
                        .toList();

                if (filteredList.isEmpty) {
                  return const Center(
                      child: EmptyStateView(
                          icon: Icons.inbox,
                          title: 'No Items',
                          subtitle:
                              'The queue is currently empty for this filter.'));
                }

                return PullToRefresh(
                  onRefresh: () async =>
                      ref.invalidate(queueProvider(widget.workspaceId)),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(24.0),
                    itemCount: filteredList.length,
                    itemBuilder: (context, idx) {
                      final item = filteredList[idx];
                      final isPosting = item.state == 'posting' ||
                          item.state == 'posting now';

                      return GestureDetector(
                        onTap: () => context.push(
                            '/workspaces/${widget.workspaceId}/queue/${item.id}'),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16.0),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceOf(context),
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(
                                color: isPosting
                                    ? AppColors.brandOrange
                                    : AppColors.borderSubtleOf(context)),
                          ),
                          child: IntrinsicHeight(
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  decoration: BoxDecoration(
                                    color: isPosting
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
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            StatusBadge(
                                                state: isPosting
                                                    ? 'posting now'
                                                    : item.state,
                                                showDot: false),
                                            Text(
                                              item.scheduledAtUtc
                                                      ?.substring(11, 16) ??
                                                  'TBD',
                                              style: AppTextStyles.mono
                                                  .copyWith(
                                                      color:
                                                          AppColors.textMutedOf(
                                                              context)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16.0),
                                        Text(
                                          item.generatedText ??
                                              item.rawSourceText,
                                          style: AppTextStyles.bodyMd.copyWith(
                                              color: AppColors.textPrimaryOf(
                                                  context)),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 16.0),
                                        const Divider(),
                                        const SizedBox(height: 12.0),
                                        Row(
                                          children: [
                                            Icon(Icons.hub_outlined,
                                                size: 16,
                                                color: AppColors.textMutedOf(
                                                    context)),
                                            const SizedBox(width: 8),
                                            Text('Automated Sequence',
                                                style: AppTextStyles.bodySm
                                                    .copyWith(
                                                        color: AppColors
                                                            .textMutedOf(
                                                                context))),
                                            const Spacer(),
                                            Icon(Icons.chevron_right,
                                                size: 18,
                                                color: AppColors.textMutedOf(
                                                    context)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
