class Routes {
  Routes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String connectionSetup = '/connect';
  static const String workspaces = '/workspaces';
  static const String createWorkspace = '/workspaces/new';
  static const String workspaceDetail = '/workspaces/:wid';
  static const String editWorkspace = '/workspaces/:wid/edit';
  static const String scrapeResults = '/workspaces/:wid/scrape-results';
  static const String drafts = '/workspaces/:wid/drafts';
  static const String draftComposer = '/workspaces/:wid/drafts/:did';
  static const String sources = '/workspaces/:wid/sources';
  static const String createSource = '/workspaces/:wid/sources/new';
  static const String editSource = '/workspaces/:wid/sources/:sid/edit';
  static const String schedule = '/workspaces/:wid/schedule';
  static const String history = '/workspaces/:wid/history';
  static const String historyItemDetail = '/workspaces/:wid/history/:hid';
  static const String styleProfiles = '/style-profiles';
  static const String createProfile = '/style-profiles/new';
  static const String profileDetail = '/style-profiles/:pid';
  static const String editProfile = '/style-profiles/:pid/edit';
  static const String settings = '/settings';
  static const String changePassword = '/settings/change-password';
}
