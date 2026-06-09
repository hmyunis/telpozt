import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class CustomTextField extends StatefulWidget {
  final String label;
  final String hintText;
  final TextEditingController? controller;
  final bool obscureText;
  final Widget? prefixIcon;
  final int maxLines;
  final String? Function(String?)? validator;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffixIcon;

  const CustomTextField({
    super.key,
    required this.label,
    required this.hintText,
    this.controller,
    this.obscureText = false,
    this.prefixIcon,
    this.maxLines = 1,
    this.validator,
    this.readOnly = false,
    this.onTap,
    this.suffixIcon,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  final GlobalKey<FormFieldState<String>> _fieldKey =
      GlobalKey<FormFieldState<String>>();
  bool _isFocused = false;
  String? _errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label.isNotEmpty) ...[
          Text(widget.label.toUpperCase(),
              style: AppTextStyles.labelMd
                  .copyWith(color: AppColors.textSecondaryOf(context))),
          const SizedBox(height: 8),
        ],
        Focus(
          onFocusChange: (focused) => setState(() => _isFocused = focused),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: _errorText != null
                    ? AppColors.danger
                    : (_isFocused
                        ? AppColors.brandOrange
                        : AppColors.borderSubtleOf(context)),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: widget.maxLines > 1
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                if (widget.prefixIcon != null)
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 16.0, top: 14.0, bottom: 14.0),
                    child: widget.prefixIcon,
                  ),
                Expanded(
                  child: TextFormField(
                    key: _fieldKey,
                    controller: widget.controller,
                    obscureText: widget.obscureText,
                    maxLines: widget.maxLines,
                    readOnly: widget.readOnly,
                    onTap: widget.onTap,
                    style: AppTextStyles.bodyLg
                        .copyWith(color: AppColors.textPrimaryOf(context)),
                    cursorColor: AppColors.brandOrange,
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      hintStyle: AppTextStyles.bodyLg
                          .copyWith(color: AppColors.textMutedOf(context)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                      isDense: true,
                    ),
                    validator: (val) {
                      final error = widget.validator?.call(val);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && _errorText != error)
                          setState(() => _errorText = error);
                      });
                      return error;
                    },
                    onChanged: (_) {
                      if (_errorText != null) {
                        final error =
                            widget.validator?.call(widget.controller?.text);
                        if (error != _errorText)
                          setState(() => _errorText = error);
                      }
                    },
                  ),
                ),
                if (widget.suffixIcon != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: widget.suffixIcon,
                  ),
              ],
            ),
          ),
        ),
        if (_errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: AppColors.danger, size: 14),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(_errorText!,
                        style: AppTextStyles.bodySm
                            .copyWith(color: AppColors.danger))),
              ],
            ),
          ),
      ],
    );
  }
}
