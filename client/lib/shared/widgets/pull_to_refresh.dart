import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class PullToRefresh extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;

  const PullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.luxuryOrange,
      onRefresh: onRefresh,
      child: child,
    );
  }
}

class RefreshableEmptyState extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;

  const RefreshableEmptyState({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return PullToRefresh(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: child,
          ),
        ],
      ),
    );
  }
}
