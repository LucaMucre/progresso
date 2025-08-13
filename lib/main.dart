import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_gate.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'navigation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool envLoaded = false;
  String? supabaseUrl;
  String? supabaseAnonKey;

  try {
    // Versuche die .env Datei zu laden
    await dotenv.load();
    
    // Validiere die Umgebungsvariablen
    supabaseUrl = dotenv.env['SUPABASE_URL'];
    supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
    
    if (supabaseUrl != null && supabaseAnonKey != null && 
        supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
      envLoaded = true;
  print('✅ .env file loaded successfully');
      print('📡 Supabase URL: ${supabaseUrl.substring(0, 30)}...');
      print('🔑 Anon Key: ${supabaseAnonKey.substring(0, 20)}...');
    } else {
      throw Exception('SUPABASE_URL oder SUPABASE_ANON_KEY fehlen in .env Datei');
    }
  } catch (e) {
  print('❌ Error loading .env file: $e');
    print('🔄 Verwende Fallback-Keys...');
    
    // Fallback zu den echten Supabase-Keys
    supabaseUrl = 'https://xssuhovxkpgorjxvflwo.supabase.co';
    supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhzc3Vob3Z4a3Bnb3JqeHZmbHdvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM5ODY2NTEsImV4cCI6MjA2OTU2MjY1MX0.y1fXBKBAQkNL17AcBiBNMIOyVyBD8_fexQWeWqGz1UY';
  }

  try {
    // Initialisiert Supabase mit den Keys
    await Supabase.initialize(
      url: supabaseUrl!,
      anonKey: supabaseAnonKey!,
    );
    
    if (envLoaded) {
      print('✅ Supabase erfolgreich mit .env Keys initialisiert');
    } else {
      print('✅ Supabase erfolgreich mit Fallback-Keys initialisiert');
    }
    
    // Teste die Verbindung
    final client = Supabase.instance.client;
    final response = await client.from('users').select('count').limit(1);
    print('✅ Supabase Verbindung getestet - erfolgreich');
    
  } catch (e) {
    print('❌ Supabase Initialisierung fehlgeschlagen: $e');
    print('🚨 App wird trotzdem gestartet, aber Supabase-Features sind nicht verfügbar');
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
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        quill.FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('de'),
      ],
      navigatorObservers: [routeObserver],
      home: const AuthGate(),
    );
  }
}