# Keep Flutter classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep JSON models (Dart → JSON via platform channel is minimal)
# Sentry
-keep class io.sentry.** { *; }
-dontwarn io.sentry.**

# Supabase/OkHttp/Coroutines warnings
-dontwarn okhttp3.**
-dontwarn kotlinx.coroutines.**