import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_state.dart';
import '../auth/auth_provider.dart';
import '../../features/auth/login_screen.dart';
import '../../features/settings/change_password_screen.dart';
import '../../features/workspaces/workspaces_list_screen.dart';
import '../../features/workspaces/workspace_detail_screen.dart';
import '../../features/workspaces/workspace_form_screen.dart';
import '../../features/sources/sources_list_screen.dart';
import '../../features/sources/source_form_screen.dart';
import '../../features/style_profiles/profiles_list_screen.dart';
import '../../features/style_profiles/profile_detail_screen.dart';
import '../../features/style_profiles/profile_form_screen.dart';
import '../../features/schedule/schedule_screen.dart';
import '../../features/queue/queue_screen.dart';
import '../../features/queue/queue_item_detail_screen.dart';
import '../../features/queue/manual_text_paste_screen.dart';
import '../../features/history/history_screen.dart';
import '../../features/history/history_item_detail_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../shared/widgets/app_bar_widget.dart';
import 'routes.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authNotifierProvider, (_, __) => notifyListeners());
  }
}

final routerNotifierProvider = Provider((ref) => RouterNotifier(ref));

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(routerNotifierProvider);
  final authState = ref.watch(authNotifierProvider);
  return GoRouter(
    initialLocation: Routes.workspaces,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final isChecking = authState.isChecking;
      final isLoginRoute = state.matchedLocation == Routes.login;
      if (isChecking) return null;
      if (!isAuthenticated && !isLoginRoute) return Routes.login;
      if (isAuthenticated && isLoginRoute) return Routes.workspaces;
      return null;
    },
    routes: [
      GoRoute(path: Routes.login, builder: (context, state) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => ScaffoldWithNavBar(child: child),
        routes: [
          GoRoute(path: Routes.workspaces, builder: (context, state) => const WorkspacesListScreen()),
          GoRoute(path: Routes.styleProfiles, builder: (context, state) => const ProfilesListScreen()),
          GoRoute(path: Routes.settings, builder: (context, state) => const SettingsScreen()),
        ],
      ),
      GoRoute(path: Routes.createWorkspace, builder: (context, state) => const WorkspaceFormScreen(isEdit: false)),
      GoRoute(path: Routes.workspaceDetail, builder: (context, state) => WorkspaceDetailScreen(workspaceId: int.parse(state.pathParameters['wid']!))),
      GoRoute(path: Routes.editWorkspace, builder: (context, state) => WorkspaceFormScreen(isEdit: true, workspaceId: int.parse(state.pathParameters['wid']!))),
      GoRoute(path: Routes.sources, builder: (context, state) => SourcesListScreen(workspaceId: int.parse(state.pathParameters['wid']!))),
      GoRoute(path: Routes.createSource, builder: (context, state) => SourceFormScreen(workspaceId: int.parse(state.pathParameters['wid']!), isEdit: false)),
      GoRoute(path: Routes.editSource, builder: (context, state) => SourceFormScreen(workspaceId: int.parse(state.pathParameters['wid']!), isEdit: true, sourceId: int.parse(state.pathParameters['sid']!))),
      GoRoute(path: Routes.schedule, builder: (context, state) => ScheduleScreen(workspaceId: int.parse(state.pathParameters['wid']!))),
      GoRoute(path: Routes.queue, builder: (context, state) => QueueScreen(workspaceId: int.parse(state.pathParameters['wid']!))),
      GoRoute(path: Routes.queueItemDetail, builder: (context, state) => QueueItemDetailScreen(workspaceId: int.parse(state.pathParameters['wid']!), queueId: int.parse(state.pathParameters['qid']!))),
      GoRoute(path: Routes.manualPaste, builder: (context, state) => ManualTextPasteScreen(workspaceId: int.parse(state.pathParameters['wid']!), queueId: int.parse(state.pathParameters['qid']!))),
      GoRoute(path: Routes.history, builder: (context, state) => HistoryScreen(workspaceId: int.parse(state.pathParameters['wid']!))),
      GoRoute(path: Routes.historyItemDetail, builder: (context, state) => HistoryItemDetailScreen(workspaceId: int.parse(state.pathParameters['wid']!), historyId: int.parse(state.pathParameters['hid']!))),
      GoRoute(path: Routes.createProfile, builder: (context, state) => const ProfileFormScreen(isEdit: false)),
      GoRoute(path: Routes.profileDetail, builder: (context, state) => ProfileDetailScreen(profileId: int.parse(state.pathParameters['pid']!))),
      GoRoute(path: Routes.editProfile, builder: (context, state) => ProfileFormScreen(isEdit: true, profileId: int.parse(state.pathParameters['pid']!))),
      GoRoute(path: Routes.changePassword, builder: (context, state) => const ChangePasswordScreen()),
    ],
  );
});
