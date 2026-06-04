import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_error.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/pull_to_refresh.dart';

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
      if (mounted) {
        context.go(Routes.workspaces);
      }
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
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    return Scaffold(
      backgroundColor: colors.bgApp,
      body: SafeArea(
        child: PullToRefresh(
          onRefresh: () async {
            _passwordController.clear();
            setState(() => _errorMessage = null);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 60.0),
                  Text('TELPOZT',
                      style: AppTextStyles.displayXl.copyWith(
                          color: colors.textPrimary, letterSpacing: 2.5)),
                  const SizedBox(height: 8.0),
                  Text('Your automation command terminal.',
                      style: AppTextStyles.bodyMd
                          .copyWith(color: colors.textMuted)),
                  const SizedBox(height: 32.0),
                  Divider(color: colors.borderDefault, height: 1.0),
                  const SizedBox(height: 32.0),
                  Row(
                    children: [
                      Container(
                          width: 2, height: 16, color: AppColors.luxuryOrange),
                      const SizedBox(width: 8.0),
                      Text('SIGN IN',
                          style: AppTextStyles.labelMd.copyWith(
                              color: AppColors.luxuryOrange,
                              letterSpacing: 1.5)),
                    ],
                  ),
                  const SizedBox(height: 24.0),
                  Text('USERNAME',
                      style: AppTextStyles.labelMd.copyWith(
                          color: colors.textSecondary, letterSpacing: 0.4)),
                  const SizedBox(height: 8.0),
                  TextFormField(
                    controller: _usernameController,
                    style: AppTextStyles.bodyLg
                        .copyWith(color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Enter terminal username',
                      hintStyle: AppTextStyles.bodyLg
                          .copyWith(color: colors.textMuted),
                      filled: true,
                      fillColor: colors.bgInput,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 14.0, horizontal: 16.0),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4.0),
                          borderSide: BorderSide(color: colors.borderDefault)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4.0),
                          borderSide: BorderSide(
                              color: colors.borderFocus, width: 1.5)),
                      prefixIcon: Icon(Icons.person_outline,
                          color: colors.textMuted, size: 20),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Username required to initiate sequence.'
                            : null,
                  ),
                  const SizedBox(height: 16.0),
                  Text('PASSWORD',
                      style: AppTextStyles.labelMd.copyWith(
                          color: colors.textSecondary, letterSpacing: 0.4)),
                  const SizedBox(height: 8.0),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: AppTextStyles.bodyLg
                        .copyWith(color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Enter passphrase credentials',
                      hintStyle: AppTextStyles.bodyLg
                          .copyWith(color: colors.textMuted),
                      filled: true,
                      fillColor: colors.bgInput,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 14.0, horizontal: 16.0),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4.0),
                          borderSide: BorderSide(color: colors.borderDefault)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4.0),
                          borderSide: BorderSide(
                              color: colors.borderFocus, width: 1.5)),
                      prefixIcon: Icon(Icons.lock_outline,
                          color: colors.textMuted, size: 20),
                      suffixIcon: GestureDetector(
                        onTap: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                        child: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: colors.textMuted,
                            size: 20),
                      ),
                    ),
                    validator: (value) => (value == null || value.isEmpty)
                        ? 'Password credentials required.'
                        : null,
                  ),
                  const SizedBox(height: 16.0),
                  if (_errorMessage != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.danger, size: 16),
                        const SizedBox(width: 8.0),
                        Expanded(
                            child: Text(_errorMessage!,
                                style: AppTextStyles.bodySm
                                    .copyWith(color: AppColors.danger))),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                  ],
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.luxuryOrange,
                      disabledBackgroundColor: colors.borderDefault,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4.0)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: AppColors.white, strokeWidth: 2.0))
                        : Text('INITIALIZE SEQUENCE',
                            style: AppTextStyles.labelLg.copyWith(
                                color: AppColors.white, letterSpacing: 1.5)),
                  ),
                  const SizedBox(height: 60.0),
                  Center(
                      child: Text('SYSTEM VERSION: v1.0.0-STABLE',
                          style: AppTextStyles.labelSm
                              .copyWith(color: colors.textMuted))),
                  const SizedBox(height: 24.0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
