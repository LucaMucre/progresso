import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'services/character_service.dart';
import 'services/life_areas_service.dart';
import 'services/db_service.dart';
import 'services/offline_cache.dart';
import 'services/avatar_sync_service.dart';
import 'services/achievement_service.dart';
// Popups are orchestrated centrally via LevelUpService; do not import dialogs directly here
import 'services/level_up_service.dart';
import 'life_area_detail_page.dart';
import 'navigation.dart';

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
  int _xpSinceBaseline = 0;
  String? _avatarUrl;
  int _cacheBust = 0;
  RealtimeChannel? _usersChannel;
  Map<String, int> _areaActivityCounts = {};

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _primeFromCacheThenReload();
    // react to global log changes
    logsChangedTick.addListener(_onExternalLogsChanged);
    _subscribeToUserChanges();
    _subscribeToActivityChanges();
    _initializeAchievements();
    // Nach Schließen von Popups keine erzwungenen Reloads auslösen
    LevelUpService.addOnDialogsClosed(() {
      // bewusst leer – UI aktualisiert sich über Realtime/State
    });
    // Global listener for level-up events (from log inserts)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LevelUpService.setOnLevelUp((level) async {
        if (!mounted) return;
        await LevelUpService.showLevelThenPending(context: context, level: level);
      });
    });
    // Lokaler Broadcast: reagiert sofort auf Avatar-Änderungen
    AvatarSyncService.avatarVersion.addListener(_loadProfile);
  }

  void _onExternalLogsChanged() {
    // lightweight refresh of statistics
    _loadStatistics();
  }

  Future<void> _primeFromCacheThenReload() async {
    try {
      final cached = await OfflineCache.getCachedProfile();
      if (cached != null) {
        _nameCtrl.text = cached['name'] ?? _supabase.auth.currentUser?.email?.split('@')[0] ?? '';
        _bioCtrl.text = cached['bio'] ?? '';
        setState(() {
          _avatarUrl = cached['avatar_url'];
          _cacheBust = DateTime.now().millisecondsSinceEpoch;
        });
      }
    } catch (_) {}
    _loadProfile();
    _loadStatistics();
  }
  
  void _subscribeToActivityChanges() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    
    final channel = _supabase
        .channel('public:action_logs:user_id=eq.${user.id}:profile-refresh')
        .on(
          RealtimeListenTypes.postgresChanges,
          ChannelFilter(
            event: 'INSERT',
            schema: 'public',
            table: 'action_logs',
            filter: 'user_id=eq.${user.id}',
          ),
          (payload, [ref]) async {
            // Reload statistics when new activity is created
            await _loadStatistics();
            if (mounted) setState(() {});
          },
        );
    channel.subscribe();
  }
  
  Future<void> _initializeAchievements() async {
    await AchievementService.loadUnlockedAchievements();
    if (mounted) setState(() {}); // refresh counts/flags after loading persisted unlocks
    // Only queue here; dialogs are orchestrated globally
    AchievementService.setOnAchievementUnlocked(_showAchievementUnlock);
  }
  
  void _showAchievementUnlock(Achievement achievement) {
    // Queue achievement; it will be shown after any level-up or immediately if none pending
    LevelUpService.queueAchievement(achievement);
    // Do not show immediately here to avoid overlap with navigation; Dashboard handles display
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
    print('Error loading profile: $e');
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
      // Load in parallel to reduce total wait time
      final user = _supabase.auth.currentUser;
      final futures = <Future<dynamic>>[
        CharacterService.getOrCreateCharacter(),
        LifeAreasService.getLifeAreas(),
        if (user != null)
          _supabase.from('action_logs').select('occurred_at, notes').eq('user_id', user.id)
        else
          Future.value(<dynamic>[]),
      ];
      final results = await Future.wait(futures);
      final character = results[0] as Character;
      final areas = results[1] as List<LifeArea>;
      final actionResponse = results[2] as List;
        
        // Ensure deduplication and correct counting of all user logs
        final logs = actionResponse;
        final dates = logs
            .map((log) => DateTime.parse(log['occurred_at'] as String))
            .map((dt) => DateTime(dt.year, dt.month, dt.day))
            .toList();
        
        // Count ALL activities (logs), not unique dates
        _totalActions = logs.length;
        _currentStreak = _calculateCurrentStreak(dates);
        _longestStreak = _calculateLongestStreak(dates);
        // Gesamt-XP anhand der Logs berechnen (nicht aus Character.total_xp, da dies evtl. nicht synchron ist)
        _totalXP = await fetchTotalXp();

        // Zeige XP direkt aus Gesamt-XP (ohne Baseline-Offset), damit die Anzeige
        // nicht nach einem Re-Login wie "reset" wirkt.
        _xpSinceBaseline = _totalXP;

        // Count each log exactly once by rolling it up to a single parent area key
        String _resolveAreaKeyForLog(Map<String, dynamic> log) {
          final raw = log['notes'];
          String? areaFromNotes;
          String? categoryFromNotes;
          if (raw != null) {
            try {
              final obj = jsonDecode(raw);
              if (obj is Map<String, dynamic>) {
                areaFromNotes = (obj['area'] as String?)?.trim().toLowerCase();
                final lifeAreaFromNotes = (obj['life_area'] as String?)?.trim().toLowerCase();
                areaFromNotes ??= lifeAreaFromNotes;
                categoryFromNotes = (obj['category'] as String?)?.trim().toLowerCase();
              }
            } catch (_) {}
          }
          bool isKnownParent(String? v) => const {
            'spirituality','finance','career','learning','relationships','health','creativity','fitness','nutrition','art'
          }.contains(v);
          // Prefer explicit area if already a known parent
          if (isKnownParent(areaFromNotes)) return areaFromNotes!;
          // Map subcategories to parents
          switch (categoryFromNotes) {
            case 'inner':
              return 'spirituality';
            case 'social':
              return 'relationships';
            case 'work':
              return 'career';
            case 'development':
              return 'learning';
            case 'finance':
              return 'finance';
            case 'health':
              return 'health';
            case 'fitness':
              return 'fitness';
            case 'nutrition':
              return 'nutrition';
            case 'art':
              return 'art';
          }
          // Fallback to area name if provided (custom names): use canonical category mapping
          if (areaFromNotes != null && areaFromNotes!.isNotEmpty) {
            return areaFromNotes!;
          }
          return 'unknown';
        }

        final countsByKey = <String, int>{};
        for (final log in logs) {
          final key = _resolveAreaKeyForLog(log as Map<String, dynamic>);
          countsByKey[key] = (countsByKey[key] ?? 0) + 1;
        }
        final areaToCount = <String, int>{};
        for (final area in areas) {
          final nameKey = LifeAreasService.canonicalAreaName(area.name);
          areaToCount[area.id] = countsByKey[nameKey] ?? 0;
        }
        areas.sort((a, b) {
          final cb = areaToCount[b.id] ?? 0;
          final ca = areaToCount[a.id] ?? 0;
          if (cb != ca) return cb.compareTo(ca);
          return a.orderIndex.compareTo(b.orderIndex);
        });
        _areaActivityCounts = areaToCount;
      
      // Check achievements after loading statistics
      await _checkAchievements();
      
      setState(() {
        _character = character;
        _lifeAreas = areas;
      });
    } catch (e) {
    print('Error loading statistics: $e');
    }
  }
  
  Future<void> _checkAchievements() async {
    if (_character == null) return;
    
    // Count today's actions for daily achievements
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final todayLogsResponse = await _supabase
            .from('action_logs')
            .select('occurred_at')
            .eq('user_id', user.id)
            .gte('occurred_at', todayStart.toIso8601String())
            .lt('occurred_at', todayEnd.toIso8601String());
        
        final dailyActions = (todayLogsResponse as List).length;
        
        // Get last action time for special achievements
        final lastActionResponse = await _supabase
            .from('action_logs')
            .select('occurred_at')
            .eq('user_id', user.id)
            .order('occurred_at', ascending: false)
            .limit(1);
        
        DateTime? lastActionTime;
        if ((lastActionResponse as List).isNotEmpty) {
          lastActionTime = DateTime.parse(lastActionResponse.first['occurred_at']);
        }
        
        // Count only areas with at least one activity
        final activeLifeAreaCount = _areaActivityCounts.values.where((n) => n > 0).length;
        // Correct any mistakenly unlocked life-area achievements from earlier bug
        await AchievementService.reconcileLifeAreaAchievements(activeLifeAreaCount);
        await AchievementService.checkAndUnlockAchievements(
          currentStreak: _currentStreak,
          totalActions: _totalActions,
          totalXP: _totalXP,
          level: _character!.level,
          lifeAreaCount: activeLifeAreaCount,
          dailyActions: dailyActions,
          lastActionTime: lastActionTime,
        );
      }
    } catch (e) {
      print('Error checking achievements: $e');
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

      // Only include avatar_url in upsert if a new one was chosen; avoid overwriting
      final profile = <String, dynamic>{
        'id': currentUser.id,
        'email': currentUser.email,
        'name': _nameCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
      };
      if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
        profile['avatar_url'] = avatarUrl;
      }
      
      print('DEBUG: Saving profile with avatar_url: $avatarUrl');
      
      await _supabase
          .from('users')
          .upsert(profile, onConflict: 'id');

      // Zentrale Synchronisierung und Broadcast (nur wenn es eine neue URL gibt)
      await AvatarSyncService.syncAvatar(avatarUrl);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
        content: Text('Profile saved!'),
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

  Widget _buildXPProgressBar() {
    if (_character == null) return const SizedBox.shrink();
    
    // Verwende Gesamt-XP aus Logs, damit Anzeige immer aktuell ist
    final levelDetails = calculateLevelDetailed(_xpSinceBaseline);
    final xpInto = levelDetails['xpInto']!;
    final xpNext = levelDetails['xpNext']!;
    final progress = xpNext > 0 ? (xpInto / xpNext).clamp(0.0, 1.0) : 1.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(3),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$xpInto / $xpNext XP',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
          'My Profile',
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
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Level ${calculateLevel(_xpSinceBaseline)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildXPProgressBar(),
                              ),
                            ],
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
            tooltip: 'Edit profile',
                      icon: const Icon(Icons.edit, color: Colors.white),
                      onPressed: () async {
                        // Öffne Bearbeitungsdialog: Name/Bio ändern und speichern
                        await showDialog(
                          context: context,
                          builder: (ctx) {
                            final nameCtrl = TextEditingController(text: _nameCtrl.text);
                            final bioCtrl = TextEditingController(text: _bioCtrl.text);
                            return AlertDialog(
            title: const Text('Edit profile'),
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
                child: const Text('Cancel'),
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
              'Your statistics',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_totalActions == 0)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline, size: 28, color: Colors.grey.withOpacity(0.6)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No activities yet. Tap the + button to add your first activity.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.withOpacity(0.8)),
                      ),
                    ),
                  ],
                ),
              ),
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
                      'Activities',
                    '$_totalActions',
                    Icons.check_circle,
                    Colors.green,
                  ),
                  (
                      'Current streak',
    '$_currentStreak days',
                    Icons.local_fire_department,
                    Colors.orange,
                  ),
                  (
                      'Longest streak',
    '$_longestStreak days',
                    Icons.emoji_events,
                    Colors.amber,
                  ),
                  (
                      'Total XP',
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
                'Your life areas',
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
                    Theme.of(context).colorScheme.surfaceContainerHigh,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(15),
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
              'Active life areas',
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
                'No life areas created yet',
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Achievements',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Text(
                    '${AchievementService.getUnlockedCount()}/${AchievementService.getTotalCount()}',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Progress bar
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: AchievementService.getProgressPercentage(),
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Achievement Grid
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final crossAxisCount = width > 800 ? 3 : width > 600 ? 2 : 1;
                
                final allAchievements = AchievementService.allAchievements;
                
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 80,
                  ),
                  itemCount: allAchievements.length,
                  itemBuilder: (context, index) {
                    final achievement = allAchievements[index];
                    final isUnlocked = AchievementService.isUnlocked(achievement.id);
                    
                    return _buildAchievementCard(
                      achievement.title,
                      achievement.description,
                      achievement.icon,
                      achievement.color,
                      isUnlocked,
                    );
                  },
                );
              },
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
    logsChangedTick.removeListener(_onExternalLogsChanged);
    // Cleanup optionaler Callback
    // Da wir eine anonyme Closure registriert haben, ist hier kein Remove möglich
    super.dispose();
  }
}