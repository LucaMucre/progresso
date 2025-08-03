import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/db_service.dart';
import 'history_page.dart';
import 'profile_page.dart';
import 'templates_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({Key? key}) : super(key: key);

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      print('SignOut Fehler: $e');
    }
  }

  Widget _badgeIcon(int badge) {
    switch (badge) {
      case 1:
        return const Icon(Icons.emoji_events, color: Colors.brown, size: 28);
      case 2:
        return const Icon(Icons.emoji_events, color: Colors.grey, size: 28);
      case 3:
        return const Icon(Icons.emoji_events, color: Colors.amber, size: 28);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    
    // Debug-Ausgaben
    print('=== DASHBOARD DEBUG ===');
    print('Current User: $user');
    print('User ID: ${user?.id}');
    print('User Email: ${user?.email}');
    print('Session: ${Supabase.instance.client.auth.currentSession}');
    print('=======================');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progresso Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Meine Logs',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HistoryPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Mein Profil',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfilePage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            tooltip: 'Abmelden',
            onPressed: _signOut,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Begrüßung
            Text(
              'Hallo, ${user?.email ?? 'User'}!',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),

            // Level-Bar
            FutureBuilder<int>(
              future: fetchTotalXp(),
              builder: (ctx, snap) {
                print('=== XP FETCH DEBUG ===');
                print('Connection State: ${snap.connectionState}');
                print('Has Error: ${snap.hasError}');
                print('Error: ${snap.error}');
                print('Data: ${snap.data}');
                print('========================');
                
                if (snap.connectionState != ConnectionState.done) {
                  return const LinearProgressIndicator();
                }
                if (snap.hasError) {
                  return Text('Fehler: ${snap.error}');
                }
                final xp = snap.data ?? 0;
                final lvlData = calculateLevel(xp);
                final level  = lvlData['level']!;
                final xpInto = lvlData['xpInto']!;
                final xpNext = lvlData['xpNext']!;
                final progress = xpInto / xpNext;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Level $level • $xpInto / $xpNext XP',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: progress),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Streak & Badge
            FutureBuilder<int>(
              future: calculateStreak(),
              builder: (ctx, snap) {
                print('=== STREAK FETCH DEBUG ===');
                print('Connection State: ${snap.connectionState}');
                print('Has Error: ${snap.hasError}');
                print('Error: ${snap.error}');
                print('Data: ${snap.data}');
                print('==========================');
                
                if (snap.connectionState != ConnectionState.done) {
                  return const SizedBox();
                }
                if (snap.hasError) {
                  return Text('Fehler: ${snap.error}');
                }
                final streak = snap.data ?? 0;
                final badge = badgeLevel(streak);
                return Row(
                  children: [
                    Text(
                      'Streak: $streak Tage',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(width: 8),
                    _badgeIcon(badge),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),

            // Deine Actions
            Text(
              'Deine Actions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),

            // Liste der Templates
            const Expanded(
              child: TemplatesList(),
            ),
          ],
        ),
      ),
    );
  }
}