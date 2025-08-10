import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_page.dart';
import 'dashboard_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription? _authSub;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    try {
      // Supabase onAuthStateChange ist ein Stream<AuthStateChange>
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
        final event = data.event;
        // Wenn Nutzer über Magic-Link in den Passwort-Reset kommt, löst Supabase USER_UPDATED aus.
        if (event == AuthChangeEvent.userUpdated) {
          await _showInAppPasswordReset();
        }
        if (mounted) setState(() {}); // beim Ein-/Ausloggen neu rendern
      });
    } catch (e) {
      print('AuthGate Fehler: $e');
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
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
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwort aktualisiert. Bitte neu einloggen.')));
                }
                // Optional: Session invalidieren
                await Supabase.instance.client.auth.signOut();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
              }
            },
            child: const Text('Speichern'),
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
                'Bitte starte Supabase lokal mit:\nflutter pub global activate supabase\nsupabase start',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    try {
      final session = Supabase.instance.client.auth.currentSession;
      return session == null
        ? const AuthPage()
        : const DashboardPage();
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
                'Fehler beim Laden der App',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Bitte überprüfe deine Supabase-Konfiguration',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
  }
}