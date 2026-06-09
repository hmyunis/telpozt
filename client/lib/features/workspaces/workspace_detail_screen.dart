import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/datetime_utils.dart';
import '../../shared/widgets/custom_button.dart';
import '../../shared/widgets/custom_switch.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/pull_to_refresh.dart';
import '../../shared/widgets/snackbar_helper.dart';
import 'workspaces_provider.dart';

class WorkspaceDetailScreen extends ConsumerStatefulWidget {
  final int workspaceId;

  const WorkspaceDetailScreen({super.key, required this.workspaceId});

  @override
  ConsumerState<WorkspaceDetailScreen> createState() =>
      _WorkspaceDetailScreenState();
}

class _WorkspaceDetailScreenState extends ConsumerState<WorkspaceDetailScreen> {
  bool _isScraping = false;
  final _scrapeMessageCountController = TextEditingController();
  DateTime? _scrapeFromDate;
  DateTime? _scrapeToDate;

  @override
  void dispose() {
    _scrapeMessageCountController.dispose();
    super.dispose();
  }

  Future<void> _runScrape() async {
    final messageCountText = _scrapeMessageCountController.text.trim();
    final messageCount =
        messageCountText.isEmpty ? null : int.tryParse(messageCountText);
    if (messageCountText.isNotEmpty &&
        (messageCount == null || messageCount <= 0)) {
      SnackbarHelper.showError(
        context,
        'Message count must be a positive whole number.',
      );
      return;
    }
    if (_scrapeFromDate != null &&
        _scrapeToDate != null &&
        _scrapeFromDate!.isAfter(_scrapeToDate!)) {
      SnackbarHelper.showError(
        context,
        'The start date must be on or before the end date.',
      );
      return;
    }

    setState(() => _isScraping = true);
    try {
      final results = await triggerManualScrape(
        ref,
        widget.workspaceId,
        messageCount: messageCount,
        fromDateUtc: _scrapeFromDate == null
            ? null
            : DateTime(
                _scrapeFromDate!.year,
                _scrapeFromDate!.month,
                _scrapeFromDate!.day,
              ).toUtc().toIso8601String(),
        toDateUtc: _scrapeToDate == null
            ? null
            : DateTime(
                _scrapeToDate!.year,
                _scrapeToDate!.month,
                _scrapeToDate!.day,
                23,
                59,
                59,
                999,
              ).toUtc().toIso8601String(),
      );
      ref.invalidate(workspaceDetailProvider(widget.workspaceId));
      if (mounted) {
        context.push(
          '/workspaces/${widget.workspaceId}/scrape-results',
          extra: results,
        );
      }
    } catch (error) {
      if (mounted) SnackbarHelper.showError(context, error);
    } finally {
      if (mounted) setState(() => _isScraping = false);
    }
  }

