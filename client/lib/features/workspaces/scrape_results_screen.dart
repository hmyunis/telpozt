import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/datetime_utils.dart';
import '../../features/drafts/drafts_provider.dart';
import '../../shared/models/scrape_candidate.dart';
import '../../shared/widgets/custom_button.dart';
import '../../shared/widgets/empty_state_view.dart';
import '../../shared/widgets/snackbar_helper.dart';
import '../../shared/widgets/status_badge.dart';

class ScrapeResultsScreen extends ConsumerStatefulWidget {
  final int workspaceId;
  final List<Map<String, dynamic>> results;

  const ScrapeResultsScreen({
    super.key,
    required this.workspaceId,
    required this.results,
  });

  @override
  ConsumerState<ScrapeResultsScreen> createState() =>
      _ScrapeResultsScreenState();
}

class _ScrapeResultsScreenState extends ConsumerState<ScrapeResultsScreen> {
  final Set<int> _selectedIds = <int>{};
  final Set<int> _expandedIds = <int>{};
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    final usable = _candidates.where((candidate) => candidate.isUsable).take(2);
    _selectedIds.addAll(usable.map((candidate) => candidate.id));
  }

  List<ScrapeCandidate> get _candidates => widget.results
      .map((item) => ScrapeCandidate.fromJson(item))
      .toList(growable: false);

  Future<void> _generateDraft() async {
    if (_selectedIds.isEmpty) {
      SnackbarHelper.show(
        context,
        message: 'Select at least one candidate before generating a draft.',
        type: SnackbarType.warning,
      );
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final draft = await ref.read(draftRepositoryProvider).createDraft(
            widget.workspaceId,
            _selectedIds.toList(),
          );
      ref.invalidate(draftsProvider);
      if (mounted) {
        context.go('/workspaces/${widget.workspaceId}/drafts/${draft.id}');
      }
    } catch (error) {
      if (mounted) SnackbarHelper.showError(context, error);
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_candidates.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: const Text('Find Content', style: AppTextStyles.heading2),
        ),
        body: const Center(
          child: EmptyStateView(
            icon: Icons.check_circle_outline,
            title: 'No New Content',
            subtitle: 'No fresh items were found during this scrape.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Choose Source Items', style: AppTextStyles.heading2),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Select one or more useful items, then generate a single combined draft.',
            style: AppTextStyles.bodyMd
                .copyWith(color: AppColors.textSecondaryOf(context)),
          ),
          const SizedBox(height: 20),
          ..._candidates.map((candidate) {
            final isSelected = _selectedIds.contains(candidate.id);
            final isExpanded = _expandedIds.contains(candidate.id);
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.brandOrange
                      : AppColors.borderSubtleOf(context),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: isSelected,
                        onChanged: candidate.isUsable
                            ? (_) {
                                setState(() {
                                  if (isSelected) {
                                    _selectedIds.remove(candidate.id);
                                  } else {
                                    _selectedIds.add(candidate.id);
                                  }
                                });
                              }
                            : null,
                      ),
                      Expanded(
                        child: Text(
                          candidate.sourceChannel,
                          style: AppTextStyles.heading3.copyWith(
                            color: AppColors.textPrimaryOf(context),
                          ),
                        ),
                      ),
                      StatusBadge(
                        state: candidate.isUsable ? 'ready' : 'failed',
                        showDot: false,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _CandidateSourceCard(
                    candidate: candidate,
                    isExpanded: isExpanded,
                    onToggle: () {
                      setState(() {
                        if (isExpanded) {
                          _expandedIds.remove(candidate.id);
                        } else {
                          _expandedIds.add(candidate.id);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    candidate.isUsable
                        ? 'Usable for draft generation'
                        : 'Marked duplicate and excluded from selection',
                    style: AppTextStyles.bodySm.copyWith(
                      color: candidate.isUsable
                          ? AppColors.brandOrange
                          : AppColors.textMutedOf(context),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: CustomButton(
            label: 'GENERATE DRAFT',
            isLoading: _isGenerating,
            onPressed: _isGenerating ? null : _generateDraft,
          ),
        ),
      ),
    );
  }
}

class _CandidateSourceCard extends StatelessWidget {
  final ScrapeCandidate candidate;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _CandidateSourceCard({
    required this.candidate,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final postedAt = candidate.originalPostedAtUtc;
    final viewCount = candidate.viewCount;

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
                    candidate.sourceLabel ?? candidate.sourceChannel,
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
                  _CandidateMetaPill(
                    icon: Icons.schedule_outlined,
                    label: DateTimeUtils.formatUtcToLocal(postedAt, 'UTC'),
                  ),
                if (viewCount != null)
                  _CandidateMetaPill(
                    icon: Icons.visibility_outlined,
                    label: '$viewCount views',
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              candidate.rawText,
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

class _CandidateMetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CandidateMetaPill({
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
