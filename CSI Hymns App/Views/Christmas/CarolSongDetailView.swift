import SwiftUI

/// Lyrics reader for a single `CarolSong` (the swipeable `CarolReaderView` with one page).
public struct CarolSongDetailView: View {
    let song: CarolSong

    public init(song: CarolSong) { self.song = song }

    public var body: some View {
        CarolReaderView(songs: [song], startId: song.id, churchName: "")
    }
}
