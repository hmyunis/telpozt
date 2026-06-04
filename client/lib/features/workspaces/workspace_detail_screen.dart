import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/form_section_header.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/pull_to_refresh.dart';
import '../../shared/widgets/snackbar_helper.dart';
import '../queue/queue_provider.dart';
import 'workspaces_provider.dart';

class WorkspaceDetailScreen extends ConsumerStatefulWidget {
  final int workspaceId;
  const WorkspaceDetailScreen({super.key, required this.workspaceId});

  @override
  ConsumerState<WorkspaceDetailScreen> createState() =>
      _WorkspaceDetailScreenState();
}

class _WorkspaceDetailScreenState extends ConsumerState<WorkspaceDetailScreen> {
  Future<void> _triggerScrapingPipeline() async {
    try {
      await triggerManualScrape(ref, widget.workspaceId);
      ref.invalidate(workspaceDetailProvider(widget.workspaceId));
      ref.invalidate(queueProvider(widget.workspaceId));
      if (mounted) {
        SnackbarHelper.show(context,
            message: 'Scraping task queued successfully.',
            type: SnackbarType.success);
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, e,
            prefix: 'Failed to initiate scraping task');
      }
    }
  }

  void _confirmDeletion() {
    showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: 'Delete Workspace?',
        body:
            'This will permanently delete this workspace, including all queued entries and histories.',
        confirmLabel: 'DELETE',
        onConfirm: () async {
          try {
            await ref
                .read(workspacesNotifierProvider.notifier)
                .deleteWorkspace(widget.workspaceId);
            if (!context.mounted) return;
            context.go(Routes.workspaces);
          } catch (e) {
            if (mounted) {
              SnackbarHelper.showError(context, e,
                  prefix: 'Failed to delete workspace');
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    final detailAsync = ref.watch(workspaceDetailProvider(widget.workspaceId));

    return detailAsync.when(
      loading: () => const LoadingView(type: LoadingViewType.detail),
      error: (err, _) => ErrorView(
        message: err.toString(),
        onRetry: () =>
            ref.invalidate(workspaceDetailProvider(widget.workspaceId)),
      ),
      data: (details) {
        final ws = details.workspace;
        return Scaffold(
          backgroundColor: colors.bgApp,
          appBar: AppBar(
            leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go(Routes.workspaces)),
            title: Text(ws.name.toUpperCase(),
                style:
                    AppTextStyles.heading2.copyWith(color: colors.textPrimary)),
            actions: [
              IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => context.push('/workspaces/${ws.id}/edit')),
            ],
          ),
          body: PullToRefresh(
            onRefresh: () async =>
                ref.invalidate(workspaceDetailProvider(widget.workspaceId)),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 12.0),
                    decoration: BoxDecoration(
                      color: ws.isActive
                          ? AppColors.success.withValues(alpha: 0.08)
                          : AppColors.warning.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(
                          color: ws.isActive
                              ? AppColors.success
                              : AppColors.warning),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: ws.isActive
                                        ? AppColors.success
                                        : AppColors.warning)),
                            const SizedBox(width: 10.0),
                            Text(ws.isActive ? 'ACTIVE' : 'PAUSED',
                                style: AppTextStyles.labelLg.copyWith(
                                    color: ws.isActive
                                        ? AppColors.success
                                        : AppColors.warning)),
                          ],
                        ),
                        Switch(
                          value: ws.isActive,
                          activeThumbColor: AppColors.white,
                          activeTrackColor: AppColors.luxuryOrange,
                          inactiveTrackColor: colors.borderDefault,
                          onChanged: (value) => ref
                              .read(workspacesNotifierProvider.notifier)
                              .toggleWorkspaceStatus(ws.id, value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24.0),
                  Row(
                    children: [
                      Expanded(
                          child: _buildStatTile(colors,
                              details.queueCount.toString(), 'IN QUEUE')),
                      const SizedBox(width: 8.0),
                      Expanded(
                          child: _buildStatTile(
                              colors, details.postsToday.toString(), 'TODAY')),
                      const SizedBox(width: 8.0),
                      Expanded(
                          child: _buildStatTile(
                              colors, details.totalPosted.toString(), 'TOTAL')),
                    ],
                  ),
                  const SizedBox(height: 24.0),
                  const FormSectionHeader(label: 'ACTIONS'),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionCard(
                          context,
                          icon: Icons.play_arrow,
                          title: 'SCRAPE NOW',
                          onTap: _triggerScrapingPipeline,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionCard(
                          context,
                          icon: Icons.rss_feed,
                          title: 'SOURCES',
                          onTap: () =>
                              context.push('/workspaces/${ws.id}/sources'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12.0),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionCard(
                          context,
                          icon: Icons.add_link,
                          title: 'ADD SOURCE',
                          onTap: () =>
                              context.push('/workspaces/${ws.id}/sources/new'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionCard(
                          context,
                          icon: Icons.edit_outlined,
                          title: 'EDIT',
                          onTap: () =>
                              context.push('/workspaces/${ws.id}/edit'),
                        ),
                      ),
                    ],
                  ),
                  const FormSectionHeader(label: 'DETAILS'),
                  _buildInfoRow('Assigned Profile',
                      details.styleProfileName ?? '—', colors),
                  _buildInfoRow('Target Channel', ws.targetChannelId, colors,
                      isMono: true),
                  _buildInfoRow(
                      'Created', ws.createdAt.substring(0, 10), colors),
                  const SizedBox(height: 40.0),
                  Divider(color: colors.borderDefault),
                  TextButton(
                    onPressed: _confirmDeletion,
                    child: Text('DELETE WORKSPACE',
                        style: AppTextStyles.labelLg
                            .copyWith(color: AppColors.danger)),
                  ),
                  const SizedBox(height: 40.0),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatTile(AppColorsExtension colors, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: colors.borderDefault),
      ),
      child: Column(
        children: [
          Text(value,
              style:
                  AppTextStyles.displayLg.copyWith(color: colors.textPrimary)),
          const SizedBox(height: 4.0),
          Text(label,
              style: AppTextStyles.labelSm.copyWith(color: colors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 96,
        decoration: BoxDecoration(
          color: colors.bgSurface,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: colors.borderDefault),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: AppColors.luxuryOrange),
            const SizedBox(height: 8.0),
            Text(title,
                style:
                    AppTextStyles.labelLg.copyWith(color: colors.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, AppColorsExtension colors,
      {bool isMono = false}) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.borderDefault))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label.toUpperCase(),
              style: AppTextStyles.labelMd.copyWith(color: colors.textMuted)),
          Text(value,
              style: isMono
                  ? AppTextStyles.mono.copyWith(color: colors.textSecondary)
                  : AppTextStyles.bodyMd.copyWith(color: colors.textPrimary)),
        ],
      ),
    );
  }
}
