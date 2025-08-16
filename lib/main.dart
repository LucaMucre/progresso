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
    if (kDebugMode) {
      debugPrint('✅ Loaded Supabase config from --dart-define');
    }
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
        if (kDebugMode) {
          debugPrint('✅ .env file loaded successfully');
        }
      } else {
        throw Exception('SUPABASE_URL oder SUPABASE_ANON_KEY fehlen in .env Datei');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error loading .env file: $e');
        debugPrint('ℹ️  Verwende --dart-define oder konfiguriere eine lokale .env für Dev.');
      }
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
        debugPrint('✅ Supabase initialisiert (Quelle: $source)');
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
          if (kDebugMode) debugPrint('✅ Supabase Verbindung getestet - erfolgreich');
        } catch (e) {
          if (kDebugMode) debugPrint('ℹ️  Supabase Test-Query übersprungen/fehlgeschlagen: $e');
        }
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Supabase Initialisierung fehlgeschlagen: $e');
        debugPrint('🚨 App wird trotzdem gestartet, aber Supabase-Features sind nicht verfügbar');
      }
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
  const ProgressoApp({Key? key}) : super(key: key);

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
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightScheme,
        scaffoldBackgroundColor: lightScheme.surface,
        visualDensity: VisualDensity.standard,
        textTheme: GoogleFonts.interTextTheme(),
        appBarTheme: AppBarTheme(
          backgroundColor: lightScheme.surface,
          foregroundColor: lightScheme.onSurface,
          elevation: 0,
          centerTitle: true,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: lightScheme.surface,
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.all(12),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: lightScheme.primary,
            foregroundColor: lightScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: lightScheme.surfaceContainerHighest,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: lightScheme.outline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: lightScheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: lightScheme.primary, width: 1.8),
          ),
          labelStyle: TextStyle(color: lightScheme.onSurfaceVariant),
          hintStyle: TextStyle(color: lightScheme.onSurfaceVariant),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: lightScheme.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: lightScheme.surface,
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: lightScheme.primary,
          foregroundColor: lightScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: lightScheme.inverseSurface,
          contentTextStyle: TextStyle(color: lightScheme.onInverseSurface),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkScheme,
        scaffoldBackgroundColor: darkScheme.surface,
        visualDensity: VisualDensity.standard,
        textTheme: GoogleFonts.interTextTheme(),
        appBarTheme: AppBarTheme(
          backgroundColor: darkScheme.surface,
          foregroundColor: darkScheme.onSurface,
          elevation: 0,
          centerTitle: true,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: darkScheme.surface,
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.all(12),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: darkScheme.primary,
            foregroundColor: darkScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: darkScheme.surfaceContainerHighest,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: darkScheme.outline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: darkScheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: darkScheme.primary, width: 1.8),
          ),
          labelStyle: TextStyle(color: darkScheme.onSurfaceVariant),
          hintStyle: TextStyle(color: darkScheme.onSurfaceVariant),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: darkScheme.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: darkScheme.surface,
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: darkScheme.primary,
          foregroundColor: darkScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: darkScheme.inverseSurface,
          contentTextStyle: TextStyle(color: darkScheme.onInverseSurface),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
      ),
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