  Future<void> _showScrapeOptionsSheet() async {
    _scrapeMessageCountController.clear();
    _scrapeFromDate = null;
    _scrapeToDate = null;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> pickDate(bool isStart) async {
              final now = DateTime.now();
              final initial = isStart
                  ? (_scrapeFromDate ?? now.subtract(const Duration(days: 7)))
                  : (_scrapeToDate ?? now);
              final picked = await showDatePicker(
                context: context,
                initialDate: initial,
                firstDate: DateTime(now.year - 3),
                lastDate: DateTime(now.year + 1),
              );
              if (picked != null) {
                setSheetState(() {
                  if (isStart) {
                    _scrapeFromDate = picked;
                  } else {
                    _scrapeToDate = picked;
                  }
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Scrape options',
                    style: AppTextStyles.heading2.copyWith(
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Set a one-time message count or date range. Leave everything blank to use each source\'s default scrape rule.',
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _scrapeMessageCountController,
                    keyboardType: TextInputType.number,
                    style: AppTextStyles.bodyLg.copyWith(
                      color: AppColors.textPrimaryOf(context),
                    ),
                    decoration: InputDecoration(
                      labelText: 'Message count',
                      hintText: 'Optional',
                      filled: true,
                      fillColor: AppColors.elevatedOf(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => pickDate(true),
                          child: Text(
                            _scrapeFromDate == null
                                ? 'From date'
                                : '${_scrapeFromDate!.year}-${_scrapeFromDate!.month.toString().padLeft(2, '0')}-${_scrapeFromDate!.day.toString().padLeft(2, '0')}',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => pickDate(false),
                          child: Text(
                            _scrapeToDate == null
                                ? 'To date'
                                : '${_scrapeToDate!.year}-${_scrapeToDate!.month.toString().padLeft(2, '0')}-${_scrapeToDate!.day.toString().padLeft(2, '0')}',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      setSheetState(() {
                        _scrapeMessageCountController.clear();
                        _scrapeFromDate = null;
                        _scrapeToDate = null;
                      });
                    },
                    child: const Text('Use source defaults'),
                  ),
                  const SizedBox(height: 12),
                  CustomButton(
                    label: 'START SCRAPE',
                    onPressed: () {
                      Navigator.of(context).pop();
                      _runScrape();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(workspaceDetailProvider(widget.workspaceId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined),
            onPressed: () =>
                context.push('/workspaces/${widget.workspaceId}/edit'),
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const LoadingView(type: LoadingViewType.detail),
        error: (err, _) => ErrorView(
          message: err.toString(),
          onRetry: () =>
              ref.invalidate(workspaceDetailProvider(widget.workspaceId)),
        ),
        data: (details) {
          final ws = details.workspace;
          return PullToRefresh(
            onRefresh: () async =>
                ref.invalidate(workspaceDetailProvider(widget.workspaceId)),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(ws.name,
                      style: AppTextStyles.displayLg.copyWith(fontSize: 28)),
                  const SizedBox(height: 4),
                  Text(
                    ws.targetChannelId,
                    style: AppTextStyles.bodyMd
                        .copyWith(color: AppColors.textMutedOf(context)),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceOf(context),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: AppColors.borderSubtleOf(context)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ws.isActive
                                    ? 'Workspace is active'
                                    : 'Workspace is paused',
                                style: AppTextStyles.heading3.copyWith(
                                  color: AppColors.textPrimaryOf(context),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Active workspaces can publish scheduled drafts automatically.',
                                style: AppTextStyles.bodySm.copyWith(
                                  color: AppColors.textMutedOf(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        CustomSwitch(
                          value: ws.isActive,
                          onChanged: (value) => ref
                              .read(workspacesNotifierProvider.notifier)
                              .toggleWorkspaceStatus(ws.id, value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceOf(context),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: AppColors.borderSubtleOf(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create your next post',
                          style: AppTextStyles.heading2.copyWith(
                            color: AppColors.textPrimaryOf(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Find fresh source items, combine the best ones, and turn them into one editable draft.',
                          style: AppTextStyles.bodyMd.copyWith(
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                        const SizedBox(height: 20),
                        CustomButton(
                          label: _isScraping
                              ? 'FINDING CONTENT...'
                              : 'FIND CONTENT',
                          isLoading: _isScraping,
                          onPressed:
                              _isScraping ? null : _showScrapeOptionsSheet,
                          trailingIcon: Icons.arrow_forward,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'DRAFTS TO REVIEW',
                          value: details.draftsNeedingAttention.toString(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'POSTED TODAY',
                          value: details.postsToday.toString(),
                          highlight: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _InfoCard(
                    title: 'Next scheduled post',
                    body: details.nextScheduledAtUtc == null
                        ? 'No post is scheduled yet.'
                        : DateTimeUtils.formatUtcToLocal(
                            details.nextScheduledAtUtc!,
                            'UTC',
                          ),
                  ),
                  const SizedBox(height: 24),
                  GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      mainAxisExtent: 160,
                    ),
                    children: [
                      _NavCard(
                        icon: Icons.edit_note_outlined,
                        title: 'Drafts',
                        subtitle:
                            'Open, refine, and publish your generated drafts.',
                        onTap: () => context
                            .push('/workspaces/${widget.workspaceId}/drafts'),
                      ),
                      _NavCard(
                        icon: Icons.history_outlined,
                        title: 'Published',
                        subtitle: 'Review your published post history.',
                        onTap: () => context
                            .push('/workspaces/${widget.workspaceId}/history'),
                      ),
                      _NavCard(
                        icon: Icons.data_object,
                        title: 'Sources',
                        subtitle:
                            'Manage the channels and inputs you scrape from.',
                        onTap: () => context
                            .push('/workspaces/${widget.workspaceId}/sources'),
                      ),
                      _NavCard(
                        icon: Icons.schedule_outlined,
                        title: 'Schedule',
                        subtitle:
                            'Choose when finished drafts can be published.',
                        onTap: () => context
                            .push('/workspaces/${widget.workspaceId}/schedule'),
                      ),
                      _NavCard(
                        icon: Icons.account_circle_outlined,
                        title: 'Profile',
                        subtitle: details.styleProfileName == null
                            ? 'Choose the writing profile for generated drafts.'
                            : 'Using ${details.styleProfileName}',
                        onTap: () => details.workspace.styleProfileId == null
                            ? context.go('/style-profiles')
                            : context.push(
                                '/style-profiles/${details.workspace.styleProfileId}'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _StatCard({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtleOf(context)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.heading2.copyWith(
              color: highlight
                  ? AppColors.success
                  : AppColors.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSm
                .copyWith(color: AppColors.textMutedOf(context)),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String body;

  const _InfoCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtleOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.labelMd
                .copyWith(color: AppColors.textMutedOf(context)),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: AppTextStyles.bodyMd
                .copyWith(color: AppColors.textPrimaryOf(context)),
          ),
        ],
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtleOf(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.elevatedOf(context),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderHighlightOf(context)),
              ),
              child: Icon(icon, color: AppColors.brandOrange, size: 20),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: AppTextStyles.heading3
                  .copyWith(color: AppColors.textPrimaryOf(context)),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: _FittedSubtitleText(text: subtitle),
            ),
          ],
        ),
      ),
    );
  }
}

class _FittedSubtitleText extends StatelessWidget {
  final String text;

  const _FittedSubtitleText({required this.text});

  @override
  Widget build(BuildContext context) {
    final candidateStyles = [
      AppTextStyles.bodySm.copyWith(
        color: AppColors.textMutedOf(context),
        height: 1.2,
      ),
      AppTextStyles.labelMd.copyWith(
        color: AppColors.textMutedOf(context),
        height: 1.2,
      ),
      AppTextStyles.labelSm.copyWith(
        color: AppColors.textMutedOf(context),
        height: 1.15,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final textDirection = Directionality.of(context);
        for (final style in candidateStyles) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: textDirection,
            maxLines: 3,
          )..layout(maxWidth: constraints.maxWidth);

          if (!painter.didExceedMaxLines) {
            return Text(
              text,
              style: style,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            );
          }
        }

        return Text(
          text,
          style: candidateStyles.last,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}
