import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/custom_button.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/snackbar_helper.dart';
import 'style_profiles_provider.dart';

class ProfileDetailScreen extends ConsumerWidget {
  final int profileId;

  const ProfileDetailScreen({super.key, required this.profileId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(styleProfileDetailProvider(profileId));

    return detailAsync.when(
      loading: () => const LoadingView(type: LoadingViewType.detail),
      error: (err, _) => ErrorView(
        message: err.toString(),
        onRetry: () => ref.invalidate(styleProfileDetailProvider(profileId)),
      ),
      data: (p) {
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => context.push('/style-profiles/${p.id}/edit'),
              ),
            ],
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.brandOrangeDim.withOpacity(0.1),
                          Colors.transparent
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppColors.borderHighlightOf(context)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.elevatedOf(context),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.brandOrange),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(p.name.toUpperCase(),
                            style:
                                AppTextStyles.displayLg.copyWith(fontSize: 28)),
                        const SizedBox(height: 8),
                        Text('ID: P-${p.id.toString().padLeft(4, "0")}A',
                            style: AppTextStyles.mono
                                .copyWith(color: AppColors.brandOrange)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Text('[VOICE]',
                    style: AppTextStyles.labelMd
                        .copyWith(color: AppColors.textMutedOf(context))),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: _DetailBlock(
                            title: 'TONE', value: p.tone.replaceAll('_', ' '))),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _DetailBlock(
                            title: 'JARGON',
                            value: p.jargonHandling.replaceAll('_', ' '))),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: _DetailBlock(
                            title: 'CTA STYLE', value: p.callToAction)),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _DetailBlock(
                            title: 'HASHTAGS', value: p.hashtagStyle)),
                  ],
                ),
                const SizedBox(height: 32),
                Text('[FORMAT]',
                    style: AppTextStyles.labelMd
                        .copyWith(color: AppColors.textMutedOf(context))),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.elevatedOf(context),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.borderHighlightOf(context)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.format_list_bulleted,
                                size: 16,
                                color: AppColors.textSecondaryOf(context)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(
                                    p.structure
                                        .replaceAll('_', ' ')
                                        .toUpperCase(),
                                    style: AppTextStyles.labelMd)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.elevatedOf(context),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.borderHighlightOf(context)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.mood_bad,
                                size: 16,
                                color: AppColors.textSecondaryOf(context)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(
                                    '${p.emojiUsage} EMOJIS'.toUpperCase(),
                                    style: AppTextStyles.labelMd)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                if (p.additionalInstructions?.isNotEmpty == true) ...[
                  Text('[INSTRUCTIONS]',
                      style: AppTextStyles.labelMd
                          .copyWith(color: AppColors.textMutedOf(context))),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.elevatedOf(context),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.borderHighlightOf(context)),
                    ),
                    child: Text(
                      p.additionalInstructions!,
                      style: AppTextStyles.bodyLg
                          .copyWith(color: AppColors.textSecondaryOf(context)),
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
                CustomButton(
                  label: 'DELETE PROFILE',
                  icon: Icons.delete_outline,
                  variant: CustomButtonVariant.destructive,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => ConfirmationDialog(
                        title: 'DELETE PROFILE?',
                        body:
                            'This will permanently remove this style profile configuration.',
                        confirmLabel: 'DELETE',
                        onConfirm: () async {
                          try {
                            await ref
                                .read(styleProfilesRepositoryProvider)
                                .deleteProfile(profileId);
                            ref.invalidate(styleProfilesListProvider);
                            await ref
                                .refresh(styleProfilesNotifierProvider.future);
                            if (context.mounted) {
                              SnackbarHelper.showSuccess(
                                  context, 'Profile removed.');
                              context.pop();
                            }
                          } catch (e) {
                            if (context.mounted)
                              SnackbarHelper.showError(context, e);
                          }
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DetailBlock extends StatelessWidget {
  final String title;
  final String value;

  const _DetailBlock({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtleOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: AppTextStyles.labelSm
                  .copyWith(color: AppColors.textMutedOf(context))),
          const SizedBox(height: 8),
          Text(
            value.toUpperCase(),
            style: AppTextStyles.labelMd
                .copyWith(color: AppColors.textPrimaryOf(context)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
