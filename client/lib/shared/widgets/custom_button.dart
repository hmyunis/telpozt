import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

enum CustomButtonVariant { primary, outline, destructive, ghost }

class CustomButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final CustomButtonVariant variant;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool isLoading;
  final bool isFullWidth;

  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = CustomButtonVariant.primary,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.isFullWidth = true,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _isPressed = true);
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _isPressed = false);
      widget.onPressed!();
    }
  }

  void _handleTapCancel() {
    if (_isPressed) setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;

    Color bgColor;
    Color textColor;
    Color borderColor;

    switch (widget.variant) {
      case CustomButtonVariant.primary:
        bgColor =
            isDisabled ? AppColors.elevatedOf(context) : AppColors.brandOrange;
        textColor = isDisabled
            ? AppColors.textMutedOf(context)
            : AppColors.textOnBrandOf(context);
        borderColor = Colors.transparent;
        break;
      case CustomButtonVariant.outline:
        bgColor = Colors.transparent;
        textColor = isDisabled
            ? AppColors.textMutedOf(context)
            : AppColors.textPrimaryOf(context);
        borderColor = isDisabled
            ? AppColors.borderSubtleOf(context)
            : AppColors.borderHighlightOf(context);
        break;
      case CustomButtonVariant.destructive:
        bgColor = Colors.transparent;
        textColor = AppColors.danger;
        borderColor = AppColors.dangerDim;
        break;
      case CustomButtonVariant.ghost:
        bgColor = Colors.transparent;
        textColor =
            isDisabled ? AppColors.textMutedOf(context) : AppColors.brandOrange;
        borderColor = Colors.transparent;
        break;
    }

    Widget content = Row(
      mainAxisSize: widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(textColor),
            ),
          )
        else ...[
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 18, color: textColor),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              widget.label,
              style: AppTextStyles.labelLg.copyWith(color: textColor),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (widget.trailingIcon != null) ...[
            const SizedBox(width: 8),
            Icon(widget.trailingIcon, size: 18, color: textColor),
          ],
        ],
      ],
    );

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.isFullWidth ? double.infinity : null,
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: borderColor,
              width: 1,
            ),
          ),
          child: content,
        ),
      ),
    );
  }
}
