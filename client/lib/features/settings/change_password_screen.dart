import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/providers/user_provider.dart';
import '../../shared/widgets/form_section_header.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/pull_to_refresh.dart';
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
        SnackbarHelper.show(context,
            message: 'Terminal access passphrase updated.',
            type: SnackbarType.success);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    return Scaffold(
      backgroundColor: colors.bgApp,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: Text('CHANGE PASSPHRASE',
            style: AppTextStyles.heading2.copyWith(color: colors.textPrimary)),
      ),
      body: _isLoading
          ? const LoadingView(type: LoadingViewType.form)
          : Form(
              key: _formKey,
              child: PullToRefresh(
                onRefresh: () async {},
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const FormSectionHeader(label: 'SECURITY KEYS'),
                      Text('CURRENT PASSWORD',
                          style: AppTextStyles.labelMd
                              .copyWith(color: colors.textSecondary)),
                      const SizedBox(height: 8.0),
                      TextFormField(
                        controller: _currentController,
                        obscureText: _obscureCurrent,
                        style: AppTextStyles.bodyLg
                            .copyWith(color: colors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Enter current credentials',
                          hintStyle: AppTextStyles.bodyLg
                              .copyWith(color: colors.textMuted),
                          filled: true,
                          fillColor: colors.bgInput,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4.0),
                              borderSide:
                                  BorderSide(color: colors.borderDefault)),
                          suffixIcon: GestureDetector(
                            onTap: () => setState(
                                () => _obscureCurrent = !_obscureCurrent),
                            child: Icon(
                                _obscureCurrent
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: colors.textMuted,
                                size: 20),
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Current password is required.'
                            : null,
                      ),
                      const SizedBox(height: 16.0),
                      Text('NEW PASSWORD',
                          style: AppTextStyles.labelMd
                              .copyWith(color: colors.textSecondary)),
                      const SizedBox(height: 8.0),
                      TextFormField(
                        controller: _newController,
                        obscureText: _obscureNew,
                        style: AppTextStyles.bodyLg
                            .copyWith(color: colors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Enter new passphrase',
                          hintStyle: AppTextStyles.bodyLg
                              .copyWith(color: colors.textMuted),
                          filled: true,
                          fillColor: colors.bgInput,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4.0),
                              borderSide:
                                  BorderSide(color: colors.borderDefault)),
                          suffixIcon: GestureDetector(
                            onTap: () =>
                                setState(() => _obscureNew = !_obscureNew),
                            child: Icon(
                                _obscureNew
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: colors.textMuted,
                                size: 20),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.length < 8) {
                            return 'Passphrase must contain at least 8 characters.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16.0),
                      Text('CONFIRM NEW PASSWORD',
                          style: AppTextStyles.labelMd
                              .copyWith(color: colors.textSecondary)),
                      const SizedBox(height: 8.0),
                      TextFormField(
                        controller: _confirmController,
                        obscureText: _obscureConfirm,
                        style: AppTextStyles.bodyLg
                            .copyWith(color: colors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Re-enter new passphrase',
                          hintStyle: AppTextStyles.bodyLg
                              .copyWith(color: colors.textMuted),
                          filled: true,
                          fillColor: colors.bgInput,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4.0),
                              borderSide:
                                  BorderSide(color: colors.borderDefault)),
                          suffixIcon: GestureDetector(
                            onTap: () => setState(
                                () => _obscureConfirm = !_obscureConfirm),
                            child: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: colors.textMuted,
                                size: 20),
                          ),
                        ),
                        validator: (v) {
                          if (v != _newController.text) {
                            return 'Confirm password does not match new password.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 40.0),
                      ElevatedButton(
                        onPressed: _changePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.luxuryOrange,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4.0)),
                        ),
                        child: Text('UPDATE PASSPHRASE',
                            style: AppTextStyles.labelLg.copyWith(
                                color: AppColors.white, letterSpacing: 1.5)),
                      ),
                      const SizedBox(height: 40.0),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
