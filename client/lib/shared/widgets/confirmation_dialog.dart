import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'custom_button.dart';

class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String body;
  final String confirmLabel;
  final Color confirmColor;
  final VoidCallback onConfirm;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.body,
    required this.confirmLabel,
    this.confirmColor = AppColors.danger,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceOf(context),
      elevation: 24,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side:
            BorderSide(color: AppColors.borderHighlightOf(context), width: 1.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title.toUpperCase(),
                style: AppTextStyles.heading2
                    .copyWith(color: AppColors.textPrimaryOf(context))),
            const SizedBox(height: 12.0),
            Text(body,
                style: AppTextStyles.bodyMd
                    .copyWith(color: AppColors.textSecondaryOf(context))),
            const SizedBox(height: 32.0),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    label: 'CANCEL',
                    variant: CustomButtonVariant.outline,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: CustomButton(
                    label: confirmLabel,
                    variant: confirmColor == AppColors.danger
                        ? CustomButtonVariant.destructive
                        : CustomButtonVariant.primary,
                    onPressed: () {
                      Navigator.pop(context);
                      onConfirm();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
