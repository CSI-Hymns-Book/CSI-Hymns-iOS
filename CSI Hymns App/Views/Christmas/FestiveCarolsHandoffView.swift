import SwiftUI

/// The Carols book opened by a partner app (YKC One): the church list, or straight into the default
/// church if one is set. Back inside a church returns to the list; the close button leaves.
struct FestiveCarolsHandoffView: View {
    let onClose: () -> Void
    @State private var path = NavigationPath()
    @State private var service = ChristmasCarolsService.shared
    private let handoff = CarolHandoff.shared
    private let store = CarolReaderStore.shared

    var body: some View {
        NavigationStack(path: $path) {
            ChristmasCarolsListView(onClose: onClose)
                .navigationDestination(for: UUID.self) { id in
                    if let church = service.churches.first(where: { $0.id == id }) { ChurchDetailView(church: church) }
                }
        }
        .tint(FestivePalette.night.gold)
        .task(id: "\(handoff.openRequest)-\(service.churches.count)-\(service.isLoading)-\(store.defaultChurchId ?? "")") {
            guard handoff.selectionPending else { return }
            if service.churches.isEmpty && service.isLoading { return } // wait for the list to load
            path = NavigationPath()
            if let id = store.defaultChurchId, let church = service.churches.first(where: { $0.id.uuidString == id }) {
                path.append(church.id)
            }
            handoff.selectionPending = false
        }
    }
}
