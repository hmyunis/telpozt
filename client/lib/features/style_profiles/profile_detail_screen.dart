import 'package:flutter/material.dart';
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
import 'style_profiles_provider.dart';

class ProfileDetailScreen extends ConsumerWidget {
  final int profileId;

  const ProfileDetailScreen({super.key, required this.profileId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    final detailAsync = ref.watch(styleProfileDetailProvider(profileId));

    return detailAsync.when(
      loading: () => const LoadingView(type: LoadingViewType.detail),
      error: (err, _) => ErrorView(
        message: err.toString(),
        onRetry: () => ref.invalidate(styleProfileDetailProvider(profileId)),
      ),
      data: (p) {
        return Scaffold(
          backgroundColor: colors.bgApp,
          appBar: AppBar(
            leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop()),
            title: Text(p.name.toUpperCase(),
                style:
                    AppTextStyles.heading2.copyWith(color: colors.textPrimary)),
            actions: [
              IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () =>
                      context.push('/style-profiles/${p.id}/edit')),
            ],
          ),
          body: PullToRefresh(
            onRefresh: () async =>
                ref.invalidate(styleProfileDetailProvider(profileId)),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FormSectionHeader(label: 'IDENTITY'),
                  _row('Entity Name', p.entityName ?? '—', colors),
                  _row('Entity Type', p.entityType ?? '—', colors),
                  const FormSectionHeader(label: 'VOICE & TONE'),
                  _row('Tone Scale', p.tone, colors),
                  _row('Technical Jargon', p.jargonHandling, colors),
                  const FormSectionHeader(label: 'FORMAT RULES'),
                  _row('Text Structure', p.structure, colors),
                  _row('Emoji Usage', p.emojiUsage, colors),
                  _row('Call to Action', p.callToAction, colors),
                  _row('Hashtags', p.hashtagStyle, colors),
                  _row('Length Preset', p.lengthPreset, colors),
                  if (p.additionalInstructions != null &&
                      p.additionalInstructions!.isNotEmpty) ...[
                    const FormSectionHeader(label: 'INSTRUCTIONS'),
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: colors.bgSurface,
                        borderRadius: BorderRadius.circular(4.0),
                        border: Border.all(color: colors.borderDefault),
                      ),
                      child: Text(p.additionalInstructions!,
                          style: AppTextStyles.bodyMd.copyWith(
                              color: colors.textPrimary,
                              fontStyle: FontStyle.italic)),
                    ),
                  ],
                  const SizedBox(height: 40.0),
                  Divider(color: colors.borderDefault),
                  TextButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => ConfirmationDialog(
                          title: 'Delete Profile?',
                          body:
                              'This will permanently remove this style profile configuration from your global library.',
                          confirmLabel: 'DELETE',
                          onConfirm: () async {
                            try {
                              await ref
                                  .read(styleProfilesRepositoryProvider)
                                  .deleteProfile(profileId);
                              ref.invalidate(styleProfilesListProvider);
                              final refreshedProfiles = ref.refresh(
                                  styleProfilesNotifierProvider.future);
                              await refreshedProfiles;
                              ref.invalidate(
                                  styleProfileDetailProvider(profileId));
                              if (context.mounted) context.pop();
                            } catch (e) {
                              if (context.mounted) {
                                SnackbarHelper.showError(context, e);
                              }
                            }
                          },
                        ),
                      );
                    },
                    child: Text('DELETE PROFILE',
                        style: AppTextStyles.labelLg
                            .copyWith(color: AppColors.danger)),
                  ),
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
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.borderDefault))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: 2,
            child: Text(
              label.toUpperCase(),
              style: AppTextStyles.labelMd.copyWith(color: colors.textMuted),
              softWrap: true,
            ),
          ),
          const SizedBox(width: 16.0),
          Flexible(
            flex: 3,
            child: Text(
              value.replaceAll('_', ' ').toUpperCase(),
              style: AppTextStyles.bodyMd.copyWith(color: colors.textPrimary),
              textAlign: TextAlign.end,
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}
