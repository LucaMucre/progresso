# TestFlight & Play Console – Internal Testing Setup

## iOS (TestFlight)
1. Create an Apple Developer account and a Team.
2. Create a Bundle ID (e.g., `app.progresso.mobile`).
3. In Xcode (or `ios/Runner.xcodeproj`), set the bundle identifier and signing team for Debug/Release.
4. Prepare signing:
   - Create an iOS Distribution certificate and a Provisioning Profile for App Store.
   - Alternatively use Xcode automatic signing for simplicity.
5. Build Archive:
   - Local: `flutter build ios --release` → Open `Runner.xcworkspace` → Product → Archive → Distribute to App Store Connect.
   - CI (recommended once signing is set): Configure App Store Connect API Key + `xcodebuild -exportArchive`.
6. In App Store Connect:
   - Create an App entry → fill metadata → add screenshots.
   - Upload build → wait for processing → enable TestFlight internal testing.

Notes:
- Our workflow `ios.yml` builds without codesign to ensure CI passes; for upload you need signing locally or in CI secrets.
- Set environment with `--dart-define=FLAVOR=staging` or `prod`.

## Android (Play Internal Testing)
1. Create a Google Play Console account, create an app (package name e.g., `app.progresso.mobile`).
2. In `android/app/build.gradle` set `applicationId` to the final package name.
3. Generate a release keystore:
   ```bash
   keytool -genkey -v -keystore keystore.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
   ```
4. Create `android/key.properties` (do not commit):
   ```
   storePassword=...
   keyPassword=...
   keyAlias=upload
   storeFile=../keystore.jks
   ```
5. Configure signing in `android/app/build.gradle` (release signingConfig) using `key.properties`.
6. Build:
   ```bash
   flutter build appbundle --release --dart-define=FLAVOR=staging
   ```
7. Upload the `.aab` to Play Console → Internal testing → Create release.

Notes:
- Our CI builds split‑per‑abi APKs; for Play upload `.aab` is preferred.
- Make sure privacy policy URL is set; content rating questionnaire completed.