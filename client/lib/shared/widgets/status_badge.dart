import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class StatusBadge extends StatelessWidget {
  final String state;
  final bool showDot;

  const StatusBadge({super.key, required this.state, this.showDot = true});

  ({Color bg, Color border, Color text, String label}) _getBadgeProperties(
      BuildContext context) {
    switch (state.toLowerCase()) {
      case 'active':
      case 'posted':
      case 'published':
        return (
          bg: AppColors.successDim,
          border: AppColors.success.withValues(alpha: 0.3),
          text: AppColors.success,
          label: state.toUpperCase()
        );
      case 'ready':
        return (
          bg: AppColors.brandOrangeDim,
          border: AppColors.brandOrange.withValues(alpha: 0.3),
          text: AppColors.brandOrange,
          label: 'READY'
        );
      case 'generating':
        return (
          bg: AppColors.info.withValues(alpha: 0.12),
          border: AppColors.info.withValues(alpha: 0.3),
          text: AppColors.info,
          label: 'GENERATING'
        );
      case 'approved':
        return (
          bg: AppColors.scheduled.withValues(alpha: 0.15),
          border: AppColors.scheduled.withValues(alpha: 0.3),
          text: AppColors.scheduled,
          label: 'APPROVED'
        );
      case 'scheduled':
        return (
          bg: AppColors.scheduled.withValues(alpha: 0.15),
          border: AppColors.scheduled.withValues(alpha: 0.3),
          text: AppColors.scheduled,
          label: 'SCHEDULED'
        );
      case 'posting':
      case 'posting now':
        return (
          bg: AppColors.brandOrangeDim,
          border: AppColors.brandOrange.withValues(alpha: 0.3),
          text: AppColors.brandOrange,
          label: 'POSTING NOW'
        );
      case 'cancelled':
        return (
          bg: AppColors.dangerDim,
          border: AppColors.danger.withValues(alpha: 0.3),
          text: AppColors.danger,
          label: 'CANCELLED'
        );
      case 'failed':
        return (
          bg: AppColors.dangerDim,
          border: AppColors.danger.withValues(alpha: 0.3),
          text: AppColors.danger,
          label: 'FAILED'
        );
      case 'paused':
        return (
          bg: AppColors.elevatedOf(context),
          border: AppColors.borderHighlightOf(context),
          text: AppColors.textMutedOf(context),
          label: 'PAUSED'
        );
      case 'draft':
      default:
        return (
          bg: AppColors.elevatedOf(context),
          border: AppColors.borderHighlightOf(context),
          text: AppColors.textSecondaryOf(context),
          label: 'DRAFT'
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final props = _getBadgeProperties(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 10.0),
      decoration: BoxDecoration(
        color: props.bg,
        borderRadius: BorderRadius.circular(100.0),
        border: Border.all(color: props.border, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration:
                  BoxDecoration(color: props.text, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(props.label,
              style: AppTextStyles.labelSm
                  .copyWith(color: props.text, letterSpacing: 0.6)),
        ],
      ),
    );
  }
}
