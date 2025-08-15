import 'package:flutter/material.dart';
import 'dashboard_page.dart';
import 'l10n/app_localizations.dart';
import 'templates_page.dart';
import 'log_action_page.dart';
import 'chat_page.dart';
import 'profile_page.dart';
import 'settings_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({Key? key}) : super(key: key);

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
  int _profileNonce = 0; // forces ProfilePage to rebuild/refresh when selected

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 700;
    final t = AppLocalizations.of(context);

    return Scaffold
    (
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            const DashboardPage(),
            const TemplatesList(),
            const LogActionPage(),
            const ChatPage(),
            // Rebuild ProfilePage when its tab is selected by bumping the key
            ProfilePage(key: ValueKey(_profileNonce)),
            const SettingsPage(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          height: isWide ? 64 : 72,
          labelBehavior: isWide ? NavigationDestinationLabelBehavior.onlyShowSelected : NavigationDestinationLabelBehavior.alwaysShow,
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => setState(() {
            _currentIndex = i;
            if (i == 4) {
              // Force a fresh ProfilePage so initState runs and statistics reload
              _profileNonce++;
            }
          }),
          destinations: [
            NavigationDestination(icon: const Icon(Icons.dashboard_outlined), selectedIcon: const Icon(Icons.dashboard), label: t?.navDashboard ?? 'Dashboard'),
            NavigationDestination(icon: const Icon(Icons.view_list_outlined), selectedIcon: const Icon(Icons.view_list), label: t?.navTemplates ?? 'Templates'),
            NavigationDestination(icon: const Icon(Icons.add_circle_outline), selectedIcon: const Icon(Icons.add_circle), label: t?.navLog ?? 'Log'),
            NavigationDestination(icon: const Icon(Icons.chat_bubble_outline), selectedIcon: const Icon(Icons.chat_bubble), label: t?.navChat ?? 'Chat'),
            NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: t?.navProfile ?? 'Profile'),
            NavigationDestination(icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings), label: t?.navSettings ?? 'Settings'),
          ],
        ),
      ),
    );
  }
}

