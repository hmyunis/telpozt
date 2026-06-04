import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String body;
  final String confirmLabel;
  final Color confirmColor;
  final VoidCallback onConfirm;
  const ConfirmationDialog({super.key, required this.title, required this.body, required this.confirmLabel, this.confirmColor = AppColors.danger, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    final isDestructive = confirmColor == AppColors.danger;
    return Dialog(
      backgroundColor: colors.bgElevated,
      elevation: 16,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0), side: BorderSide(color: colors.borderDefault, width: 1.0)),
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isDestructive) ...[
              Center(child: Container(width: 44, height: 44, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.danger.withValues(alpha: 0.15)), child: const Icon(Icons.delete_outline, color: AppColors.danger, size: 24))),
              const SizedBox(height: 16.0),
            ],
            Text(title, style: AppTextStyles.heading2.copyWith(color: colors.textPrimary), textAlign: TextAlign.center),
            const SizedBox(height: 8.0),
            Text(body, style: AppTextStyles.bodyMd.copyWith(color: colors.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 24.0),
            Row(children: [
              Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: Text('CANCEL', style: AppTextStyles.labelLg.copyWith(color: AppColors.luxuryOrange)))),
              const SizedBox(width: 8.0),
              Expanded(child: ElevatedButton(onPressed: () { Navigator.pop(context); onConfirm(); }, style: ElevatedButton.styleFrom(backgroundColor: confirmColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)), elevation: 0), child: Text(confirmLabel, style: AppTextStyles.labelLg.copyWith(color: AppColors.white)))),
            ]),
          ],
        ),
      ),
    );
  }
}
