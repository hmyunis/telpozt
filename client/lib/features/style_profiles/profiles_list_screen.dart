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
import 'style_profiles_provider.dart';

class ProfilesListScreen extends ConsumerWidget {
  const ProfilesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(styleProfilesNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Voices', style: AppTextStyles.heading1),
        automaticallyImplyLeading: false,
      ),
      body: profilesAsync.when(
        loading: () => const LoadingView(),
        error: (err, _) => ErrorView(
            message: err.toString(),
            onRetry: () => ref.invalidate(styleProfilesNotifierProvider)),
        data: (list) {
          return PullToRefresh(
            onRefresh: () async =>
                ref.invalidate(styleProfilesNotifierProvider),
            child: list.isEmpty
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height * 0.7,
                      child: Center(
                        child: EmptyStateView(
                          icon: Icons.spatial_audio_off_outlined,
                          title: 'No Voices Defined',
                          subtitle:
                              'Create a style profile to control generated post tone, structure, and length.',
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics()),
                    padding: const EdgeInsets.all(24.0),
                    itemCount: list.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 24.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Manage persona styles and usage.',
                                  style: AppTextStyles.bodySm.copyWith(
                                      color: AppColors.textMutedOf(context))),
                              Text(
                                  'Total: ${list.length.toString().padLeft(2, '0')}',
                                  style: AppTextStyles.mono
                                      .copyWith(color: AppColors.brandOrange)),
                            ],
                          ),
                        );
                      }

                      final p = list[index - 1];
                      // Dynamic accent colors based on index for aesthetic variation
                      final stripColors = [
                        AppColors.brandOrange,
                        AppColors.brandOrangeDark,
                        AppColors.info,
                        AppColors.textMutedOf(context)
                      ];
                      final stripColor =
                          stripColors[(index - 1) % stripColors.length];

                      return GestureDetector(
                        onTap: () => context.push('/style-profiles/${p.id}'),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceOf(context),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.borderSubtleOf(context)),
                          ),
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  width: 4,
                                  decoration: BoxDecoration(
                                    color: stripColor,
                                    borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(8),
                                        bottomLeft: Radius.circular(8)),
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(20.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: AppColors.elevatedOf(
                                                    context),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                    color: AppColors
                                                        .borderHighlightOf(
                                                            context)),
                                              ),
                                              child: Icon(
                                                  Icons.smart_toy_outlined,
                                                  size: 20,
                                                  color: stripColor),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(p.name,
                                                      style: AppTextStyles
                                                          .heading2
                                                          .copyWith(
                                                              color: AppColors
                                                                  .textPrimaryOf(
                                                                      context))),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    (p.entityName?.isNotEmpty ==
                                                                true
                                                            ? p.entityName!
                                                            : 'GENERAL PERSONA')
                                                        .toUpperCase(),
                                                    style: AppTextStyles.labelSm
                                                        .copyWith(
                                                            color: AppColors
                                                                .textMutedOf(
                                                                    context)),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 20),
                                        const Divider(height: 1),
                                        const SizedBox(height: 20),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text('USAGE',
                                                    style: AppTextStyles.labelSm
                                                        .copyWith(
                                                            color: AppColors
                                                                .textMutedOf(
                                                                    context))),
                                                const SizedBox(height: 4),
                                                Text('--',
                                                    style: AppTextStyles.mono
                                                        .copyWith(
                                                            color: AppColors
                                                                .textPrimaryOf(
                                                                    context),
                                                            fontSize: 16)),
                                              ],
                                            ),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text('TONE',
                                                    style: AppTextStyles.labelSm
                                                        .copyWith(
                                                            color: AppColors
                                                                .textMutedOf(
                                                                    context))),
                                                const SizedBox(height: 4),
                                                Text(
                                                    p.tone
                                                        .replaceAll('_', ' ')
                                                        .toUpperCase(),
                                                    style: AppTextStyles.labelMd
                                                        .copyWith(
                                                            color: AppColors
                                                                .success)),
                                              ],
                                            ),
                                            const StatusBadge(state: 'active'),
                                          ],
                                        ),
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
        onPressed: () => context.push(Routes.createProfile),
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
