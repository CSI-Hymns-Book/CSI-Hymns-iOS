# CSI Hymns Book — Native iOS

Native **SwiftUI** app for the Kannada CSI Hymns & Keerthane lyrics book. Built for congregations who need reliable offline access, bilingual reading, cloud sync, and a modern iOS 26 **Liquid Glass** experience.

<p align="center">
  <a href="https://apps.apple.com/in/app/csi-hymns-book/id6759966582">
    <img src="https://img.shields.io/badge/App_Store-CSI_Hymns_Book-0D96F6?style=for-the-badge&logo=appstore&logoColor=white" alt="Download on the App Store" />
  </a>
  <img src="https://img.shields.io/badge/iOS-26+-007AFF?style=for-the-badge&logo=apple&logoColor=white" alt="iOS 26+" />
  <img src="https://img.shields.io/badge/Swift-6-F05138?style=for-the-badge&logo=swift&logoColor=white" alt="Swift 6" />
  <img src="https://img.shields.io/badge/SwiftUI-✓-007AFF?style=for-the-badge&logo=swift&logoColor=white" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/Version-4.2.1-blue?style=for-the-badge" alt="Version 4.2.1" />
  <img src="https://img.shields.io/badge/License-Proprietary-lightgrey?style=for-the-badge" alt="License" />
</p>

