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

  const SegmentedField({
    super.key,
    required this.label,
    required this.options,
    required this.selectedValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label.toUpperCase(),
            style: AppTextStyles.labelMd
                .copyWith(color: AppColors.textSecondaryOf(context)),
          ),
          const SizedBox(height: 12.0),
        ],
        Wrap(
          spacing: 12.0,
          runSpacing: 12.0,
          children: options.map((opt) {
            final isSelected = opt.value == selectedValue;
            return GestureDetector(
              onTap: () => onChanged(opt.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 10.0),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.brandOrangeDim
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20.0),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.brandOrange
                        : AppColors.borderHighlightOf(context),
                    width: 1.0,
                  ),
                ),
                child: Text(
                  opt.label.toUpperCase(),
                  style: AppTextStyles.labelMd.copyWith(
                    color: isSelected
                        ? AppColors.brandOrange
                        : AppColors.textSecondaryOf(context),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
