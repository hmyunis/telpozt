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
import '../../shared/widgets/snackbar_helper.dart';
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
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    final queueAsync = ref.watch(queueProvider(widget.workspaceId));

    return Scaffold(
      backgroundColor: colors.bgApp,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('QUEUE', style: AppTextStyles.heading2.copyWith(color: colors.textPrimary)),
            Text('Workspace Terminal #${widget.workspaceId}', style: AppTextStyles.bodySm.copyWith(color: colors.textMuted)),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: Row(
              children: ['all', 'draft', 'approved', 'scheduled', 'failed', 'cancelled'].map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(filter.toUpperCase(), style: AppTextStyles.labelMd.copyWith(color: isSelected ? AppColors.luxuryOrange : colors.textMuted)),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedFilter = filter);
                    },
                    backgroundColor: Colors.transparent,
                    selectedColor: AppColors.luxuryOrange.withValues(alpha: 0.15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100.0),
                      side: BorderSide(color: isSelected ? AppColors.luxuryOrange : colors.borderDefault, width: isSelected ? 1.5 : 1.0),
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
                onRetry: () => ref.invalidate(queueProvider(widget.workspaceId)),
              ),
              data: (list) {
                final filteredList = _selectedFilter == 'all' ? list : list.where((item) => item.state.toLowerCase() == _selectedFilter).toList();
                if (filteredList.isEmpty) {
                  return RefreshableEmptyState(
                    onRefresh: () async => ref.invalidate(queueProvider(widget.workspaceId)),
                    child: Center(
                      child: EmptyStateView(
                      icon: Icons.pending_actions,
                      title: 'Queue is Clear',
                      subtitle: 'No items matching state filter inside this queue.',
                      action: OutlinedButton(
                        onPressed: () => _showAddQueueItemDialog(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.luxuryOrange, width: 1.5),
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
                        ),
                        child: Text('ADD RAW TEXT', style: AppTextStyles.labelLg.copyWith(color: AppColors.luxuryOrange)),
                      ),
                    ),
                    ),
                  );
                }
                return PullToRefresh(
                  onRefresh: () async => ref.invalidate(queueProvider(widget.workspaceId)),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                    itemCount: filteredList.length,
                    itemBuilder: (context, idx) {
                      final item = filteredList[idx];
                      return GestureDetector(
                        onTap: () => context.push('/workspaces/${widget.workspaceId}/queue/${item.id}'),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10.0),
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: colors.bgSurface,
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(
                              color: item.state == 'posting' ? AppColors.neonOrange : colors.borderDefault,
                              width: item.state == 'posting' ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  StatusBadge(state: item.state),
                                  if (item.scheduledAtUtc != null)
                                    Row(
                                      children: [
                                        const Icon(Icons.schedule, color: AppColors.silver, size: 12),
                                        const SizedBox(width: 4.0),
                                        Text(item.scheduledAtUtc!.substring(11, 16), style: AppTextStyles.labelSm.copyWith(color: colors.textSecondary)),
                                      ],
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10.0),
                              Text(item.generatedText ?? item.rawSourceText, style: AppTextStyles.bodyMd.copyWith(color: colors.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddQueueItemDialog(context),
        backgroundColor: AppColors.luxuryOrange,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        child: const Icon(Icons.add, color: AppColors.white, size: 24),
      ),
    );
  }

  void _showAddQueueItemDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        final colors = Theme.of(context).extension<AppColorsExtension>()!;
        return AlertDialog(
          backgroundColor: colors.bgElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0), side: BorderSide(color: colors.borderDefault)),
          title: Text('QUEUE RAW ENTRY', style: AppTextStyles.heading2.copyWith(color: colors.textPrimary)),
          content: TextField(
            controller: controller,
            maxLines: 4,
            style: AppTextStyles.bodyLg.copyWith(color: colors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Paste raw channel post context...',
              hintStyle: AppTextStyles.bodyLg.copyWith(color: colors.textMuted),
              filled: true,
              fillColor: colors.bgInput,
              border: const OutlineInputBorder(borderSide: BorderSide.none),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('CANCEL', style: AppTextStyles.labelLg.copyWith(color: colors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                final txt = controller.text.trim();
                if (txt.isNotEmpty) {
                  Navigator.pop(context);
                  try {
                    await ref.read(queueRepositoryProvider).createQueueItem(widget.workspaceId, txt);
                    ref.invalidate(queueProvider(widget.workspaceId));
                    if (context.mounted) {
                      SnackbarHelper.show(context, message: 'Draft added to queue.', type: SnackbarType.success);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      SnackbarHelper.showError(context, e);
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.luxuryOrange),
              child: Text('ADD', style: AppTextStyles.labelLg.copyWith(color: AppColors.white)),
            ),
          ],
        );
      },
    );
  }
}
