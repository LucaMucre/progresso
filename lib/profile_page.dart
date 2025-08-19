import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'utils/web_file_picker_stub.dart'
    if (dart.library.html) 'utils/web_file_picker_web.dart' as web_file_picker;
import 'utils/logging_service.dart';
import 'services/character_service.dart';
import 'services/life_areas_service.dart';
import 'services/db_service.dart';
import 'services/offline_cache.dart';
import 'services/avatar_sync_service.dart';
import 'services/achievement_service.dart';
import 'services/anonymous_user_service.dart';
import 'services/anonymous_migration_service.dart';
import 'repository/local_logs_repository.dart';
import 'auth_page.dart';
import 'models/action_models.dart' as models;
// Popups are orchestrated centrally via LevelUpService; do not import dialogs directly here
import 'services/level_up_service.dart';
import 'life_area_detail_page.dart';
import 'navigation.dart';
import 'utils/app_theme.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

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
  bool _isAnonymous = false;

  final _supabase = Supabase.instance.client;
  final _localLogsRepo = LocalLogsRepository();

  @override
  void initState() {
    super.initState();
    _initializeAnonymousStatus();
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

  Future<void> _initializeAnonymousStatus() async {
    try {
      _isAnonymous = await AnonymousUserService.isAnonymousUser();
      if (mounted) setState(() {});
    } catch (e) {
      LoggingService.error('Fehler beim Prüfen des anonymen Status', e);
    }
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
    } catch (e, stackTrace) {
      LoggingService.error('Error in profile operation', e, stackTrace, 'Profile');
    }
    _loadProfile();
    _loadStatistics();
  }
  
  void _subscribeToActivityChanges() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    
    final channel = _supabase
        .channel('public:action_logs:user_id=eq.${user.id}:profile-refresh')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'action_logs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (PostgresChangePayload payload) async {
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
    if (kDebugMode) debugPrint('Error loading profile: $e');
      // Erstelle Standard-Profil wenn noch nicht vorhanden
      _nameCtrl.text = _supabase.auth.currentUser?.email?.split('@')[0] ?? 'User';
      _bioCtrl.text = 'This is my bio.';
      setState(() {});
    }
  }

  void _subscribeToUserChanges() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    _usersChannel?.unsubscribe();
    final channel = _supabase
        .channel('public:users:id=eq.${user.id}:profile-page')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'users',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: user.id,
          ),
          callback: (PostgresChangePayload payload) async {
            await _loadProfile();
            if (mounted) setState(() {});
          },
        );
    channel.subscribe();
    _usersChannel = channel;
  }

  Future<void> _loadStatistics() async {
    try {
      // Load in parallel using local repository
      final futures = <Future<dynamic>>[
        CharacterService.getOrCreateCharacter(),
        LifeAreasService.getLifeAreas(),
        _localLogsRepo.fetchLogs(),
        _localLogsRepo.fetchTotalXp(),
        _localLogsRepo.calculateStreak(),
      ];
      final results = await Future.wait(futures);
      final character = results[0] as Character;
      final areas = results[1] as List<LifeArea>;
      final logs = results[2] as List<models.ActionLog>;
      final totalXP = results[3] as int;
      final currentStreak = results[4] as int;
        
        // Calculate statistics from local data
        _totalActions = logs.length;
        _currentStreak = currentStreak;
        _longestStreak = _calculateLongestStreakFromActionLogs(logs);
        _totalXP = totalXP;
        _xpSinceBaseline = _totalXP;

        // Count activities by life area
        String _resolveAreaKeyForActionLog(models.ActionLog log) {
          final raw = log.notes;
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
            } catch (e, stackTrace) {
              LoggingService.error('Error in profile operation', e, stackTrace, 'Profile');
            }
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
          // Fallback to area name if provided
          if (areaFromNotes != null && areaFromNotes!.isNotEmpty) {
            return areaFromNotes!;
          }
          return 'unknown';
        }

        final countsByKey = <String, int>{};
        for (final log in logs) {
          final key = _resolveAreaKeyForActionLog(log);
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
      
      if (mounted) {
        setState(() {
          _character = character;
          _lifeAreas = areas;
        });
      }
    } catch (e) {
    if (kDebugMode) debugPrint('Error loading statistics: $e');
    }
  }
  
  Future<void> _checkAchievements() async {
    if (_character == null) return;
    
    // Count today's actions for daily achievements using local repository
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    
    try {
      // Get today's logs from local repository
      final todayLogs = await _localLogsRepo.fetchLogs();
      final todayActions = todayLogs
          .where((log) => log.occurredAt.isAfter(todayStart) && log.occurredAt.isBefore(todayEnd))
          .length;
      
      // Get last action time for special achievements
      DateTime? lastActionTime;
      if (todayLogs.isNotEmpty) {
        final sortedLogs = todayLogs.toList()..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
        lastActionTime = sortedLogs.first.occurredAt;
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
        dailyActions: todayActions,
        lastActionTime: lastActionTime,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Error checking achievements: $e');
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

  int _calculateLongestStreakFromActionLogs(List<models.ActionLog> logs) {
    if (logs.isEmpty) return 0;
    
    final dates = logs
        .map((log) => DateTime(log.occurredAt.year, log.occurredAt.month, log.occurredAt.day))
        .toSet()
        .toList()..sort();
    
    int longestStreak = 0;
    int currentStreak = 0;
    
    for (int i = 0; i < dates.length; i++) {
      if (i == 0 || dates[i].difference(dates[i - 1]).inDays == 1) {
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
    if (kIsWeb) {
      // Use custom web file picker to avoid password manager popup
      final result = await web_file_picker.pickImageFile();
      if (result != null) {
        // For web: create a temporary file-like object
        final bytes = _dataUrlToBytes(result['dataUrl']);
        // Set up for upload (profile_page handles avatar differently than profile_edit_page)
        setState(() {
          _avatarFile = null;
        });
        // Handle web upload directly
        await _uploadWebAvatar(bytes);
      }
    } else {
      // For Mobile: Use standard ImagePicker
      final picker = ImagePicker();
      final img = await picker.pickImage(source: ImageSource.gallery);
      if (img != null) {
        setState(() {
          _avatarFile = File(img.path);
        });
      }
    }
  }

  Uint8List _dataUrlToBytes(String dataUrl) {
    final base64String = dataUrl.split(',')[1];
    return base64Decode(base64String);
  }

  Future<void> _uploadWebAvatar(Uint8List bytes) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      final currentUser = _supabase.auth.currentUser!;
      const ext = 'jpg'; // Standard for web
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${currentUser.id}/avatar_${timestamp}.$ext';
      
      await _supabase.storage
          .from('avatars')
          .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));
      final avatarUrl = _supabase.storage.from('avatars').getPublicUrl(path);
      
      // Update profile with new avatar URL
      final profile = {
        'id': currentUser.id,
        'email': currentUser.email,
        'name': _nameCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'avatar_url': avatarUrl,
      };
      
      await _supabase
          .from('users')
          .upsert(profile, onConflict: 'id');

      // Sync avatar across all tables
      await AvatarSyncService.syncAvatar(avatarUrl);
      
      // Update local state
      setState(() {
        _avatarUrl = avatarUrl;
        _cacheBust = DateTime.now().millisecondsSinceEpoch;
        _loading = false;
      });
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Avatar gespeichert!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      
    } catch (err) {
      setState(() {
        _error = err.toString();
        _loading = false;
      });
      if (kDebugMode) debugPrint('Error uploading web avatar: $err');
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
        
        if (kDebugMode) debugPrint('DEBUG: Uploading avatar to path: $path');
        if (kDebugMode) debugPrint('DEBUG: File size: ${bytes.length} bytes');
        
        await _supabase.storage
            .from('avatars')
            .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));
        avatarUrl = _supabase.storage.from('avatars').getPublicUrl(path);
        
        if (kDebugMode) debugPrint('DEBUG: Avatar URL: $avatarUrl');
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
      
      if (kDebugMode) debugPrint('DEBUG: Saving profile with avatar_url: $avatarUrl');
      
      await _supabase
          .from('users')
          .upsert(profile, onConflict: 'id');

      // Zentrale Synchronisierung und Broadcast (nur wenn es eine neue URL gibt)
      await AvatarSyncService.syncAvatar(avatarUrl);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
        content: Text('Profile saved!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (err) {
      if (kDebugMode) debugPrint('DEBUG: Error saving profile: $err');
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
              color: color.withValues(alpha: 0.8),
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
            color: Colors.white.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(3),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$xpInto / $xpNext XP',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
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
        color: unlocked ? color.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unlocked ? color.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.3),
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
                    color: unlocked ? color.withValues(alpha: 0.8) : Colors.grey.withValues(alpha: 0.8),
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
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => LifeAreaDetailPage(area: area)),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: areaColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: areaColor.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
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
                  color: areaColor.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: areaColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: areaColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: areaColor.withValues(alpha: 0.9),
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
            // Anonymous User Registration Banner
            if (_isAnonymous) _buildAnonymousUserBanner(),
            
            // Profile Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
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
                            color: Colors.black.withValues(alpha: 0.2),
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
                            color: Colors.white.withValues(alpha: 0.9),
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
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
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
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
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
                                  child: const Text('Save'),
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
            SizedBox(height: AppTheme.spacing24),

            // Activity Contributions Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Activity Contributions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$_totalActions activities this year',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            SizedBox(height: AppTheme.spacing16),
            if (_totalActions == 0)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline, size: 28, color: Colors.grey.withValues(alpha: 0.6)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No activities yet. Tap the + button to add your first activity.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.withValues(alpha: 0.8)),
                      ),
                    ),
                  ],
                ),
              ),
            // GitHub-style contributions table
            _buildContributionsTable(),
            SizedBox(height: AppTheme.spacing24),

            // Life Areas Summary
            Text(
                'Your life areas',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: AppTheme.spacing16),
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
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
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
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
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
                  SizedBox(height: AppTheme.spacing16),
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
            SizedBox(height: AppTheme.spacing24),

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
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${AchievementService.getUnlockedCount()}/${AchievementService.getTotalCount()}',
                    style: const TextStyle(
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
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
            ),
            
            SizedBox(height: AppTheme.spacing16),
            
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
            SizedBox(height: AppTheme.spacing24),

            // Profile bearbeiten Bereich entfernt (wird an anderer Stelle bearbeitet)
          ],
        ),
      ),
    );
  }

  Widget _buildContributionsTable() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Activity data for the year
          _buildContributionsGrid(),
          const SizedBox(height: 12),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Learn how we count contributions',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Row(
                children: [
                  Text(
                    'Less',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildLegendSquare(0),
                  const SizedBox(width: 2),
                  _buildLegendSquare(1),
                  const SizedBox(width: 2),
                  _buildLegendSquare(2),
                  const SizedBox(width: 2),
                  _buildLegendSquare(3),
                  const SizedBox(width: 8),
                  Text(
                    'More',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContributionsGrid() {
    final now = DateTime.now();
    final startOfYear = DateTime(now.year, 1, 1);
    final weeks = <List<DateTime>>[];
    
    // Generate weeks for the entire year
    DateTime current = startOfYear;
    while (current.year == now.year) {
      final week = <DateTime>[];
      for (int i = 0; i < 7; i++) {
        if (current.year == now.year) {
          week.add(current);
          current = current.add(const Duration(days: 1));
        }
      }
      if (week.isNotEmpty) weeks.add(week);
    }

    // Calculate activity counts per day
    final activityCounts = _calculateDailyActivityCounts();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month labels
          Row(
            children: [
              const SizedBox(width: 20), // Space for day labels
              ...List.generate(12, (month) {
                final monthDate = DateTime(now.year, month + 1, 1);
                final weeksInMonth = weeks.where((week) => 
                  week.any((day) => day.month == month + 1)).length;
                return SizedBox(
                  width: weeksInMonth * 12.0,
                  child: Text(
                    ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                     'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][month],
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 8),
          // Grid
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day labels
              Column(
                children: [
                  _buildDayLabel('Mon'),
                  _buildDayLabel(''),
                  _buildDayLabel('Wed'),
                  _buildDayLabel(''),
                  _buildDayLabel('Fri'),
                  _buildDayLabel(''),
                  _buildDayLabel(''),
                ],
              ),
              const SizedBox(width: 8),
              // Contributions grid
              Row(
                children: weeks.map((week) {
                  return Column(
                    children: week.map((day) {
                      final count = activityCounts[_dateKey(day)] ?? 0;
                      return Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: _getContributionColor(count),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }).toList(),
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayLabel(String label) {
    return SizedBox(
      height: 12,
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 9,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _buildLegendSquare(int level) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: _getContributionColor(level == 0 ? 0 : level * 2),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Color _getContributionColor(int count) {
    final primary = Theme.of(context).colorScheme.primary;
    if (count == 0) {
      return Theme.of(context).colorScheme.surfaceContainerHighest;
    } else if (count == 1) {
      return primary.withValues(alpha: 0.3);
    } else if (count <= 3) {
      return primary.withValues(alpha: 0.6);
    } else {
      return primary;
    }
  }

  Map<String, int> _calculateDailyActivityCounts() {
    final counts = <String, int>{};
    
    // Since this is called during build, we'll need to use a different approach
    // We'll calculate from the existing activities if available
    if (_totalActions > 0) {
      // For now, add activity counts to recent days as a placeholder
      // This should be replaced with a proper async state management solution
      final now = DateTime.now();
      for (int i = 0; i < _totalActions && i < 30; i++) {
        final date = now.subtract(Duration(days: i * 2));
        final key = _dateKey(date);
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    
    return counts;
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Widget _buildAnonymousUserBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.cloud_outlined,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Guest Mode',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Save your progress to the cloud',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _showRegistrationDialog,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: Text(
                'Sign up',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRegistrationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Create Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_upload_outlined, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            const Text(
              'Create an account to save your progress to the cloud.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: const Column(
                children: [
                  Text('✓ Alle bisherigen Daten bleiben erhalten'),
                  Text('✓ Synchronisation zwischen Geräten'),
                  Text('✓ Backup in der Cloud'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create Account'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await _navigateToRegistration();
    }
  }

  Future<void> _navigateToRegistration() async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AuthPage(),
        ),
      );

      if (result == true) {
        await _migrateAnonymousData();
      }
    } catch (e) {
      LoggingService.error('Fehler bei der Navigation zur Registrierung', e);
    }
  }

  Future<void> _migrateAnonymousData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Kein authentifizierter User für Migration gefunden');
      }

      final shouldMigrate = await _showMigrationDialog();
      if (!shouldMigrate) return;

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          title: Text('Daten werden übertragen...'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Bitte warten, während deine Daten übertragen werden.'),
            ],
          ),
        ),
      );

      await AnonymousMigrationService.migrateAnonymousDataToAccount(user.id);

      if (mounted) Navigator.pop(context);

      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('✅ Migration erfolgreich!'),
            content: const Text(
              'Alle deine Daten wurden erfolgreich zu deinem Account übertragen.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fertig'),
              ),
            ],
          ),
        );
      }

      await _initializeAnonymousStatus();
      
    } catch (e) {
      LoggingService.error('Fehler bei der Datenmigration', e);
      
      if (mounted) Navigator.pop(context);
      
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('❌ Migration fehlgeschlagen'),
            content: Text('Fehler bei der Datenübertragung: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<bool> _showMigrationDialog() async {
    try {
      final canMigrate = await AnonymousMigrationService.canMigrateData();
      if (!canMigrate) return false;

      final preview = await AnonymousMigrationService.getMigrationPreview();

      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Daten übertragen'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(preview),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                  ),
                  child: const Column(
                    children: [
                      Text('ℹ️ Nach der Übertragung:'),
                      Text('• Deine Daten sind in der Cloud gesichert'),
                      Text('• Synchronisation zwischen Geräten möglich'),
                      Text('• Lokale Daten werden gelöscht'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Daten übertragen'),
            ),
          ],
        ),
      );

      return result ?? false;
    } catch (e) {
      LoggingService.error('Fehler beim Anzeigen des Migrations-Dialogs', e);
      return false;
    }
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