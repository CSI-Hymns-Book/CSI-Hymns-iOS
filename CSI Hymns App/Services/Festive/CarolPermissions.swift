import Foundation

/// Who may change what in the Community Carols library. Pure logic, checked in
/// `scripts/festive-logic-check`, and mirrored by the Android app and the database policies.
enum CarolPermissions {
    /// Deleting a church, or any song or PDF in it: only the person who added the church, or an
    /// admin. A song's own uploader may NOT delete it unless they also own the church.
    static func canDelete(userId: UUID?, churchOwnerId: UUID?, isAdmin: Bool) -> Bool {
        if isAdmin { return true }
        guard let userId, let churchOwnerId else { return false }
        return userId == churchOwnerId
    }

    /// Editing a song: the church's owner, the song's own uploader, or an admin.
    static func canEditSong(userId: UUID?, churchOwnerId: UUID?, songOwnerId: UUID?, isAdmin: Bool) -> Bool {
        if canDelete(userId: userId, churchOwnerId: churchOwnerId, isAdmin: isAdmin) { return true }
        guard let userId, let songOwnerId else { return false }
        return userId == songOwnerId
    }
}
