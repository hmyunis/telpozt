import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/routes.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/providers/user_provider.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/form_section_header.dart';
import '../../shared/widgets/pull_to_refresh.dart';
import '../../shared/widgets/snackbar_helper.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: 'Sign Out?',
        body: 'This will terminate your current console session.',
        confirmLabel: 'SIGN OUT',
        onConfirm: () async {
          await ref.read(authNotifierProvider.notifier).logout();
        },
      ),
    );
  }

  void _showTimezonePickerBottomSheet(BuildContext context, WidgetRef ref) {
    final List<String> timezones = [
      'Africa/Addis_Ababa',
      'UTC',
      'America/New_York',
      'Europe/London',
      'Asia/Tokyo',
      'Asia/Dubai',
      'Australia/Sydney',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final colors = Theme.of(context).extension<AppColorsExtension>()!;
        return SafeArea(
          top: false,
          child: FractionallySizedBox(
            heightFactor: 0.72,
            alignment: Alignment.bottomCenter,
            child: Material(
              color: colors.bgElevated,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(12.0), topRight: Radius.circular(12.0)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(top: 12.0, bottom: 16.0),
                      decoration: BoxDecoration(color: colors.borderDefault, borderRadius: BorderRadius.circular(2.0)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text('SELECT TIMEZONE', style: AppTextStyles.heading2.copyWith(color: colors.textPrimary)),
                  ),
                  const SizedBox(height: 12.0),
                  Divider(color: colors.borderDefault, height: 1.0),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24.0),
                      itemCount: timezones.length,
                      itemBuilder: (context, idx) {
                        final tz = timezones[idx];
                        final current = ref.watch(userTimezoneProvider);
                        final isSelected = tz == current;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 24.0),
                          title: Text(tz, style: AppTextStyles.bodyLg.copyWith(color: colors.textPrimary)),
                          trailing: isSelected ? const Icon(Icons.check, color: AppColors.luxuryOrange) : null,
                          onTap: () async {
                            try {
                              await ref.read(userNotifierProvider.notifier).updateTimezone(tz);
                              if (context.mounted) {
                                SnackbarHelper.show(context, message: 'Timezone parameters updated.', type: SnackbarType.success);
                                Navigator.pop(context);
                              }
                            } catch (e) {
                              if (context.mounted) {
                            SnackbarHelper.showError(context, e);
                              }
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    final user = ref.watch(userNotifierProvider);
    final prefs = ref.watch(prefsStorageProvider);

    return Scaffold(
      backgroundColor: colors.bgApp,
      appBar: AppBar(
        title: Text('SETTINGS', style: AppTextStyles.heading1.copyWith(color: colors.textPrimary, letterSpacing: 1.5)),
        automaticallyImplyLeading: false,
      ),
      body: PullToRefresh(
        onRefresh: () async {
          await ref.read(authNotifierProvider.notifier).checkToken();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FormSectionHeader(label: 'ACCOUNT PARAMETERS'),
            _buildActionRow(colors, icon: Icons.person_outline, label: 'Username', value: user?.username ?? '@admin'),
            _buildActionRow(colors, icon: Icons.schedule, label: 'Timezone', value: user?.timezone ?? 'UTC', onTap: () => _showTimezonePickerBottomSheet(context, ref)),
            _buildActionRow(colors, icon: Icons.lock_outline, label: 'Change Passphrase', onTap: () => context.push(Routes.changePassword)),
            const FormSectionHeader(label: 'APP PREFERENCES'),
            _buildToggleRow(colors, icon: Icons.dark_mode_outlined, label: 'Dark Mode Force', value: prefs.isDarkMode, onChanged: (val) async {
              await ref.read(prefsStorageProvider).setDarkMode(val);
              ref.invalidate(prefsStorageProvider);
            }),
            _buildToggleRow(colors, icon: Icons.fingerprint, label: 'App Biometric Shield', value: prefs.isBiometricEnabled, onChanged: (val) async {
              await ref.read(prefsStorageProvider).setBiometricEnabled(val);
              ref.invalidate(prefsStorageProvider);
            }),
            const FormSectionHeader(label: 'ABOUT CONSOLE'),
            _buildActionRow(colors, icon: Icons.info_outline, label: 'Terminal Version', value: 'v1.0.0-release'),
            _buildActionRow(colors, icon: Icons.cloud_queue_outlined, label: 'Host Core Gateway', value: 'api.telpozt.io'),
            const SizedBox(height: 40.0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: ElevatedButton.icon(
                onPressed: () => _confirmLogout(context, ref),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.bgSurface,
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger, width: 1.0),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.logout, size: 20),
                label: Text('LOG OUT TERMINAL SESSION', style: AppTextStyles.labelLg.copyWith(letterSpacing: 1.5)),
              ),
            ),
            const SizedBox(height: 60.0),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildActionRow(AppColorsExtension colors, {required IconData icon, required String label, String? value, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.borderDefault))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: colors.textMuted, size: 20),
                const SizedBox(width: 12.0),
                Text(label, style: AppTextStyles.bodyLg.copyWith(color: colors.textPrimary)),
              ],
            ),
            Row(
              children: [
                if (value != null) ...[
                  Text(value, style: AppTextStyles.bodyMd.copyWith(color: colors.textSecondary)),
                  const SizedBox(width: 8.0),
                ],
                if (onTap != null) Icon(Icons.chevron_right, color: colors.textDisabled, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow(AppColorsExtension colors, {required IconData icon, required String label, required bool value, required ValueChanged<bool> onChanged}) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.borderDefault))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: colors.textMuted, size: 20),
              const SizedBox(width: 12.0),
              Text(label, style: AppTextStyles.bodyLg.copyWith(color: colors.textPrimary)),
            ],
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.luxuryOrange,
            inactiveTrackColor: colors.borderDefault,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
