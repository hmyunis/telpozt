// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart'
    as picker;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/form_section_header.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/pull_to_refresh.dart';
import '../../shared/widgets/snackbar_helper.dart';
import 'queue_provider.dart';

class QueueItemDetailScreen extends ConsumerStatefulWidget {
  final int workspaceId;
  final int queueId;

  const QueueItemDetailScreen({
    super.key,
    required this.workspaceId,
    required this.queueId,
  });

  @override
  ConsumerState<QueueItemDetailScreen> createState() =>
      _QueueItemDetailScreenState();
}

class _QueueItemDetailScreenState extends ConsumerState<QueueItemDetailScreen> {
  bool _isActionRunning = false;

  Future<void> _triggerAction(String action, {String? scheduledAt}) async {
    setState(() => _isActionRunning = true);
    try {
      await ref.read(queueRepositoryProvider).updateItemState(
            widget.workspaceId,
            queueId: widget.queueId,
            action: action,
            scheduledAt: scheduledAt,
          );
      ref.invalidate(queueItemProvider(
          (workspaceId: widget.workspaceId, queueId: widget.queueId)));
      ref.invalidate(queueProvider(widget.workspaceId));
      if (mounted) {
        SnackbarHelper.show(context,
            message: 'Command processed successfully.',
            type: SnackbarType.success);
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _isActionRunning = false);
    }
  }

  void _schedulePost() {
    picker.DatePicker.showDateTimePicker(
      context,
      showTitleActions: true,
      minTime: DateTime.now().add(const Duration(minutes: 5)),
      onConfirm: (dateTime) {
        final utcIso = dateTime.toUtc().toIso8601String();
        _triggerAction('set_schedule', scheduledAt: utcIso);
      },
      locale: picker.LocaleType.en,
    );
  }

  Future<void> _sendBotPreview() async {
    setState(() => _isActionRunning = true);
    try {
      await ref
          .read(queueRepositoryProvider)
          .triggerPreview(widget.workspaceId, widget.queueId);
      if (mounted) {
        SnackbarHelper.show(context,
            message: 'Preview dispatch sent to bot DM.',
            type: SnackbarType.success);
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _isActionRunning = false);
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: 'Delete Entry?',
        body: 'This will permanently delete this queue record from the system.',
        confirmLabel: 'DELETE',
        onConfirm: () async {
          final navigator = Navigator.of(context);
          setState(() => _isActionRunning = true);
          try {
            await ref
                .read(queueRepositoryProvider)
                .deleteQueueItem(widget.workspaceId, widget.queueId);
            ref.invalidate(queueProvider(widget.workspaceId));
            if (mounted) {
              SnackbarHelper.show(context,
                  message: 'Entry deleted.', type: SnackbarType.success);
              navigator.pop();
            }
          } catch (e) {
            if (mounted) {
              SnackbarHelper.showError(context, e);
            }
          } finally {
            if (mounted) setState(() => _isActionRunning = false);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    final itemAsync = ref.watch(queueItemProvider(
        (workspaceId: widget.workspaceId, queueId: widget.queueId)));
    final promptAsync = ref.watch(queuePromptProvider(
        (workspaceId: widget.workspaceId, queueId: widget.queueId)));

    return itemAsync.when(
      loading: () => const LoadingView(type: LoadingViewType.detail),
      error: (err, _) => ErrorView(
        message: err.toString(),
        onRetry: () => ref.invalidate(queueItemProvider(
            (workspaceId: widget.workspaceId, queueId: widget.queueId))),
      ),
      data: (item) {
        final isDraft = item.state == 'draft';
        final isApproved = item.state == 'approved';
        final isScheduled = item.state == 'scheduled';
        final isFailed = item.state == 'failed';
        final isCancelled = item.state == 'cancelled';
        return Scaffold(
          backgroundColor: colors.bgApp,
          appBar: AppBar(
            leading: IconButton(
                icon: Icon(Icons.arrow_back), onPressed: () => context.pop()),
            title: Text('QUEUE ITEM #${item.id}',
                style:
                    AppTextStyles.heading2.copyWith(color: colors.textPrimary)),
            actions: [
              IconButton(
                  onPressed: _confirmDelete, icon: Icon(Icons.delete_outline)),
            ],
          ),
          body: PullToRefresh(
            onRefresh: () async {
              ref.invalidate(queueItemProvider(
                  (workspaceId: widget.workspaceId, queueId: widget.queueId)));
              ref.invalidate(queuePromptProvider(
                  (workspaceId: widget.workspaceId, queueId: widget.queueId)));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FormSectionHeader(label: 'STATE MACHINE'),
                  _metricRow('Current State', item.state.toUpperCase(), colors),
                  _metricRow('Generation Status',
                      item.generationStatus.toUpperCase(), colors),
                  _metricRow('Retry Count', item.retryCount.toString(), colors),
                  if (item.failureReason != null)
                    _metricRow('Failure Reason', item.failureReason!, colors),
                  const FormSectionHeader(label: 'CONTENT'),
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                        color: colors.bgSurface,
                        borderRadius: BorderRadius.circular(4.0),
                        border: Border.all(color: colors.borderDefault)),
                    child: SelectableText(
                        item.generatedText ?? item.rawSourceText,
                        style: AppTextStyles.bodyLg
                            .copyWith(color: colors.textPrimary)),
                  ),
                  const SizedBox(height: 24.0),
                  if (promptAsync.hasValue) ...[
                    const FormSectionHeader(label: 'PROMPT FALLBACK'),
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                          color: colors.bgSurface,
                          borderRadius: BorderRadius.circular(4.0),
                          border: Border.all(color: colors.borderDefault)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SelectableText(promptAsync.value!['prompt'] ?? '',
                              style: AppTextStyles.bodyMd
                                  .copyWith(color: colors.textPrimary)),
                          const SizedBox(height: 12.0),
                          SelectableText(promptAsync.value!['raw_text'] ?? '',
                              style: AppTextStyles.bodySm
                                  .copyWith(color: colors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24.0),
                  const FormSectionHeader(label: 'ACTIONS'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (isDraft)
                        ElevatedButton(
                            onPressed: _isActionRunning
                                ? null
                                : () => _triggerAction('approve'),
                            child: const Text('APPROVE')),
                      if (isApproved || isScheduled)
                        ElevatedButton(
                            onPressed: _isActionRunning
                                ? null
                                : () => _triggerAction('post_now'),
                            child: const Text('POST NOW')),
                      if (!isCancelled && !isFailed)
                        OutlinedButton(
                            onPressed: _isActionRunning ? null : _schedulePost,
                            child: const Text('SCHEDULE')),
                      OutlinedButton(
                          onPressed: _isActionRunning ? null : _sendBotPreview,
                          child: const Text('PREVIEW')),
                      OutlinedButton(
                          onPressed: _isActionRunning
                              ? null
                              : () => _triggerAction('cancel'),
                          child: const Text('CANCEL')),
                    ],
                  ),
                  const SizedBox(height: 24.0),
                  _metricRow(
                      'Scheduled At', item.scheduledAtUtc ?? '—', colors),
                  _metricRow('Posted At', item.postedAtUtc ?? '—', colors),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _metricRow(String label, String value, AppColorsExtension colors) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.borderDefault))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label.toUpperCase(),
              style: AppTextStyles.labelMd.copyWith(color: colors.textMuted)),
          Flexible(
              child: Text(value,
                  style:
                      AppTextStyles.mono.copyWith(color: colors.textSecondary),
                  textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}
