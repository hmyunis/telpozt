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
    final workspacesAsync = ref.watch(workspacesNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workspaces', style: AppTextStyles.heading1),
        automaticallyImplyLeading: false,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 24.0),
              child: Text(
                '${workspacesAsync.valueOrNull?.where((w) => w.isActive).length ?? 0} ACTIVE',
                style: AppTextStyles.labelSm
                    .copyWith(color: AppColors.textMutedOf(context)),
              ),
            ),
          )
        ],
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
              child: const Center(
                child: EmptyStateView(
                  icon: Icons.workspaces_outline,
                  title: 'No Workspaces',
                  subtitle: 'Add your first workspace to start automating.',
                ),
              ),
            );
          }

          return PullToRefresh(
            onRefresh: () async => ref.invalidate(workspacesNotifierProvider),
            child: ListView.builder(
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.all(24.0),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final ws = list[index];

                return GestureDetector(
                  onTap: () {
                    ref.read(activeWorkspaceIdProvider.notifier).state = ws.id;
                    context.push('/workspaces/${ws.id}');
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16.0),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceOf(context),
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(
                        color: ws.isActive
                            ? AppColors.brandOrange
                            : AppColors.borderSubtleOf(context),
                        width: 1.0,
                      ),
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: 4,
                            decoration: BoxDecoration(
                              color: ws.isActive
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
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Icon(Icons.rocket_launch_outlined,
                                                color: ws.isActive
                                                    ? AppColors.brandOrange
                                                    : AppColors.textMutedOf(
                                                        context),
                                                size: 24),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(ws.name,
                                                      style: AppTextStyles
                                                          .heading2
                                                          .copyWith(
                                                              color: AppColors
                                                                  .textPrimaryOf(
                                                                      context))),
                                                  const SizedBox(height: 2),
                                                  Text(ws.targetChannelId,
                                                      style: AppTextStyles
                                                          .bodySm
                                                          .copyWith(
                                                              color: AppColors
                                                                  .textMutedOf(
                                                                      context))),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      StatusBadge(
                                          state:
                                              ws.isActive ? 'active' : 'paused',
                                          showDot: true),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color:
                                                AppColors.elevatedOf(context),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color:
                                                    AppColors.borderHighlightOf(
                                                        context)),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text('FLOW',
                                                  style: AppTextStyles.labelSm
                                                      .copyWith(
                                                          color: AppColors
                                                              .textMutedOf(
                                                                  context))),
                                              const SizedBox(height: 4),
                                              Text('Draft workflow',
                                                  style: AppTextStyles.bodyMd
                                                      .copyWith(
                                                          color: AppColors
                                                              .textPrimaryOf(
                                                                  context))),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color:
                                                AppColors.elevatedOf(context),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color:
                                                    AppColors.borderHighlightOf(
                                                        context)),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text('LAST POST',
                                                  style: AppTextStyles.labelSm
                                                      .copyWith(
                                                          color: AppColors
                                                              .textMutedOf(
                                                                  context))),
                                              const SizedBox(height: 4),
                                              Text('Open workspace',
                                                  style: AppTextStyles.bodyMd
                                                      .copyWith(
                                                          color: AppColors
                                                              .textPrimaryOf(
                                                                  context))),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(Routes.createWorkspace),
        backgroundColor: AppColors.brandOrange,
        elevation: 10,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        child:
            Icon(Icons.add, color: AppColors.textOnBrandOf(context), size: 28),
      ),
    );
  }
}
