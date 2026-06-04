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
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    final selectedIndex = _getSelectedIndex(context);
    return Scaffold(
      backgroundColor: colors.bgApp,
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: colors.borderDefault, width: 1.0))),
        child: BottomNavigationBar(
          currentIndex: selectedIndex,
          onTap: (index) => _onTabTapped(index, context),
          backgroundColor: colors.bgSurface,
          selectedItemColor: AppColors.luxuryOrange,
          unselectedItemColor: colors.textDisabled,
          selectedLabelStyle: AppTextStyles.labelSm.copyWith(letterSpacing: 0.6),
          unselectedLabelStyle: AppTextStyles.labelSm.copyWith(letterSpacing: 0.6),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.workspaces_outlined, size: 24), activeIcon: Icon(Icons.workspaces, color: AppColors.luxuryOrange, size: 24), label: 'WORKSPACES'),
            BottomNavigationBarItem(icon: Icon(Icons.style_outlined, size: 24), activeIcon: Icon(Icons.style, color: AppColors.luxuryOrange, size: 24), label: 'PROFILES'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_outlined, size: 24), activeIcon: Icon(Icons.settings, color: AppColors.luxuryOrange, size: 24), label: 'SETTINGS'),
          ],
        ),
      ),
    );
  }
}
