// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart'
    as picker;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/datetime_utils.dart';
import '../../features/style_profiles/style_profiles_provider.dart';
import '../../features/workspaces/workspaces_provider.dart';
import '../../shared/models/draft.dart';
import '../../shared/models/scrape_candidate.dart';
import '../../shared/models/style_profile.dart';
import '../../shared/widgets/custom_button.dart';
import '../../shared/widgets/custom_text_field.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/pull_to_refresh.dart';
import '../../shared/widgets/snackbar_helper.dart';
import '../../shared/widgets/status_badge.dart';
import 'drafts_provider.dart';

class DraftComposerScreen extends ConsumerStatefulWidget {
  final int workspaceId;
  final int draftId;

  const DraftComposerScreen({
    super.key,
    required this.workspaceId,
    required this.draftId,
  });

  @override
  ConsumerState<DraftComposerScreen> createState() =>
      _DraftComposerScreenState();
}

class _DraftComposerScreenState extends ConsumerState<DraftComposerScreen> {
  final _textController = TextEditingController();
  final _instructionController = TextEditingController();
  final Set<int> _expandedSourceIds = <int>{};
  bool _isDirty = false;
  bool _isSaving = false;
  bool _isRegenerating = false;
  bool _isPublishing = false;
  bool _didSeedText = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      if (!_didSeedText) return;
      if (!_isDirty) {
        setState(() => _isDirty = true);
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _instructionController.dispose();
    super.dispose();
  }

