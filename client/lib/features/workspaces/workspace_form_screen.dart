import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/form_section_header.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/pull_to_refresh.dart';
import '../../shared/widgets/snackbar_helper.dart';
import '../style_profiles/style_profiles_provider.dart';
import 'workspaces_provider.dart';

class WorkspaceFormScreen extends ConsumerStatefulWidget {
  final bool isEdit;
  final int? workspaceId;

  const WorkspaceFormScreen({super.key, required this.isEdit, this.workspaceId});

  @override
  ConsumerState<WorkspaceFormScreen> createState() => _WorkspaceFormScreenState();
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
  bool _isActive = true;

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
      _isActive = (data['is_active'] as int? ?? 1) == 1;
      if (_selectedProfileId != null) {
        final profileResponse = await client.get('/style-profiles/$_selectedProfileId');
        _selectedProfileName = profileResponse.data['data']['name'] as String?;
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, e, prefix: 'Failed to pre-populate configuration data');
      }
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
              isActive: _isActive,
              styleProfileId: _selectedProfileId,
            );
        if (mounted) {
          SnackbarHelper.show(context, message: 'Workspace configurations updated.', type: SnackbarType.success);
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
          SnackbarHelper.show(context, message: 'Workspace registered successfully.', type: SnackbarType.success);
          context.go(Routes.workspaces);
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showProfileSelectorBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final colors = Theme.of(context).extension<AppColorsExtension>()!;
        return SafeArea(
          top: false,
          child: FractionallySizedBox(
            heightFactor: 0.72,
            alignment: Alignment.bottomCenter,
            child: Material(
              color: colors.bgElevated,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(12.0), topRight: Radius.circular(12.0)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(top: 12.0, bottom: 16.0),
                      decoration: BoxDecoration(color: colors.borderDefault, borderRadius: BorderRadius.circular(2.0)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text('SELECT PROFILE', style: AppTextStyles.heading2.copyWith(color: colors.textPrimary)),
                  ),
                  const SizedBox(height: 12.0),
                  Divider(color: colors.borderDefault, height: 1.0),
                  Expanded(
                    child: Consumer(
                      builder: (context, ref, child) {
                        final listAsync = ref.watch(styleProfilesListProvider);
                        return listAsync.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.all(32.0),
                            child: SizedBox(height: 160, child: LoadingView(type: LoadingViewType.compact)),
                          ),
                          error: (err, _) => Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Text(SnackbarHelper.readableError(err), style: AppTextStyles.bodyMd.copyWith(color: AppColors.danger)),
                          ),
                          data: (list) {
                            return ListView.builder(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              itemCount: list.length + 1,
                              itemBuilder: (context, idx) {
                                if (idx == list.length) {
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 24.0),
                                    title: Text('No profile (Select later)', style: AppTextStyles.bodyLg.copyWith(color: colors.textMuted)),
                                    trailing: _selectedProfileId == null ? const Icon(Icons.check, color: AppColors.luxuryOrange) : null,
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
                                final id = p['id'] as int;
                                final name = p['name'] as String;
                                final isSelected = id == _selectedProfileId;
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 24.0),
                                  title: Text(name, style: AppTextStyles.bodyLg.copyWith(color: colors.textPrimary)),
                                  trailing: isSelected ? const Icon(Icons.check, color: AppColors.luxuryOrange) : null,
                                  onTap: () {
                                    setState(() {
                                      _selectedProfileId = id;
                                      _selectedProfileName = name;
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
                  const SizedBox(height: 16.0),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    return Scaffold(
      backgroundColor: colors.bgApp,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: Text(widget.isEdit ? 'EDIT WORKSPACE' : 'NEW WORKSPACE', style: AppTextStyles.heading2.copyWith(color: colors.textPrimary)),
      ),
      body: _isLoading
          ? const LoadingView(type: LoadingViewType.form)
          : Form(
              key: _formKey,
              child: PullToRefresh(
                onRefresh: () async {
                  if (widget.isEdit && widget.workspaceId != null) {
                    await _loadExistingWorkspaceData();
                  }
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FormSectionHeader(label: 'IDENTITY'),
                    Text('WORKSPACE NAME', style: AppTextStyles.labelMd.copyWith(color: colors.textSecondary)),
                    const SizedBox(height: 8.0),
                    TextFormField(
                      controller: _nameController,
                      style: AppTextStyles.bodyLg.copyWith(color: colors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'e.g. Primary Broadcast Feed',
                        hintStyle: AppTextStyles.bodyLg.copyWith(color: colors.textMuted),
                        filled: true,
                        fillColor: colors.bgInput,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4.0), borderSide: BorderSide(color: colors.borderDefault)),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Workspace identity name required.' : null,
                    ),
                    const SizedBox(height: 16.0),
                    Text('TARGET CHANNEL', style: AppTextStyles.labelMd.copyWith(color: colors.textSecondary)),
                    const SizedBox(height: 8.0),
                    TextFormField(
                      controller: _channelController,
                      style: AppTextStyles.mono.copyWith(color: colors.textPrimary),
                      decoration: InputDecoration(
                        hintText: '@yourchannel_handle',
                        hintStyle: AppTextStyles.bodyLg.copyWith(color: colors.textMuted),
                        filled: true,
                        fillColor: colors.bgInput,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4.0), borderSide: BorderSide(color: colors.borderDefault)),
                        prefixIcon: Icon(Icons.alternate_email, color: colors.textMuted, size: 20),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Target channel identifier required.';
                        if (!v.startsWith('@') && !RegExp(r'^\d+$').hasMatch(v)) {
                          return 'Channel ID must start with @ or be numeric.';
                        }
                        return null;
                      },
                    ),
                    const FormSectionHeader(label: 'BOT CONFIGURATION'),
                    Text('BOT TOKEN', style: AppTextStyles.labelMd.copyWith(color: colors.textSecondary)),
                    const SizedBox(height: 8.0),
                    TextFormField(
                      controller: _tokenController,
                      obscureText: _obscureToken,
                      style: AppTextStyles.mono.copyWith(color: colors.textPrimary),
                      decoration: InputDecoration(
                        hintText: '123456789:ABCdef...',
                        hintStyle: AppTextStyles.bodyLg.copyWith(color: colors.textMuted),
                        filled: true,
                        fillColor: colors.bgInput,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4.0), borderSide: BorderSide(color: colors.borderDefault)),
                        suffixIcon: GestureDetector(
                          onTap: () => setState(() => _obscureToken = !_obscureToken),
                          child: Icon(_obscureToken ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: colors.textMuted, size: 20),
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'A valid bot authorization token is required.' : null,
                    ),
                    const FormSectionHeader(label: 'STYLE PROFILE'),
                    Text('ASSIGN PROFILE', style: AppTextStyles.labelMd.copyWith(color: colors.textSecondary)),
                    const SizedBox(height: 8.0),
                    GestureDetector(
                      onTap: _showProfileSelectorBottomSheet,
                      child: Container(
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        decoration: BoxDecoration(
                          color: colors.bgInput,
                          borderRadius: BorderRadius.circular(4.0),
                          border: Border.all(color: colors.borderDefault),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedProfileName ?? 'No profile (Select later)',
                              style: AppTextStyles.bodyLg.copyWith(color: _selectedProfileName != null ? colors.textPrimary : colors.textMuted),
                            ),
                            Icon(Icons.expand_more, color: colors.textMuted, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40.0),
                    if (widget.isEdit) ...[
                      SwitchListTile(
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                        title: Text('ACTIVE', style: AppTextStyles.labelLg.copyWith(color: colors.textPrimary)),
                        subtitle: Text('Toggle whether this workspace can run.', style: AppTextStyles.bodySm.copyWith(color: colors.textSecondary)),
                        activeThumbColor: AppColors.luxuryOrange,
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 16.0),
                    ],
                    ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.luxuryOrange,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
                        elevation: 0,
                      ),
                      child: Text(
                        widget.isEdit ? 'SAVE CHANGES' : 'CREATE WORKSPACE',
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
