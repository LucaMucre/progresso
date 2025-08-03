import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Versuche die .env Datei zu laden
    await dotenv.load();
    
    // Initialisiert Supabase mit deinen Cloud-Keys
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );
    print('Supabase Cloud erfolgreich initialisiert');
  } catch (e) {
    print('Fehler beim Laden der .env Datei: $e');
    print('Verwende echte Supabase-Keys...');
    
    try {
      // Echte Supabase-Keys
      await Supabase.initialize(
        url: 'https://xssuhovxkpgorjxvflwo.supabase.co',
        anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhzc3Vob3Z4a3Bnb3JqeHZmbHdvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM5ODY2NTEsImV4cCI6MjA2OTU2MjY1MX0.y1fXBKBAQkNL17AcBiBNMIOyVyBD8_fexQWeWqGz1UY',
      );
      print('Supabase mit echten Keys initialisiert');
    } catch (e2) {
      print('Supabase Initialisierung fehlgeschlagen: $e2');
    }
  }

  runApp(const ProgressoApp());
}

class ProgressoApp extends StatelessWidget {
  const ProgressoApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Progresso',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.blue)
          .copyWith(secondary: Colors.green),
      ),
      home: const AuthGate(),
    );
  }
}