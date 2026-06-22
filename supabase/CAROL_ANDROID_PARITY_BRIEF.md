# Community Carols — Kotlin / Native Android Parity Brief

Use this spec to update the **native Kotlin Android** app to match the iOS **church-first** carols model.

**Backend schema (shared, applied in Supabase Dashboard):**  
Tables `carol_churches`, `carol_songs`, `carol_pdfs` + RLS + `carol-pdfs` storage bucket.

**iOS reference (already shipped):** see section 12.

---

## 1. Concept change (old → new)

| Old (flat model) | New (iOS + target Android) |
|------------------|----------------------------|
| Single table `christmas_carols` | Three tables: `carol_churches`, `carol_songs`, `carol_pdfs` |
| One upload: church name + lyrics + optional PDF in one form | **Create church first**, then add **Song** OR **PDF** inside it |
| Grouped by `church_name` string on each row | Church is a real row with `id`; songs/PDFs use `church_id` FK |
| Delete: admin or row uploader | Delete **church**: owner or admin. Delete **song/PDF**: **that item’s uploader** or admin only |

---

## 2. Supabase schema

### `carol_churches`
| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `name` | text | Unique case-insensitive (`lower(trim(name))`) |
| `description` | text nullable | Optional |
| `created_by_user_id` | uuid → auth.users | Church owner |
| `created_at` | timestamptz | |
| `updated_at` | timestamptz nullable | Auto-updated on change |

### `carol_songs` (lyrics / hymn-style text)
| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `church_id` | uuid FK → carol_churches | CASCADE delete with church |
| `title` | text | |
| `song_number` | text nullable | Sort/search |
| `lyrics` | text | Required; bilingual separator: `\n\n---\n\nEnglish Translation:\n` |
| `scale` | text | Default `'C Major'` |
| `created_by_user_id` | uuid | Song uploader |
| `created_at` / `updated_at` | timestamptz | |

### `carol_pdfs` (sheet music only)
| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | Same uuid used as storage key `{id}.pdf` |
| `church_id` | uuid FK | |
| `title` | text | |
| `song_number` | text nullable | |
| `pdf_url` | text | Public URL from `carol-pdfs` bucket |
| `created_by_user_id` | uuid | PDF uploader |
| `created_at` / `updated_at` | timestamptz | |

### Legacy `christmas_carols`
- Still **readable** by all (migration copies into new tables).
- **Writes admin-only** after migration (optional).
- Updated Kotlin app must **stop inserting** into `christmas_carols`.

---

## 3. RLS / permissions (Supabase + mirror in UI)

Admin emails (JWT `email` claim, **not** user_metadata):
- reynoldclare29022902@gmail.com
- reynoldclare02@gmail.com
- reyziecrafts@gmail.com
- reynold.clare29022902@gmail.com

Function: `app_private.is_carol_admin()`

| Action | Policy |
|--------|--------|
| SELECT | Public (anon + authenticated) |
| INSERT church | Authenticated; `created_by_user_id = auth.uid()` |
| INSERT song/pdf | Authenticated; `created_by_user_id = auth.uid()`; church exists |
| UPDATE | Admin **OR** row owner |
| DELETE church | Admin **OR** church owner |
| DELETE song/pdf | Admin **OR** **item uploader only** |

**Important:** Church owner **cannot** delete another user’s song/PDF in the same church.

### Storage `carol-pdfs`
- Public read · Authenticated upload/update · Delete: owner or admin  
- Path: `{pdf_id}.pdf` (lowercase uuid)

---

## 4. App UX (match iOS)

```
CommunityCarolsScreen
  ├── Search (churches, song titles, PDF titles)
  ├── FAB (+) → CreateChurchScreen / BottomSheet (auth required)
  └── Tap church → ChurchDetailScreen
        ├── TabLayout / Segmented: [ Songs | PDFs ]
        ├── Songs tab → LazyColumn hymn-style rows → CarolSongDetailScreen
        ├── PDFs tab → list → tap → PdfViewerActivity/Fragment (remote URL)
        └── Overflow (+): Add Song | Add PDF (auth required)
```

| Screen | Purpose |
|--------|---------|
| `CreateChurchScreen` | name (required), description (optional) |
| `AddCarolSongScreen` | title, song_number?, Kannada lyrics, English optional |
| `AddCarolPdfScreen` | title, song_number?, PDF picker (Storage Access Framework) |
| `CarolSongDetailScreen` | Existing lyrics reader (reuse hymn detail patterns) |
| `PdfViewerScreen` | Download/cache remote `pdf_url` then render (PdfRenderer or library) |

Delete: swipe-to-dismiss or long-press menu — only show if `canDelete*()` is true.

---

## 5. Suggested Kotlin package layout

