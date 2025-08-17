import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'auth_gate.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'navigation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'utils/logging_service.dart';
import 'utils/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool envLoaded = false;
  bool dartDefineLoaded = false;
  String? supabaseUrl;
  String? supabaseAnonKey;
  const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');

  // 1) Prod/CI bevorzugt --dart-define
  const ddSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const ddSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (ddSupabaseUrl.isNotEmpty && ddSupabaseAnonKey.isNotEmpty) {
    supabaseUrl = ddSupabaseUrl;
    supabaseAnonKey = ddSupabaseAnonKey;
    dartDefineLoaded = true;
    LoggingService.info('✅ Loaded Supabase config from --dart-define');
  }

  // 2) Nur in Nicht-Release zusätzlich .env lesen (Dev‑Bequemlichkeit)
  if (!kReleaseMode && !dartDefineLoaded) {
    try {
      // .env nach Flavor laden (.env / .env.staging / .env.prod)
      final envFile = switch (flavor) {
        'prod' => '.env.prod',
        'staging' => '.env.staging',
        _ => '.env',
      };
      await dotenv.load(fileName: envFile);

      // Validiere die Umgebungsvariablen
      supabaseUrl = dotenv.env['SUPABASE_URL'];
      supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

      if (supabaseUrl != null && supabaseAnonKey != null &&
          supabaseUrl!.isNotEmpty && supabaseAnonKey!.isNotEmpty) {
        envLoaded = true;
        LoggingService.info('✅ .env file loaded successfully');
      } else {
        throw Exception('SUPABASE_URL oder SUPABASE_ANON_KEY fehlen in .env Datei');
      }
    } catch (e) {
      LoggingService.warning('❌ Error loading .env file: $e');
      LoggingService.info('ℹ️  Verwende --dart-define oder konfiguriere eine lokale .env für Dev.');
    }
  }

  Future<Widget> bootstrap() async {
    try {
      if (supabaseUrl == null || supabaseAnonKey == null) {
        throw Exception('Supabase-Konfiguration fehlt (.env nicht geladen)');
      }
      await Supabase.initialize(
        url: supabaseUrl!,
        anonKey: supabaseAnonKey!,
      );
      if (kDebugMode) {
        final source = dartDefineLoaded
            ? '--dart-define'
            : (envLoaded ? '.env' : 'unknown source');
        LoggingService.info('✅ Supabase initialisiert (Quelle: $source)');
      }
      // Nicht blockierend testen, damit der App-Start nicht hängt (z. B. bei CORS/Netzwerkproblemen)
      Future(() async {
        try {
          final client = Supabase.instance.client;
          await client
              .from('users')
              .select('count')
              .limit(1)
              .timeout(const Duration(seconds: 3));
          LoggingService.info('✅ Supabase Verbindung getestet - erfolgreich');
        } catch (e) {
          LoggingService.warning('ℹ️  Supabase Test-Query übersprungen/fehlgeschlagen: $e');
        }
      });
    } catch (e) {
      LoggingService.error('❌ Supabase Initialisierung fehlgeschlagen', e);
      LoggingService.warning('🚨 App wird trotzdem gestartet, aber Supabase-Features sind nicht verfügbar');
    }
    return const ProviderScope(child: ProgressoApp());
  }

  // Optional Sentry nur aktivieren, wenn DSN vorhanden ist
  // Sentry DSN ebenfalls bevorzugt via --dart-define
  const ddSentryDsn = String.fromEnvironment('SENTRY_DSN');
  final sentryDsn = (ddSentryDsn.isNotEmpty)
      ? ddSentryDsn
      : (envLoaded ? dotenv.env['SENTRY_DSN'] : null);
  final enableSentry = (sentryDsn != null && sentryDsn.isNotEmpty && kReleaseMode);
  if (enableSentry) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.tracesSampleRate = 0.2; // adjust later
        options.enableAutoNativeBreadcrumbs = true;
        options.environment = flavor;
      },
      appRunner: () async => runApp(await bootstrap()),
    );
  } else {
    runApp(await bootstrap());
  }
}

class ProgressoApp extends StatelessWidget {
  const ProgressoApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color seedColor = Color(0xFF2563EB);
    final ColorScheme lightScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );
    final ColorScheme darkScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );
    return MaterialApp(
      title: 'Progresso',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
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