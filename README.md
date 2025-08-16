# Progresso - Flutter App mit Supabase Integration

Eine Flutter-App zur Verfolgung von Fortschritten und Gewohnheiten mit Supabase-Backend.


okay gut, lass uns mit der app weitermachen. Vorher will ich dir aber noch eine detaillierte beschreibung von ihr geben. Lies es genau durch und verstehe es:
Es ist ein interessantes psychologische Phänomen. Mann kann mühelos hunderte von Stunden verschwenden um einen video game charakter zu verbessern. Mehrere Stunden an einem Ort zu stehen und immer die gleichen Monster zu töten ist kein Problem. Geht es aber darum, den eigenen Charakter, die eigene Persönlichkeit im real life zu verbessern, lässt die Motivation oft zu wünschen übrig, obwohl die Person die du bist und das reale leben ja eigentlich die Priorität sein sollten. Warum fällt es so schwer, sich selbst im reallife zu verbessern (indem man beispielsweise in buch liest, sich weiterbildet, sport treibt, gesund isst usw.) aber im gegensatz so leicht, stunden zu verschwenden nur um einen Video game character zu verbessern. Ich möchte eine App (oder website) erstellen, welches beiden welten verbindet. Ich möchte den videogamecharacter durch die reale person ersetzen und verbesserungen, die man im real life macht, auf diesen ingame character übertragen. Der Nutzer soll den character bzw. die app quasi dazu nutzen können, um Fortschritte und Verbesserungen aus dem real life in der app zu Tracken. Er kann dann quasi festhalten, dass er ein Buch fertig gelesen hat, was er dabei gelernt hat, dass er heute schon zum 3. mal die woche beim sport war und dass er sich jetzt den 3. tag infolge gesund ernährt. Oder dass er einen Kurz oder ein Video über Finanzen gesehen hat. Dass er eine Aktie gekauft hast  und alles was einem noch so in den sinn kommen könnte. Durch die app möchte ich quasi den psychologischen trick anwenden, den nutzer denken zu lassen, dass er einen videogame charakter leveled oder verbessert, wodurch eine andere Art von Motivation freigeschaltet wird. Allein schon deswegen, da er alle Verbesserungen immer an einem Ort einsehen kann. Somit kann er quasi tracken, wie stark er sich sienen vorstellungen nach verbessert hat und ob er nähe an seine Zielperson herangerückt ist. Durch diese Verbesserungen im Real life verbessert er also auch seinen Ingame charakter. Er macht ihn stärker, schlauer, effizienter, weiser usw. Ich will dabei kein RPG game erstellen. Ich will viel mehr eine oberfläche bzw. eine riesige datenbank im sinne eines organizers schaffen, in welchem alle wichtigen Infos festgehalten werden können. Aus jedem bereich des lebens. Habe ich ein buch gelesen, will ich es dort eintragen bzw. festhalten können und möglicherweise eine eigene Zusammenfassung bzw. wesentliche erkenntnisse die ich aus dem buch gewonnen habe anhängen. Für gymbesuche will ich die menge an besuchen tracken und kommentare hinzufügen hinsichtlich dessen, wie gut mir der trainingsplan gefällt und was ich evtl besser machen kann. Versteht du was ich meine? Wenn nein, erfrage gerne weitere informationen. Falls ja, stelle mir bitte eine schritt für schritt anleitung vor, welche mich in den Prozess der erstellung einer solchen app einführt. Bleibe dabei vorerst auf einem höhren level und erkläre mir, welche schritte generll nötig sind und was ich dafür brauche. Danke im Voraus, ich glaube mit der Idee können wir großes bewirken! :) 
Dabei sol die APp im Layout sein, wie ein Inventar in einem video spiel. Der character in der mitte und drum herum bubbles, die die einzelnen lebensbereiche betrefffen wie Fitness, Ernährung, Wissen, Bildung, Finanzen usw. In diese bubbles soll reingeklickt werden können und in der bubble können dann beliebig neue bereiche/bubbles hinzugefügt werden, um unterkategorien zu erstellen. Es sollen auch freitexte hinzugefügt werden. So soll man beispoiel in einem Bereich "Kunst" Bilder hochladen und diese mit eigenen Texten beschreiben können. Oder unter "Wissen" Bücher hochladen und mit eigenen worten zusammenfassen oder in stichpunkten wichtige erkenntnisse festhalten können.



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

3. **Secrets/Env Variablen setzen:**
   Für Production und CI/CD werden Secrets via `--dart-define` übergeben. Für lokales Development kannst du optional `.env` verwenden (siehe `.env.example`).
   - Beispiel Run (Dev):
     ```bash
     flutter run --dart-define=FLAVOR=dev \
       --dart-define=SUPABASE_URL=... \
       --dart-define=SUPABASE_ANON_KEY=... \
       --dart-define=SENTRY_DSN=...
     ```
   - Optional: `.env` nur für Nicht‑Release Builds nutzen.

4. **App starten:**
   ```bash
   flutter run --dart-define=FLAVOR=dev
   # oder
   flutter run --dart-define=FLAVOR=staging
   flutter run --dart-define=FLAVOR=prod
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
