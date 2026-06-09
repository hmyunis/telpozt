import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class ScaffoldWithNavBar extends StatelessWidget {
  final Widget child;

  const ScaffoldWithNavBar({super.key, required this.child});

  int _getSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith(Routes.styleProfiles)) return 1;
    if (location.startsWith(Routes.settings)) return 2;
    return 0;
  }

  void _onTabTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go(Routes.workspaces);
        break;
      case 1:
        context.go(Routes.styleProfiles);
        break;
      case 2:
        context.go(Routes.settings);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _getSelectedIndex(context);

    return Scaffold(
      backgroundColor: AppColors.appBackgroundOf(context),
      body: child,
      bottomNavigationBar: Container(
        height: 80,
        decoration: BoxDecoration(
          color: AppColors.appBackgroundOf(context),
          border: Border(
              top: BorderSide(
                  color: AppColors.borderSubtleOf(context), width: 1.0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.dashboard_customize_outlined,
              label: 'WORKSPACES',
              isSelected: selectedIndex == 0,
              onTap: () => _onTabTapped(0, context),
            ),
            _NavItem(
              icon: Icons.account_circle_outlined,
              label: 'PROFILES',
              isSelected: selectedIndex == 1,
              onTap: () => _onTabTapped(1, context),
            ),
            _NavItem(
              icon: Icons.settings_outlined,
              label: 'SETTINGS',
              isSelected: selectedIndex == 2,
              onTap: () => _onTabTapped(2, context),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 100,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 2,
              width: isSelected ? 60 : 0,
              color: AppColors.brandOrange,
            ),
            const Spacer(),
            AnimatedScale(
              scale: isSelected ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                icon,
                color: isSelected
                    ? AppColors.brandOrange
                    : AppColors.textMutedOf(context),
                size: 24,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTextStyles.labelSm.copyWith(
                color: isSelected
                    ? AppColors.brandOrange
                    : AppColors.textMutedOf(context),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
