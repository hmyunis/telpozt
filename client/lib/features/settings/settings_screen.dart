import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/router/routes.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/providers/user_provider.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/custom_switch.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static final Future<PackageInfo> _packageInfoFuture =
      PackageInfo.fromPlatform();

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: 'LOG OUT?',
        body: 'This will terminate your current console session.',
        confirmLabel: 'LOG OUT',
        onConfirm: () async {
          await ref.read(authNotifierProvider.notifier).logout();
        },
      ),
    );
  }

  Future<void> _openAuthorSite(BuildContext context) async {
    final uri = Uri.parse('https://hamdi.dev.et');
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the author website.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userNotifierProvider);
    final prefs = ref.watch(prefsStorageProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: AppTextStyles.heading1),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionTitle(context, 'ACCOUNT'),
            _buildCardGroup(context, [
              _SettingsRow(
                icon: Icons.person_outline,
                title: 'Username',
                subtitle: '@${user?.username ?? "admin"}',
              ),
              _SettingsRow(
                icon: Icons.language,
                title: 'Timezone',
                trailingText: user?.timezone ?? 'UTC',
                onTap: () {}, // Timezone picker can be triggered here
              ),
              _SettingsRow(
                icon: Icons.key_outlined,
                title: 'Change Password',
                onTap: () => context.push(Routes.changePassword),
                showChevron: true,
              ),
            ]),
            const SizedBox(height: 32),
            _buildSectionTitle(context, 'APP PREFERENCES'),
            _buildCardGroup(context, [
              _SettingsRow(
                icon: Icons.dark_mode_outlined,
                title: 'Dark Mode',
                subtitle: 'Force AMOLED black',
                trailingWidget: CustomSwitch(
                  value: prefs.isDarkMode,
                  onChanged: (val) async {
                    await ref.read(prefsStorageProvider).setDarkMode(val);
                    ref.invalidate(prefsStorageProvider);
                  },
                ),
              ),
              _SettingsRow(
                icon: Icons.lock_outline,
                title: 'App Lock',
                subtitle: 'Require biometrics',
                trailingWidget: CustomSwitch(
                  value: prefs.isBiometricEnabled,
                  onChanged: (val) async {
                    await ref
                        .read(prefsStorageProvider)
                        .setBiometricEnabled(val);
                    ref.invalidate(prefsStorageProvider);
                  },
                ),
              ),
            ]),
            const SizedBox(height: 32),
            _buildSectionTitle(context, 'ABOUT'),
            _buildCardGroup(context, [
              FutureBuilder<PackageInfo>(
                future: _packageInfoFuture,
                builder: (context, snapshot) {
                  final packageInfo = snapshot.data;
                  final version = packageInfo == null
                      ? 'Loading...'
                      : 'v${packageInfo.version}+${packageInfo.buildNumber}';
                  return _SettingsRow(
                    icon: Icons.info_outline,
                    title: 'Version',
                    trailingText: version,
                  );
                },
              ),
              _SettingsRow(
                icon: Icons.person_outline,
                title: 'Author',
                trailingText: 'Hamdi M.',
                onTap: () => _openAuthorSite(context),
              ),
              _SettingsRow(
                icon: Icons.wifi_tethering,
                title: 'Connection Setup',
                subtitle: 'Validate backend and Ollama reachability',
                onTap: () => context.push(Routes.connectionSetup),
                showChevron: true,
              ),
            ]),
            const SizedBox(height: 48),
            GestureDetector(
              onTap: () => _confirmLogout(context, ref),
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.surfaceOf(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderSubtleOf(context)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout, color: AppColors.danger, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'LOG OUT',
                      style: AppTextStyles.labelLg
                          .copyWith(color: AppColors.danger),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4.0),
      child: Text(
        title,
        style: AppTextStyles.labelMd.copyWith(
            color: AppColors.textSecondaryOf(context), letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildCardGroup(BuildContext context, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtleOf(context)),
      ),
      child: Column(
        children: children.asMap().entries.map((entry) {
          final isLast = entry.key == children.length - 1;
          return Column(
            children: [
              entry.value,
              if (!isLast) const Divider(height: 1, indent: 56, endIndent: 16),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final Widget? trailingWidget;
  final VoidCallback? onTap;
  final bool showChevron;

  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.trailingWidget,
    this.onTap,
    this.showChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textMutedOf(context), size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTextStyles.heading3
                          .copyWith(color: AppColors.textPrimaryOf(context))),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle!,
                        style: AppTextStyles.bodySm
                            .copyWith(color: AppColors.textMutedOf(context))),
                  ],
                ],
              ),
            ),
            if (trailingText != null)
              Text(trailingText!,
                  style: AppTextStyles.bodyMd
                      .copyWith(color: AppColors.textSecondaryOf(context))),
            if (trailingWidget != null) trailingWidget!,
            if (showChevron)
              Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Icon(Icons.chevron_right,
                    color: AppColors.textMutedOf(context), size: 20),
              ),
          ],
        ),
      ),
    );
  }
}
