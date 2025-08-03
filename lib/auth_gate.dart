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
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
        setState(() {}); // beim Ein-/Ausloggen neu rendern
      });
    } catch (e) {
      print('AuthGate Fehler: $e');
      setState(() {
        _hasError = true;
      });
    }
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