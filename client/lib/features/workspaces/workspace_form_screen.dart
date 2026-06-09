import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/custom_button.dart';
import '../../shared/widgets/custom_text_field.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/snackbar_helper.dart';
import '../style_profiles/style_profiles_provider.dart';
import 'workspaces_provider.dart';

class WorkspaceFormScreen extends ConsumerStatefulWidget {
  final bool isEdit;
  final int? workspaceId;

  const WorkspaceFormScreen(
      {super.key, required this.isEdit, this.workspaceId});

  @override
  ConsumerState<WorkspaceFormScreen> createState() =>
      _WorkspaceFormScreenState();
}

class _WorkspaceFormScreenState extends ConsumerState<WorkspaceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _channelController = TextEditingController();
  final _tokenController = TextEditingController();
  int? _selectedProfileId;
  String? _selectedProfileName;
  bool _obscureToken = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEdit && widget.workspaceId != null) {
      _loadExistingWorkspaceData();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _channelController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingWorkspaceData() async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get('/workspaces/${widget.workspaceId}');
      final data = response.data['data'] as Map<String, dynamic>;
      _nameController.text = data['name'] as String? ?? '';
      _channelController.text = data['target_channel_id'] as String? ?? '';
      _tokenController.text = data['bot_token'] as String? ?? '';
      _selectedProfileId = data['style_profile_id'] as int?;

      if (_selectedProfileId != null) {
        final profileResponse =
            await client.get('/style-profiles/$_selectedProfileId');
        _selectedProfileName = profileResponse.data['data']['name'] as String?;
      }
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      if (widget.isEdit && widget.workspaceId != null) {
        await ref.read(workspacesNotifierProvider.notifier).updateWorkspace(
              id: widget.workspaceId!,
              name: _nameController.text.trim(),
              targetChannelId: _channelController.text.trim(),
              botToken: _tokenController.text,
              isActive: true,
              styleProfileId: _selectedProfileId,
            );
        if (mounted) {
          SnackbarHelper.showSuccess(context, 'Workspace updated.');
          context.pop();
        }
      } else {
        await ref.read(workspacesNotifierProvider.notifier).createWorkspace(
              name: _nameController.text.trim(),
              targetChannelId: _channelController.text.trim(),
              botToken: _tokenController.text,
              styleProfileId: _selectedProfileId,
            );
        if (mounted) {
          SnackbarHelper.showSuccess(context, 'Workspace registered.');
          context.go(Routes.workspaces);
        }
      }
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showProfileSelectorBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceOf(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.7,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                      color: AppColors.borderHighlightOf(context),
                      borderRadius: BorderRadius.circular(2)),
                ),
                Text('SELECT PROFILE',
                    style: AppTextStyles.heading2
                        .copyWith(color: AppColors.textPrimaryOf(context))),
                const SizedBox(height: 16),
                const Divider(),
                Expanded(
                  child: Consumer(
                    builder: (context, ref, child) {
                      final listAsync = ref.watch(styleProfilesListProvider);
                      return listAsync.when(
                        loading: () => const LoadingView(),
                        error: (err, _) => Center(
                            child: Text(err.toString(),
                                style:
                                    const TextStyle(color: AppColors.danger))),
                        data: (list) {
                          return ListView.builder(
                            itemCount: list.length + 1,
                            itemBuilder: (context, idx) {
                              if (idx == list.length) {
                                return ListTile(
                                  title: Text('No profile',
                                      style: AppTextStyles.bodyLg.copyWith(
                                          color:
                                              AppColors.textMutedOf(context))),
                                  onTap: () {
                                    setState(() {
                                      _selectedProfileId = null;
                                      _selectedProfileName = null;
                                    });
                                    Navigator.pop(context);
                                  },
                                );
                              }
                              final p = list[idx];
                              return ListTile(
                                title: Text(p['name'],
                                    style: AppTextStyles.bodyLg.copyWith(
                                        color:
                                            AppColors.textPrimaryOf(context))),
                                trailing: _selectedProfileId == p['id']
                                    ? Icon(Icons.check,
                                        color: AppColors.brandOrange)
                                    : null,
                                onTap: () {
                                  setState(() {
                                    _selectedProfileId = p['id'] as int;
                                    _selectedProfileName = p['name'] as String;
                                  });
                                  Navigator.pop(context);
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading:
            IconButton(icon: Icon(Icons.close), onPressed: () => context.pop()),
      ),
      body: _isLoading
          ? const LoadingView(type: LoadingViewType.form)
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(widget.isEdit ? 'EDIT WORKSPACE' : 'NEW WORKSPACE',
                        style: AppTextStyles.displayLg.copyWith(fontSize: 32)),
                    const SizedBox(height: 8),
                    Text(
                        'Configure target destination and integration settings.',
                        style: AppTextStyles.bodyMd
                            .copyWith(color: AppColors.textMutedOf(context))),
                    const SizedBox(height: 24),
                    Text('[IDENTITY]',
                        style: AppTextStyles.labelMd
                            .copyWith(color: AppColors.textMutedOf(context))),
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: 'Workspace Name',
                      hintText: 'e.g. Primary Alpha Channel',
                      controller: _nameController,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: 'Target Channel',
                      hintText: '@channel_username',
                      controller: _channelController,
                      prefixIcon: Icon(Icons.alternate_email,
                          size: 18, color: AppColors.textMutedOf(context)),
                    ),
                    const SizedBox(height: 32),
                    Text('[BOT CONFIGURATION]',
                        style: AppTextStyles.labelMd
                            .copyWith(color: AppColors.textMutedOf(context))),
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: 'Bot Token',
                      hintText: '1234567890:AAH_...',
                      controller: _tokenController,
                      obscureText: _obscureToken,
                      suffixIcon: GestureDetector(
                        onTap: () =>
                            setState(() => _obscureToken = !_obscureToken),
                        child: Icon(
                            _obscureToken
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18,
                            color: AppColors.textMutedOf(context)),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 32),
                    Text('[STYLE PROFILE]',
                        style: AppTextStyles.labelMd
                            .copyWith(color: AppColors.textMutedOf(context))),
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text('Assigned Profile',
                        style: AppTextStyles.labelMd.copyWith(
                            color: AppColors.textSecondaryOf(context))),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _showProfileSelectorBottomSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceOf(context),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: AppColors.borderSubtleOf(context)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.color_lens_outlined,
                                size: 18,
                                color: AppColors.textMutedOf(context)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedProfileName ??
                                    'Select a styling profile...',
                                style: AppTextStyles.bodyLg.copyWith(
                                    color: _selectedProfileName != null
                                        ? AppColors.textPrimaryOf(context)
                                        : AppColors.textMutedOf(context)),
                              ),
                            ),
                            Icon(Icons.unfold_more,
                                size: 18,
                                color: AppColors.textMutedOf(context)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
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
            label: widget.isEdit ? 'SAVE CHANGES' : 'CREATE WORKSPACE',
            icon: widget.isEdit ? Icons.save : Icons.add_circle_outline,
            onPressed: _isLoading ? null : _submitForm,
            isLoading: _isLoading,
          ),
        ),
      ),
    );
  }
}