  Future<void> _saveDraft() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      SnackbarHelper.show(
        context,
        message: 'Draft text cannot be empty.',
        type: SnackbarType.warning,
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(draftRepositoryProvider).saveDraftText(
            widget.workspaceId,
            draftId: widget.draftId,
            generatedText: text,
          );
      ref.invalidate(draftDetailProvider((
        workspaceId: widget.workspaceId,
        draftId: widget.draftId,
      )));
      ref.invalidate(draftsProvider);
      setState(() => _isDirty = false);
      SnackbarHelper.showSuccess(context, 'Draft saved.');
    } catch (error) {
      SnackbarHelper.showError(context, error);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _regenerate() async {
    final instruction = _instructionController.text.trim();
    final previousText = _textController.text;
    setState(() => _isRegenerating = true);
    try {
      final updated = await ref.read(draftRepositoryProvider).regenerateDraft(
            widget.workspaceId,
            widget.draftId,
            instruction: instruction.isEmpty ? null : instruction,
          );
      _textController.text = updated.generatedText ?? previousText;
      ref.invalidate(draftDetailProvider((
        workspaceId: widget.workspaceId,
        draftId: widget.draftId,
      )));
      ref.invalidate(draftsProvider);
      setState(() => _isDirty = false);
      SnackbarHelper.showSuccess(context, 'Draft regenerated.');
    } catch (error) {
      _textController.text = previousText;
      SnackbarHelper.showError(context, error);
    } finally {
      if (mounted) setState(() => _isRegenerating = false);
    }
  }

  Future<void> _publishNow() async {
    if (_isDirty) {
      await _saveDraft();
      if (_isDirty) return;
    }
    setState(() => _isPublishing = true);
    try {
      await ref.read(draftRepositoryProvider).publishDraft(
            widget.workspaceId,
            widget.draftId,
          );
      ref.invalidate(draftDetailProvider((
        workspaceId: widget.workspaceId,
        draftId: widget.draftId,
      )));
      ref.invalidate(draftsProvider);
      SnackbarHelper.showSuccess(context, 'Post published.');
      context.pop();
    } catch (error) {
      SnackbarHelper.showError(context, error);
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  Future<void> _scheduleDraft() async {
    if (_isDirty) {
      await _saveDraft();
      if (_isDirty) return;
    }
    picker.DatePicker.showDateTimePicker(
      context,
      showTitleActions: true,
      minTime: DateTime.now().add(const Duration(minutes: 5)),
      onConfirm: (dateTime) async {
        setState(() => _isPublishing = true);
        try {
          await ref.read(draftRepositoryProvider).scheduleDraft(
                widget.workspaceId,
                widget.draftId,
                dateTime.toUtc().toIso8601String(),
              );
          ref.invalidate(draftDetailProvider((
            workspaceId: widget.workspaceId,
            draftId: widget.draftId,
          )));
          ref.invalidate(draftsProvider);
          SnackbarHelper.showSuccess(context, 'Draft scheduled.');
        } catch (error) {
          SnackbarHelper.showError(context, error);
        } finally {
          if (mounted) setState(() => _isPublishing = false);
        }
      },
      locale: picker.LocaleType.en,
    );
  }

  Future<void> _copyExternalPrompt(
    Draft draft, {
    required StyleProfile? styleProfile,
    required String? workspaceName,
    required String? targetChannelId,
  }) async {
    final prompt = _buildExternalPrompt(
      draft,
      styleProfile: styleProfile,
      workspaceName: workspaceName,
      targetChannelId: targetChannelId,
    );
    await Clipboard.setData(ClipboardData(text: prompt));
    if (mounted) {
      SnackbarHelper.showSuccess(context, 'Prompt copied to clipboard.');
    }
  }

  String _buildExternalPrompt(
    Draft draft, {
    required StyleProfile? styleProfile,
    required String? workspaceName,
    required String? targetChannelId,
  }) {
    final instruction = _instructionController.text.trim();
    final draftText = _textController.text.trim();
    final profileLines = <String>[
      if (styleProfile != null) 'Profile name: ${styleProfile.name}',
      if (styleProfile?.entityName != null &&
          styleProfile!.entityName!.trim().isNotEmpty)
        'Entity name: ${styleProfile.entityName!.trim()}',
      if (styleProfile?.entityType != null &&
          styleProfile!.entityType!.trim().isNotEmpty)
        'Entity type: ${styleProfile.entityType!.trim()}',
      if (styleProfile != null) 'Tone: ${styleProfile.tone}',
      if (styleProfile != null) 'Structure: ${styleProfile.structure}',
      if (styleProfile != null) 'Length preset: ${styleProfile.lengthPreset}',
      if (styleProfile?.charMin != null)
        'Minimum characters: ${styleProfile!.charMin}',
      if (styleProfile?.charMax != null)
        'Maximum characters: ${styleProfile!.charMax}',
      if (styleProfile != null) 'Emoji usage: ${styleProfile.emojiUsage}',
      if (styleProfile != null)
        'Jargon handling: ${styleProfile.jargonHandling}',
      if (styleProfile != null) 'Call to action: ${styleProfile.callToAction}',
      if (styleProfile != null) 'Hashtag style: ${styleProfile.hashtagStyle}',
      if (styleProfile?.additionalInstructions != null &&
          styleProfile!.additionalInstructions!.trim().isNotEmpty)
        'Additional instructions: ${styleProfile.additionalInstructions!.trim()}',
      if (styleProfile == null)
        'No style profile is currently attached to this workspace. Keep the output polished, concise, and ready to publish.',
    ];

    final sourceSections = draft.selectedSources
        .asMap()
        .entries
        .map((entry) => _formatSourcePromptBlock(entry.key + 1, entry.value))
        .join('\n\n');

    return '''
Generate one final social post draft from the provided source messages.

Workspace
- Name: ${workspaceName ?? 'Unknown workspace'}
- Target channel: ${targetChannelId ?? 'Not available'}

Style profile
${profileLines.map((line) => '- $line').join('\n')}

Task
- Combine the source items into one cohesive post.
- Keep the output publication-ready.
- Prioritize the most relevant details and avoid repetition.
- Preserve factual accuracy from the sources.
${instruction.isEmpty ? '' : '- Apply this extra refinement instruction: $instruction'}

Current draft text
${draftText.isEmpty ? '(No current draft text)' : draftText}

Source items
$sourceSections

Return only the final post text with no explanation.
''';
  }

  String _formatSourcePromptBlock(int index, ScrapeCandidate source) {
    final metadata = <String>[
      'Source channel: ${source.sourceChannel}',
      if (source.sourceLabel != null && source.sourceLabel!.trim().isNotEmpty)
        'Source label: ${source.sourceLabel!.trim()}',
      if (source.originalPostedAtUtc != null &&
          source.originalPostedAtUtc!.isNotEmpty)
        'Posted at (UTC): ${source.originalPostedAtUtc}',
      if (source.viewCount != null) 'Views: ${source.viewCount}',
    ];

    return '''$index.
${metadata.map((line) => '- $line').join('\n')}
- Message:
${source.rawText}''';
  }

  @override
  Widget build(BuildContext context) {
    final draftAsync = ref.watch(draftDetailProvider((
      workspaceId: widget.workspaceId,
      draftId: widget.draftId,
    )));
    final workspaceDetailsAsync =
        ref.watch(workspaceDetailProvider(widget.workspaceId));

    return draftAsync.when(
      loading: () => const LoadingView(type: LoadingViewType.detail),
      error: (err, _) => ErrorView(
        message: err.toString(),
        onRetry: () => ref.invalidate(draftDetailProvider((
          workspaceId: widget.workspaceId,
          draftId: widget.draftId,
        ))),
      ),
      data: (draft) {
        if (!_didSeedText) {
          _textController.text = draft.generatedText ?? '';
          _instructionController.text = draft.lastGenerationInstruction ?? '';
          _didSeedText = true;
          _isDirty = false;
        }

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            title: const Text('Draft Composer', style: AppTextStyles.heading2),
            actions: [
              workspaceDetailsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (_, __) => IconButton(
                  onPressed: () => _copyExternalPrompt(
                    draft,
                    styleProfile: null,
                    workspaceName: null,
                    targetChannelId: null,
                  ),
                  icon: Icon(Icons.content_copy_outlined),
                  tooltip: 'Copy prompt for external AI',
                ),
                data: (workspaceDetails) {
                  final profileId = workspaceDetails.workspace.styleProfileId;
                  if (profileId == null) {
                    return IconButton(
                      onPressed: () => _copyExternalPrompt(
                        draft,
                        styleProfile: null,
                        workspaceName: workspaceDetails.workspace.name,
                        targetChannelId:
                            workspaceDetails.workspace.targetChannelId,
                      ),
                      icon: Icon(Icons.content_copy_outlined),
                      tooltip: 'Copy prompt for external AI',
                    );
                  }

                  final styleProfileAsync =
                      ref.watch(styleProfileDetailProvider(profileId));
                  return styleProfileAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    error: (_, __) => IconButton(
                      onPressed: () => _copyExternalPrompt(
                        draft,
                        styleProfile: null,
                        workspaceName: workspaceDetails.workspace.name,
                        targetChannelId:
                            workspaceDetails.workspace.targetChannelId,
                      ),
                      icon: Icon(Icons.content_copy_outlined),
                      tooltip: 'Copy prompt for external AI',
                    ),
                    data: (styleProfile) => IconButton(
                      onPressed: () => _copyExternalPrompt(
                        draft,
                        styleProfile: styleProfile,
                        workspaceName: workspaceDetails.workspace.name,
                        targetChannelId:
                            workspaceDetails.workspace.targetChannelId,
                      ),
                      icon: Icon(Icons.content_copy_outlined),
                      tooltip: 'Copy prompt for external AI',
                    ),
                  );
                },
              ),
            ],
          ),
          body: PullToRefresh(
            onRefresh: () async => ref.invalidate(draftDetailProvider((
              workspaceId: widget.workspaceId,
              draftId: widget.draftId,
            ))),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      StatusBadge(state: draft.status, showDot: false),
                      const Spacer(),
                      Text(
                        DateTimeUtils.formatRelativeTime(draft.updatedAt),
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.textMutedOf(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
                          'Selected source items',
                          style: AppTextStyles.heading3.copyWith(
                            color: AppColors.textPrimaryOf(context),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...draft.selectedSources.map(
                          (source) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _SourceItemCard(
                              source: source,
                              isExpanded:
                                  _expandedSourceIds.contains(source.id),
                              onToggle: () {
                                setState(() {
                                  if (_expandedSourceIds.contains(source.id)) {
                                    _expandedSourceIds.remove(source.id);
                                  } else {
                                    _expandedSourceIds.add(source.id);
                                  }
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  CustomTextField(
                    label: 'Regeneration Suggestion',
                    hintText:
                        'Make it shorter, focus on the main update, add a stronger CTA...',
                    controller: _instructionController,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  CustomButton(
                    label: 'REGENERATE',
                    variant: CustomButtonVariant.outline,
                    isLoading: _isRegenerating,
                    onPressed: _isRegenerating ? null : _regenerate,
                  ),
                  const SizedBox(height: 24),
                  CustomTextField(
                    label: 'Draft Text',
                    hintText: 'Your generated draft will appear here.',
                    controller: _textController,
                    maxLines: 14,
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Draft text is required.'
                            : null,
                  ),
                  if (draft.failureReason != null &&
                      draft.failureReason!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      draft.failureReason!,
                      style: AppTextStyles.bodySm
                          .copyWith(color: AppColors.danger),
                    ),
                  ],
                  if (draft.scheduledAtUtc != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Scheduled for ${DateTimeUtils.formatUtcToLocal(draft.scheduledAtUtc!, "UTC")}',
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.scheduled,
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          label: 'SAVE DRAFT',
                          variant: CustomButtonVariant.outline,
                          isLoading: _isSaving,
                          onPressed: _isSaving ? null : _saveDraft,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomButton(
                          label: 'SCHEDULE',
                          variant: CustomButtonVariant.outline,
                          isLoading: _isPublishing,
                          onPressed: _isPublishing ? null : _scheduleDraft,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CustomButton(
                    label: 'POST NOW',
                    isLoading: _isPublishing,
                    onPressed: _isPublishing ? null : _publishNow,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SourceItemCard extends StatelessWidget {
  final ScrapeCandidate source;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _SourceItemCard({
    required this.source,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final postedAt = source.originalPostedAtUtc;
    final viewCount = source.viewCount;

    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.elevatedOf(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderHighlightOf(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    source.sourceChannel,
                    style: AppTextStyles.labelLg.copyWith(
                      color: AppColors.brandOrange,
                    ),
                  ),
                ),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.textMutedOf(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (postedAt != null && postedAt.isNotEmpty)
                  _SourceMetaPill(
                    icon: Icons.schedule_outlined,
                    label: DateTimeUtils.formatUtcToLocal(postedAt, 'UTC'),
                  ),
                if (viewCount != null)
                  _SourceMetaPill(
                    icon: Icons.visibility_outlined,
                    label: '$viewCount views',
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              source.rawText,
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.textSecondaryOf(context),
                height: 1.4,
              ),
              maxLines: isExpanded ? null : 3,
              overflow:
                  isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceMetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SourceMetaPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderSubtleOf(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textMutedOf(context)),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.textSecondaryOf(context),
            ),
          ),
        ],
      ),
    );
  }
}
