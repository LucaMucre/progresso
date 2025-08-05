import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_page.dart';
import 'dashboard_page.dart';
import 'history_page.dart';
import 'life_area_detail_page.dart';
import 'log_action_page.dart';
import 'profile_page.dart';
import 'services/db_service.dart';
import 'services/life_areas_service.dart';
import 'widgets/bubble_widget.dart';
import 'templates_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // Add a counter to force FutureBuilder rebuild
  int _refreshCounter = 0;
  
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

  void _showAddLifeAreaDialog(BuildContext context) {
    final nameController = TextEditingController();
    final categoryController = TextEditingController();
    String selectedColor = '#2196F3';
    String selectedIcon = 'fitness_center';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Neuen Lebensbereich hinzufügen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'z.B. Fitness, Bildung, etc.',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(
                  labelText: 'Kategorie',
                  hintText: 'z.B. Gesundheit, Entwicklung, etc.',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Farbe: '),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Color(int.parse(selectedColor.replaceAll('#', '0xFF'))),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Icon: '),
                  Icon(_getIconData(selectedIcon)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bitte geben Sie einen Namen ein')),
                  );
                  return;
                }

                                 try {
                   await LifeAreasService.createLifeArea(
                     name: nameController.text.trim(),
                     category: categoryController.text.trim().isEmpty ? 'Allgemein' : categoryController.text.trim(),
                     color: selectedColor,
                     icon: selectedIcon,
                   );
                   Navigator.of(context).pop();
                   // Force rebuild
                   setState(() {
                     _refreshCounter++;
                   });
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text('Lebensbereich erfolgreich erstellt')),
                   );
                 } catch (e) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text('Fehler beim Erstellen: $e')),
                   );
                 }
              },
              child: const Text('Erstellen'),
            ),
          ],
        );
      },
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'fitness_center':
        return Icons.fitness_center;
      case 'restaurant':
        return Icons.restaurant;
      case 'school':
        return Icons.school;
      case 'account_balance':
        return Icons.account_balance;
      case 'palette':
        return Icons.palette;
      case 'people':
        return Icons.people;
      case 'self_improvement':
        return Icons.self_improvement;
      case 'work':
        return Icons.work;
      case 'home':
        return Icons.home;
      case 'favorite':
        return Icons.favorite;
      case 'sports_soccer':
        return Icons.sports_soccer;
      case 'music_note':
        return Icons.music_note;
      case 'book':
        return Icons.book;
      case 'computer':
        return Icons.computer;
      case 'psychology':
        return Icons.psychology;
      case 'nature':
        return Icons.nature;
      case 'directions_car':
        return Icons.directions_car;
      case 'flight':
        return Icons.flight;
      case 'local_shipping':
        return Icons.local_shipping;
      case 'sports_esports':
        return Icons.sports_esports;
      case 'camera_alt':
        return Icons.camera_alt;
      case 'eco':
        return Icons.eco;
      case 'pets':
        return Icons.pets;
      case 'child_care':
        return Icons.child_care;
      default:
        return Icons.circle;
    }
  }

  int badgeLevel(int streak) {
    if (streak >= 30) return 3;
    if (streak >= 7) return 2;
    if (streak >= 1) return 1;
    return 0;
  }

  Future<int> calculateStreak() async {
    try {
      final dates = await fetchLoggedDates();
      if (dates.isEmpty) return 0;

      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      
      int streak = 0;
      DateTime currentDate = todayDate;

      while (true) {
        final hasEntry = dates.any((date) {
          final entryDate = DateTime(date.year, date.month, date.day);
          return entryDate.isAtSameMomentAs(currentDate);
        });

        if (hasEntry) {
          streak++;
          currentDate = currentDate.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }

      return streak;
    } catch (e) {
      print('Fehler beim Berechnen des Streaks: $e');
      return 0;
    }
  }

  Future<List<DateTime>> fetchLoggedDates() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return [];

      final response = await Supabase.instance.client
          .from('action_logs')
          .select('occurred_at')
          .eq('user_id', user.id);

      final dates = (response as List)
          .map((log) => DateTime.parse(log['occurred_at']))
          .toList();

      return dates;
    } catch (e) {
      print('Fehler beim Laden der Log-Daten: $e');
      return [];
    }
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
                    _showAddLifeAreaDialog(context);
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
                 key: ValueKey(_refreshCounter), // Force rebuild when counter changes
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
                               setState(() {
                                 _refreshCounter++;
                               });
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
                                 setState(() {
                                   _refreshCounter++;
                                 });
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
                     onDelete: (area) {
                       // Force rebuild when a life area is deleted
                       setState(() {
                         _refreshCounter++;
                       });
                     },
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