import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/custom_text_field.dart';
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
  final _messageCountController = TextEditingController();
  final _lookbackDaysController = TextEditingController();
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
    _messageCountController.dispose();
    _lookbackDaysController.dispose();
    super.dispose();
  }

  Future<void> _loadSourceData() async {
    setState(() => _isLoading = true);
    try {
      final list = await ref.read(sourcesProvider(widget.workspaceId).future);
      final item = list.firstWhere((e) => e.id == widget.sourceId);
      _channelController.text = item.channelId;
      _displayController.text = item.displayName ?? '';
      _messageCountController.text =
          item.defaultScrapeMessageCount?.toString() ?? '';
      _lookbackDaysController.text = item.defaultLookbackDays?.toString() ?? '';
      _priority = item.priority;
      _isActive = item.isActive;
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, e,
            prefix: 'Failed to load source record');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int? _parseOptionalInt(TextEditingController controller) {
    final raw = controller.text.trim();
    if (raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final defaultScrapeMessageCount =
          _parseOptionalInt(_messageCountController);
      final defaultLookbackDays = _parseOptionalInt(_lookbackDaysController);
      if (widget.isEdit && widget.sourceId != null) {
        await ref.read(sourcesRepositoryProvider).updateSource(
              workspaceId: widget.workspaceId,
              sourceId: widget.sourceId!,
              priority: _priority,
              isActive: _isActive,
              displayName: _displayController.text.trim(),
              defaultScrapeMessageCount: defaultScrapeMessageCount,
              defaultLookbackDays: defaultLookbackDays,
            );
      } else {
        await ref.read(sourcesRepositoryProvider).addSource(
              workspaceId: widget.workspaceId,
              channelId: _channelController.text.trim(),
              displayName: _displayController.text.trim(),
              priority: _priority,
              defaultScrapeMessageCount: defaultScrapeMessageCount,
              defaultLookbackDays: defaultLookbackDays,
            );
      }
      ref.invalidate(sourcesProvider(widget.workspaceId));
      if (mounted) {
        SnackbarHelper.show(context,
            message: 'Source channel registered.', type: SnackbarType.success);
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

  Future<void> _deleteSource() async {
    if (!widget.isEdit || widget.sourceId == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Delete source?'),
              content: const Text(
                'This will remove the source channel from this workspace. This action cannot be undone.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(sourcesRepositoryProvider).deleteSource(
            workspaceId: widget.workspaceId,
            sourceId: widget.sourceId!,
          );
      ref.invalidate(sourcesProvider(widget.workspaceId));
      if (mounted) {
        context.pop('deleted');
      }
    } catch (error) {
      if (mounted) {
        SnackbarHelper.showError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;

    return Scaffold(
      backgroundColor: colors.bgApp,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
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
                      CustomTextField(
                        label: 'Channel ID',
                        hintText: '@username_handle',
                        controller: _channelController,
                        readOnly: widget.isEdit,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'A target channel handle is required.'
                            : null,
                      ),
                      const SizedBox(height: 16.0),
                      CustomTextField(
                        label: 'Display Name',
                        hintText: 'e.g. Technology Wire',
                        controller: _displayController,
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
                      const FormSectionHeader(label: 'DEFAULT SCRAPE RULE'),
                      CustomTextField(
                        label: 'Default Message Count',
                        hintText: 'e.g. 20',
                        controller: _messageCountController,
                        validator: (value) {
                          final raw = value?.trim() ?? '';
                          if (raw.isEmpty) return null;
                          final parsed = int.tryParse(raw);
                          if (parsed == null || parsed <= 0) {
                            return 'Enter a positive number.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        label: 'Default Lookback Days',
                        hintText: 'e.g. 7',
                        controller: _lookbackDaysController,
                        validator: (value) {
                          final raw = value?.trim() ?? '';
                          if (raw.isEmpty) return null;
                          final parsed = int.tryParse(raw);
                          if (parsed == null || parsed <= 0) {
                            return 'Enter a positive number of days.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Leave both blank to use the system default. During Find Content you can still override these with a per-run message count or date range.',
                        style: AppTextStyles.bodySm
                            .copyWith(color: colors.textSecondary),
                      ),
                      const SizedBox(height: 16.0),
                      SwitchListTile(
                        value: _isActive,
                        activeThumbColor: AppColors.luxuryOrange,
                        onChanged: (value) => setState(() => _isActive = value),
                        title: Text('ACTIVE',
                            style: AppTextStyles.labelLg
                                .copyWith(color: colors.textPrimary)),
                        subtitle: Text('Enable or disable this source.',
                            style: AppTextStyles.bodySm
                                .copyWith(color: colors.textSecondary)),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 40.0),
                      ElevatedButton(
                        onPressed: _saveForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.luxuryOrange,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4.0)),
                          elevation: 0,
                        ),
                        child: Text(
                          widget.isEdit ? 'SAVE CHANGES' : 'ADD SOURCE',
                          style: AppTextStyles.labelLg.copyWith(
                              color: colors.textOnBrand, letterSpacing: 1.5),
                        ),
                      ),
                      if (widget.isEdit) ...[
                        const SizedBox(height: 16.0),
                        OutlinedButton.icon(
                          onPressed: _deleteSource,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            side: BorderSide(color: AppColors.danger),
                            foregroundColor: AppColors.danger,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4.0),
                            ),
                          ),
                          icon: Icon(Icons.delete_outline),
                          label: const Text('DELETE SOURCE'),
                        ),
                      ],
                      const SizedBox(height: 40.0),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
