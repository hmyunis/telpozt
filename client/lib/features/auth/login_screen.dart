import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_error.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/custom_button.dart';
import '../../shared/widgets/custom_text_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _errorMessage;
  bool _isLoading = false;

  Future<void> _openConnectionSetup() async {
    await context.push(Routes.connectionSetup);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authNotifierProvider.notifier).login(
            _usernameController.text.trim(),
            _passwordController.text,
          );
      if (mounted) context.go(Routes.workspaces);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e is ApiError
            ? e.message
            : 'An unexpected connection error occurred.';
      });
      _passwordController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final savedBackendUrl = normalizeBackendBaseUrl(
      ref.read(prefsStorageProvider).backendBaseUrl,
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Container(
              padding: const EdgeInsets.all(32.0),
              decoration: BoxDecoration(
                color: AppColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: AppColors.borderSubtleOf(context)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.pureBlack.withValues(alpha: 0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('SIGN IN',
                        style: AppTextStyles.displayLg
                            .copyWith(color: AppColors.textPrimaryOf(context)),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 8.0),
                    Text('Enter your credentials to access the terminal.',
                        style: AppTextStyles.bodyMd
                            .copyWith(color: AppColors.textMutedOf(context)),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 24.0),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.elevatedOf(context),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.borderSubtleOf(context),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'BACKEND URL',
                            style: AppTextStyles.labelMd.copyWith(
                              color: AppColors.textMutedOf(context),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            savedBackendUrl,
                            style: AppTextStyles.bodyMd.copyWith(
                              color: AppColors.textPrimaryOf(context),
                            ),
                          ),
                          const SizedBox(height: 12),
                          CustomButton(
                            label: 'CONFIGURE CONNECTION',
                            variant: CustomButtonVariant.outline,
                            onPressed: _openConnectionSetup,
                            icon: Icons.settings_ethernet,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40.0),
                    CustomTextField(
                      label: 'USERNAME',
                      hintText: 'Admin_01',
                      controller: _usernameController,
                      prefixIcon: Icon(Icons.person_outline,
                          color: AppColors.textMutedOf(context), size: 20),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Username required.'
                              : null,
                    ),
                    const SizedBox(height: 24.0),
                    CustomTextField(
                      label: 'PASSPHRASE',
                      hintText: '••••••••',
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      prefixIcon: Icon(Icons.key_outlined,
                          color: AppColors.textMutedOf(context), size: 20),
                      suffixIcon: GestureDetector(
                        onTap: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                        child: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.textMutedOf(context),
                            size: 20),
                      ),
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Passphrase required.'
                          : null,
                    ),
                    const SizedBox(height: 16.0),
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.dangerDim,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: AppColors.danger.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: AppColors.danger, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(_errorMessage!,
                                    style: AppTextStyles.bodySm
                                        .copyWith(color: AppColors.danger))),
                          ],
                        ),
                      ),
                    const SizedBox(height: 32.0),
                    CustomButton(
                      label: 'INITIALIZE SEQUENCE',
                      onPressed: _isLoading ? null : _submitForm,
                      isLoading: _isLoading,
                      trailingIcon: Icons.arrow_forward,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
