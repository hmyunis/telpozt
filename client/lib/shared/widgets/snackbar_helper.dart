import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_error.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

enum SnackbarType { success, error, info, warning }

class SnackbarHelper {
  SnackbarHelper._();

  static String readableError(Object error) {
    if (error is ApiError) return error.message;
    if (error is DioException && error.error is ApiError) {
      return (error.error as ApiError).message;
    }
    final message = error.toString();
    return message
        .replaceFirst('Exception: ', '')
        .replaceFirst(RegExp(r'^ApiError\(code: [^,]+, message: '), '')
        .replaceFirst(RegExp(r', statusCode: .+\)$'), '');
  }

  static void showSuccess(BuildContext context, String message) {
    show(context, message: message, type: SnackbarType.success);
  }

  static void showError(BuildContext context, Object error, {String? prefix}) {
    final message = readableError(error);
    show(context,
        message: prefix == null ? message : '$prefix: $message',
        type: SnackbarType.error);
  }

  static void show(BuildContext context,
      {required String message, SnackbarType type = SnackbarType.info}) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.removeCurrentSnackBar();

    late final Color accentColor;
    late final IconData icon;
    switch (type) {
      case SnackbarType.success:
        accentColor = AppColors.success;
        icon = Icons.check_circle_outline;
        break;
      case SnackbarType.error:
        accentColor = AppColors.danger;
        icon = Icons.error_outline;
        break;
      case SnackbarType.info:
        accentColor = AppColors.luxuryOrange;
        icon = Icons.info_outline;
        break;
      case SnackbarType.warning:
        accentColor = AppColors.brandOrange;
        icon = Icons.warning_amber_outlined;
        break;
    }

    scaffoldMessenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceOf(context),
        elevation: 6,
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        content: Row(
          children: [
            Container(
              width: 3,
              height: 24,
              decoration: BoxDecoration(
                  color: accentColor, borderRadius: BorderRadius.circular(1.5)),
            ),
            const SizedBox(width: 10.0),
            Icon(icon, color: accentColor, size: 18),
            const SizedBox(width: 10.0),
            Expanded(
                child: Text(message,
                    style: AppTextStyles.bodyMd
                        .copyWith(color: AppColors.textPrimaryOf(context)))),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
