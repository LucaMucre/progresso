import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_shell.dart';
import 'services/achievement_service.dart';
import 'services/anonymous_user_service.dart';
import 'services/anonymous_migration_service.dart';
import 'navigation.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription? _authSub;
  bool _hasError = false;
  bool _resetDialogShown = false;

  @override
  void initState() {
    super.initState();
    try {
      // Supabase onAuthStateChange ist ein Stream<AuthStateChange>
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
        final event = data.event;
        // Passwort-Recovery zuverlässig abfangen (beide Events berücksichtigen)
        if ((event == AuthChangeEvent.passwordRecovery || event == AuthChangeEvent.userUpdated) && !_resetDialogShown) {
          _resetDialogShown = true;
          await _showInAppPasswordReset();
        }
        // Nach erfolgreichem Login/Registrierung
        if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.userUpdated) {
          try {
            final user = Supabase.instance.client.auth.currentUser;
            if (user != null) {
              // 1. Prüfen ob anonyme Daten migriert werden müssen
              final canMigrate = await AnonymousMigrationService.canMigrateData();
              if (canMigrate) {
                if (kDebugMode) debugPrint('Synchronisiere lokale Daten mit Cloud für User: ${user.id}');
                try {
                  await AnonymousMigrationService.syncLocalDataToCloud(user.id);
                  if (kDebugMode) debugPrint('Synchronisation erfolgreich abgeschlossen');
                } catch (migrationError) {
                  // Sync failed - but don't lose the user session
                  if (kDebugMode) debugPrint('WARNUNG: Synchronisation fehlgeschlagen, lokale Daten bleiben erhalten: $migrationError');
                  // Continue with login flow even if migration fails
                }
              }
              
              // 2. Achievements des Users laden
              await AchievementService.loadUnlockedAchievements();
              
              // 3. Check for pending redirect after login
              final pendingTabIndex = getPendingRedirectAfterLogin();
              if (pendingTabIndex != null) {
                clearPendingRedirectAfterLogin();
                // Small delay to ensure UI is ready
                Future.delayed(const Duration(milliseconds: 500), () {
                  goToHomeTab(pendingTabIndex);
                });
              }
            }
          } catch (e) {
            if (kDebugMode) debugPrint('Fehler bei Login-Migration: $e');
          }
        }
        if (mounted) setState(() {}); // beim Ein-/Ausloggen neu rendern
      });

      // Falls die App via Recovery-Link geöffnet wurde, enthält die URL typischerweise type=recovery
      final uri = Uri.base;
      final isRecovery = uri.queryParameters['type'] == 'recovery' || uri.fragment.contains('reset');
      if (isRecovery && !_resetDialogShown) {
        // Leicht verzögert zeigen, sobald der Build-Kontext steht
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (mounted && !_resetDialogShown) {
            _resetDialogShown = true;
            await _showInAppPasswordReset();
          }
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('AuthGate error: $e');
      setState(() {
        _hasError = true;
      });
    }
  }

  Future<void> _showInAppPasswordReset() async {
    final newPwCtrl = TextEditingController();
    final newPw2Ctrl = TextEditingController();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Neues Passwort setzen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: newPwCtrl,
              decoration: const InputDecoration(labelText: 'Neues Passwort'),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPw2Ctrl,
              decoration: const InputDecoration(labelText: 'Neues Passwort (wiederholen)'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final a = newPwCtrl.text.trim();
              final b = newPw2Ctrl.text.trim();
              if (a.isEmpty || b.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bitte Passwort eingeben')));
                return;
              }
              if (a != b) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwörter stimmen nicht überein')));
                return;
              }
              try {
                await Supabase.instance.client.auth.updateUser(UserAttributes(password: a));
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwort aktualisiert. Bitte neu einloggen.')));
                }
                // Optional: Session invalidieren
                await Supabase.instance.client.auth.signOut();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Save'),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Progresso')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'Supabase nicht verfügbar',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'App läuft im lokalen Modus ohne Cloud-Sync',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    try {
      // ===== NEUER ANONYMER START =====
      // Immer direkt zur HomeShell - keine Authentifizierung erforderlich
      // Anonyme User erhalten eine persistente lokale ID
      
      // Stelle sicher, dass eine anonyme User-ID existiert
      Future(() async {
        try {
          await AnonymousUserService.getOrCreateAnonymousUserId();
          if (kDebugMode) debugPrint('Anonymous user ID initialisiert');
        } catch (e) {
          if (kDebugMode) debugPrint('Fehler bei anonymer User-ID: $e');
        }
      });
      
      // Direkt zur Hauptapp - sowohl für anonyme als auch authentifizierte User
      return const HomeShell();
      
    } catch (e) {
      return Scaffold(
        appBar: AppBar(title: const Text('Progresso')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'Error loading app',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'App läuft im lokalen Modus',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
  }
}