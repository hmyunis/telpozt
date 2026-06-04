import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;
  const EmptyStateView({super.key, required this.icon, required this.title, required this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: colors.textDisabled),
          const SizedBox(height: 16.0),
          Text(title, style: AppTextStyles.displayLg.copyWith(color: colors.textPrimary), textAlign: TextAlign.center),
          const SizedBox(height: 8.0),
          SizedBox(width: 260, child: Text(subtitle, style: AppTextStyles.bodyMd.copyWith(color: colors.textSecondary), textAlign: TextAlign.center)),
          if (action != null) ...[const SizedBox(height: 32.0), action!],
        ],
      ),
    );
  }
}
