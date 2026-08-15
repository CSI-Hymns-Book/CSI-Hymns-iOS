import SwiftUI

/// Full changelog browser reading bundled `changelog.json` (Android `ChangelogScreen` parity).
public struct ChangelogListView: View {
    @State private var theme = ThemeManager.shared
    @State private var entries: [ChangelogRelease] = []
    @State private var isLoading = true
    
    public init() {}
    
    public var body: some View {
        ZStack {
            theme.backgroundColor.ignoresSafeArea()
            if theme.activeTheme != .amoled {
                theme.backgroundGradient.ignoresSafeArea()
            }
            
            if isLoading {
                ProgressView()
                    .tint(theme.accentColor)
            } else if entries.isEmpty {
                Text("No changelog entries found.")
                    .foregroundColor(theme.textSecondary)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(entries) { entry in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(entry.title)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(theme.textPrimary)
                                
                                Text("Version: \(entry.version)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(theme.textPrimary)
                                
                                Text("Date: \(entry.date)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(theme.textSecondary)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(entry.changes, id: \.self) { change in
                                        Text("• \(change)")
                                            .font(.system(size: 13))
                                            .foregroundColor(theme.textSecondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                .padding(.top, 4)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(theme.cardBackground)
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(theme.cardStroke, lineWidth: 1)
                            )
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("Changelog")
        .navigationBarTitleDisplayMode(.inline)
        .csiGlassNavigationBar(theme: theme)
        .toolbar(.hidden, for: .tabBar)
        .onAppear { loadChangelog() }
    }
    
    private func loadChangelog() {
        defer { isLoading = false }
        guard let url = Bundle.main.url(forResource: "changelog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([ChangelogRelease].self, from: data) else {
            entries = []
            return
        }
        entries = decoded
    }
}
