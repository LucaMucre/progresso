import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/db_service.dart';
import 'services/life_areas_service.dart';
import 'history_page.dart';
import 'profile_page.dart';
import 'templates_page.dart';
import 'life_area_detail_page.dart';
import 'widgets/bubble_widget.dart';

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
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.brown.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.emoji_events, color: Colors.brown, size: 24),
        );
      case 2:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.emoji_events, color: Colors.grey, size: 24),
        );
      case 3:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.emoji_events, color: Colors.amber, size: 24),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _onBubbleTap(BuildContext context, LifeArea area) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LifeAreaDetailPage(area: area),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        title: const Text(
          'Progresso',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Begrüßung
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primary.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: Icon(
                      Icons.person,
                      size: 30,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Willkommen zurück!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.email ?? 'User',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Life Areas Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Lebensbereiche',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    // TODO: Add new life area
                    print('Add new life area');
                  },
                  tooltip: 'Neuen Bereich hinzufügen',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Bubbles Grid
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: FutureBuilder<List<LifeArea>>(
                future: _loadLifeAreas(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Lade Lebensbereiche...'),
                        ],
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        children: [
                          Icon(Icons.error, color: Colors.red, size: 48),
                          const SizedBox(height: 8),
                          Text('Fehler beim Laden der Lebensbereiche'),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () {
                              // Force rebuild
                              (context as Element).markNeedsBuild();
                            },
                            child: const Text('Erneut versuchen'),
                          ),
                        ],
                      ),
                    );
                  }

                  final areas = snapshot.data ?? [];
                  
                  if (areas.isEmpty) {
                    return Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.add_circle_outline,
                            size: 48,
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Noch keine Lebensbereiche',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () async {
                              try {
                                await LifeAreasService.createDefaultLifeAreas();
                                // Force rebuild
                                (context as Element).markNeedsBuild();
                              } catch (e) {
                                print('Fehler beim Erstellen der Standard-Bereiche: $e');
                              }
                            },
                            child: const Text('Standard-Bereiche erstellen'),
                          ),
                        ],
                      ),
                    );
                  }

                  return BubblesGrid(
                    areas: areas,
                    onBubbleTap: (area) => _onBubbleTap(context, area),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Streak & Badge Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: FutureBuilder<int>(
                future: calculateStreak(),
                builder: (ctx, snap) {
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
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.local_fire_department,
                          color: Colors.orange,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Streak',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '$streak Tage',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _badgeIcon(badge),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Actions Section
            Text(
              'Deine Actions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Templates List
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const TemplatesList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<LifeArea>> _loadLifeAreas() async {
    try {
      final areas = await LifeAreasService.getLifeAreas();
      if (areas.isEmpty) {
        // Erstelle Standard-Bereiche wenn keine vorhanden
        await LifeAreasService.createDefaultLifeAreas();
        return await LifeAreasService.getLifeAreas();
      }
      return areas;
    } catch (e) {
      print('Fehler beim Laden der Life Areas: $e');
      rethrow;
    }
  }
}