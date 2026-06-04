import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/form_section_header.dart';
import '../../shared/widgets/pull_to_refresh.dart';
import '../../shared/widgets/snackbar_helper.dart';
import 'queue_provider.dart';

class ManualTextPasteScreen extends ConsumerStatefulWidget {
  final int workspaceId;
  final int queueId;
  const ManualTextPasteScreen(
      {super.key, required this.workspaceId, required this.queueId});

  @override
  ConsumerState<ManualTextPasteScreen> createState() =>
      _ManualTextPasteScreenState();
}

class _ManualTextPasteScreenState extends ConsumerState<ManualTextPasteScreen> {
  final _controller = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(queueRepositoryProvider).saveManualText(widget.workspaceId,
          queueId: widget.queueId, generatedText: _controller.text.trim());
      ref.invalidate(queueItemProvider(
          (workspaceId: widget.workspaceId, queueId: widget.queueId)));
      ref.invalidate(queueProvider(widget.workspaceId));
      if (mounted) {
        SnackbarHelper.show(context,
            message: 'Manual text saved.', type: SnackbarType.success);
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
          title: Text('PASTE TEXT',
              style:
                  AppTextStyles.heading2.copyWith(color: colors.textPrimary))),
      body: PullToRefresh(
        onRefresh: () async {
          ref.invalidate(queueItemProvider(
              (workspaceId: widget.workspaceId, queueId: widget.queueId)));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FormSectionHeader(label: 'MANUAL OVERRIDE'),
              TextField(
                controller: _controller,
                maxLines: 10,
                style: AppTextStyles.bodyLg.copyWith(color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Paste final post text here...',
                  hintStyle:
                      AppTextStyles.bodyLg.copyWith(color: colors.textMuted),
                  filled: true,
                  fillColor: colors.bgInput,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4.0),
                      borderSide: BorderSide(color: colors.borderDefault)),
                ),
              ),
              const SizedBox(height: 24.0),
              ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.luxuryOrange,
                    minimumSize: const Size.fromHeight(52)),
                child: Text('SAVE TEXT',
                    style:
                        AppTextStyles.labelLg.copyWith(color: AppColors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
