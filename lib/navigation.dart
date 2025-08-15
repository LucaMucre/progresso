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

