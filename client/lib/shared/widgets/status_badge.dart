import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class StatusBadge extends StatelessWidget {
  final String state;
  const StatusBadge({super.key, required this.state});

  ({Color bg, Color border, Color text, String label}) _getBadgeProperties() {
    switch (state.toLowerCase()) {
      case 'active':
      case 'posted':
        return (bg: AppColors.success.withValues(alpha: 0.15), border: AppColors.success, text: AppColors.success, label: 'POSTED');
      case 'approved':
        return (bg: AppColors.info.withValues(alpha: 0.15), border: AppColors.info, text: AppColors.info, label: 'APPROVED');
      case 'scheduled':
        return (bg: AppColors.scheduled.withValues(alpha: 0.15), border: AppColors.scheduled, text: AppColors.scheduled, label: 'SCHEDULED');
      case 'posting':
        return (bg: AppColors.neonOrange.withValues(alpha: 0.20), border: AppColors.neonOrange, text: AppColors.neonOrange, label: 'POSTING');
      case 'cancelled':
        return (bg: AppColors.danger.withValues(alpha: 0.10), border: AppColors.danger.withValues(alpha: 0.30), text: AppColors.danger.withValues(alpha: 0.60), label: 'CANCELLED');
      case 'failed':
        return (bg: AppColors.danger.withValues(alpha: 0.15), border: AppColors.danger, text: AppColors.danger, label: 'FAILED');
      case 'manual_review':
        return (bg: AppColors.warning.withValues(alpha: 0.15), border: AppColors.warning, text: AppColors.warning, label: 'MANUAL REVIEW');
      case 'paused':
        return (bg: AppColors.warning.withValues(alpha: 0.15), border: AppColors.warning, text: AppColors.warning, label: 'PAUSED');
      case 'draft':
      default:
        return (bg: AppColors.steelDark.withValues(alpha: 0.5), border: AppColors.steelDark, text: AppColors.ash, label: 'DRAFT');
    }
  }

  @override
  Widget build(BuildContext context) {
    final props = _getBadgeProperties();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 10.0),
      decoration: BoxDecoration(color: props.bg, borderRadius: BorderRadius.circular(100.0), border: Border.all(color: props.border, width: 1.0)),
      child: Text(props.label, style: AppTextStyles.labelSm.copyWith(color: props.text, letterSpacing: 0.6)),
    );
  }
}