```
com.reyzie.hymns.carols/
├── data/
│   ├── model/
│   │   ├── CarolChurch.kt
│   │   ├── CarolSong.kt
│   │   └── CarolPdf.kt
│   ├── remote/
│   │   └── CarolsSupabaseDataSource.kt
│   ├── local/
│   │   ├── CarolsDao.kt              // Room
│   │   ├── CarolChurchEntity.kt
│   │   ├── CarolSongEntity.kt
│   │   └── CarolPdfEntity.kt
│   └── repository/
│       └── CarolsRepository.kt
├── domain/
│   └── CarolsPermissions.kt          // isAdmin, canDeleteChurch/Song/Pdf
└── ui/
    ├── list/
    │   ├── CommunityCarolsScreen.kt
    │   └── CommunityCarolsViewModel.kt
    ├── church/
    │   ├── ChurchDetailScreen.kt
    │   └── ChurchDetailViewModel.kt
    ├── create/
    │   ├── CreateChurchScreen.kt
    │   ├── AddCarolSongScreen.kt
    │   └── AddCarolPdfScreen.kt
    └── detail/
        ├── CarolSongDetailScreen.kt
        └── PdfViewerScreen.kt
```

Adapt names to your existing project structure — the **responsibilities** matter more than exact paths.

---

## 6. Kotlin data models

Use `@Serializable` (kotlinx.serialization) or your existing JSON mapper.

```kotlin
@Serializable
data class CarolChurch(
    val id: String,
    val name: String,
    val description: String? = null,
    @SerialName("created_by_user_id") val createdByUserId: String,
    @SerialName("created_at") val createdAt: String,
    @SerialName("updated_at") val updatedAt: String? = null,
)

@Serializable
data class CarolSong(
    val id: String,
    @SerialName("church_id") val churchId: String,
    val title: String,
    @SerialName("song_number") val songNumber: String? = null,
    val lyrics: String,
    val scale: String = "C Major",
    @SerialName("created_by_user_id") val createdByUserId: String,
    @SerialName("created_at") val createdAt: String,
    @SerialName("updated_at") val updatedAt: String? = null,
)

@Serializable
data class CarolPdf(
    val id: String,
    @SerialName("church_id") val churchId: String,
    val title: String,
    @SerialName("song_number") val songNumber: String? = null,
    @SerialName("pdf_url") val pdfUrl: String,
    @SerialName("created_by_user_id") val createdByUserId: String,
    @SerialName("created_at") val createdAt: String,
    @SerialName("updated_at") val updatedAt: String? = null,
)
```

---

## 7. Repository API (Kotlin)

```kotlin
interface CarolsRepository {
    val churches: Flow<List<CarolChurch>>
    val songs: Flow<List<CarolSong>>
    val pdfs: Flow<List<CarolPdf>>

    suspend fun refresh(force: Boolean = false)

    suspend fun createChurch(name: String, description: String? = null): CarolChurch
    suspend fun addSong(
        churchId: String,
        title: String,
        songNumber: String?,
        lyricsKannada: String,
        lyricsEnglish: String?,
        scale: String = "C Major",
    ): CarolSong

    suspend fun addPdf(
        churchId: String,
        title: String,
        songNumber: String?,
        pdfBytes: ByteArray,
    ): CarolPdf

    suspend fun deleteChurch(id: String)
    suspend fun deleteSong(id: String)
    suspend fun deletePdf(id: String)

    fun songsForChurch(churchId: String): List<CarolSong>
    fun pdfsForChurch(churchId: String): List<CarolPdf>
}
```

### Permissions helper

```kotlin
object CarolsPermissions {
    private val ADMIN_EMAILS = setOf(
        "reynoldclare29022902@gmail.com",
        "reynoldclare02@gmail.com",
        "reyziecrafts@gmail.com",
        "reynold.clare29022902@gmail.com",
    )

    fun isAdmin(userEmail: String?): Boolean =
        userEmail?.lowercase() in ADMIN_EMAILS

    fun canDeleteChurch(church: CarolChurch, userId: String?, userEmail: String?): Boolean =
        isAdmin(userEmail) || church.createdByUserId == userId

    fun canDeleteSong(song: CarolSong, userId: String?, userEmail: String?): Boolean =
        isAdmin(userEmail) || song.createdByUserId == userId

    fun canDeletePdf(pdf: CarolPdf, userId: String?, userEmail: String?): Boolean =
        isAdmin(userEmail) || pdf.createdByUserId == userId
}
```

UI should hide delete actions when these return `false`. RLS is the real enforcement on the server.

---

## 8. Supabase Kotlin SDK calls

Dependency (if not already): `io.github.jan-tennert.supabase:postgrest-kt`, `storage-kt`, `auth-kt`

