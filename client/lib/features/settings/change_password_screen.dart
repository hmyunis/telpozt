import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/providers/user_provider.dart';
import '../../shared/widgets/custom_button.dart';
import '../../shared/widgets/custom_text_field.dart';
import '../../shared/widgets/snackbar_helper.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .changePassword(_currentController.text, _newController.text);
      if (mounted) {
        SnackbarHelper.showSuccess(
            context, 'Terminal access passphrase updated.');
        context.pop();
      }
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('CHANGE PASSWORD', style: AppTextStyles.heading2),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('[SECURITY]',
                  style: AppTextStyles.labelMd
                      .copyWith(color: AppColors.textMutedOf(context))),
              const SizedBox(height: 12),
              Divider(color: AppColors.borderSubtleOf(context)),
              const SizedBox(height: 24),
              CustomTextField(
                label: 'CURRENT PASSWORD',
                hintText: 'Enter current password',
                controller: _currentController,
                obscureText: _obscureCurrent,
                suffixIcon: GestureDetector(
                  onTap: () =>
                      setState(() => _obscureCurrent = !_obscureCurrent),
                  child: Icon(
                      _obscureCurrent
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textMutedOf(context),
                      size: 20),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Required.' : null,
              ),
              const SizedBox(height: 24.0),
              CustomTextField(
                label: 'NEW PASSWORD',
                hintText: 'Enter new password',
                controller: _newController,
                obscureText: _obscureNew,
                suffixIcon: GestureDetector(
                  onTap: () => setState(() => _obscureNew = !_obscureNew),
                  child: Icon(
                      _obscureNew
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textMutedOf(context),
                      size: 20),
                ),
                validator: (v) {
                  if (v == null || v.length < 8) return 'Min 8 chars.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _RequirementDot(
                      text: '8+ chars',
                      isValid: _newController.text.length >= 8),
                  const SizedBox(width: 16),
                  _RequirementDot(
                      text: '1 Number',
                      isValid: RegExp(r'\d').hasMatch(_newController.text)),
                  const SizedBox(width: 16),
                  _RequirementDot(
                      text: '1 Symbol',
                      isValid: RegExp(r'[^a-zA-Z0-9]')
                          .hasMatch(_newController.text)),
                ],
              ),
              const SizedBox(height: 24.0),
              CustomTextField(
                label: 'CONFIRM PASSWORD',
                hintText: 'Repeat new password',
                controller: _confirmController,
                obscureText: _obscureConfirm,
                suffixIcon: GestureDetector(
                  onTap: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                  child: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textMutedOf(context),
                      size: 20),
                ),
                validator: (v) {
                  if (v != _newController.text)
                    return 'Passwords do not match.';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: CustomButton(
            label: 'UPDATE PASSWORD',
            onPressed: _isLoading ? null : _changePassword,
            isLoading: _isLoading,
            trailingIcon: Icons.refresh,
          ),
        ),
      ),
    );
  }
}

class _RequirementDot extends StatelessWidget {
  final String text;
  final bool isValid;

  const _RequirementDot({required this.text, required this.isValid});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isValid ? AppColors.success : AppColors.textMutedOf(context),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: AppTextStyles.labelSm.copyWith(
            color: isValid
                ? AppColors.textPrimaryOf(context)
                : AppColors.textMutedOf(context),
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}
