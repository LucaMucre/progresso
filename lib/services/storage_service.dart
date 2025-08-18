import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repository/logs_repository.dart';
import '../repository/templates_repository.dart';
import '../repository/stats_repository.dart';
import '../repository/local_logs_repository.dart';
import '../repository/local_templates_repository.dart';
import '../repository/local_stats_repository.dart';

/// Service to manage storage mode and repository routing
class StorageService {
  static final _db = Supabase.instance.client;
  
  // Local repositories (primary)
  static final LocalLogsRepository _localLogsRepo = LocalLogsRepository();
  static final LocalTemplatesRepository _localTemplatesRepo = LocalTemplatesRepository();
  static final LocalStatsRepository _localStatsRepo = LocalStatsRepository();

  // Remote repositories (fallback/sync)
  static final LogsRepository _logsRepo = LogsRepository(_db);
  static final TemplatesRepository _templatesRepo = TemplatesRepository(_db);
  static final StatsRepository _statsRepo = StatsRepository(_db);

  // Flag to control local vs remote storage
  static bool _useLocalStorage = true;

  /// Switch between local and remote storage
  static void setStorageMode({required bool useLocal}) {
    _useLocalStorage = useLocal;
    if (kDebugMode) debugPrint('Storage mode changed to: ${useLocal ? "Local" : "Remote"}');
  }

  /// Get current storage mode
  static bool get isUsingLocalStorage => _useLocalStorage;

  /// Get appropriate logs repository based on storage mode
  static dynamic get logsRepo => _useLocalStorage ? _localLogsRepo : _logsRepo;

  /// Get appropriate templates repository based on storage mode
  static dynamic get templatesRepo => _useLocalStorage ? _localTemplatesRepo : _templatesRepo;

  /// Get appropriate stats repository based on storage mode
  static dynamic get statsRepo => _useLocalStorage ? _localStatsRepo : _statsRepo;

  /// Get database info and stats
  static Future<Map<String, dynamic>> getDatabaseInfo() async {
    if (_useLocalStorage) {
      return await _localLogsRepo.getDatabaseInfo();
    } else {
      return {
        'storage_type': 'remote',
        'provider': 'supabase',
        'user_id': _db.auth.currentUser?.id,
      };
    }
  }
}