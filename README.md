# Progresso - Personal Progress Tracker

Eine Flutter-App für das Tracking persönlicher Fortschritte mit XP-System, Streaks und detaillierten Logs.

## 🚀 Features

### ✅ Implementiert
- **Authentifizierung**: Supabase Auth mit Email/Passwort
- **XP-System**: Level-basiertes Fortschrittssystem
- **Streak-Tracking**: Tägliche Aktivitätsverfolgung
- **Action Templates**: Vorlagen für wiederkehrende Aktivitäten
- **Detailed Logging**: Dauer, Notizen und XP-Berechnung
- **Profile Management**: Avatar-Upload und Bio
- **Cross-Platform**: Windows, Web, Android, iOS

### 🔒 Sicherheit
- **Row Level Security (RLS)**: Vollständige Datenisolation
- **Storage Policies**: Sichere Avatar-Uploads
- **User Authentication**: Supabase Auth Integration

### 📱 State Management
- **Riverpod**: Zentrales State Management
- **Caching**: Offline-Support mit Local Cache
- **Error Handling**: Konsistente Fehlerbehandlung

## 🛠️ Technologie-Stack

- **Frontend**: Flutter 3.24.5
- **Backend**: Supabase (PostgreSQL, Auth, Storage)
- **State Management**: Riverpod
- **Testing**: Flutter Test
- **CI/CD**: GitHub Actions

## 📦 Installation

### Voraussetzungen
- Flutter SDK 3.24.5+
- Supabase Cloud Account
- Git

### Setup
```bash
# Repository klonen
git clone https://github.com/your-username/progresso.git
cd progresso

# Dependencies installieren
flutter pub get

# Code generieren (Riverpod)
flutter packages pub run build_runner build

# App starten
flutter run -d windows  # Windows
flutter run -d chrome   # Web
flutter run -d android  # Android
```

### Environment Setup
Erstelle eine `.env` Datei im Root-Verzeichnis:
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

## 🗄️ Datenbank-Schema

### Tabellen
- `users`: Benutzerprofile
- `action_templates`: Aktivitätsvorlagen
- `action_logs`: Aktivitätslogs

### RLS Policies
- Benutzer können nur eigene Daten sehen/bearbeiten
- Storage-Policies für sichere Avatar-Uploads
- Automatische User-Profile-Erstellung

## 🧪 Testing

### Unit Tests
```bash
flutter test test/unit/
```

### Widget Tests
```bash
flutter test test/widget/
```

### Code Analysis
```bash
flutter analyze
```

## 🚀 Deployment

### CI/CD Pipeline
- Automatische Tests bei Push/PR
- Windows Build mit Artifacts
- Web Build mit Artifacts

### Supabase Edge Functions
- `calculate-xp`: Komplexe XP-Berechnung mit Boni
- Streak-Boni für 7+ Tage
- Duration-Boni für längere Aktivitäten

## 📁 Projektstruktur

```
lib/
├── main.dart                 # App Entry Point
├── auth_gate.dart           # Auth Routing
├── auth_page.dart           # Login/Register
├── dashboard_page.dart      # Haupt-Dashboard
├── profile_page.dart        # Profil-Management
├── history_page.dart        # Log-Historie
├── templates_page.dart      # Template-Management
└── services/
    ├── db_service.dart      # Datenbank-Operationen
    ├── app_state.dart       # Riverpod State Management
    ├── error_service.dart   # Error Handling
    └── offline_cache.dart   # Offline-Support

test/
├── unit/                    # Unit Tests
└── widget/                  # Widget Tests

supabase/
├── migrations/              # Datenbank-Migrationen
└── functions/               # Edge Functions

.github/workflows/
└── ci.yml                  # CI/CD Pipeline
```

## 🔧 Konfiguration

### Supabase Setup
1. Projekt in Supabase Console erstellen
2. RLS-Policies aktivieren (siehe `migrations/`)
3. Storage Bucket "avatars" erstellen
4. Edge Functions deployen

### Flutter Configuration
- Riverpod für State Management
- SharedPreferences für Offline-Cache
- ImagePicker für Avatar-Uploads

## 📈 Roadmap

### Geplant
- [ ] Push-Notifications
- [ ] Social Features (Freunde, Challenges)
- [ ] Advanced Analytics
- [ ] Export/Import von Daten
- [ ] Dark Mode
- [ ] Localization (i18n)

### In Entwicklung
- [ ] Offline-First Architecture
- [ ] Advanced XP-Berechnungen
- [ ] Achievement System
- [ ] Data Visualization

## 🤝 Contributing

1. Fork das Repository
2. Feature Branch erstellen (`git checkout -b feature/AmazingFeature`)
3. Changes committen (`git commit -m 'Add AmazingFeature'`)
4. Branch pushen (`git push origin feature/AmazingFeature`)
5. Pull Request erstellen

## 📄 License

Dieses Projekt ist unter der MIT License lizenziert - siehe [LICENSE](LICENSE) Datei für Details.

## 🙏 Danksagungen

- Flutter Team für das großartige Framework
- Supabase für die Backend-as-a-Service Lösung
- Riverpod für das State Management
- Alle Contributors und Tester

---

**Progresso** - Track your progress, level up your life! 🎯
