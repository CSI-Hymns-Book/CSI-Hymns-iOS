import Foundation

// Run with: scripts/check-freeshow-formatter.sh
// Mirrors the Android FreeShowFormatterTest cases, plus the verse-to-English pairing check.

var failures = 0
func check(_ condition: Bool, _ message: String) {
    if condition { print("ok    \(message)") } else { failures += 1; print("FAIL  \(message)") }
}

let kannada = """
ಆಚರಿಸು ವಿಶ್ರಾಂತಿದಿನವನ್ನು - ಬಹು ಭಕ್ತಿಭಾವದಿಂ
ದಾಚಾರಿಸು ವಿಶ್ರಾಂತಿದಿನವನ್ನು
\t
1. ಕಾರುಣ್ಯ ಮೂರ್ತಿಯು ಧಾರಿಣಿಯನೆಲ್ಲಾ
ಆರೇ ದಿನಗಲ್ಲಿ ಪೂರಯಿಸಿ
ಮಾರಣೆ ದಿನದಲ್ಲಿ ತೀರಿಕೆಯಾಗಿಯೇ
ಸಾರಿಪೇಳಿದ ಮಾತ ಮೀರದೆ ನಿತ್ಯವೂ
\t
2.. ಗುರುರಾಯನೀ ಹೊತ್ತು ಮರಣದ ಕೊಂಡಿಯಂ
ಮುರಿದುಬಿಟ್ಟನು ಬಹು ಕರುಣೆಯಿಂದ
ಪರಿಶುದ್ಧ ಆತ್ಮನು ಭಕ್ತರ ಮೇಲೈದಿ
ವರಗಳ ಪಾಲಿಸಿ ಹರಸಿದ ಸುದಿನವ

--END--
"""

let english = """
Aacharisu Vishraantidinavannu - Bahu Bhaktibhaavadim
Daacharisu Vishraantidinavannu
\t
1. Kaarunya moortiyu Dhaariniyanellaa
Aare Dinagalli Poorayisi
Maarane Dinadalli Teerikeyaagiye
Saaripelida Maata Meerade Nityavu
\t
2.. Gururaayanee Hottu Maranada Kondiyam
Muridubittanu Bahu Karuneyinda
Parishudda Aatmanu Bhaktara Melaidi
Varagala Paalisi Harasida Sudinava.

...End...
"""

func slides(_ mode: LyricsLanguageMode) -> [PresentationSlide] {
    FreeShowFormatter.parseSlides(number: 214, title: "Aacharisu Vishraantidinavannu", isKeerthane: true,
                                  kannadaLyrics: kannada, englishLyrics: english, mode: mode)
}

// Kannada mode: chorus then numbered verses, end markers removed.
let base = slides(.kannada)
check(base.map { $0.group } == ["Chorus", "Verse 1", "Verse 2"], "keerthane splits into Chorus, Verse 1, Verse 2")
check(base[0].content.contains("ಆಚರಿಸು"), "chorus text is kept")
check(base[1].content.contains("ಕಾರುಣ್ಯ ಮೂರ್ತಿಯು"), "verse 1 text is kept")
check(base[2].content.contains("ಗುರುರಾಯನೀ ಹೊತ್ತು"), "verse 2 text is kept")
check(!base.contains { $0.content.contains("--END--") || $0.content.contains("...End...") }, "end markers are removed")

// Bilingual mode: each verse pairs with its own English stanza (the bug the Android review found).
let both = slides(.bilingual)
check(both.map { $0.group } == ["Chorus", "Verse 1", "Verse 2"], "bilingual keeps the same groups")
check(both[0].content.contains("ಆಚರಿಸು") && both[0].content.contains("Aacharisu"), "chorus pairs with the English chorus")
check(both[1].content.contains("ಕಾರುಣ್ಯ") && both[1].content.contains("Kaarunya") && !both[1].content.contains("Aacharisu"), "verse 1 pairs with English verse 1")
check(both[2].content.contains("ಗುರುರಾಯ") && both[2].content.contains("Gururaayanee") && !both[2].content.contains("Kaarunya"), "verse 2 pairs with English verse 2")

