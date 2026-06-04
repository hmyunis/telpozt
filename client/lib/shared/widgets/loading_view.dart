import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum LoadingViewType { list, detail, form, compact }

class LoadingView extends StatelessWidget {
  final LoadingViewType type;
  final int itemCount;

  const LoadingView({
    super.key,
    this.type = LoadingViewType.list,
    this.itemCount = 6,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    return ColoredBox(
      color: colors.bgApp,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: switch (type) {
          LoadingViewType.compact => const Center(child: _PulseLoader()),
          LoadingViewType.detail => const _DetailSkeleton(),
          LoadingViewType.form => const _FormSkeleton(),
          LoadingViewType.list => _ListSkeleton(itemCount: itemCount),
        },
      ),
    );
  }
}

class _PulseLoader extends StatelessWidget {
  const _PulseLoader();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.luxuryOrange.withValues(alpha: 0.08),
          ),
        ),
        const SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(color: AppColors.luxuryOrange, strokeWidth: 2.0),
        ),
      ],
    );
  }
}

class SkeletonBlock extends StatelessWidget {
  final double height;
  final double? width;
  final BorderRadius borderRadius;

  const SkeletonBlock({
    super.key,
    required this.height,
    this.width,
    this.borderRadius = const BorderRadius.all(Radius.circular(4.0)),
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: colors.bgElevated,
        borderRadius: borderRadius,
        border: Border.all(color: colors.borderDefault.withValues(alpha: 0.7)),
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  final int itemCount;

  const _ListSkeleton({required this.itemCount});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 2.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SkeletonBlock(height: 78, borderRadius: BorderRadius.all(Radius.circular(8.0))),
            ],
          ),
        );
      },
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SkeletonBlock(height: 48),
          SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: SkeletonBlock(height: 72, borderRadius: BorderRadius.all(Radius.circular(8.0)))),
              SizedBox(width: 8),
              Expanded(child: SkeletonBlock(height: 72, borderRadius: BorderRadius.all(Radius.circular(8.0)))),
              SizedBox(width: 8),
              Expanded(child: SkeletonBlock(height: 72, borderRadius: BorderRadius.all(Radius.circular(8.0)))),
            ],
          ),
          SizedBox(height: 24),
          SkeletonBlock(height: 160),
          SizedBox(height: 16),
          SkeletonBlock(height: 48),
          SizedBox(height: 8),
          SkeletonBlock(height: 48),
        ],
      ),
    );
  }
}

class _FormSkeleton extends StatelessWidget {
  const _FormSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SkeletonBlock(height: 18, width: 120),
          SizedBox(height: 12),
          SkeletonBlock(height: 52),
          SizedBox(height: 16),
          SkeletonBlock(height: 18, width: 140),
          SizedBox(height: 12),
          SkeletonBlock(height: 52),
          SizedBox(height: 24),
          SkeletonBlock(height: 18, width: 130),
          SizedBox(height: 12),
          SkeletonBlock(height: 52),
          SizedBox(height: 40),
          SkeletonBlock(height: 52),
        ],
      ),
    );
  }
}
