import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/pull_to_refresh.dart';

class BiometricLockScreen extends ConsumerStatefulWidget {
  final VoidCallback onUnlock;

  const BiometricLockScreen({super.key, required this.onUnlock});

  @override
  ConsumerState<BiometricLockScreen> createState() =>
      _BiometricLockScreenState();
}

class _BiometricLockScreenState extends ConsumerState<BiometricLockScreen> {
  final LocalAuthentication _auth = LocalAuthentication();
  String _statusMessage = 'Authenticate to continue';
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _authenticate();
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
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
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
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: PullToRefresh(
          onRefresh: _authenticate,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.sizeOf(context).height -
                    MediaQuery.of(context).padding.vertical,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.obsidian,
                        borderRadius: BorderRadius.circular(16.0),
                        border: Border.all(color: AppColors.iron, width: 1.0),
                      ),
                      child: const Center(
                        child: Icon(Icons.terminal_outlined,
                            color: AppColors.luxuryOrange, size: 40),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32.0),
                  Text(
                    'LOCKED',
                    style: AppTextStyles.displayLg
                        .copyWith(color: AppColors.white, letterSpacing: 2.0),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12.0),
                  Text(
                    _statusMessage,
                    style: AppTextStyles.bodyMd.copyWith(
                        color: _isError ? AppColors.danger : AppColors.ash),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40.0),
                  Center(
                    child: GestureDetector(
                      onTap: _authenticate,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.obsidian,
                          border: Border.all(
                            color: _isError
                                ? AppColors.danger
                                : AppColors.luxuryOrange,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _isError
                                  ? AppColors.danger.withValues(alpha: 0.3)
                                  : AppColors.neonOrange.withValues(alpha: 0.3),
                              blurRadius: 16.0,
                              spreadRadius: 2.0,
                            ),
                          ],
                        ),
                        child: Icon(Icons.fingerprint,
                            color: _isError
                                ? AppColors.danger
                                : AppColors.luxuryOrange,
                            size: 32),
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      ref.read(authNotifierProvider.notifier).logout();
                    },
                    child: Text(
                      'LOG OUT',
                      style: AppTextStyles.labelMd
                          .copyWith(color: AppColors.ash, letterSpacing: 1.5),
                    ),
                  ),
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
