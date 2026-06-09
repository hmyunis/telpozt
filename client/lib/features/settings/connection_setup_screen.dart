import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/custom_button.dart';
import '../../shared/widgets/custom_text_field.dart';
import '../../shared/widgets/snackbar_helper.dart';

class ConnectionSetupScreen extends ConsumerStatefulWidget {
  const ConnectionSetupScreen({super.key});

  @override
  ConsumerState<ConnectionSetupScreen> createState() =>
      _ConnectionSetupScreenState();
}

class _ConnectionSetupScreenState extends ConsumerState<ConnectionSetupScreen> {
  final _backendUrlController = TextEditingController();
  bool _isChecking = false;
  String? _errorMessage;
  Map<String, dynamic>? _diagnostics;
  List<_GuideStep> _steps = const [];

  @override
  void initState() {
    super.initState();
    final savedUrl = ref.read(prefsStorageProvider).backendBaseUrl;
    _backendUrlController.text = savedUrl;
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _runChecks(showSuccessMessage: false));
  }

  @override
  void dispose() {
    _backendUrlController.dispose();
    super.dispose();
  }

  Future<void> _runChecks({bool showSuccessMessage = true}) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isChecking = true;
      _errorMessage = null;
    });

    final normalizedBaseUrl =
        normalizeBackendBaseUrl(_backendUrlController.text);
    final client = Dio(
      BaseOptions(
        baseUrl: normalizedBaseUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    try {
      final response = await client.get('/system/health');
      final data = Map<String, dynamic>.from(response.data['data'] as Map);
      final stepPayload =
          (data['guide'] as Map<String, dynamic>)['steps'] as List<dynamic>? ??
              [];
      final parsedSteps = stepPayload
          .map((step) =>
              _GuideStep.fromMap(Map<String, dynamic>.from(step as Map)))
          .toList();

      await ref.read(prefsStorageProvider).setBackendBaseUrl(normalizedBaseUrl);
      ref.invalidate(apiClientProvider);

      setState(() {
        _backendUrlController.text = normalizedBaseUrl;
        _diagnostics = data;
        _steps = parsedSteps;
      });

      if (showSuccessMessage && mounted) {
        SnackbarHelper.showSuccess(context,
            'Connection settings saved. Checks refreshed successfully.');
      }
    } on DioException catch (error) {
      setState(() {
        _diagnostics = null;
        _steps = _buildLocalFailureSteps(normalizedBaseUrl);
        _errorMessage = _readConnectionError(error, normalizedBaseUrl);
      });
    } catch (error) {
      setState(() {
        _diagnostics = null;
        _steps = _buildLocalFailureSteps(normalizedBaseUrl);
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  List<_GuideStep> _buildLocalFailureSteps(String normalizedBaseUrl) {
    return [
      const _GuideStep(
        id: 'wifi',
        label: 'Phone and backend computer share the same Wi-Fi',
        status: 'failed',
        message:
            'Verify both devices are on the same local network before retrying.',
      ),
      const _GuideStep(
        id: 'backend_url',
        label: 'Backend URL points to the computer running Flask',
        status: 'failed',
        message: '',
      ),
      const _GuideStep(
        id: 'backend_process',
        label: 'Flask backend is running on port 5000',
        status: 'failed',
        message:
            'Start the backend with `python wsgi.py` on the host computer.',
      ),
    ].map((step) {
      if (step.id == 'backend_url') {
        return _GuideStep(
          id: step.id,
          label: step.label,
          status: step.status,
          message: 'Current value: $normalizedBaseUrl',
        );
      }
      return step;
    }).toList();
  }

  String _readConnectionError(DioException error, String normalizedBaseUrl) {
    if (error.error is ApiError) {
      return (error.error as ApiError).message;
    }
    final host = Uri.tryParse(normalizedBaseUrl)?.host ?? normalizedBaseUrl;
    final isLoopback =
        host == '127.0.0.1' || host == 'localhost' || host == '::1';
    if (isLoopback) {
      return '127.0.0.1 and localhost only work on the same device. For a physical phone, enter the computer\'s Wi-Fi IP, for example `http://192.168.1.23:5000`.';
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.connectionError) {
      return 'Could not reach $host. Check that the backend is running, Windows Firewall allows port 5000, and the phone is on the same Wi-Fi.';
    }
    return error.message ?? 'Connection validation failed unexpectedly.';
  }

  @override
  Widget build(BuildContext context) {
    final notes = _diagnostics == null
        ? const <String>[
            'Start the backend on the computer with `python wsgi.py`.',
            'Run Ollama on the backend host and pull `qwen3.5:0.8b` plus `qwen3-embedding:0.6b`.',
            'Connect the phone and backend computer to the same Wi-Fi.',
            'Enter the computer IP as `http://YOUR_IP:5000` and tap Validate.',
          ]
        : List<String>.from((_diagnostics!['guide']
                as Map<String, dynamic>)['notes'] as List<dynamic>? ??
            const []);

    final preferredBaseUrl = (_diagnostics?['backend']
        as Map<String, dynamic>?)?['preferred_mobile_base_url'] as String?;
    final detectedIps = List<String>.from((_diagnostics?['backend']
                as Map<String, dynamic>?)?['detected_server_ips']
            as List<dynamic>? ??
        const []);
    final ai = _diagnostics?['ai'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connection Setup', style: AppTextStyles.heading1),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceOf(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderSubtleOf(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pair your phone to the local backend',
                        style: AppTextStyles.heading2
                            .copyWith(color: AppColors.textPrimaryOf(context))),
                    const SizedBox(height: 8),
                    Text(
                      'This app now uses a local Ollama pipeline. Enter the backend computer URL, then validate each step below.',
                      style: AppTextStyles.bodyMd
                          .copyWith(color: AppColors.textMutedOf(context)),
                    ),
                    const SizedBox(height: 20),
                    CustomTextField(
                      label: 'Backend URL',
                      hintText: 'http://192.168.1.23:5000',
                      controller: _backendUrlController,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Use the computer running Flask. Do not use localhost or 127.0.0.1 from a physical phone.',
                      style: AppTextStyles.bodySm
                          .copyWith(color: AppColors.textSecondaryOf(context)),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            label: 'VALIDATE CONNECTION',
                            onPressed: _isChecking ? null : () => _runChecks(),
                            isLoading: _isChecking,
                            trailingIcon: Icons.network_check,
                          ),
                        ),
                      ],
                    ),
                    if (preferredBaseUrl != null &&
                        preferredBaseUrl != _backendUrlController.text) ...[
                      const SizedBox(height: 12),
                      CustomButton(
                        label: 'USE DETECTED URL',
                        variant: CustomButtonVariant.outline,
                        onPressed: () {
                          setState(() =>
                              _backendUrlController.text = preferredBaseUrl);
                        },
                        icon: Icons.wifi_tethering,
                      ),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      _ErrorBanner(message: _errorMessage!),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _GuideCard(
                title: 'Quick guide',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: notes
                      .asMap()
                      .entries
                      .map(
                        (entry) => Padding(
                          padding: EdgeInsets.only(
                              bottom: entry.key == notes.length - 1 ? 0 : 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${entry.key + 1}.',
                                  style: AppTextStyles.labelMd
                                      .copyWith(color: AppColors.brandOrange)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(entry.value,
                                    style: AppTextStyles.bodyMd.copyWith(
                                        color: AppColors.textSecondaryOf(
                                            context))),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 24),
              _GuideCard(
                title: 'Automatic checks',
                child: Column(
                  children: _steps.isEmpty
                      ? [
                          Text(
                            'No checks have run yet. Tap Validate Connection.',
                            style: AppTextStyles.bodyMd.copyWith(
                                color: AppColors.textMutedOf(context)),
                          ),
                        ]
                      : _steps
                          .map(
                            (step) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _StepRow(step: step),
                            ),
                          )
                          .toList(),
                ),
              ),
              if (detectedIps.isNotEmpty) ...[
                const SizedBox(height: 24),
                _GuideCard(
                  title: 'Detected backend IPs',
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: detectedIps
                        .map(
                          (ip) => ActionChip(
                            label: Text(ip),
                            onPressed: () {
                              setState(() => _backendUrlController.text =
                                  'http://$ip:5000');
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
              if (ai != null) ...[
                const SizedBox(height: 24),
                _GuideCard(
                  title: 'Ollama status',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StatusLine(
                          label: 'Provider', value: '${ai['provider']}'),
                      _StatusLine(
                          label: 'Ollama API',
                          value: '${ai['ollama_base_url']}'),
                      _StatusLine(
                          label: 'Generation model',
                          value: '${ai['generation_model']}'),
                      _StatusLine(
                          label: 'Embedding model',
                          value: '${ai['embedding_model']}'),
                      if ((ai['warmup']
                              as Map<String, dynamic>?)?['response_ms'] !=
                          null)
                        _StatusLine(
                            label: 'Warmup latency',
                            value:
                                '${(ai['warmup'] as Map<String, dynamic>)['response_ms']} ms'),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              CustomButton(
                label: 'DONE',
                variant: CustomButtonVariant.ghost,
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(Routes.login);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _GuideCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtleOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: AppTextStyles.heading3
                  .copyWith(color: AppColors.textPrimaryOf(context))),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.dangerDim,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.error_outline, color: AppColors.danger, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySm.copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final _GuideStep step;

  const _StepRow({required this.step});

  @override
  Widget build(BuildContext context) {
    final isDone = step.status == 'done';
    final color = isDone ? AppColors.success : AppColors.danger;
    final icon = isDone ? Icons.check_circle : Icons.cancel;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDone ? AppColors.successDim : AppColors.dangerDim,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.label,
                    style: AppTextStyles.labelLg
                        .copyWith(color: AppColors.textPrimaryOf(context))),
                const SizedBox(height: 4),
                Text(step.message,
                    style: AppTextStyles.bodySm
                        .copyWith(color: AppColors.textSecondaryOf(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  final String label;
  final String value;

  const _StatusLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 136,
            child: Text(label,
                style: AppTextStyles.labelMd
                    .copyWith(color: AppColors.textMutedOf(context))),
          ),
          Expanded(
            child: Text(value,
                style: AppTextStyles.bodyMd
                    .copyWith(color: AppColors.textSecondaryOf(context))),
          ),
        ],
      ),
    );
  }
}

class _GuideStep {
  final String id;
  final String label;
  final String status;
  final String message;

  const _GuideStep({
    required this.id,
    required this.label,
    required this.status,
    required this.message,
  });

  factory _GuideStep.fromMap(Map<String, dynamic> map) {
    return _GuideStep(
      id: '${map['id'] ?? ''}',
      label: '${map['label'] ?? ''}',
      status: '${map['status'] ?? 'failed'}',
      message: '${map['message'] ?? ''}',
    );
  }
}
