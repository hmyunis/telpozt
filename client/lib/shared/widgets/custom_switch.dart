import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class CustomSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const CustomSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 24,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: value ? AppColors.brandOrange : AppColors.elevatedOf(context),
          border: Border.all(
            color: value
                ? AppColors.brandOrange
                : AppColors.borderHighlightOf(context),
            width: 1,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              left: value ? 20 : 2,
              right: value ? 2 : 20,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value
                      ? AppColors.textOnBrandOf(context)
                      : AppColors.textMutedOf(context),
                ),
                child: value
                    ? Icon(Icons.check, size: 12, color: AppColors.brandOrange)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
