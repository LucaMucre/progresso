import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'services/character_service.dart';
import 'services/life_areas_service.dart';
import 'services/db_service.dart';
import 'services/avatar_sync_service.dart';
import 'life_area_detail_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  File? _avatarFile;
  bool _loading = false;
  String? _error;
  Character? _character;
  List<LifeArea> _lifeAreas = [];
  int _totalActions = 0;
  int _currentStreak = 0;
  int _longestStreak = 0;
  int _totalXP = 0;
  String? _avatarUrl;
  int _cacheBust = 0;
  RealtimeChannel? _usersChannel;
  Map<String, int> _areaActivityCounts = {};

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadStatistics();
    _subscribeToUserChanges();
    // Lokaler Broadcast: reagiert sofort auf Avatar-Änderungen
    AvatarSyncService.avatarVersion.addListener(_loadProfile);
  }

  Future<void> _loadProfile() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final res = await _supabase
          .from('users')
          .select('name,bio,avatar_url,email')
          .eq('id', userId)
          .single();
      if (res != null) {
        _nameCtrl.text = res['name'] ?? '';
        _bioCtrl.text = res['bio'] ?? '';
        setState(() {
          _avatarUrl = res['avatar_url'];
          _cacheBust = DateTime.now().millisecondsSinceEpoch;
        });
      }
    } catch (e) {
      print('Fehler beim Laden des Profils: $e');
      // Erstelle Standard-Profil wenn noch nicht vorhanden
      _nameCtrl.text = _supabase.auth.currentUser?.email?.split('@')[0] ?? 'User';
      _bioCtrl.text = 'Das ist meine Bio.';
      setState(() {});
    }
  }

  void _subscribeToUserChanges() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    _usersChannel?.unsubscribe();
    final channel = _supabase
        .channel('public:users:id=eq.${user.id}:profile-page')
        .on(
          RealtimeListenTypes.postgresChanges,
          ChannelFilter(
            event: 'UPDATE',
            schema: 'public',
            table: 'users',
            filter: 'id=eq.${user.id}',
          ),
          (payload, [ref]) async {
            await _loadProfile();
            if (mounted) setState(() {});
          },
        );
    channel.subscribe();
    _usersChannel = channel;
  }

  Future<void> _loadStatistics() async {
    try {
      // Load character
      final character = await CharacterService.getOrCreateCharacter();
      
      // Load life areas
      final areas = await LifeAreasService.getLifeAreas();
      
      // Load action statistics
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final actionResponse = await _supabase
            .from('action_logs')
            .select('occurred_at, notes')
            .eq('user_id', user.id);
        
        final logs = (actionResponse as List);
        final dates = logs.map((log) => DateTime.parse(log['occurred_at'])).toList();
        
        _totalActions = dates.length;
        _currentStreak = _calculateCurrentStreak(dates);
        _longestStreak = _calculateLongestStreak(dates);
        _totalXP = character.totalXp;

        // Rank life areas by activity count (desc)
        int countForArea(Map<String, dynamic> log, LifeArea area) {
          final raw = log['notes'];
          if (raw == null) return 0;
          try {
            final obj = jsonDecode(raw);
            if (obj is Map<String, dynamic>) {
              final a = (obj['area'] as String?)?.toLowerCase();
              final c = (obj['category'] as String?)?.toLowerCase();
              if (a == area.name.toLowerCase() || c == area.category.toLowerCase()) return 1;
            } else if (obj is List) {
              // quill delta → plaintext contains name/category
              final text = obj.map((op) => (op is Map && op['insert'] is String) ? op['insert'] as String : '').join().toLowerCase();
              if (text.contains(area.name.toLowerCase()) || text.contains(area.category.toLowerCase())) return 1;
            }
          } catch (_) {
            final text = raw.toString().toLowerCase();
            if (text.contains(area.name.toLowerCase()) || text.contains(area.category.toLowerCase())) return 1;
          }
          return 0;
        }

        final areaToCount = <String, int>{};
        for (final area in areas) {
          final n = logs.fold<int>(0, (sum, log) => sum + countForArea(log as Map<String, dynamic>, area));
          areaToCount[area.id] = n;
        }
        areas.sort((a, b) {
          final cb = areaToCount[b.id] ?? 0;
          final ca = areaToCount[a.id] ?? 0;
          if (cb != ca) return cb.compareTo(ca);
          return a.orderIndex.compareTo(b.orderIndex);
        });
        _areaActivityCounts = areaToCount;
      }
      
      setState(() {
        _character = character;
        _lifeAreas = areas;
      });
    } catch (e) {
      print('Fehler beim Laden der Statistiken: $e');
    }
  }

  int _calculateCurrentStreak(List<DateTime> dates) {
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
  }

  int _calculateLongestStreak(List<DateTime> dates) {
    if (dates.isEmpty) return 0;
    
    final sortedDates = dates.map((d) => DateTime(d.year, d.month, d.day)).toSet().toList()..sort();
    
    int longestStreak = 0;
    int currentStreak = 0;
    
    for (int i = 0; i < sortedDates.length; i++) {
      if (i == 0 || sortedDates[i].difference(sortedDates[i - 1]).inDays == 1) {
        currentStreak++;
      } else {
        currentStreak = 1;
      }
      
      if (currentStreak > longestStreak) {
        longestStreak = currentStreak;
      }
    }
    
    return longestStreak;
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery);
    if (img != null) {
      setState(() {
        _avatarFile = File(img.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final currentUser = _supabase.auth.currentUser!;
    String? avatarUrl;

    try {
      if (_avatarFile != null) {
        final ext = _avatarFile!.path.split('.').last;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final path = '${currentUser.id}/avatar_${timestamp}.$ext';
        final bytes = await _avatarFile!.readAsBytes();
        
        print('DEBUG: Uploading avatar to path: $path');
        print('DEBUG: File size: ${bytes.length} bytes');
        
        await _supabase.storage
            .from('avatars')
            .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));
        avatarUrl = _supabase.storage.from('avatars').getPublicUrl(path);
        
        print('DEBUG: Avatar URL: $avatarUrl');
      }

      final profile = {
        'id': currentUser.id,
        'email': currentUser.email,
        'name': _nameCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'avatar_url': avatarUrl,
      };
      
      print('DEBUG: Saving profile with avatar_url: $avatarUrl');
      
      await _supabase
          .from('users')
          .upsert(profile, onConflict: 'id');

      // Zentrale Synchronisierung und Broadcast
      await AvatarSyncService.syncAvatar(avatarUrl);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil gespeichert!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (err) {
      print('DEBUG: Error saving profile: $err');
      setState(() {
        _error = err.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementCard(String title, String description, IconData icon, Color color, bool unlocked) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: unlocked ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unlocked ? color.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: unlocked ? color : Colors.grey,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: unlocked ? color : Colors.grey,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: unlocked ? color.withOpacity(0.8) : Colors.grey.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLifeAreaChip(LifeArea area) {
    final areaColor = Color(int.parse(area.color.replaceAll('#', '0xFF')));
    final count = _areaActivityCounts[area.id] ?? 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => LifeAreaDetailPage(area: area)),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: areaColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: areaColor.withOpacity(0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: areaColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                area.name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: areaColor.withOpacity(0.9),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: areaColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: areaColor.withOpacity(0.3)),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: areaColor.withOpacity(0.9),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Avatar-URL aus users Tabelle mit Cache-Busting
    final avatarUrl = _avatarUrl != null ? '${_avatarUrl!}?cb=$_cacheBust' : null;
    final avatarProvider = avatarUrl != null
        ? NetworkImage(avatarUrl) as ImageProvider
        : const AssetImage('assets/default_avatar.png');

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        title: const Text(
          'Mein Profil',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primary.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _pickAvatar,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white,
                        child: ClipOval(
                          child: avatarUrl != null
                              ? Image.network(
                                  avatarUrl,
                                  key: ValueKey(avatarUrl),
                                  fit: BoxFit.cover,
                                  width: 80,
                                  height: 80,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, color: Colors.grey),
                                )
                              : const Icon(Icons.person, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _nameCtrl.text.isEmpty ? 'Dein Name' : _nameCtrl.text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _supabase.auth.currentUser?.email ?? 'user@example.com',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                        if (_character != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Level ${_character!.level}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      tooltip: 'Profil bearbeiten',
                      icon: const Icon(Icons.edit, color: Colors.white),
                      onPressed: () async {
                        // Öffne Bearbeitungsdialog: Name/Bio ändern und speichern
                        await showDialog(
                          context: context,
                          builder: (ctx) {
                            final nameCtrl = TextEditingController(text: _nameCtrl.text);
                            final bioCtrl = TextEditingController(text: _bioCtrl.text);
                            return AlertDialog(
                              title: const Text('Profil bearbeiten'),
                              content: SizedBox(
                                width: 420,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextField(
                                      controller: nameCtrl,
                                      decoration: const InputDecoration(labelText: 'Name'),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: bioCtrl,
                                      decoration: const InputDecoration(labelText: 'Bio (optional)'),
                                      maxLines: 3,
                                    ),
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: const Text('Abbrechen'),
                                ),
                                ElevatedButton(
                                  onPressed: () async {
                                    _nameCtrl.text = nameCtrl.text.trim();
                                    _bioCtrl.text = bioCtrl.text.trim();
                                    await _saveProfile();
                                    if (mounted) Navigator.of(ctx).pop(true);
                                  },
                                  child: const Text('Speichern'),
                                )
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Statistics Section
            Text(
              'Deine Statistiken',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final crossAxisCount = width > 1000
                    ? 4
                    : width > 700
                        ? 3
                        : 2;
                // Feste Höhe sorgt dafür, dass Inhalte der Karten nicht abgeschnitten werden
                final tileHeight = width > 800 ? 120.0 : 140.0;

                final stats = [
                  (
                    'Aktionen',
                    '$_totalActions',
                    Icons.check_circle,
                    Colors.green,
                  ),
                  (
                    'Aktueller Streak',
                    '$_currentStreak Tage',
                    Icons.local_fire_department,
                    Colors.orange,
                  ),
                  (
                    'Längster Streak',
                    '$_longestStreak Tage',
                    Icons.emoji_events,
                    Colors.amber,
                  ),
                  (
                    'Gesamt XP',
                    '$_totalXP',
                    Icons.star,
                    Colors.purple,
                  ),
                ];

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: tileHeight,
                  ),
                  itemCount: stats.length,
                  itemBuilder: (context, index) {
                    final s = stats[index];
                    return _buildStatCard(
                      s.$1,
                      s.$2,
                      s.$3,
                      s.$4,
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 24),

            // Life Areas Summary
            Text(
              'Deine Lebensbereiche',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.surface,
                    Theme.of(context).colorScheme.surface.withOpacity(0.94),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.category,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Aktive Bereiche',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${_lifeAreas.length}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_lifeAreas.isNotEmpty)
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _lifeAreas
                          .map((area) => _buildLifeAreaChip(area))
                          .toList(),
                    )
                  else
                    Text(
                      'Noch keine Lebensbereiche erstellt',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Achievements Section
            Text(
              'Achievements',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Column(
              children: [
                _buildAchievementCard(
                  'Erste Schritte',
                  'Erstelle deinen ersten Lebensbereich',
                  Icons.add_circle,
                  Colors.blue,
                  _lifeAreas.isNotEmpty,
                ),
                const SizedBox(height: 12),
                _buildAchievementCard(
                  'Durchhalter',
                  '7 Tage in Folge aktiv',
                  Icons.local_fire_department,
                  Colors.orange,
                  _currentStreak >= 7,
                ),
                const SizedBox(height: 12),
                _buildAchievementCard(
                  'Experte',
                  '30 Tage in Folge aktiv',
                  Icons.emoji_events,
                  Colors.amber,
                  _currentStreak >= 30,
                ),
                const SizedBox(height: 12),
                _buildAchievementCard(
                  'Vielseitig',
                  '5 verschiedene Lebensbereiche',
                  Icons.category,
                  Colors.green,
                  _lifeAreas.length >= 5,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Profile bearbeiten Bereich entfernt (wird an anderer Stelle bearbeitet)
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usersChannel?.unsubscribe();
    AvatarSyncService.avatarVersion.removeListener(_loadProfile);
    super.dispose();
  }
}