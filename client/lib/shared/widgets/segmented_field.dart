import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class SegmentedOption<T> {
  final T value;
  final String label;
  SegmentedOption({required this.value, required this.label});
}

class SegmentedField<T> extends StatelessWidget {
  final String label;
  final List<SegmentedOption<T>> options;
  final T selectedValue;
  final ValueChanged<T> onChanged;
  const SegmentedField({super.key, required this.label, required this.options, required this.selectedValue, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label.toUpperCase(), style: AppTextStyles.labelMd.copyWith(color: colors.textSecondary, letterSpacing: 0.4)),
        const SizedBox(height: 8.0),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: options.map((opt) {
            final isSelected = opt.value == selectedValue;
            return ChoiceChip(
              label: Text(opt.label.toUpperCase(), style: AppTextStyles.labelMd.copyWith(color: isSelected ? AppColors.luxuryOrange : colors.textMuted)),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) onChanged(opt.value);
              },
              backgroundColor: Colors.transparent,
              selectedColor: AppColors.luxuryOrange.withValues(alpha: 0.15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0), side: BorderSide(color: isSelected ? AppColors.luxuryOrange : colors.borderDefault, width: isSelected ? 1.5 : 1.0)),
              elevation: 0,
              pressElevation: 0,
            );
          }).toList(),
        ),
      ],
    );
  }
}