```kotlin
// Fetch (public — works without session too)
supabase.from("carol_churches")
    .select { order("created_at", Order.DESCENDING) }
    .decodeList<CarolChurch>()

supabase.from("carol_songs")
    .select { order("created_at", Order.DESCENDING) }
    .decodeList<CarolSong>()

supabase.from("carol_pdfs")
    .select { order("created_at", Order.DESCENDING) }
    .decodeList<CarolPdf>()

// Create church (requires auth session)
supabase.from("carol_churches").insert(
    CarolChurch(
        id = UUID.randomUUID().toString(),
        name = name.trim(),
        description = description?.trim(),
        createdByUserId = session.user.id,
        createdAt = Instant.now().toString(),
    )
)

// Add song
supabase.from("carol_songs").insert(
    CarolSong(
        id = UUID.randomUUID().toString(),
        churchId = churchId,
        title = title,
        songNumber = songNumber,
        lyrics = buildBilingualLyrics(kannada, english),
        createdByUserId = session.user.id,
        createdAt = Instant.now().toString(),
    )
)

// Upload PDF then insert row
val pdfId = UUID.randomUUID().toString()
supabase.storage.from("carol-pdfs").upload(
    path = "$pdfId.pdf",
    data = pdfBytes,
    upsert = true,
)
val publicUrl = supabase.storage.from("carol-pdfs").publicUrl("$pdfId.pdf")

supabase.from("carol_pdfs").insert(
    CarolPdf(
        id = pdfId,
        churchId = churchId,
        title = title,
        pdfUrl = publicUrl,
        createdByUserId = session.user.id,
        createdAt = Instant.now().toString(),
    )
)

// Delete (RLS enforces ownership)
supabase.from("carol_songs").delete { filter { eq("id", songId) } }
```

### Bilingual lyrics helper (same as iOS / legacy app)

```kotlin
fun buildBilingualLyrics(kannada: String, english: String?): String {
    val en = english?.trim().orEmpty()
    return if (en.isEmpty()) kannada.trim()
    else "${kannada.trim()}\n\n---\n\nEnglish Translation:\n$en"
}
```

---

## 9. PDF viewing on Android

Remote `pdf_url` cannot be loaded directly by `PdfRenderer` — download first:

1. `GET pdf_url` → cache file in `context.cacheDir/pdf_cache/{hash}.pdf`
2. Open with `PdfRenderer` / Android PdfViewer library / WebView fallback
3. Reuse cache on next open (same pattern as iOS `RemotePDFLoader`)

---

## 10. Offline / Room cache

| Entity | Room table | Notes |
|--------|------------|-------|
| Churches | `carol_churches` | Upsert on successful sync |
| Songs | `carol_songs` | FK `church_id` |
| PDFs | `carol_pdfs` | Store `pdf_url`; optional local file path after download |

Rules:
- On sync success → upsert all three tables  
- On sync failure → read Room  
- Optional: merge legacy `christmas_carols` + GitHub JSON until fully migrated  
- **Never** clear cache when remote returns empty  

---

## 11. JSON column mapping

| Kotlin property | Supabase column |
|-----------------|-----------------|
| `churchId` | `church_id` |
| `songNumber` | `song_number` |
| `createdByUserId` | `created_by_user_id` |
| `createdAt` | `created_at` |
| `updatedAt` | `updated_at` |
| `pdfUrl` | `pdf_url` |

Legacy `christmas_carols` used column `pdf` — migration reads both; **new writes** use `carol_pdfs.pdf_url`.

---

## 12. iOS reference (Swift — behaviour to mirror)

| Area | Path |
|------|------|
| Supabase schema | Applied in Supabase Dashboard (not in this repo) |
| Repository | `CSI Hymns App/Services/ChristmasCarolsService.swift` |
| Models | `Models/CarolChurch.swift`, `CarolSong.swift`, `CarolPdf.swift` |
| Church list | `Views/Christmas/ChristmasCarolsListView.swift` |
| Church detail | `Views/Christmas/ChurchDetailView.swift` |
| Create church | `Views/Christmas/AddChurchFormView.swift` |
| Add song | `Views/Christmas/AddCarolSongFormView.swift` |
| Add PDF | `Views/Christmas/AddCarolPdfFormView.swift` |
| Song reader | `Views/Christmas/CarolSongDetailView.swift` |
| PDF reader | `Views/Service/PDFDocumentReaderView.swift` |

---

## 13. Rollout order

1. Run SQL migration on Supabase (once)  
2. Ship Kotlin Android with new tables  
3. iOS already uses new model  
4. Deprecate `christmas_carols` writes from all clients  
5. Later: drop legacy table when safe  

---

## 14. QA checklist (Kotlin Android)

- [ ] Guest browses churches / songs / PDFs  
- [ ] Guest cannot create or upload  
- [ ] Create church → visible on iOS after sync  
- [ ] Add song → lyrics screen works  
- [ ] Add PDF → viewer loads Supabase public URL  
- [ ] User A cannot delete User B’s song in same church  
- [ ] Church owner can delete own church (cascade)  
- [ ] Admin can delete anything  
- [ ] Swipe refresh syncs  
- [ ] Offline: Room cache shows last sync  

---

## 15. What to remove / replace in old Kotlin code

| Old pattern | Replace with |
|-------------|--------------|
| Single `ChristmasCarol` model with `churchName` + optional `pdf` | `CarolChurch` + `CarolSong` + `CarolPdf` |
| One “Add Carol” dialog (church + lyrics + PDF together) | Three flows: Create Church, Add Song, Add PDF |
| `INSERT INTO christmas_carols` | Inserts into `carol_churches` / `carol_songs` / `carol_pdfs` |
| Group list by `church_name` string | Query `carol_churches`, join/filter by `church_id` |
| PDF attached to lyrics row | PDFs live only in PDFs tab (`carol_pdfs`) |
