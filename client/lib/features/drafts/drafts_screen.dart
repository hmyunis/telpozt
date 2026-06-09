import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/datetime_utils.dart';
import '../../shared/models/draft.dart';
import '../../shared/widgets/empty_state_view.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/pull_to_refresh.dart';
import '../../shared/widgets/status_badge.dart';
import '../sources/sources_provider.dart';
import '../workspaces/workspaces_provider.dart';
import 'drafts_provider.dart';

class DraftsScreen extends ConsumerStatefulWidget {
  final int workspaceId;

  const DraftsScreen({super.key, required this.workspaceId});

  @override
  ConsumerState<DraftsScreen> createState() => _DraftsScreenState();
}

class _DraftsScreenState extends ConsumerState<DraftsScreen> {
  final _searchController = TextEditingController();
  String _selectedFilter = 'all';
  String _appliedSearchQuery = '';
  int _currentPage = 1;
  bool _filtersExpanded = false;
  DateTime? _scrapedFromDate;
  DateTime? _scrapedToDate;
  final Set<int> _hiddenDraftIds = <int>{};
  final Set<int> _selectedSourceChannelIds = <int>{};
  final Map<int, _PendingDraftDelete> _pendingDeletes = {};
  Timer? _searchDebounce;

  String? get _sourceChannelIdsCsv {
    if (_selectedSourceChannelIds.isEmpty) {
      return null;
    }
    final sorted = _selectedSourceChannelIds.toList()..sort();
    return sorted.join(',');
  }

  String? get _scrapedFromUtc => _scrapedFromDate == null
      ? null
      : DateTime(
          _scrapedFromDate!.year,
          _scrapedFromDate!.month,
          _scrapedFromDate!.day,
        ).toUtc().toIso8601String();

  String? get _scrapedToUtc => _scrapedToDate == null
      ? null
      : DateTime(
          _scrapedToDate!.year,
          _scrapedToDate!.month,
          _scrapedToDate!.day,
          23,
          59,
          59,
          999,
        ).toUtc().toIso8601String();

