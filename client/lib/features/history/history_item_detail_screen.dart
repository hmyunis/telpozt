import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/form_section_header.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/pull_to_refresh.dart';
import 'history_provider.dart';

class HistoryItemDetailScreen extends ConsumerWidget {
  final int workspaceId;
  final int historyId;

  const HistoryItemDetailScreen({super.key, required this.workspaceId, required this.historyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    final itemAsync = ref.watch(historyItemProvider((workspaceId: workspaceId, historyId: historyId)));

    return itemAsync.when(
      loading: () => const LoadingView(type: LoadingViewType.detail),
      error: (err, _) => ErrorView(message: err.toString(), onRetry: () => ref.invalidate(historyItemProvider((workspaceId: workspaceId, historyId: historyId)))),
      data: (item) {
        return Scaffold(
          backgroundColor: colors.bgApp,
          appBar: AppBar(
            leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
            title: Text('HISTORY ITEM #$historyId', style: AppTextStyles.heading2.copyWith(color: colors.textPrimary)),
          ),
          body: PullToRefresh(
            onRefresh: () async => ref.invalidate(historyItemProvider((workspaceId: workspaceId, historyId: historyId))),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FormSectionHeader(label: 'FINAL TEXT'),
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(color: colors.bgSurface, borderRadius: BorderRadius.circular(4.0), border: Border.all(color: colors.borderDefault)),
                  child: SelectableText(item.finalText, style: AppTextStyles.bodyLg.copyWith(color: colors.textPrimary)),
                ),
                const SizedBox(height: 24.0),
                _row('Source Channel', item.sourceChannel ?? '—', colors),
                _row('Telegram Message ID', item.telegramMessageId ?? '—', colors),
                _row('Posted At UTC', item.postedAtUtc, colors),
              ],
            ),
            ),
          ),
        );
      },
    );
  }

  Widget _row(String label, String value, AppColorsExtension colors) {
    return Container(
      height: 48,
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.borderDefault))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label.toUpperCase(), style: AppTextStyles.labelMd.copyWith(color: colors.textMuted)),
          Text(value, style: AppTextStyles.mono.copyWith(color: colors.textSecondary)),
        ],
      ),
    );
  }
}
