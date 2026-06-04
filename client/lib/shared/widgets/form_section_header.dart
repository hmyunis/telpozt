import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class FormSectionHeader extends StatelessWidget {
  final String label;
  const FormSectionHeader({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 32.0, bottom: 12.0),
      child: Row(
        children: [
          Container(width: 2, height: 16, color: AppColors.luxuryOrange),
          const SizedBox(width: 12.0),
          Text(label.toUpperCase(), style: AppTextStyles.heading3.copyWith(color: AppColors.luxuryOrange, letterSpacing: 0.6)),
        ],
      ),
    );
  }
}
