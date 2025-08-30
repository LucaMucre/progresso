# Store Listing Checklist (iOS + Android)

Use this file to prepare App Store Connect and Google Play Console listings.

## Text assets
- App name: Progresso
- Subtitle (iOS, 30 chars max): Track real-life progress
- Promotional text (iOS, 170 chars): Level up your real-life character. Log activities, see stats and streaks, and stay motivated with achievements.
- Short description (Play, 80 chars): Track activities, earn XP, and level up your real-life character.
- Full description (<= 4000 chars, Play & iOS):
  - What it does: activities, life areas, calendar, profile stats, achievements
  - Why: motivation via gamification, streaks, XP
  - Privacy: account deletion in-app, no ads, optional crash reports
- Keywords (iOS, 100 chars): productivity, habits, tracker, life, goals, streak, calendar, xp, fitness, learning
- Category: Health & Fitness or Productivity (pick one and subcategory if needed)
- Support URL: https://progresso.app/support (or mailto)
- Marketing URL: https://progresso.app
- Privacy Policy URL: https://progresso.app/privacy

## Graphics
- App Icon (already in project; ensure final brand):
  - iOS: AppIcon asset present
  - Android: mipmap/ic_launcher present (consider adaptive icon)
- App Store Screenshots (provide at least 6–8; dark/light mixed OK):
  - iPhone 6.7" (1290×2796 px) – required for modern iPhones
  - iPhone 5.5" (1242×2208 px) – legacy size still accepted
  - iPad Pro 12.9" (2048×2732 px) – optional
- Google Play Screenshots:
  - Phone (minimum 2): 1080×1920 px (portrait) recommended
  - Optional: 1242×2688 px to reuse iOS assets
  - Feature graphic: 1024×500 px (no transparency)
  - App icon: 512×512 px, max 1024 KB, PNG

Suggested screens to capture:
- Dashboard with calendar + summary chips
- Day details modal
- Profile with statistics + life areas
- Life area bubbles view
- Log activity flow (image upload)
- Achievements / level‑up dialog

## Compliance/Metadata
- Age rating: 4+ / ESRB E (no user‑generated public sharing, no violence)
- Copyright: © 2025 Progresso
- Contact email: progresso.sup@gmail.com
- Sign‑in required: Yes (Supabase Auth)
- App privacy: see `docs/app_store_privacy.md`

## Localization
- English (en), German (de) – ARB strings exist. Update store texts for both languages.

## QA before submission
- New account flow: sign up → default life areas present → create activity → calendar/profil updates instantly
- Image upload on both platforms
- Delete account works and signs out
- Offline banner/behavior acceptable
- Crash opt‑out respected