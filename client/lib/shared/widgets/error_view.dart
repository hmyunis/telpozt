import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'snackbar_helper.dart';

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    return Scaffold(
      backgroundColor: colors.bgApp,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.error_outline, size: 48, color: colors.textDisabled),
            const SizedBox(height: 16.0),
            Text('SOMETHING WENT WRONG', style: AppTextStyles.heading2.copyWith(color: colors.textPrimary), textAlign: TextAlign.center),
            const SizedBox(height: 8.0),
            Text(SnackbarHelper.readableError(message), style: AppTextStyles.bodyMd.copyWith(color: colors.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 32.0),
            Center(
              child: SizedBox(
                width: 200,
                child: OutlinedButton(
                  onPressed: onRetry,
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.luxuryOrange, width: 1.5), padding: const EdgeInsets.symmetric(vertical: 14.0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0))),
                  child: Text('RETRY', style: AppTextStyles.labelLg.copyWith(color: AppColors.luxuryOrange)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
