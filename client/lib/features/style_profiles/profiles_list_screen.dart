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
import 'style_profiles_provider.dart';

class ProfilesListScreen extends ConsumerWidget {
  const ProfilesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    final profilesAsync = ref.watch(styleProfilesNotifierProvider);

    return Scaffold(
      backgroundColor: colors.bgApp,
      appBar: AppBar(
        title: Text('STYLE PROFILES', style: AppTextStyles.heading1.copyWith(color: colors.textPrimary)),
        automaticallyImplyLeading: false,
      ),
      body: profilesAsync.when(
        loading: () => const LoadingView(),
        error: (err, _) => ErrorView(message: err.toString(), onRetry: () => ref.invalidate(styleProfilesNotifierProvider)),
        data: (list) {
          if (list.isEmpty) {
            return RefreshableEmptyState(
              onRefresh: () async => ref.invalidate(styleProfilesNotifierProvider),
              child: Center(
                child: EmptyStateView(
                icon: Icons.style_outlined,
                title: 'No Profiles Defined',
                subtitle: 'Create a style profile to control generated post tone, structure, and length.',
                action: OutlinedButton(
                  onPressed: () => context.push(Routes.createProfile),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.luxuryOrange, width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
                  ),
                  child: Text('ADD PROFILE', style: AppTextStyles.labelLg.copyWith(color: AppColors.luxuryOrange)),
                ),
              ),
              ),
            );
          }

          return PullToRefresh(
            onRefresh: () async => ref.invalidate(styleProfilesNotifierProvider),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              itemCount: list.length,
              separatorBuilder: (_, __) => Divider(color: colors.borderDefault, height: 1),
              itemBuilder: (context, index) {
                final p = list[index];
                return ListTile(
                  title: Text(p.name, style: AppTextStyles.heading3.copyWith(color: colors.textPrimary)),
                  subtitle: Text([p.entityName, p.entityType].where((v) => v != null && v.isNotEmpty).join(' · '), style: AppTextStyles.bodySm.copyWith(color: colors.textSecondary)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/style-profiles/${p.id}'),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(Routes.createProfile),
        backgroundColor: AppColors.luxuryOrange,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        child: const Icon(Icons.add, color: AppColors.white, size: 24),
      ),
    );
  }
}
