import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/models/style_profile.dart';
import '../../shared/widgets/custom_button.dart';
import '../../shared/widgets/custom_text_field.dart';
import '../../shared/widgets/form_section_header.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/segmented_field.dart';
import '../../shared/widgets/snackbar_helper.dart';
import 'style_profiles_provider.dart';

class ProfileFormScreen extends ConsumerStatefulWidget {
  final bool isEdit;
  final int? profileId;

  const ProfileFormScreen({super.key, required this.isEdit, this.profileId});

  @override
  ConsumerState<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends ConsumerState<ProfileFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _entityNameController = TextEditingController();
  final _instructionsController = TextEditingController();

  String? _entityType;
  String _tone = 'semi_formal';
  String _jargonHandling = 'simplify';
  String _structure = 'paragraph';
  String _emojiUsage = 'minimal';
  String _callToAction = 'none';
  String _hashtagStyle = 'none';
  String _lengthPreset = 'medium';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEdit && widget.profileId != null) {
      _loadProfileData();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _entityNameController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    try {
      final p =
          await ref.read(styleProfileDetailProvider(widget.profileId!).future);
      _nameController.text = p.name;
      _entityNameController.text = p.entityName ?? '';
      _instructionsController.text = p.additionalInstructions ?? '';
      _entityType = p.entityType;
      _tone = p.tone;
      _jargonHandling = p.jargonHandling;
      _structure = p.structure;
      _emojiUsage = p.emojiUsage;
      _callToAction = p.callToAction;
      _hashtagStyle = p.hashtagStyle;
      _lengthPreset = p.lengthPreset;
    } catch (e) {
      if (mounted)
        SnackbarHelper.showError(context, e, prefix: 'Failed to load');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final profile = StyleProfile(
      id: widget.profileId ?? 0,
      userId: 0,
      name: _nameController.text.trim().isEmpty
          ? 'Untitled Profile'
          : _nameController.text.trim(),
      entityName: _entityNameController.text.trim().isEmpty
          ? null
          : _entityNameController.text.trim(),
      entityType: _entityType,
      tone: _tone,
      structure: _structure,
      lengthPreset: _lengthPreset,
      emojiUsage: _emojiUsage,
      jargonHandling: _jargonHandling,
      callToAction: _callToAction,
      hashtagStyle: _hashtagStyle,
      additionalInstructions: _instructionsController.text.trim().isEmpty
          ? null
          : _instructionsController.text.trim(),
    );

    try {
      if (widget.isEdit && widget.profileId != null) {
        await ref
            .read(styleProfilesRepositoryProvider)
            .updateProfile(widget.profileId!, profile);
        ref.invalidate(styleProfileDetailProvider(widget.profileId!));
      } else {
        await ref.read(styleProfilesRepositoryProvider).createProfile(profile);
      }
      ref.invalidate(styleProfilesListProvider);
      ref.refresh(styleProfilesNotifierProvider.future);

      if (mounted) {
        SnackbarHelper.showSuccess(
            context, 'Style configuration profile saved.');
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: Text(widget.isEdit ? 'EDIT STYLE PROFILE' : 'NEW STYLE PROFILE',
            style: AppTextStyles.heading2),
      ),
      body: _isLoading
          ? const LoadingView(type: LoadingViewType.form)
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FormSectionHeader(label: 'IDENTITY'),
                    CustomTextField(
                      label: 'PROFILE NAME',
                      hintText: 'e.g. Technical Executive Voice',
                      controller: _nameController,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: 'ENTITY NAME',
                      hintText: 'e.g. Senior Architect',
                      controller: _entityNameController,
                    ),
                    const SizedBox(height: 16),
                    const FormSectionHeader(label: 'VOICE & TONE'),
                    SegmentedField<String>(
                      label: 'BASE TONE',
                      options: [
                        SegmentedOption(value: 'formal', label: 'FORMAL'),
                        SegmentedOption(
                            value: 'semi_formal', label: 'SEMI-FORMAL'),
                        SegmentedOption(value: 'casual', label: 'CASUAL'),
                        SegmentedOption(value: 'punchy', label: 'PUNCHY'),
                      ],
                      selectedValue: _tone,
                      onChanged: (val) => setState(() => _tone = val),
                    ),
                    const SizedBox(height: 24),
                    const FormSectionHeader(label: 'FORMAT'),
                    SegmentedField<String>(
                      label: 'EMOJI USAGE',
                      options: [
                        SegmentedOption(value: 'none', label: 'NONE'),
                        SegmentedOption(value: 'minimal', label: 'MINIMAL'),
                        SegmentedOption(value: 'moderate', label: 'MODERATE'),
                        SegmentedOption(value: 'heavy', label: 'HEAVY'),
                      ],
                      selectedValue: _emojiUsage,
                      onChanged: (val) => setState(() => _emojiUsage = val),
                    ),
                    const SizedBox(height: 24),
                    SegmentedField<String>(
                      label: 'STRUCTURE',
                      options: [
                        SegmentedOption(value: 'paragraph', label: 'PARAGRAPH'),
                        SegmentedOption(
                            value: 'bullet_points', label: 'BULLETS'),
                      ],
                      selectedValue: _structure,
                      onChanged: (val) => setState(() => _structure = val),
                    ),
                    const SizedBox(height: 24),
                    SegmentedField<String>(
                      label: 'LENGTH',
                      options: [
                        SegmentedOption(value: 'short', label: 'SHORT'),
                        SegmentedOption(value: 'medium', label: 'MEDIUM'),
                        SegmentedOption(value: 'long', label: 'LONG'),
                      ],
                      selectedValue: _lengthPreset,
                      onChanged: (val) => setState(() => _lengthPreset = val),
                    ),
                    const SizedBox(height: 24),
                    const FormSectionHeader(label: 'ADDITIONAL INSTRUCTIONS'),
                    CustomTextField(
                      label: '',
                      hintText:
                          'E.g., Never use bullet points, limit paragraphs to 2 sentences...',
                      controller: _instructionsController,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: CustomButton(
            label: widget.isEdit ? 'SAVE CHANGES' : 'CREATE PROFILE',
            onPressed: _isLoading ? null : _saveForm,
            isLoading: _isLoading,
          ),
        ),
      ),
    );
  }
}
