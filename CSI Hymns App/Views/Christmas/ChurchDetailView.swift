import SwiftUI

enum ChurchContentTab: String, CaseIterable, Identifiable {
    case songs = "Songs"
    case pdfs = "PDFs"
    var id: String { rawValue }
}

/// Church hub — browse/add songs (lyrics) or PDFs separately.
public struct ChurchDetailView: View {
    let church: CarolChurch
    
    @State private var service = ChristmasCarolsService.shared
    @State private var selectedTab: ChurchContentTab = .songs
    @State private var isShowingAddSong = false
    @State private var isShowingAddPdf = false
    @State private var isShowingDeleteConfirm = false
    @State private var toastMessage: String?
    @State private var selectedPdf: CarolPdf?
    
    public init(church: CarolChurch) {
        self.church = church
    }
    
    private var churchSongs: [CarolSong] { service.songs(for: church.id) }
    private var churchPdfs: [CarolPdf] { service.pdfs(for: church.id) }
    private var legacyItems: [ChristmasCarol] { service.legacyCarols(forChurchName: church.name) }
    
    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0D1B2A"), Color(hex: "0B2516")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Picker("Content", selection: $selectedTab) {
                    ForEach(ChurchContentTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                if selectedTab == .songs {
                    songsContent
                } else {
                    pdfsContent
                }
            }
        }
        .navigationTitle(church.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if SupabaseService.instance.isAuthenticated {
                        Button {
                            isShowingAddSong = true
                        } label: {
                            Label("Add Song (Lyrics)", systemImage: "text.alignleft")
                        }
                        Button {
                            isShowingAddPdf = true
                        } label: {
                            Label("Add PDF Sheet", systemImage: "doc.richtext")
                        }
                    }
                    if service.canDeleteChurch(church) {
                        Button(role: .destructive) {
                            isShowingDeleteConfirm = true
                        } label: {
                            Label("Delete Church", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(.white)
                }
            }
        }
        .sheet(isPresented: $isShowingAddSong) {
            AddCarolSongFormView(church: church)
        }
        .sheet(isPresented: $isShowingAddPdf) {
            AddCarolPdfFormView(church: church)
        }
        .sheet(item: $selectedPdf) { pdf in
            NavigationStack {
                PDFDocumentReaderView(documentUrlString: pdf.pdfUrl, documentTitle: pdf.title)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") { selectedPdf = nil }.foregroundStyle(.white)
                        }
                    }
            }
        }
        .alert("Delete Church?", isPresented: $isShowingDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    do {
                        try await service.deleteChurch(id: church.id)
                        toastMessage = "Church deleted."
                    } catch {
                        toastMessage = error.localizedDescription
                    }
                }
            }
        } message: {
            Text("This removes the church and all songs/PDFs inside it. Only you or an admin can do this.")
        }
        .appToast(message: $toastMessage, isError: toastMessage?.contains("only") == true || toastMessage?.contains("Couldn't") == true)
    }
    
    private var songsContent: some View {
        Group {
            if churchSongs.isEmpty && legacyItems.filter({ $0.hasLyrics }).isEmpty {
                emptyState(message: "No songs yet.", actionTitle: "Add Song") {
                    if SupabaseService.instance.isAuthenticated { isShowingAddSong = true }
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(churchSongs) { song in
                            songRow(song)
                        }
                        ForEach(legacyItems.filter { $0.hasLyrics && !$0.hasPdf }) { legacy in
                            NavigationLink(destination: CarolDetailView(carol: legacy)) {
                                legacySongRow(legacy)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
    }
    
    private var pdfsContent: some View {
        Group {
            if churchPdfs.isEmpty && legacyItems.filter(\.hasPdf).isEmpty {
                emptyState(message: "No PDF sheets yet.", actionTitle: "Add PDF") {
                    if SupabaseService.instance.isAuthenticated { isShowingAddPdf = true }
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(churchPdfs) { pdf in
                            pdfRow(pdf)
                        }
                        ForEach(legacyItems.filter(\.hasPdf)) { legacy in
                            if let url = legacy.pdfUrl {
                                Button {
                                    selectedPdf = CarolPdf(
                                        id: UUID(uuidString: legacy.id) ?? UUID(),
                                        churchId: church.id,
                                        title: legacy.title,
                                        songNumber: legacy.songNumber,
                                        pdfUrl: url,
                                        createdByUserId: UUID(uuidString: legacy.createdByUserId ?? "") ?? UUID()
                                    )
                                } label: {
                                    legacyPdfRow(legacy)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
    }
    
    private func songRow(_ song: CarolSong) -> some View {
        NavigationLink(destination: CarolSongDetailView(song: song)) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "B22222").opacity(0.2))
                        .frame(width: 46, height: 46)
                    Image(systemName: "music.note")
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    if let num = song.songNumber, !num.isEmpty {
                        Text("#\(num) · \(song.scale)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(14)
            .background(Color.white.opacity(0.07))
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if service.canDeleteSong(song) {
                Button(role: .destructive) {
                    Task {
                        do { try await service.deleteSong(id: song.id) }
                        catch { toastMessage = error.localizedDescription }
                    }
                } label: {
                    Label("Delete Song", systemImage: "trash")
                }
            }
        }
    }
    
    private func pdfRow(_ pdf: CarolPdf) -> some View {
        Button { selectedPdf = pdf } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "FFB347").opacity(0.25))
                        .frame(width: 46, height: 46)
                    Image(systemName: "doc.richtext.fill")
                        .foregroundStyle(Color(hex: "FFB347"))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(pdf.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Tap to open PDF")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(14)
            .background(Color.white.opacity(0.07))
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if service.canDeletePdf(pdf) {
                Button(role: .destructive) {
                    Task {
                        do { try await service.deletePdf(id: pdf.id) }
                        catch { toastMessage = error.localizedDescription }
                    }
                } label: {
                    Label("Delete PDF", systemImage: "trash")
                }
            }
        }
    }
    
    private func legacySongRow(_ carol: ChristmasCarol) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.1)).frame(width: 46, height: 46)
                Image(systemName: "music.note").foregroundStyle(.white)
            }
            VStack(alignment: .leading) {
                Text(carol.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                Text("Legacy").font(.caption).foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.35))
        }
        .padding(14)
        .background(Color.white.opacity(0.07))
        .cornerRadius(14)
    }
    
    private func legacyPdfRow(_ carol: ChristmasCarol) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color(hex: "FFB347").opacity(0.25)).frame(width: 46, height: 46)
                Image(systemName: "doc.richtext.fill").foregroundStyle(Color(hex: "FFB347"))
            }
            VStack(alignment: .leading) {
                Text(carol.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                Text("Legacy PDF").font(.caption).foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.07))
        .cornerRadius(14)
    }
    
    private func emptyState(message: String, actionTitle: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 14) {
            Spacer()
            Text(message).foregroundStyle(.white.opacity(0.7))
            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "B22222"))
            Spacer()
        }
    }
}
