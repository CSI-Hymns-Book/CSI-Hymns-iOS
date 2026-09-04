import SwiftUI

#if canImport(GoogleCast)
import GoogleCast
#endif

/// Cast control sheet showing song title, connection status, and disconnect (Android CastControlSheet parity).
public struct CastControlSheet: View {
    let songTitle: String
    @Environment(\.dismiss) private var dismiss
    @State private var theme = ThemeManager.shared
    @State private var castService = CastService.shared
    
    public init(songTitle: String) {
        self.songTitle = songTitle
    }
    
    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Cast audio")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                Text(songTitle)
                    .font(.system(size: 14))
                    .foregroundColor(theme.textSecondary)
                
                HStack(spacing: 12) {
                    Image(systemName: castService.isConnected ? "dot.radiowaves.left.and.right" : "airplayaudio")
                        .foregroundColor(theme.accentColor)
                    Text(castService.isConnected ? "Connected — ready to cast this song" : "Choose a Cast / AirPlay device")
                        .font(.system(size: 14))
                        .foregroundColor(theme.textPrimary)
                }
                
                CastButton(tint: theme.accentColor)
                    .frame(height: 36)
                    .frame(maxWidth: .infinity)
                
                AirPlayRoutePicker()
                    .frame(height: 36)
                    .frame(maxWidth: .infinity)
                
                if castService.isConnected {
                    Button(role: .destructive) {
                        castService.disconnect()
                    } label: {
                        Text("Disconnect")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
                
                Spacer()
            }
            .padding(20)
            .background(theme.backgroundColor.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
