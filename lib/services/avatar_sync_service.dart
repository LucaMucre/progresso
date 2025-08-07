import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class AvatarSyncService {
  static final _client = Supabase.instance.client;
  // Broadcast für lokale UI-Listener
  static final ValueNotifier<int> avatarVersion = ValueNotifier<int>(0);

  /// Synchronisiert das Avatar in allen relevanten Tabellen
  static Future<void> syncAvatar(String? avatarUrl) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) throw Exception('User nicht angemeldet');

      print('DEBUG: Syncing avatar URL: $avatarUrl');

      // 1. Update users table
      await _client
          .from('users')
          .update({'avatar_url': avatarUrl})
          .eq('id', user.id);

      // 2. Update characters table
      await _client
          .from('characters')
          .update({'avatar_url': avatarUrl})
          .eq('user_id', user.id);

      print('DEBUG: Avatar sync completed successfully');
      // UI-Update auslösen
      avatarVersion.value++;
    } catch (e) {
      print('DEBUG: Error syncing avatar: $e');
      rethrow;
    }
  }

  /// Lädt die aktuelle Avatar-URL aus der users Tabelle
  static Future<String?> getCurrentAvatarUrl() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final res = await _client
          .from('users')
          .select('avatar_url')
          .eq('id', user.id)
          .single();

      return res['avatar_url'];
    } catch (e) {
      print('DEBUG: Error getting current avatar URL: $e');
      return null;
    }
  }

  /// Überprüft, ob alle Avatar-URLs synchronisiert sind
  static Future<Map<String, String?>> checkAvatarSync() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) throw Exception('User nicht angemeldet');

      // Lade Avatar-URLs aus beiden Tabellen
      final userRes = await _client
          .from('users')
          .select('avatar_url')
          .eq('id', user.id)
          .single();

      final characterRes = await _client
          .from('characters')
          .select('avatar_url')
          .eq('user_id', user.id)
          .single();

      return {
        'users': userRes['avatar_url'],
        'characters': characterRes['avatar_url'],
      };
    } catch (e) {
      print('DEBUG: Error checking avatar sync: $e');
      return {};
    }
  }

  /// Erzwingt eine vollständige Synchronisation aller Avatar-URLs
  static Future<void> forceSync() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) throw Exception('User nicht angemeldet');

      // Lade die aktuelle Avatar-URL aus der users Tabelle
      final currentAvatarUrl = await getCurrentAvatarUrl();
      
      // Synchronisiere mit der aktuellen URL
      await syncAvatar(currentAvatarUrl);

      print('DEBUG: Force sync completed');
      avatarVersion.value++;
    } catch (e) {
      print('DEBUG: Error in force sync: $e');
      rethrow;
    }
  }
} 