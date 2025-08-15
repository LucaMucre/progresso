# App Privacy answers (Apple App Store)

This document summarizes what you can answer in App Store Connect → App Privacy.

NOTE: This app does not track users across apps/websites. No SDKs for ads/attribution are used.

## Data types collected

- Contact Info (optional, user-initiated)
  - Email (support contact only via mailto) → Not collected automatically by the app
- User Content (collected)
  - Activity logs, notes, images (user-generated content)
- Identifiers (collected)
  - Account identifier (Supabase `auth.uid`)
- Usage Data (limited)
  - Crash data (only if user opted in to anonymous crash reporting)

## Data usage purposes

- App Functionality: user content, identifiers (required to operate the service)
- Analytics/Diagnostics: crash data (optional, opt-in)

## Data linked to the user

- Activity logs/notes/images are linked to the account (required for core functionality).
- Crash data is not linked (sent anonymously when enabled).

## Data used for tracking

- None. No tracking across apps or websites.

## Optional notes for review

- Account deletion is available in-app (Settings → Delete account).
- Data export can be requested via Settings → Request data export (mailto).

## Location

- No location data collected.

## Health/Fitness/Sensitive data

- No health data per Apple HealthKit. User logs may include time spent or text content the user enters; this is general user content.

---

# Privacy Manifest (FYI)

The app uses UserDefaults (SharedPreferences) for local settings. No Required Reasons API beyond UserDefaults. Third‑party SDK privacy manifests (e.g., Sentry) are maintained by vendors; Sentry only sends crash data when user opt‑in is enabled and DSN is set in release.
