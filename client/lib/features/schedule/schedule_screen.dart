import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/custom_button.dart';
import '../../shared/widgets/custom_switch.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/pull_to_refresh.dart';
import '../../shared/widgets/snackbar_helper.dart';
import 'schedule_provider.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  final int workspaceId;
  const ScheduleScreen({super.key, required this.workspaceId});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  bool _autoPosting = true;
  List<String> _slots = [];
  bool _isInitialized = false;
  bool _isSaving = false;

  Future<void> _saveSchedule() async {
    setState(() => _isSaving = true);
    try {
      await ref
          .read(scheduleRepositoryProvider)
          .updateSchedule(widget.workspaceId, _slots, _autoPosting);
      ref.invalidate(scheduleProvider(widget.workspaceId));
      if (mounted) {
        SnackbarHelper.showSuccess(
            context, 'Schedule configuration synchronized.');
        context.pop();
      }
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, e);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _addSlot() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.brandOrange,
              surface: AppColors.surfaceOf(context),
              onSurface: AppColors.textPrimaryOf(context),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final hour = picked.hour.toString().padLeft(2, '0');
      final min = picked.minute.toString().padLeft(2, '0');
      final timeStr = '$hour:$min';

      if (!_slots.contains(timeStr)) {
        setState(() {
          _slots.add(timeStr);
          _slots.sort(); // Keep slots ordered chronologically
        });
      } else {
        SnackbarHelper.show(context,
            message: 'Time slot already exists.', type: SnackbarType.warning);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheduleAsync = ref.watch(scheduleProvider(widget.workspaceId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: scheduleAsync.when(
          loading: () => const LoadingView(),
          error: (err, _) => ErrorView(
              message: err.toString(),
              onRetry: () =>
                  ref.invalidate(scheduleProvider(widget.workspaceId))),
          data: (config) {
            if (!_isInitialized) {
              _slots = List.from(config.timeSlots);
              _autoPosting = config.isEnabled;
              _isInitialized = true;
            }

            return PullToRefresh(
              onRefresh: () async =>
                  ref.invalidate(scheduleProvider(widget.workspaceId)),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Posting Schedule',
                        style: AppTextStyles.displayLg),
                    const SizedBox(height: 8),
                    Text(
                        'Configure automated publishing constraints for this workspace.',
                        style: AppTextStyles.bodyMd
                            .copyWith(color: AppColors.textMutedOf(context))),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceOf(context),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.borderSubtleOf(context)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Auto-Posting',
                                    style: AppTextStyles.heading3.copyWith(
                                        color:
                                            AppColors.textPrimaryOf(context))),
                                const SizedBox(height: 4),
                                Text(
                                    'System automatically selects next available slot',
                                    style: AppTextStyles.bodySm.copyWith(
                                        color: AppColors.textMutedOf(context))),
                              ],
                            ),
                          ),
                          CustomSwitch(
                              value: _autoPosting,
                              onChanged: (v) =>
                                  setState(() => _autoPosting = v)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceOf(context),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.info),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.public, color: AppColors.info, size: 20),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('WORKSPACE TIMEZONE',
                                    style: AppTextStyles.labelSm
                                        .copyWith(color: AppColors.info)),
                                Text(config.timezone,
                                    style: AppTextStyles.bodyLg.copyWith(
                                        color:
                                            AppColors.textPrimaryOf(context))),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text('ACTIVE TIME SLOTS',
                        style: AppTextStyles.labelMd
                            .copyWith(color: AppColors.textMutedOf(context))),
                    const SizedBox(height: 16),
                    ..._slots.map((slot) => _buildSlotCard(slot)).toList(),
                    GestureDetector(
                      onTap: _addSlot,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.borderHighlightOf(context),
                              style: BorderStyle.solid),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add,
                                color: AppColors.textMutedOf(context),
                                size: 16),
                            const SizedBox(width: 8),
                            Text('ADD TIME SLOT',
                                style: AppTextStyles.labelLg.copyWith(
                                    color: AppColors.textMutedOf(context))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            );
          }),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: CustomButton(
            label: 'SAVE SCHEDULE',
            onPressed: _isSaving ? null : _saveSchedule,
            isLoading: _isSaving,
          ),
        ),
      ),
    );
  }

  Widget _buildSlotCard(String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtleOf(context)),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time, color: AppColors.brandOrange, size: 20),
          const SizedBox(width: 16),
          Expanded(
              child: Text(time,
                  style: AppTextStyles.heading2.copyWith(letterSpacing: 2.0))),
          GestureDetector(
            onTap: () => setState(() => _slots.remove(time)),
            child: Icon(Icons.close,
                color: AppColors.textMutedOf(context), size: 20),
          )
        ],
      ),
    );
  }
}
