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

  late final List<Widget> _pages = [
    const DashboardPage(),
    const TemplatesList(),
    const LogActionPage(),
    const ChatPage(),
    const ProfilePage(),
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 700;
    final t = AppLocalizations.of(context);

    return Scaffold
    (
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          height: isWide ? 64 : 72,
          labelBehavior: isWide ? NavigationDestinationLabelBehavior.onlyShowSelected : NavigationDestinationLabelBehavior.alwaysShow,
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
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

