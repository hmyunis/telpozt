import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/models/style_profile.dart';
import '../../shared/widgets/form_section_header.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/pull_to_refresh.dart';
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
      if (mounted) {
        SnackbarHelper.showError(context, e,
            prefix: 'Failed to populate profile');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<StyleProfile>> _refreshProfilesCache() {
    ref.invalidate(styleProfilesListProvider);
    return ref.refresh(styleProfilesNotifierProvider.future);
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final profile = StyleProfile(
      id: widget.profileId ?? 0,
      userId: 0,
      name: _nameController.text.trim(),
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
      await _refreshProfilesCache();
      if (mounted) {
        SnackbarHelper.show(context,
            message: 'Style configuration profile saved.',
            type: SnackbarType.success);
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
            icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: Text(widget.isEdit ? 'EDIT PROFILE' : 'NEW PROFILE',
            style: AppTextStyles.heading2.copyWith(color: colors.textPrimary)),
      ),
      body: _isLoading
          ? const LoadingView(type: LoadingViewType.form)
          : Form(
              key: _formKey,
              child: PullToRefresh(
                onRefresh: () async {
                  if (widget.isEdit && widget.profileId != null) {
                    await _loadProfileData();
                  }
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const FormSectionHeader(label: 'IDENTITY'),
                      Text('PROFILE NAME',
                          style: AppTextStyles.labelMd
                              .copyWith(color: colors.textSecondary)),
                      const SizedBox(height: 8.0),
                      TextFormField(
                        controller: _nameController,
                        style: AppTextStyles.bodyLg
                            .copyWith(color: colors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'e.g. Technical Executive Voice',
                          hintStyle: AppTextStyles.bodyLg
                              .copyWith(color: colors.textMuted),
                          filled: true,
                          fillColor: colors.bgInput,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4.0),
                              borderSide:
                                  BorderSide(color: colors.borderDefault)),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Profile name is required.'
                            : null,
                      ),
                      const SizedBox(height: 16.0),
                      Text('SPEAK AS ENTITY',
                          style: AppTextStyles.labelMd
                              .copyWith(color: colors.textSecondary)),
                      const SizedBox(height: 8.0),
                      TextFormField(
                        controller: _entityNameController,
                        style: AppTextStyles.bodyLg
                            .copyWith(color: colors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'e.g. Senior Architect (optional)',
                          hintStyle: AppTextStyles.bodyLg
                              .copyWith(color: colors.textMuted),
                          filled: true,
                          fillColor: colors.bgInput,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4.0),
                              borderSide:
                                  BorderSide(color: colors.borderDefault)),
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      SegmentedField<String?>(
                        label: 'Entity Type Scale',
                        options: [
                          SegmentedOption(value: 'company', label: 'Company'),
                          SegmentedOption(
                              value: 'individual', label: 'Individual'),
                          SegmentedOption(
                              value: 'media_outlet', label: 'Media'),
                          SegmentedOption(
                              value: 'community', label: 'Community'),
                        ],
                        selectedValue: _entityType,
                        onChanged: (val) => setState(() => _entityType = val),
                      ),
                      const FormSectionHeader(label: 'VOICE & TONE'),
                      SegmentedField<String>(
                        label: 'Tonal Direction',
                        options: [
                          SegmentedOption(value: 'formal', label: 'Formal'),
                          SegmentedOption(
                              value: 'semi_formal', label: 'Semi-Formal'),
                          SegmentedOption(value: 'casual', label: 'Casual'),
                          SegmentedOption(value: 'punchy', label: 'Punchy'),
                        ],
                        selectedValue: _tone,
                        onChanged: (val) => setState(() => _tone = val),
                      ),
                      const SizedBox(height: 16.0),
                      SegmentedField<String>(
                        label: 'Technical Jargon Treatment',
                        options: [
                          SegmentedOption(value: 'preserve', label: 'Preserve'),
                          SegmentedOption(value: 'simplify', label: 'Simplify'),
                          SegmentedOption(
                              value: 'explain_inline', label: 'Explain Inline'),
                        ],
                        selectedValue: _jargonHandling,
                        onChanged: (val) =>
                            setState(() => _jargonHandling = val),
                      ),
                      const FormSectionHeader(label: 'FORMAT RULES'),
                      SegmentedField<String>(
                        label: 'Text Structure',
                        options: [
                          SegmentedOption(
                              value: 'paragraph', label: 'Paragraph'),
                          SegmentedOption(
                              value: 'bullet_points', label: 'Bullets'),
                          SegmentedOption(
                              value: 'lead_conclusion',
                              label: 'Lead & Conclusion'),
                          SegmentedOption(
                              value: 'inverted_pyramid',
                              label: 'Inverted Pyramid'),
                        ],
                        selectedValue: _structure,
                        onChanged: (val) => setState(() => _structure = val),
                      ),
                      const SizedBox(height: 16.0),
                      SegmentedField<String>(
                        label: 'Emoji Usage',
                        options: [
                          SegmentedOption(value: 'none', label: 'None'),
                          SegmentedOption(value: 'minimal', label: 'Minimal'),
                          SegmentedOption(value: 'moderate', label: 'Moderate'),
                          SegmentedOption(value: 'heavy', label: 'Heavy'),
                        ],
                        selectedValue: _emojiUsage,
                        onChanged: (val) => setState(() => _emojiUsage = val),
                      ),
                      const SizedBox(height: 16.0),
                      SegmentedField<String>(
                        label: 'Closing Call to Action',
                        options: [
                          SegmentedOption(value: 'none', label: 'None'),
                          SegmentedOption(value: 'soft', label: 'Soft'),
                          SegmentedOption(value: 'strong', label: 'Strong'),
                        ],
                        selectedValue: _callToAction,
                        onChanged: (val) => setState(() => _callToAction = val),
                      ),
                      const SizedBox(height: 16.0),
                      SegmentedField<String>(
                        label: 'Hashtag Curation',
                        options: [
                          SegmentedOption(value: 'none', label: 'None'),
                          SegmentedOption(value: 'minimal', label: 'Minimal'),
                          SegmentedOption(value: 'topical', label: 'Topical'),
                        ],
                        selectedValue: _hashtagStyle,
                        onChanged: (val) => setState(() => _hashtagStyle = val),
                      ),
                      const SizedBox(height: 16.0),
                      SegmentedField<String>(
                        label: 'Target Post Length Preset',
                        options: [
                          SegmentedOption(
                              value: 'short', label: 'Short (200-500)'),
                          SegmentedOption(
                              value: 'medium', label: 'Medium (500-1k)'),
                          SegmentedOption(value: 'long', label: 'Long (1k-2k)'),
                        ],
                        selectedValue: _lengthPreset,
                        onChanged: (val) => setState(() => _lengthPreset = val),
                      ),
                      const FormSectionHeader(label: 'ADDITIONAL INSTRUCTIONS'),
                      Text('CUSTOM GUIDANCE',
                          style: AppTextStyles.labelMd
                              .copyWith(color: colors.textSecondary)),
                      const SizedBox(height: 8.0),
                      TextFormField(
                        controller: _instructionsController,
                        maxLines: 4,
                        style: AppTextStyles.bodyLg
                            .copyWith(color: colors.textPrimary),
                        decoration: InputDecoration(
                          hintText:
                              'e.g. Always begin with a timestamp block. Never output friendly greetings.',
                          hintStyle: AppTextStyles.bodyLg
                              .copyWith(color: colors.textMuted),
                          filled: true,
                          fillColor: colors.bgInput,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4.0),
                              borderSide:
                                  BorderSide(color: colors.borderDefault)),
                        ),
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
                          widget.isEdit ? 'SAVE CHANGES' : 'CREATE PROFILE',
                          style: AppTextStyles.labelLg.copyWith(
                              color: AppColors.white, letterSpacing: 1.5),
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
