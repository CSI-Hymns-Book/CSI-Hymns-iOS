# CSI Hymns Book — Native iOS

Native **SwiftUI** app for the Kannada CSI Hymns & Keerthane lyrics book. Built for congregations who need reliable offline access, bilingual reading, cloud sync, and a modern iOS 26 **Liquid Glass** experience.

<p align="center">
  <a href="https://apps.apple.com/in/app/csi-hymns-book/id6759966582">
    <img src="https://img.shields.io/badge/App_Store-CSI_Hymns_Book-0D96F6?style=for-the-badge&logo=appstore&logoColor=white" alt="Download on the App Store" />
  </a>
  <img src="https://img.shields.io/badge/iOS-26+-007AFF?style=for-the-badge&logo=apple&logoColor=white" alt="iOS 26+" />
  <img src="https://img.shields.io/badge/Swift-5-F05138?style=for-the-badge&logo=swift&logoColor=white" alt="Swift 5" />
  <img src="https://img.shields.io/badge/SwiftUI-✓-007AFF?style=for-the-badge&logo=swift&logoColor=white" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/Version-5.1.0-blue?style=for-the-badge" alt="Version 5.1.0" />
  <img src="https://img.shields.io/badge/License-Proprietary-lightgrey?style=for-the-badge" alt="License" />
</p>

| | |
|---|---|
| **Platform** | iOS 26+ (iPhone, iPad, visionOS) |
| **Bundle ID** | `com.reyzie.hymns` |
| **Version** | 5.1.0 (build 29) |
| **Language** | Swift 5 · SwiftUI |
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

### Hymns, Keerthanes & M.T. Hymns
- Home **section selector** for CSI Hymns & Keerthanes, Order of Service, and **Mangalore Tunes (M.T.) Hymns**
- Full **CSI hymn book**, **keerthane** library, and **M.T. Hymns** with bundled offline data
- **Bilingual lyrics** (Kannada + English) with page-flip or scroll reading modes
- Search by number, title, or meter/signature
- **Audio playback** (OGG accompaniments) plus a **MIDI engine** with SATB part routing, tempo, transpose, and a Settings instrument picker
- Contribute a missing audio or MIDI file from the hymn reader when no track is available
- Remote lyric refresh from GitHub with **local-first** cache (background re-check about every 3 days)

### Worship & community
- **Order of Service** — liturgy hub with PDF reader, page navigation, and a split-pane landscape layout
- **Community Carols** — church-first model: create a parish, then add **songs (lyrics)** or **PDF sheets** separately
- **Custom categories** — build and sync personal song folders
- **Favorites** and **recent songs**

### Account & sync
- Sign in with **Apple**, **Google**, or email/password (Supabase Auth), including password reset
- Cloud sync for favorites, custom categories, consent, and carol libraries
- Profile editing, **download my information** (zip export, rate-limited), and account deactivation

### Privacy
- First-launch **DPDP** notice (English / Kannada) for Privacy Policy and Terms
- **Privacy Centre** — review consent, toggle optional analytics and push, withdraw consent, and request rights
- In-app Privacy Policy and Terms of Use

### App experience
- **Christmas mode** — festive portal, snowfall overlay, and seasonal tab layout
- **Liquid Glass** navigation bars, tab bar, and list cards (iOS 26)
- Light / Dark / AMOLED themes with accent color picker
- Optional tactile haptics, in-app changelog, and announcement dialogs
- Force-update gate, in-app lyric/audio issue reporting via Jira, optional PostHog analytics
- Optional Chromecast (remote-config gated; Google Cast SDK is not bundled via SPM)
- Push notifications (OneSignal), with an in-app opt-out in Privacy Centre
- Optional **Support the Project** donations when enabled in remote config

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
| `JiraURL` / `JiraEmail` / `JiraAPIToken` | In-app lyric / audio issue reporting |
| `JiraProjectKey` / `JiraIssueType` | Jira project and issue type (defaults: `CSI` / `Task`) |
| `PostHogAPIKey` / `PostHogHost` | Analytics (optional) |

### 3. Open in Xcode

```bash
open "CSI Hymns App.xcodeproj"
```

Select the **CSI Hymns App** scheme, pick a simulator or device, and run (**⌘R**).

Swift Package Manager resolves dependencies automatically:

- [supabase-swift](https://github.com/supabase-community/supabase-swift) 2.5.1+
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
├── changelog.json             # In-app welcome changelog
├── Legal/                     # In-app Privacy Policy & Terms
├── Models/                    # Hymn, CarolChurch, CarolSong, CarolPdf, …
├── Services/                  # Supabase, audio, MIDI, themes, carols, sync, …
├── Views/
│   ├── HomeSelectorView.swift # CSI / M.T. / liturgies home
│   ├── HymnsListView.swift    # Hymn, keerthane, and M.T. lists
│   ├── HymnDetailView.swift   # Lyrics reader + audio / MIDI
│   ├── Auth/                  # Sign in / sign up
│   ├── Onboarding/            # First-run tour + DPDP consent
│   ├── Christmas/             # Church-first community carols
│   ├── Service/               # Order of Service + PDF reader
│   ├── Settings/              # Profile, Privacy Centre, themes, tickets
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

Remote flags (Christmas mode, force-update, M.T. visibility, payments, Cast, and similar) live in Supabase `app_config`. Schema is applied in the **Supabase Dashboard** (not versioned in this repo). See [`supabase/README.md`](supabase/README.md) for RLS rules, storage bucket (`carol-pdfs`), and admin notes.

Kotlin/Android parity spec: [`supabase/CAROL_ANDROID_PARITY_BRIEF.md`](supabase/CAROL_ANDROID_PARITY_BRIEF.md)

---

## Data sources

| Content | Source |
|---------|--------|
| Hymns / keerthanes / M.T. hymns (bundled) | `Assets.xcassets/*_data.dataset` |
| Hymns / keerthanes / M.T. hymns (updates) | [csi-hymns-vault](https://github.com/Reynold29/csi-hymns-vault) on GitHub |
| MIDI accompaniments | [midi-vault](https://github.com/Reynold29/midi-vault) |
| OGG audio fallback | [midi-files](https://github.com/reynold29/midi-files) |
| Carols (legacy seed) | Same vault + Supabase |
| Order of Service PDFs | Remote URLs with on-device cache |

---

## Related apps

- **[CSI Hymns Book on the App Store](https://apps.apple.com/in/app/csi-hymns-book/id6759966582)**
- **[Worship Companion](https://apps.apple.com/in/app/worship-companion/id6759990066)** — praise & worship lyrics companion app (linked from Settings)

---

## Privacy

Open **Settings → Privacy Centre** for the in-app Privacy Policy, Terms of Use, consent record, and rights requests (aligned with India’s DPDP Act, 2023).

Public policy page: [CSI Hymns Privacy Policy](https://sites.google.com/view/csi-hymns-privacy-policy/home)

---

## Contributing

This repository is maintained by the CSI Hymns Book team. For lyric corrections or bugs, use **Report an Issue** inside the app (Settings) or open a GitHub issue.

---

## License

Copyright © CSI Hymns Book. All rights reserved.
