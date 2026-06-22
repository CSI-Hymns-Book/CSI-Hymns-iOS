import SwiftUI

/// Lyrics reader wrapper for `CarolSong`.
public struct CarolSongDetailView: View {
    let song: CarolSong
    
    public init(song: CarolSong) {
        self.song = song
    }
    
    public var body: some View {
        CarolDetailView(
            carol: ChristmasCarol(
                id: song.id.uuidString.lowercased(),
                title: song.title,
                churchName: "",
                lyrics: song.lyrics,
                scale: song.scale,
                songNumber: song.songNumber,
                createdByUserId: song.createdByUserId.uuidString.lowercased(),
                createdAt: song.createdAt,
                updatedAt: song.updatedAt
            )
        )
    }
}