| | |
|---|---|
| **Platform** | iOS 26+ (iPhone, iPad, visionOS) |
| **Bundle ID** | `com.reyzie.hymns` |
| **Version** | 4.2.1 |
| **Language** | Swift 6 · SwiftUI |
| **Backend** | [Supabase](https://supabase.com) |

---

## Screenshots

> Add PNGs to [`docs/screenshots/`](docs/screenshots/) — filenames below. See [`docs/screenshots/README.md`](docs/screenshots/README.md) for capture suggestions.

<p align="center">
  <img src="docs/screenshots/01-hymns-list.png" width="220" alt="Hymns list (add screenshot)" />
  &nbsp;&nbsp;
  <img src="docs/screenshots/02-hymn-detail.png" width="220" alt="Lyrics reader (add screenshot)" />
  &nbsp;&nbsp;
  <img src="docs/screenshots/03-keerthanes.png" width="220" alt="Keerthanes (add screenshot)" />
</p>

<p align="center">
  <img src="docs/screenshots/04-christmas-portal.png" width="220" alt="Christmas portal (add screenshot)" />
  &nbsp;&nbsp;
  <img src="docs/screenshots/05-carols-churches.png" width="220" alt="Community carols (add screenshot)" />
  &nbsp;&nbsp;
  <img src="docs/screenshots/06-settings.png" width="220" alt="Settings (add screenshot)" />
</p>

---

## Features

### Hymns & Keerthanes
- Full **CSI hymn book** and **keerthane** library with bundled offline data
- **Bilingual lyrics** (Kannada + English) with page-flip or scroll reading modes
- Search by number, title, meter, or raga/tala (keerthanes)
- **Audio playback** for hymn and keerthane accompaniments
- Remote lyric refresh from GitHub with local cache fallback

### Worship & community
- **Order of Service** — liturgy hub with PDF reader and page navigation
- **Community Carols** — church-first model: create a parish, then add **songs (lyrics)** or **PDF sheets** separately
- **Custom categories** — build and sync personal song folders
- **Favorites** and **recent songs**

### Account & sync
- Sign in with **Apple**, **Google**, or email (Supabase Auth)
- Cloud sync for favorites, custom categories, and carol libraries
- Profile editing with display name sync

### App experience
- **Christmas mode** — festive portal, snowfall overlay, and seasonal tab layout
- **Liquid Glass** navigation bars, tab bar, and list cards (iOS 26)
- Light / Dark / AMOLED themes with accent color picker
- Force-update gate, in-app feedback via Jira, PostHog analytics
- Chromecast support, push notifications (OneSignal)

---

## Requirements

- **macOS** with **Xcode 26** or later
- **iOS 26** device or simulator (deployment target is iOS 26)
- Apple Developer account (for Sign in with Apple and device builds)
- A Supabase project (shared with the Android app)

---

## Getting started

### 1. Clone the repo

```bash
git clone https://github.com/CSI-Hymns-Book/CSI-Hymns-iOS.git
cd CSI-Hymns-iOS
```

### 2. Configure secrets

Secrets are **not** committed. Copy the template and fill in your values:

```bash
cp "CSI Hymns App/Secrets.plist.template" "CSI Hymns App/Secrets.plist"
```

`Secrets.plist` supports:

| Key | Purpose |
|-----|---------|
| `SupabaseURL` / `SupabaseAnonKey` | Auth, sync, carols backend |
| `JiraURL` / `JiraEmail` / `JiraAPIToken` | In-app lyric issue reporting |
| `PostHogAPIKey` / `PostHogHost` | Analytics (optional) |

### 3. Open in Xcode

```bash
open "CSI Hymns App.xcodeproj"
```

Select the **CSI Hymns App** scheme, pick a simulator or device, and run (**⌘R**).

Swift Package Manager resolves dependencies automatically:

- [supabase-swift](https://github.com/supabase-community/supabase-swift) 2.x
- [OneSignal-iOS-SDK](https://github.com/OneSignal/OneSignal-iOS-SDK) 5.x

### 4. Capabilities

The project expects these entitlements (already configured in Xcode):

- **Sign in with Apple**
- Push notifications (OneSignal)
- Associated URL scheme: `com.reyzie.hymns` (OAuth redirect)

---

## Project structure

```
CSI Hymns App/
├── CSIHymnsApp.swift          # App entry + lifecycle
├── AppDelegate.swift          # OneSignal, push setup
├── Models/                    # Hymn, CarolChurch, CarolSong, CarolPdf, …
├── Services/                  # Supabase, audio, themes, carols, favorites, …
├── Views/
│   ├── HymnsListView.swift    # Hymn & keerthane lists
│   ├── HymnDetailView.swift   # Lyrics reader + audio
│   ├── Christmas/             # Church-first community carols
│   ├── Service/               # Order of Service + PDF reader
│   ├── Settings/              # Profile, themes, tickets, about
│   └── GlassChrome.swift      # Liquid Glass helpers
├── Assets.xcassets/           # App icon, hymn/keerthane art, bundled JSON
├── Info.plist
├── Secrets.plist              # Local only (gitignored)
└── CSI Hymns App.entitlements

supabase/
├── README.md                  # Carol churches backend notes
└── CAROL_ANDROID_PARITY_BRIEF.md
```

---

## Backend (Supabase)

Community carols use a **church-first** schema:

| Table | Purpose |
|-------|---------|
| `carol_churches` | Parish / church container |
| `carol_songs` | Lyrics inside a church |
| `carol_pdfs` | PDF sheets inside a church |

Schema is applied in the **Supabase Dashboard** (not versioned in this repo). See [`supabase/README.md`](supabase/README.md) for RLS rules, storage bucket (`carol-pdfs`), and admin notes.

Kotlin/Android parity spec: [`supabase/CAROL_ANDROID_PARITY_BRIEF.md`](supabase/CAROL_ANDROID_PARITY_BRIEF.md)

---

## Data sources

| Content | Source |
|---------|--------|
| Hymns / keerthanes (bundled) | `Assets.xcassets/*_data.dataset` |
| Hymns / keerthanes (updates) | [csi-hymns-vault](https://github.com/Reynold29/csi-hymns-vault) on GitHub |
| Carols (legacy seed) | Same vault + Supabase |
| Order of Service PDFs | Remote URLs with on-device cache |

---

## Related apps

- **[CSI Hymns Book on the App Store](https://apps.apple.com/in/app/csi-hymns-book/id6759966582)**
- **[Worship Companion](https://apps.apple.com/in/app/worship-companion/id6759990066)** — praise & worship lyrics companion app (linked from Settings)

---

## Privacy

[CSI Hymns Privacy Policy](https://sites.google.com/view/csi-hymns-privacy-policy/home)

---

## Contributing

This repository is maintained by the CSI Hymns Book team. For lyric corrections or bugs, use **Report an Issue** inside the app (Settings) or open a GitHub issue.

---

## License

Copyright © CSI Hymns Book. All rights reserved.
