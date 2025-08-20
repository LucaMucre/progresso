import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'legal/privacy_page.dart';
import 'legal/terms_page.dart';
import 'pages/backup_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'services/test_data_service.dart';
import 'services/crash_reporting_service.dart';
import 'services/db_service.dart' as db_service;

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _assistOptIn = false;
  bool _loading = true;
  final _newPwCtrl = TextEditingController();
  final _newPw2Ctrl = TextEditingController();
  bool _crashOptIn = true;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    // KI-Assistenz für alle Nutzer deaktivieren (Datenschutz: keine externen Aufrufe)
    await prefs.setBool('assist_opt_in', false);
    _crashOptIn = CrashReportingService.isUserOptedIn;
    try {
      _appVersion = await getPackageVersion();
    } catch (_) {}
    setState(() {
      _assistOptIn = false;
      _loading = false;
    });
  }

  Future<String> getPackageVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } catch (_) {
      return '';
    }
  }

  Future<void> _changePassword() async {
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Change password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _newPwCtrl,
                  decoration: const InputDecoration(labelText: 'New password'),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _newPw2Ctrl,
                  decoration: const InputDecoration(labelText: 'Repeat new password'),
                  obscureText: true,
                ),
              ],
            ),
          ),
          actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final newPw = _newPwCtrl.text.trim();
                final newPw2 = _newPw2Ctrl.text.trim();
                if (newPw.isEmpty || newPw2.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a new password')));
                  return;
                }
                if (newPw != newPw2) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
                  return;
                }
                try {
                  // Hinweis: Supabase benötigt das alte Passwort hier nicht, der Nutzer muss eingeloggt sein
                  await Supabase.instance.client.auth.updateUser(UserAttributes(password: newPw));
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated')));
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    _newPwCtrl.clear();
    _newPw2Ctrl.clear();
  }

  Future<void> _toggleAssist(bool enable) async {
    if (enable) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Enable AI assistance?'),
          content: const Text(
              'If you enable AI assistance, requests with summarized content may be sent to an external AI service. Your data stays restricted to your account via RLS. You can disable this mode at any time.'),
          actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enable')),
          ],
        ),
      );
      if (ok != true) return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('assist_opt_in', enable);
    setState(() => _assistOptIn = enable);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('AI assistance is now ${enable ? 'enabled' : 'disabled'}')),
    );
  }

  Future<void> _deleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account permanently?'),
        content: const Text(
            'This will permanently delete your account and all associated data. This action cannot be undone.'),
        actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete permanently')),
        ],
      ),
    );
    if (ok != true) return;

    // 1) Serverseitig löschen
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'delete-account',
        body: {},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Account deleted: ${res.data ?? 'ok'}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting account: $e')),
      );
      // trotzdem lokal abmelden versuchen
    }
    // 2) Lokale Session beenden; 403 nach Server-Delete ignorieren
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Debug section (only in debug mode)
                if (kDebugMode) ..._buildDebugSection(),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Logout'),
                  onTap: () async {
                    try {
                      await Supabase.instance.client.auth.signOut();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logged out')));
                      Navigator.of(context).pop();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.lock_reset),
                  title: const Text('Change password'),
                  onTap: _changePassword,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.privacy_tip),
                  title: const Text('Share anonymous crash reports'),
                  subtitle: const Text('Helps improve app stability and performance'),
                  value: _crashOptIn,
                  onChanged: (v) async {
                    await CrashReportingService.setUserOptIn(v);
                    setState(() => _crashOptIn = v);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('Contact support'),
                  subtitle: const Text('support@progresso.app'),
                  onTap: () async {
                    final uri = Uri(scheme: 'mailto', path: 'support@progresso.app', query: 'subject=Progresso Support');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.backup),
                  title: const Text('Backup & Export'),
                  subtitle: const Text('Create backups or export your data'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BackupPage()),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PrivacyPage()),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Terms of Service'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TermsPage()),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(_appVersion.isEmpty ? 'Licenses' : 'Licenses • v$_appVersion'),
                  onTap: () => showLicensePage(context: context, applicationName: 'Progresso', applicationVersion: _appVersion),
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Delete account'),
                  textColor: Colors.red,
                  iconColor: Colors.red,
                  onTap: _deleteAccount,
                ),
              ],
            ),
    );
  }

  List<Widget> _buildDebugSection() {
    return [
      const ListTile(
        leading: Icon(Icons.bug_report),
        title: Text('Debug Tools'),
        subtitle: Text('Development tools (debug mode only)'),
      ),
      ListTile(
        leading: const Icon(Icons.data_usage),
        title: const Text('Create Test Data'),
        subtitle: const Text('Generate sample activities for testing'),
        onTap: () async {
          try {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Creating test data...')),
            );
            
            await TestDataService.createTestData();
            
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ Test data created successfully')),
            );
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('❌ Error creating test data: $e')),
            );
          }
        },
      ),
      ListTile(
        leading: const Icon(Icons.info),
        title: const Text('Storage Info'),
        subtitle: const Text('View local storage statistics'),
        onTap: () async {
          try {
            final stats = await TestDataService.getLocalStats();
            final hasData = await TestDataService.hasLocalData();
            final storageMode = db_service.isUsingLocalStorage ? 'Local' : 'Remote';
            
            if (!mounted) return;
            
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Storage Information'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Storage Mode: $storageMode'),
                    Text('Has Local Data: $hasData'),
                    Text('Templates: ${stats['templates'] ?? 0}'),
                    Text('Logs: ${stats['logs'] ?? 0}'),
                    Text('Achievements: ${stats['achievements'] ?? 0}'),
                    Text('Total XP: ${stats['total_xp'] ?? 0}'),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error getting storage info: $e')),
            );
          }
        },
      ),
      const Divider(),
    ];
  }

  @override
  void dispose() {
    _newPwCtrl.dispose();
    _newPw2Ctrl.dispose();
    super.dispose();
  }
}

