import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'db_service.dart';
import 'offline_cache.dart';
import 'migration_service.dart';

part 'app_state.g.dart';

// Supabase Client Provider (langlebig - ohne autoDispose)
@riverpod
SupabaseClient supabaseClient(SupabaseClientRef ref) {
  return Supabase.instance.client;
}

// User Provider (langlebig - ohne autoDispose)
@riverpod
User? currentUser(CurrentUserRef ref) {
  return ref.watch(supabaseClientProvider).auth.currentUser;
}

// Templates Provider mit Caching und autoDispose
@riverpod
class TemplatesNotifier extends _$TemplatesNotifier {
  @override
  Future<List<ActionTemplate>> build() async {
    // Auto-dispose after 5 minutes of inactivity
    final timer = Timer(const Duration(minutes: 5), () {
      ref.invalidateSelf();
    });
    ref.onDispose(() => timer.cancel());
    
    final user = ref.read(currentUserProvider);
    if (user == null) return [];
    
    // Erst Cache laden für schnelle Anzeige
    final cachedTemplates = await OfflineCache.getCachedTemplates();
    if (cachedTemplates.isNotEmpty) {
      // Cache als initial state setzen
      state = AsyncValue.data(cachedTemplates);
    }
    
    try {
      // Remote-Daten laden
      final templates = await fetchTemplates();
      // Cache aktualisieren
      await OfflineCache.cacheTemplates(templates);
      return templates;
    } catch (e) {
      // Bei Fehler Cache verwenden
      if (cachedTemplates.isNotEmpty) {
        return cachedTemplates;
      }
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final templates = await fetchTemplates();
      await OfflineCache.cacheTemplates(templates);
      return templates;
    });
  }

  Future<void> addTemplate(ActionTemplate template) async {
    // Hier würde die Logik zum Hinzufügen eines Templates stehen
    await refresh();
  }
}

// Logs Provider mit Caching und autoDispose
@riverpod
class LogsNotifier extends _$LogsNotifier {
  @override
  Future<List<ActionLog>> build() async {
    // Auto-dispose after 3 minutes of inactivity (logs change more frequently)
    final timer = Timer(const Duration(minutes: 3), () {
      ref.invalidateSelf();
    });
    ref.onDispose(() => timer.cancel());
    
    final user = ref.read(currentUserProvider);
    if (user == null) return [];
    
    // Auto-migrate if needed (only once)
    if (isUsingLocalStorage) {
      await MigrationService.autoMigrateIfNeeded();
    }
    
    // Erst Cache laden für schnelle Anzeige
    final cachedLogs = await OfflineCache.getCachedLogs();
    if (cachedLogs.isNotEmpty) {
      // Cache als initial state setzen
      state = AsyncValue.data(cachedLogs);
    }
    
    try {
      // Remote-Daten laden
      final logs = await fetchLogs();
      // Cache aktualisieren
      await OfflineCache.cacheLogs(logs);
      return logs;
    } catch (e) {
      // Bei Fehler Cache verwenden
      if (cachedLogs.isNotEmpty) {
        return cachedLogs;
      }
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final logs = await fetchLogs();
      await OfflineCache.cacheLogs(logs);
      return logs;
    });
  }

  Future<void> addLog(ActionLog log) async {
    // Hier würde die Logik zum Hinzufügen eines Logs stehen
    await refresh();
  }
}

// XP Provider (autoDispose für häufige Updates)
@riverpod
class XpNotifier extends _$XpNotifier {
  @override
  Future<int> build() async {
    // Auto-dispose after 2 minutes of inactivity (frequent updates)
    final timer = Timer(const Duration(minutes: 2), () {
      ref.invalidateSelf();
    });
    ref.onDispose(() => timer.cancel());
    
    final user = ref.read(currentUserProvider);
    if (user == null) return 0;
    
    return fetchTotalXp();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final value = await fetchTotalXp();
      return value;
    });
  }
}

// Streak Provider (autoDispose für häufige Updates)
@riverpod
class StreakNotifier extends _$StreakNotifier {
  @override
  Future<int> build() async {
    // Auto-dispose after 2 minutes of inactivity (frequent updates)
    final timer = Timer(const Duration(minutes: 2), () {
      ref.invalidateSelf();
    });
    ref.onDispose(() => timer.cancel());
    
    final user = ref.read(currentUserProvider);
    if (user == null) return 0;
    
    return calculateStreak();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => calculateStreak());
  }
}

// User Profile Provider (langlebig für Session)
@riverpod
class UserProfileNotifier extends _$UserProfileNotifier {
  @override
  Future<Map<String, dynamic>?> build() async {
    // Auto-dispose after 10 minutes of inactivity (longer-lived for sessions)
    final timer = Timer(const Duration(minutes: 10), () {
      ref.invalidateSelf();
    });
    ref.onDispose(() => timer.cancel());
    
    final user = ref.read(currentUserProvider);
    if (user == null) return null;
    
    // Erst Cache laden
    final cachedProfile = await OfflineCache.getCachedProfile();
    if (cachedProfile != null) {
      // Cache als initial state setzen
      state = AsyncValue.data(cachedProfile);
    }
    
    try {
      final res = await ref.read(supabaseClientProvider)
          .from('users')
          .select('name,bio,avatar_url,email')
          .eq('id', user.id)
          .single();
      
      // Cache aktualisieren
      await OfflineCache.cacheProfile(res);
      return res;
    } catch (e) {
      // Bei Fehler Cache verwenden
      if (cachedProfile != null) {
        return cachedProfile;
      }
      if (kDebugMode) debugPrint('Error loading profile: $e');
      return null;
    }
  }

  Future<void> updateProfile(Map<String, dynamic> profile) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    
    try {
      await ref.read(supabaseClientProvider)
          .from('users')
          .upsert(profile, onConflict: 'id');
      
      // Cache aktualisieren
      await OfflineCache.cacheProfile(profile);
      await refresh();
    } catch (e) {
      if (kDebugMode) debugPrint('Error updating profile: $e');
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(currentUserProvider);
      if (user == null) return null;
      
      final res = await ref.read(supabaseClientProvider)
          .from('users')
          .select('name,bio,avatar_url,email')
          .eq('id', user.id)
          .single();
      
      await OfflineCache.cacheProfile(res);
      return res;
    });
  }
} 