import 'package:flutter/material.dart';
import 'dashboard_page.dart';
import 'l10n/app_localizations.dart';
import 'life_area_selection_page.dart';
import 'insights_page.dart';
import 'statistics_page.dart';
// import 'chat_page.dart';
import 'profile_page.dart';
import 'settings_page.dart';
import 'navigation.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    homeShellTabIndex.addListener(_onExternalTabChange);
    homeShellProfileRefreshTick.addListener(_onExternalProfileRefresh);
  }

  @override
  void dispose() {
    homeShellTabIndex.removeListener(_onExternalTabChange);
    homeShellProfileRefreshTick.removeListener(_onExternalProfileRefresh);
    super.dispose();
  }

  void _onExternalTabChange() {
    final i = homeShellTabIndex.value;
    if (!mounted) return;
    setState(() {
      _currentIndex = i;
    });
  }

  void _onExternalProfileRefresh() {
    if (!mounted) return;
    setState(() {
      _currentIndex = 4; // Profile is now at index 4 (after adding Statistics)
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 700;
    final t = AppLocalizations.of(context);

    return Scaffold
    (
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: const [
            DashboardPage(),
            LifeAreaSelectionPage(),
            InsightsPage(),
            StatisticsPage(),
            ProfilePage(),
            SettingsPage(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          height: isWide ? 64 : 76,
          labelBehavior: isWide ? NavigationDestinationLabelBehavior.onlyShowSelected : NavigationDestinationLabelBehavior.alwaysShow,
          backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) => setState(() {
              _currentIndex = i;
            }),
            backgroundColor: Colors.transparent,
            elevation: 0,
            destinations: [
              NavigationDestination(icon: const Icon(Icons.dashboard_outlined), selectedIcon: const Icon(Icons.dashboard), label: t?.navDashboard ?? 'Dashboard'),
              NavigationDestination(icon: const Icon(Icons.add_circle_outline), selectedIcon: const Icon(Icons.add_circle), label: t?.navLog ?? 'Log'),
              NavigationDestination(icon: const Icon(Icons.lightbulb_outline), selectedIcon: const Icon(Icons.lightbulb), label: 'Insights'),
              NavigationDestination(icon: const Icon(Icons.analytics_outlined), selectedIcon: const Icon(Icons.analytics), label: 'Statistics'),
              NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: t?.navProfile ?? 'Profile'),
              NavigationDestination(icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings), label: t?.navSettings ?? 'Settings'),
            ],
          ),
        ),
      ),
    );
  }
}

