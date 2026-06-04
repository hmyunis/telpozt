import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/form_section_header.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/pull_to_refresh.dart';
import '../../shared/widgets/segmented_field.dart';
import '../../shared/widgets/snackbar_helper.dart';
import 'sources_provider.dart';

class SourceFormScreen extends ConsumerStatefulWidget {
  final int workspaceId;
  final bool isEdit;
  final int? sourceId;

  const SourceFormScreen({
    super.key,
    required this.workspaceId,
    required this.isEdit,
    this.sourceId,
  });

  @override
  ConsumerState<SourceFormScreen> createState() => _SourceFormScreenState();
}

class _SourceFormScreenState extends ConsumerState<SourceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _channelController = TextEditingController();
  final _displayController = TextEditingController();
  String _priority = 'normal';
  bool _isLoading = false;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    if (widget.isEdit && widget.sourceId != null) {
      _loadSourceData();
    }
  }

  @override
  void dispose() {
    _channelController.dispose();
    _displayController.dispose();
    super.dispose();
  }

  Future<void> _loadSourceData() async {
    setState(() => _isLoading = true);
    try {
      final list = await ref.read(sourcesProvider(widget.workspaceId).future);
      final item = list.firstWhere((e) => e.id == widget.sourceId);
      _channelController.text = item.channelId;
      _displayController.text = item.displayName ?? '';
      _priority = item.priority;
      _isActive = item.isActive;
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, e, prefix: 'Failed to load source record');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      if (widget.isEdit && widget.sourceId != null) {
        await ref.read(sourcesRepositoryProvider).updateSource(
              workspaceId: widget.workspaceId,
              sourceId: widget.sourceId!,
              priority: _priority,
              isActive: _isActive,
              displayName: _displayController.text.trim(),
            );
      } else {
        await ref.read(sourcesRepositoryProvider).addSource(
              workspaceId: widget.workspaceId,
              channelId: _channelController.text.trim(),
              displayName: _displayController.text.trim(),
              priority: _priority,
            );
      }
      ref.invalidate(sourcesProvider(widget.workspaceId));
      if (mounted) {
        SnackbarHelper.show(context, message: 'Source channel registered.', type: SnackbarType.success);
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
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.isEdit ? 'EDIT SOURCE' : 'ADD SOURCE',
          style: AppTextStyles.heading2.copyWith(color: colors.textPrimary),
        ),
      ),
      body: _isLoading
          ? const LoadingView(type: LoadingViewType.form)
          : Form(
              key: _formKey,
              child: PullToRefresh(
                onRefresh: () async {
                  if (widget.isEdit && widget.sourceId != null) {
                    await _loadSourceData();
                  }
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FormSectionHeader(label: 'CHANNEL'),
                    Text('CHANNEL ID', style: AppTextStyles.labelMd.copyWith(color: colors.textSecondary)),
                    const SizedBox(height: 8.0),
                    TextFormField(
                      controller: _channelController,
                      enabled: !widget.isEdit,
                      style: AppTextStyles.mono.copyWith(color: widget.isEdit ? colors.textDisabled : colors.textPrimary),
                      decoration: InputDecoration(
                        hintText: '@username_handle',
                        hintStyle: AppTextStyles.bodyLg.copyWith(color: colors.textMuted),
                        filled: true,
                        fillColor: colors.bgInput,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4.0), borderSide: BorderSide(color: colors.borderDefault)),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'A target channel handle is required.' : null,
                    ),
                    const SizedBox(height: 16.0),
                    Text('DISPLAY NAME', style: AppTextStyles.labelMd.copyWith(color: colors.textSecondary)),
                    const SizedBox(height: 8.0),
                    TextFormField(
                      controller: _displayController,
                      style: AppTextStyles.bodyLg.copyWith(color: colors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'e.g. Technology Wire',
                        hintStyle: AppTextStyles.bodyLg.copyWith(color: colors.textMuted),
                        filled: true,
                        fillColor: colors.bgInput,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4.0), borderSide: BorderSide(color: colors.borderDefault)),
                      ),
                    ),
                    const FormSectionHeader(label: 'PRIORITY'),
                    SegmentedField<String>(
                      label: 'Scrape Tier Priority',
                      options: [
                        SegmentedOption(value: 'high', label: 'High'),
                        SegmentedOption(value: 'normal', label: 'Normal'),
                        SegmentedOption(value: 'low', label: 'Low'),
                      ],
                      selectedValue: _priority,
                      onChanged: (val) => setState(() => _priority = val),
                    ),
                    const SizedBox(height: 16.0),
                    SwitchListTile(
                      value: _isActive,
                      activeThumbColor: AppColors.luxuryOrange,
                      onChanged: (value) => setState(() => _isActive = value),
                      title: Text('ACTIVE', style: AppTextStyles.labelLg.copyWith(color: colors.textPrimary)),
                      subtitle: Text('Enable or disable this source.', style: AppTextStyles.bodySm.copyWith(color: colors.textSecondary)),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 40.0),
                    ElevatedButton(
                      onPressed: _saveForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.luxuryOrange,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
                        elevation: 0,
                      ),
                      child: Text(
                        widget.isEdit ? 'SAVE CHANGES' : 'ADD SOURCE',
                        style: AppTextStyles.labelLg.copyWith(color: AppColors.white, letterSpacing: 1.5),
                      ),
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