// English-only and a hymn (no keerthane layout).
check(slides(.english)[1].content.hasPrefix("1. Kaarunya"), "english mode uses the English stanzas")
let hymn = FreeShowFormatter.parseSlides(number: 5, title: "T", isKeerthane: false, kannadaLyrics: "1. ಒಂದು\nಎರಡು\n\n2. ಮೂರು", englishLyrics: "1. one\ntwo\n\n2. three", mode: .bilingual)
check(hymn.map { $0.group } == ["Verse 1", "Verse 2"] && hymn[1].content.contains("three"), "hymn verses pair in bilingual mode")

// Quick Lyrics text.
let quick = FreeShowFormatter.formatQuickLyricsText(number: 214, title: "Aacharisu Vishraantidinavannu", isKeerthane: true, slides: base)
check(quick.hasPrefix("Title=CSI Keerthane 214 - Aacharisu Vishraantidinavannu"), "quick lyrics title line")
check(quick.contains("Author=CSI Hymns Book App") && quick.contains("Copyright=By CSI Hymns Book App"), "quick lyrics author and copyright")
check(quick.contains("[Chorus]") && quick.contains("[Verse 1]") && quick.contains("[Verse 2]"), "quick lyrics group headers")

// Show data for FreeShow.
let show = FreeShowFormatter.createShow(number: 214, title: "Aacharisu Vishraantidinavannu", isKeerthane: true, slides: base)
check(show.id.count == 11, "show id is 11 characters")
check((show.data["name"] as? String) == "Keerthane 214 - Aacharisu Vishraantidinavannu", "show name")
let showSlides = show.data["slides"] as? [String: Any] ?? [:]
check(showSlides.count == base.count, "one FreeShow slide per presentation slide")
let firstItems = (showSlides.values.first as? [String: Any])?["items"] as? [[String: Any]] ?? []
check(firstItems.count == 2 && (firstItems[1]["decoration"] as? Bool) == true, "plain show has lyrics plus a credit decoration")
let chorusSlide = showSlides.values.compactMap { $0 as? [String: Any] }.first { ($0["group"] as? String) == "Chorus" }
check((chorusSlide?["color"] as? String) == "#e0a300", "chorus slide is coloured")
check(FreeShowFormatter.jsonString(show.data, pretty: false) != nil, "show data is valid JSON")

// Project data and file.
let project = FreeShowFormatter.projectData(number: 214, title: "Aacharisu Vishraantidinavannu", isKeerthane: true, slides: base)
check(project["project"] != nil && project["shows"] != nil && (project["files"] as? [String]) == ["app_icon.png"], "project has project, shows and files")
let projectShows = project["shows"] as? [String: Any] ?? [:]
let projectItems = ((projectShows.values.first as? [String: Any])?["slides"] as? [String: Any])?.values.first.flatMap { ($0 as? [String: Any])?["items"] as? [[String: Any]] } ?? []
check(projectItems.count == 4 && (projectItems[2]["type"] as? String) == "media", "project slides carry the logo media item")

let png = Data([0x89, 0x50, 0x4E, 0x47])
if let file = FreeShowFormatter.projectFile(number: 214, title: "Aacharisu Vishraantidinavannu", isKeerthane: true, slides: base, logoPNG: png) {
    check(file.fileName == "Keerthane_214_Aacharisu_Vishraantidinavannu.project", "project file name")
    check(file.data.starts(with: [0x50, 0x4B, 0x03, 0x04]), "project file is a ZIP")
    let text = String(decoding: file.data, as: UTF8.self)
    check(text.contains("data.json") && text.contains("project.json") && text.contains("app_icon.png"), "project ZIP lists data.json, project.json and app_icon.png")
} else {
    check(false, "project file is created")
}
let beam = FreeShowFormatter.showForBeam(number: 214, title: "T", isKeerthane: true, slides: base, logoDataURI: "data:image/png;base64,AAAA/BBB")
check(beam?.json.contains("data:image/png;base64,AAAA/BBB") == true, "beam data embeds the logo without escaping slashes")

print(failures == 0 ? "\nall passed" : "\n\(failures) failed")
exit(failures == 0 ? 0 : 1)
