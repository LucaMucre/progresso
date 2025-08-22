import 'package:flutter/widgets.dart';

/// Global route observer to react to navigation changes across the app.
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

/// Global tab control for `HomeShell` so other widgets can switch tabs
final ValueNotifier<int> homeShellTabIndex = ValueNotifier<int>(0);

/// Signal to force-refresh Profile tab (increments value to trigger listener)
final ValueNotifier<int> homeShellProfileRefreshTick = ValueNotifier<int>(0);

void goToHomeTab(int index) {
  homeShellTabIndex.value = index;
}

void refreshProfileTab() {
  homeShellProfileRefreshTick.value++;
}

/// Global signal when action_logs changed (insert/update/delete)
final ValueNotifier<int> logsChangedTick = ValueNotifier<int>(0);

void notifyLogsChanged() {
  logsChangedTick.value++;
}

/// Global signal when life_areas changed (insert/update/delete)
final ValueNotifier<int> lifeAreasChangedTick = ValueNotifier<int>(0);

void notifyLifeAreasChanged() {
  lifeAreasChangedTick.value++;
}

/// Global redirect after login - stores the tab index to navigate to after successful login
int? _pendingRedirectTabIndex;

void setPendingRedirectAfterLogin(int tabIndex) {
  _pendingRedirectTabIndex = tabIndex;
}

void clearPendingRedirectAfterLogin() {
  _pendingRedirectTabIndex = null;
}

int? getPendingRedirectAfterLogin() {
  return _pendingRedirectTabIndex;
}

