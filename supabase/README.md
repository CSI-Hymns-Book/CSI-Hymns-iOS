# Carol Churches — Supabase Setup

Shared backend for **iOS (Swift)** and **Android (Kotlin native)**.

**Android parity spec:** `CAROL_ANDROID_PARITY_BRIEF.md` (Kotlin / native Android)

Schema is managed in the **Supabase Dashboard** (SQL Editor) — not stored in this iOS repo.

## Verify in Dashboard

Confirm tables exist: `carol_churches`, `carol_songs`, `carol_pdfs`

## What it creates

| Table | Purpose |
|-------|---------|
| `carol_churches` | Parish/church container (created first) |
| `carol_songs` | Lyrics/text songs inside a church |
| `carol_pdfs` | PDF sheets inside a church |

Legacy `christmas_carols` rows are migrated automatically (best-effort).

## Permissions (RLS)

| Action | Who |
|--------|-----|
| **Read** churches/songs/PDFs | Everyone (anon + signed-in) |
| **Create church** | Signed-in user (becomes owner) |
| **Add song/PDF** | Any signed-in user (inside existing church) |
| **Delete church** | Church creator **or** app admin |
| **Delete song/PDF** | Item uploader **or** app admin |
| **Update** | Same as delete |

Admin emails (JWT email claim):

- reynoldclare29022902@gmail.com
- reynoldclare02@gmail.com
- reyziecrafts@gmail.com
- reynold.clare29022902@gmail.com

## Storage (`carol-pdfs` bucket)

- Public read
- Authenticated upload/update
- Delete: file owner or admin

## App flow

1. **Community Carols** → **+** → **Create Church**
2. Open church → **Songs** tab (lyrics, hymn-style cards) or **PDFs** tab (opens PDF directly)
3. **+** menu inside church → Add Song **or** Add PDF
