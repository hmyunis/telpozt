import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class BiometricLockScreen extends ConsumerStatefulWidget {
  final VoidCallback onUnlock;

  const BiometricLockScreen({super.key, required this.onUnlock});

  @override
  ConsumerState<BiometricLockScreen> createState() =>
      _BiometricLockScreenState();
}

class _BiometricLockScreenState extends ConsumerState<BiometricLockScreen>
    with SingleTickerProviderStateMixin {
  final LocalAuthentication _auth = LocalAuthentication();
  String _statusMessage = 'Authenticate to continue';
  bool _isError = false;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _authenticate();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    try {
      final canUseBiometrics = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      if (!canUseBiometrics && !isDeviceSupported) {
        setState(() {
          _statusMessage = 'Biometric hardware unavailable.';
          _isError = true;
        });
        return;
      }

      final authenticated = await _auth.authenticate(
        localizedReason: 'Access the Telpozt Secure Terminal',
        options:
            const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
      );

      if (authenticated) {
        widget.onUnlock();
      } else {
        setState(() {
          _statusMessage = 'Authentication failed. Touch to retry.';
          _isError = true;
        });
      }
    } catch (_) {
      setState(() {
        _statusMessage = 'Authentication error. Please retry.';
        _isError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackgroundOf(context),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(flex: 3),
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.surfaceOf(context),
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(
                      color: AppColors.borderHighlightOf(context), width: 1.0),
                ),
                child: const Center(
                    child: Icon(Icons.terminal_outlined,
                        color: AppColors.brandOrange, size: 40)),
              ),
            ),
            const SizedBox(height: 32.0),
            Text('LOCKED',
                style: AppTextStyles.displayLg
                    .copyWith(color: AppColors.textPrimaryOf(context)),
                textAlign: TextAlign.center),
            const SizedBox(height: 12.0),
            Text(_statusMessage,
                style: AppTextStyles.bodyMd.copyWith(
                    color: _isError
                        ? AppColors.danger
                        : AppColors.textMutedOf(context)),
                textAlign: TextAlign.center),
            const Spacer(flex: 2),
            Center(
              child: GestureDetector(
                onTap: _authenticate,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final accent =
                        _isError ? AppColors.danger : AppColors.brandOrange;
                    return Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: accent, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(
                                alpha: 0.2 * _pulseController.value),
                            blurRadius: 30,
                            spreadRadius: 10 * _pulseController.value,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.fingerprint, color: accent, size: 40),
                          const SizedBox(height: 8),
                          Text('TOUCH ID',
                              style: AppTextStyles.labelSm.copyWith(
                                  color: _isError
                                      ? AppColors.danger
                                      : AppColors.textMutedOf(context))),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const Spacer(flex: 3),
            Center(
              child: TextButton.icon(
                onPressed: () =>
                    ref.read(authNotifierProvider.notifier).logout(),
                icon: Icon(Icons.logout, size: 16),
                label: const Text('LOG OUT'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textMutedOf(context),
                  textStyle: AppTextStyles.labelMd,
                ),
              ),
            ),
            const SizedBox(height: 32.0),
          ],
        ),
      ),
    );
  }
}