  ({
    int workspaceId,
    int page,
    String? status,
    String? query,
    String? sourceChannelIdsCsv,
    String? scrapedFromUtc,
    String? scrapedToUtc,
  }) get _draftsQueryArgs => (
        workspaceId: widget.workspaceId,
        page: _currentPage,
        status: _selectedFilter == 'all' ? null : _selectedFilter,
        query: _appliedSearchQuery.isEmpty ? null : _appliedSearchQuery,
        sourceChannelIdsCsv: _sourceChannelIdsCsv,
        scrapedFromUtc: _scrapedFromUtc,
        scrapedToUtc: _scrapedToUtc,
      );

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    for (final pending in _pendingDeletes.values) {
      pending.timer.cancel();
    }
    super.dispose();
  }

  bool get _hasActiveFilters =>
      _selectedSourceChannelIds.isNotEmpty ||
      _scrapedFromDate != null ||
      _scrapedToDate != null;

  void _handleSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _appliedSearchQuery = value.trim();
        _currentPage = 1;
      });
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initialDate = isStart
        ? (_scrapedFromDate ?? now.subtract(const Duration(days: 7)))
        : (_scrapedToDate ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      if (isStart) {
        _scrapedFromDate = picked;
      } else {
        _scrapedToDate = picked;
      }
      _currentPage = 1;
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedSourceChannelIds.clear();
      _scrapedFromDate = null;
      _scrapedToDate = null;
      _currentPage = 1;
    });
  }

  bool _matchesSearchQuery(Draft draft) {
    final query = _appliedSearchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return true;
    }

    if ((draft.generatedText ?? '').toLowerCase().contains(query)) {
      return true;
    }
    if (draft.rawSourceText.toLowerCase().contains(query)) {
      return true;
    }

    for (final source in draft.selectedSources) {
      if (source.rawText.toLowerCase().contains(query) ||
          source.sourceChannel.toLowerCase().contains(query) ||
          (source.sourceLabel ?? '').toLowerCase().contains(query)) {
        return true;
      }
    }

    return false;
  }

  Future<void> _queueDraftDelete(Draft draft) async {
    if (_pendingDeletes.containsKey(draft.id)) {
      return;
    }

    setState(() {
      _hiddenDraftIds.add(draft.id);
    });

    final timer = Timer(const Duration(seconds: 5), () async {
      final pending = _pendingDeletes.remove(draft.id);
      if (pending == null || pending.isUndone) {
        return;
      }

      try {
        await ref
            .read(draftRepositoryProvider)
            .deleteDraft(widget.workspaceId, draft.id);
        ref.invalidate(draftsProvider);
        ref.invalidate(workspaceDetailProvider(widget.workspaceId));
      } catch (error) {
        if (!mounted) {
          return;
        }
        setState(() {
          _hiddenDraftIds.remove(draft.id);
        });
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _showDeleteFailedSnack(error);
      }
    });

    _pendingDeletes[draft.id] = _PendingDraftDelete(timer: timer);
    _showDeleteSnackbar(draft);
  }

  void _undoDraftDelete(Draft draft) {
    final pending = _pendingDeletes.remove(draft.id);
    if (pending == null) {
      return;
    }

    pending.isUndone = true;
    pending.timer.cancel();
    if (!mounted) {
      return;
    }

    setState(() {
      _hiddenDraftIds.remove(draft.id);
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  void _showDeleteFailedSnack(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceOf(context),
        content: Text(
          'Failed to delete draft: $error',
          style: AppTextStyles.bodySm
              .copyWith(color: AppColors.textPrimaryOf(context)),
        ),
      ),
    );
  }

  void _showDeleteSnackbar(Draft draft) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surfaceOf(context),
          content: _DraftDeleteToast(
            onUndo: () => _undoDraftDelete(draft),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final draftsAsync = ref.watch(draftsProvider(_draftsQueryArgs));
    final sourcesAsync = ref.watch(sourcesProvider(widget.workspaceId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Drafts', style: AppTextStyles.heading1),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSubtleOf(context)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _handleSearchChanged,
                style: AppTextStyles.bodyMd
                    .copyWith(color: AppColors.textPrimaryOf(context)),
                decoration: InputDecoration(
                  hintText: 'Search draft content',
                  hintStyle: AppTextStyles.bodyMd
                      .copyWith(color: AppColors.textMutedOf(context)),
                  border: InputBorder.none,
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppColors.textMutedOf(context),
                  ),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() {
                      _filtersExpanded = !_filtersExpanded;
                    }),
                    icon: Icon(
                      _filtersExpanded
                          ? Icons.filter_alt_off_outlined
                          : Icons.filter_alt_outlined,
                      color: _hasActiveFilters
                          ? AppColors.brandOrange
                          : AppColors.textMutedOf(context),
                    ),
                    tooltip: 'Toggle filters',
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: _filtersExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceOf(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderSubtleOf(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Filters',
                          style: AppTextStyles.heading3.copyWith(
                            color: AppColors.textPrimaryOf(context),
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _hasActiveFilters ? _clearFilters : null,
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Sources',
                      style: AppTextStyles.labelMd.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 10),
                    sourcesAsync.when(
                      loading: () => Text(
                        'Loading sources...',
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.textMutedOf(context),
                        ),
                      ),
                      error: (_, __) => Text(
                        'Could not load source filters.',
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.danger,
                        ),
                      ),
                      data: (sources) {
                        if (sources.isEmpty) {
                          return Text(
                            'No source channels available.',
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.textMutedOf(context),
                            ),
                          );
                        }
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: sources.map((source) {
                            final selected =
                                _selectedSourceChannelIds.contains(source.id);
                            return FilterChip(
                              label:
                                  Text(source.displayName ?? source.channelId),
                              selected: selected,
                              onSelected: (value) {
                                setState(() {
                                  if (value) {
                                    _selectedSourceChannelIds.add(source.id);
                                  } else {
                                    _selectedSourceChannelIds.remove(source.id);
                                  }
                                  _currentPage = 1;
                                });
                              },
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Scraped post date',
                      style: AppTextStyles.labelMd.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _pickDate(isStart: true),
                            child: Text(
                              _scrapedFromDate == null
                                  ? 'From date'
                                  : '${_scrapedFromDate!.year}-${_scrapedFromDate!.month.toString().padLeft(2, '0')}-${_scrapedFromDate!.day.toString().padLeft(2, '0')}',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _pickDate(isStart: false),
                            child: Text(
                              _scrapedToDate == null
                                  ? 'To date'
                                  : '${_scrapedToDate!.year}-${_scrapedToDate!.month.toString().padLeft(2, '0')}-${_scrapedToDate!.day.toString().padLeft(2, '0')}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: ['all', 'generating', 'ready', 'scheduled', 'failed']
                  .map(
                    (filter) => Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: ChoiceChip(
                        label: Text(filter.toUpperCase()),
                        selected: _selectedFilter == filter,
                        onSelected: (_) => setState(() {
                          _selectedFilter = filter;
                          _currentPage = 1;
                        }),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Expanded(
            child: draftsAsync.when(
              loading: () => const LoadingView(),
              error: (err, _) => ErrorView(
                message: err.toString(),
                onRetry: () => ref.invalidate(draftsProvider(_draftsQueryArgs)),
              ),
              data: (draftPage) {
                final filtered = draftPage.items
                    .where((draft) => !_hiddenDraftIds.contains(draft.id))
                    .where(_matchesSearchQuery)
                    .toList();

                if (filtered.isEmpty) {
                  final hasQuery = _appliedSearchQuery.isNotEmpty;
                  return Center(
                    child: EmptyStateView(
                      icon: Icons.edit_note_outlined,
                      title: hasQuery || _hasActiveFilters
                          ? 'No Matching Drafts'
                          : 'No Drafts',
                      subtitle: hasQuery || _hasActiveFilters
                          ? 'Try a different search term or adjust the filters.'
                          : 'Use Find Content to create your next post draft.',
                    ),
                  );
                }

                return PullToRefresh(
                  onRefresh: () async =>
                      ref.invalidate(draftsProvider(_draftsQueryArgs)),
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      ...filtered.map((draft) {
                        return GestureDetector(
                          onTap: () => context.push(
                              '/workspaces/${widget.workspaceId}/drafts/${draft.id}'),
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
                                  children: [
                                    StatusBadge(
                                        state: draft.status, showDot: false),
                                    const Spacer(),
                                    IconButton(
                                      onPressed: draft.status == 'generating'
                                          ? null
                                          : () => _queueDraftDelete(draft),
                                      tooltip: 'Delete draft',
                                      icon: Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                      ),
                                      color: AppColors.textMutedOf(context),
                                      splashRadius: 18,
                                    ),
                                    Text(
                                      DateTimeUtils.formatRelativeTime(
                                          draft.updatedAt),
                                      style: AppTextStyles.bodySm.copyWith(
                                        color: AppColors.textMutedOf(context),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  draft.generatedText ??
                                      'Generating your draft...',
                                  style: AppTextStyles.bodyMd.copyWith(
                                    color: AppColors.textPrimaryOf(context),
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: draft.selectedSources
                                      .map(
                                        (source) => Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                AppColors.elevatedOf(context),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            border: Border.all(
                                              color:
                                                  AppColors.borderHighlightOf(
                                                      context),
                                            ),
                                          ),
                                          child: Text(
                                            source.sourceChannel,
                                            style:
                                                AppTextStyles.labelSm.copyWith(
                                              color: AppColors.textSecondaryOf(
                                                  context),
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                                if (draft.failureReason != null &&
                                    draft.failureReason!.isNotEmpty) ...[
                                  const SizedBox(height: 14),
                                  Text(
                                    draft.failureReason!,
                                    style: AppTextStyles.bodySm.copyWith(
                                      color: AppColors.danger,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      _DraftsPaginationBar(
                        currentPage: draftPage.page,
                        totalPages: draftPage.totalPages,
                        totalItems: draftPage.totalItems,
                        onPrevious: draftPage.page > 1
                            ? () => setState(() => _currentPage -= 1)
                            : null,
                        onNext: draftPage.page < draftPage.totalPages
                            ? () => setState(() => _currentPage += 1)
                            : null,
                      ),
                    ],
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

class _DraftsPaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _DraftsPaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) {
      return Text(
        '$totalItems drafts',
        textAlign: TextAlign.center,
        style: AppTextStyles.bodySm
            .copyWith(color: AppColors.textMutedOf(context)),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtleOf(context)),
      ),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: onPrevious,
            child: const Text('Previous'),
          ),
          Expanded(
            child: Text(
              'Page $currentPage of $totalPages',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ),
          OutlinedButton(
            onPressed: onNext,
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }
}

class _PendingDraftDelete {
  final Timer timer;
  bool isUndone;

  _PendingDraftDelete({
    required this.timer,
  }) : isUndone = false;
}

class _DraftDeleteToast extends StatelessWidget {
  final VoidCallback onUndo;

  const _DraftDeleteToast({required this.onUndo});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 1, end: 0),
            duration: const Duration(seconds: 5),
            builder: (context, value, _) {
              return CircularProgressIndicator(
                value: value,
                strokeWidth: 2,
                backgroundColor: AppColors.borderHighlightOf(context),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.brandOrange,
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Draft removed. Undo before it is permanently deleted.',
            style: AppTextStyles.bodySm
                .copyWith(color: AppColors.textPrimaryOf(context)),
          ),
        ),
        TextButton(
          onPressed: onUndo,
          child: Text(
            'UNDO',
            style: AppTextStyles.labelMd.copyWith(color: AppColors.brandOrange),
          ),
        ),
      ],
    );
  }
}
