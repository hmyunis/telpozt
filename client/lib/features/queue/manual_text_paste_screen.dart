import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/custom_button.dart';
import '../../shared/widgets/custom_text_field.dart';
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
        SnackbarHelper.showSuccess(context, 'Manual text saved.');
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
    final promptAsync = ref.watch(queuePromptProvider(
        (workspaceId: widget.workspaceId, queueId: widget.queueId)));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: const Text('MANUAL ENTRY', style: AppTextStyles.heading2),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.info.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: AppColors.info, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Copy the system prompt below and generate your content externally. Once complete, paste the raw result into the designated area to proceed.',
                      style: AppTextStyles.bodySm
                          .copyWith(color: AppColors.textSecondaryOf(context)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                        color: AppColors.textMutedOf(context),
                        shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text('GENERATION PROMPT',
                    style: AppTextStyles.labelMd
                        .copyWith(color: AppColors.textMutedOf(context))),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderSubtleOf(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    promptAsync.valueOrNull?['prompt'] ??
                        'Loading prompt data...',
                    style: AppTextStyles.bodyMd
                        .copyWith(color: AppColors.textSecondaryOf(context)),
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    label: 'COPY PROMPT',
                    icon: Icons.copy,
                    variant: CustomButtonVariant.outline,
                    onPressed: () {}, // copy logic implementation here
                  )
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                            color: AppColors.brandOrange,
                            shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text('AI RESULT',
                        style: AppTextStyles.labelMd
                            .copyWith(color: AppColors.brandOrange)),
                  ],
                ),
                Text('INPUT REQUIRED',
                    style: AppTextStyles.labelSm
                        .copyWith(color: AppColors.textMutedOf(context))),
              ],
            ),
            const SizedBox(height: 12),
            CustomTextField(
              label: '',
              hintText: 'Paste your generated text here...',
              controller: _controller,
              maxLines: 8,
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            border: Border(
                top: BorderSide(color: AppColors.borderSubtleOf(context))),
          ),
          child: CustomButton(
            label: 'SAVE & USE THIS TEXT',
            icon: Icons.save,
            onPressed: _isLoading ? null : _save,
            isLoading: _isLoading,
          ),
        ),
      ),
    );
  }
}
