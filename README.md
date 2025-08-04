# Progresso - Flutter App mit Supabase Integration

Eine Flutter-App zur Verfolgung von Fortschritten und Gewohnheiten mit Supabase-Backend.

## Features

- 🔐 Authentifizierung mit Supabase
- 📊 Fortschrittsverfolgung
- 🏆 Badge-System
- 📱 Cross-Platform (Web, Windows, Mobile)
- 🔄 Offline-Caching
- 🎯 Template-basierte Aktionen

## Technologie-Stack

- **Frontend**: Flutter 3.24.5
- **Backend**: Supabase
- **State Management**: Riverpod
- **Code Generation**: build_runner
- **Testing**: flutter_test

## Setup

1. **Dependencies installieren:**
   ```bash
   flutter pub get
   ```

2. **Code generieren:**
   ```bash
   flutter packages pub run build_runner build --delete-conflicting-outputs
   ```

3. **Environment-Variablen setzen:**
   Erstelle eine `.env` Datei mit:
   ```
   SUPABASE_URL=your_supabase_url
   SUPABASE_ANON_KEY=your_supabase_anon_key
   ```

4. **App starten:**
   ```bash
   flutter run
   ```

## Testing

- **Unit Tests:** `flutter test test/unit/`
- **Widget Tests:** `flutter test test/widget/`
- **Integration Tests:** `flutter test test/integration/`

## CI/CD Pipeline

Die GitHub Actions Pipeline führt folgende Schritte aus:

1. **Test Job:**
   - Flutter Setup
   - Dependencies installieren
   - Code generieren
   - Analyse durchführen
   - Unit und Widget Tests ausführen
   - Web und Windows Builds erstellen

2. **Build Jobs:**
   - Separate Builds für Windows und Web
   - Artifacts hochladen

## Projektstruktur

```
lib/
├── main.dart              # App-Einstiegspunkt
├── auth_gate.dart         # Authentifizierung
├── auth_page.dart         # Login/Register UI
├── dashboard_page.dart    # Hauptdashboard
├── history_page.dart      # Verlaufsansicht
├── log_action_page.dart   # Aktion loggen
├── profile_page.dart      # Profilseite
├── templates_page.dart    # Template-Verwaltung
└── services/
    ├── app_state.dart     # Riverpod State Management
    ├── db_service.dart    # Supabase Integration
    ├── error_service.dart # Fehlerbehandlung
    └── offline_cache.dart # Offline-Caching
```

## Deployment

Die App kann auf folgenden Plattformen deployed werden:

- **Web:** `flutter build web`
- **Windows:** `flutter build windows`
- **Android:** `flutter build apk`
- **iOS:** `flutter build ios`

## Contributing

1. Fork das Repository
2. Erstelle einen Feature Branch
3. Committe deine Änderungen
4. Push zum Branch
5. Erstelle einen Pull Request

## License

Dieses Projekt ist unter der MIT-Lizenz lizenziert.
