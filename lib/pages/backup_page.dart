import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../services/backup_service.dart';
import '../utils/app_theme.dart';
import '../utils/haptic_utils.dart';
import '../widgets/state_widgets.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool _isLoading = false;
  Map<String, dynamic> _backupStats = {};
  String? _statusMessage;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _loadBackupStats();
  }

  Future<void> _loadBackupStats() async {
    setState(() => _isLoading = true);
    try {
      final stats = await BackupService.getBackupStats();
      setState(() {
        _backupStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to load backup statistics: $e';
        _isError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _createBackup() async {
    setState(() => _isLoading = true);
    try {
      HapticUtils.submit();
      final result = await BackupService.createAndShareBackup();
      setState(() {
        _statusMessage = result.message;
        _isError = !result.success;
        _isLoading = false;
      });
      if (result.success) {
        HapticUtils.success();
      } else {
        HapticUtils.error();
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to create backup: $e';
        _isError = true;
        _isLoading = false;
      });
      HapticUtils.error();
    }
  }

  Future<void> _copyToClipboard() async {
    setState(() => _isLoading = true);
    try {
      HapticUtils.submit();
      final result = await BackupService.copyBackupToClipboard();
      setState(() {
        _statusMessage = result.message;
        _isError = !result.success;
        _isLoading = false;
      });
      if (result.success) {
        HapticUtils.success();
      } else {
        HapticUtils.error();
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to copy backup: $e';
        _isError = true;
        _isLoading = false;
      });
      HapticUtils.error();
    }
  }

  Future<void> _restoreFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() => _isLoading = true);
        
        final content = String.fromCharCodes(result.files.single.bytes!);
        final restoreResult = await BackupService.restoreFromBackup(content);
        
        setState(() {
          _statusMessage = restoreResult.message;
          _isError = !restoreResult.success;
          _isLoading = false;
        });

        if (restoreResult.success) {
          HapticUtils.success();
          await _loadBackupStats(); // Refresh stats after restore
        } else {
          HapticUtils.error();
        }
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to restore from file: $e';
        _isError = true;
        _isLoading = false;
      });
      HapticUtils.error();
    }
  }

  Future<void> _restoreFromClipboard() async {
    setState(() => _isLoading = true);
    try {
      HapticUtils.submit();
      final result = await BackupService.restoreFromClipboard();
      setState(() {
        _statusMessage = result.message;
        _isError = !result.success;
        _isLoading = false;
      });

      if (result.success) {
        HapticUtils.success();
        await _loadBackupStats(); // Refresh stats after restore
      } else {
        HapticUtils.error();
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to restore from clipboard: $e';
        _isError = true;
        _isLoading = false;
      });
      HapticUtils.error();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore'),
        backgroundColor: theme.colorScheme.surface,
      ),
      body: _isLoading
          ? const StateWidget.loading(message: 'Processing...')
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status message
                  if (_statusMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacing16),
                      decoration: BoxDecoration(
                        color: _isError 
                            ? theme.colorScheme.errorContainer
                            : theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                      child: Text(
                        _statusMessage!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _isError 
                              ? theme.colorScheme.onErrorContainer
                              : theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing20),
                  ],

                  // Backup statistics
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spacing16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Data',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacing12),
                          if (_backupStats.isNotEmpty) ...[
                            _buildStatRow('Activities', '${_backupStats['logs_count'] ?? 0}'),
                            _buildStatRow('Templates', '${_backupStats['templates_count'] ?? 0}'),
                            _buildStatRow('Achievements', '${_backupStats['achievements_count'] ?? 0}'),
                            _buildStatRow('Total XP', '${_backupStats['total_xp'] ?? 0}'),
                            _buildStatRow('Est. Backup Size', '${_backupStats['estimated_export_size_kb'] ?? 0} KB'),
                          ] else ...[
                            const Text('Loading statistics...'),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppTheme.spacing24),

                  // Backup section
                  Text(
                    'Create Backup',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  Text(
                    'Export all your data to keep it safe. This includes your activities, templates, and achievements.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing16),

                  ElevatedButton.icon(
                    onPressed: _createBackup,
                    icon: const Icon(Icons.backup),
                    label: const Text('Create & Share Backup'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
                  ),

                  const SizedBox(height: AppTheme.spacing12),

                  OutlinedButton.icon(
                    onPressed: _copyToClipboard,
                    icon: const Icon(Icons.content_copy),
                    label: const Text('Copy to Clipboard'),
                  ),

                  const SizedBox(height: AppTheme.spacing32),

                  // Restore section
                  Text(
                    'Restore from Backup',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  Text(
                    'Import data from a previous backup. This will replace your current data.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing16),

                  ElevatedButton.icon(
                    onPressed: _restoreFromFile,
                    icon: const Icon(Icons.file_upload),
                    label: const Text('Restore from File'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.secondary,
                      foregroundColor: theme.colorScheme.onSecondary,
                    ),
                  ),

                  const SizedBox(height: AppTheme.spacing12),

                  OutlinedButton.icon(
                    onPressed: _restoreFromClipboard,
                    icon: const Icon(Icons.content_paste),
                    label: const Text('Restore from Clipboard'),
                  ),

                  const SizedBox(height: AppTheme.spacing32),

                  // Warning
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacing16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: theme.colorScheme.onSecondaryContainer,
                              size: AppTheme.iconMedium,
                            ),
                            const SizedBox(width: AppTheme.spacing8),
                            Text(
                              'Important',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacing8),
                        Text(
                          '• Backups contain all your personal data\n'
                          '• Keep backup files secure and private\n'
                          '• Restoring will overwrite current data\n'
                          '• A safety backup is created before restore',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}