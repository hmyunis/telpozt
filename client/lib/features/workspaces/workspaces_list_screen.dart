import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/empty_state_view.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/pull_to_refresh.dart';
import '../../shared/widgets/status_badge.dart';
import 'workspaces_provider.dart';

class WorkspacesListScreen extends ConsumerWidget {
  const WorkspacesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    final workspacesAsync = ref.watch(workspacesNotifierProvider);
    final activeWorkspaceId = ref.watch(activeWorkspaceIdProvider);

    return Scaffold(
      backgroundColor: colors.bgApp,
      appBar: AppBar(
        title: Text('WORKSPACES', style: AppTextStyles.heading1.copyWith(color: colors.textPrimary, letterSpacing: 1.5)),
        automaticallyImplyLeading: false,
      ),
      body: workspacesAsync.when(
        loading: () => const LoadingView(),
        error: (err, _) => ErrorView(
          message: err.toString(),
          onRetry: () => ref.invalidate(workspacesNotifierProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return RefreshableEmptyState(
              onRefresh: () async => ref.invalidate(workspacesNotifierProvider),
              child: Center(
                child: EmptyStateView(
                icon: Icons.workspaces_outline,
                title: 'No Workspaces Yet',
                subtitle: 'Add your first workspace to start automating a Telegram destination channel.',
                action: OutlinedButton(
                  onPressed: () => context.push(Routes.createWorkspace),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.luxuryOrange, width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
                  ),
                  child: Text('ADD WORKSPACE', style: AppTextStyles.labelLg.copyWith(color: AppColors.luxuryOrange)),
                ),
              ),
              ),
            );
          }

          return PullToRefresh(
            onRefresh: () async => ref.invalidate(workspacesNotifierProvider),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final ws = list[index];
                final isSelected = ws.id == activeWorkspaceId;
                return GestureDetector(
                  onTap: () {
                    ref.read(activeWorkspaceIdProvider.notifier).state = ws.id;
                    context.push('/workspaces/${ws.id}');
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12.0),
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: colors.bgSurface,
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: isSelected ? AppColors.luxuryOrange : colors.borderDefault, width: isSelected ? 1.5 : 1.0),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.luxuryOrange.withValues(alpha: 0.06),
                                offset: const Offset(-3, 0),
                              )
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(ws.name, style: AppTextStyles.heading2.copyWith(color: colors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            StatusBadge(state: ws.isActive ? 'active' : 'paused'),
                          ],
                        ),
                        const SizedBox(height: 6.0),
                        Row(
                          children: [
                            Icon(Icons.alternate_email, color: colors.textMuted, size: 16),
                            const SizedBox(width: 6.0),
                            Expanded(
                              child: Text(ws.targetChannelId, style: AppTextStyles.mono.copyWith(color: colors.textSecondary)),
                            ),
                          ],
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
        onPressed: () => context.push(Routes.createWorkspace),
        backgroundColor: AppColors.luxuryOrange,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        child: const Icon(Icons.add, color: AppColors.white, size: 24),
      ),
    );
  }
}
