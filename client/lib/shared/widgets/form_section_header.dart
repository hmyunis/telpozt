import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class FormSectionHeader extends StatelessWidget {
  final String label;

  const FormSectionHeader({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 32.0, bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.brandOrange,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
          const SizedBox(width: 12.0),
          Text(
            label.toUpperCase(),
            style: AppTextStyles.labelLg.copyWith(
              color: AppColors.brandOrange,
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }
}
