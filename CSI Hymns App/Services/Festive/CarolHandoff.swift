import Foundation
import Observation
import UIKit

/// A partner app's request to open the Carols book, and who the "Back to ..." button returns to.
/// Held in memory only and dropped once handled; nothing is saved.
@MainActor
@Observable
final class CarolHandoff {
    static let shared = CarolHandoff()

    /// The partner to return to, or nil when Carols was not opened by an allowlisted partner.
    private(set) var caller: CarolInterop.Caller?
    /// Goes up each time an allowlisted partner asks to open Carols.
    private(set) var openRequest = 0
    /// True until the Carols screen has chosen between the default church and the church list.
    var selectionPending = false

    private init() {}

    /// Handles `csihymns://carols?from=<bundleId>`. Unknown or unlisted callers are ignored.
    @discardableResult
    func handle(url: URL) -> Bool {
        guard let caller = CarolInterop.resolveCaller(url: url) else { return false }
        self.caller = caller
        selectionPending = true
        openRequest += 1
        return true
    }

    /// Opens the partner app (only if it is still allowlisted) and clears the button.
    func returnToCaller() {
        guard let caller, CarolInterop.canReturn(to: caller) else { self.caller = nil; return }
        self.caller = nil
        UIApplication.shared.open(caller.returnURL)
    }
}

/// The reader's own carol choices, kept on this device: favourites, recents, text size and the
/// default church that partner apps open straight to.
@MainActor
@Observable
final class CarolReaderStore {
    static let shared = CarolReaderStore()

    private enum Key {
        static let favourites = "carol_favourite_ids", recents = "carol_recent_ids"
        static let textScale = "carol_text_scale", defaultChurch = "carol_default_church_id"
    }

    private(set) var favourites: Set<String>
    private(set) var recents: [String]
    private(set) var textScale: Double
    private(set) var defaultChurchId: String?

    private init() {
        let d = UserDefaults.standard
        favourites = Set(d.stringArray(forKey: Key.favourites) ?? [])
        recents = d.stringArray(forKey: Key.recents) ?? []
        let saved = d.object(forKey: Key.textScale) as? Double ?? CarolTextScale.defaultScale
        textScale = CarolTextScale.clamp(saved)
        defaultChurchId = d.string(forKey: Key.defaultChurch)
    }

    func toggleFavourite(_ id: String) {
        if favourites.contains(id) { favourites.remove(id) } else { favourites.insert(id) }
        UserDefaults.standard.set(Array(favourites), forKey: Key.favourites)
    }

    func markViewed(_ id: String) {
        recents = CarolRecents.push(recents, id)
        UserDefaults.standard.set(recents, forKey: Key.recents)
    }

    func setTextScale(_ scale: Double) {
        textScale = CarolTextScale.clamp(scale)
        UserDefaults.standard.set(textScale, forKey: Key.textScale)
    }

    /// Makes the church the default, or clears the default if it already is.
    func toggleDefaultChurch(_ id: String) {
        defaultChurchId = defaultChurchId == id ? nil : id
        if let defaultChurchId { UserDefaults.standard.set(defaultChurchId, forKey: Key.defaultChurch) }
        else { UserDefaults.standard.removeObject(forKey: Key.defaultChurch) }
    }
}
