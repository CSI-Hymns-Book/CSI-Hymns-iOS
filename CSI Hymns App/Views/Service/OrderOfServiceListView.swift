import SwiftUI

/// Core Page structure for liturgies downloaded from remote JSON.
public struct OrderPage: Codable, Identifiable, Hashable, Sendable {
    public var id: Int { pageNo }
    public let pageNo: Int
    public let title: String?
    public let content: String
    public let type: String // 'regular' or 'festival'
}

/// A premium, glassmorphic liturgy browser listing Regular Sunday and Festival service guides.
public struct OrderOfServiceListView: View {
    @State private var showEnglishPrimary = true
    @State private var isRefreshing = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // Deep liquid glass gradient background
                LinearGradient(
                    colors: [Color(hex: "0D1B2A"), Color(hex: "132237"), Color(hex: "0D1B2A")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible())], spacing: 18) {
                            // Regular Sunday card
                            orderCard(
                                englishTitle: "Regular Sunday – Order of Service",
                                kannadaTitle: "ಭಾನುವಾರದ ದೇವರಾರಾಧನೆ",
                                gradientColors: [Color(hex: "FFC66A"), Color(hex: "FFD48C")],
                                readerType: "regular"
                            )
                            
                            // Festival card
                            orderCard(
                                englishTitle: "Festival – Order of Service",
                                kannadaTitle: "ಹಬ್ಬದ ಆರಾಧನೆ",
                                gradientColors: [Color(hex: "BCEBFF"), Color(hex: "D7F4FF")],
                                readerType: "festival"
                            )
                        }
                        .padding(.top, 16)
                    }
                    
                    // Refresh Button
                    Button {
                        Task {
                            await refreshLiturgyCaches()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isRefreshing {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                Text("Refresh Liturgies")
                            }
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .cornerRadius(28)
                        .shadow(color: Color.black.opacity(0.2), radius: 10, y: 5)
                    }
                    .disabled(isRefreshing)
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("ಆರಾಧನಾ ಕ್ರಮ / Liturgies")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                startTitleAlternatingTimer()
            }
        }
    }
    
    // MARK: - Subviews
    
    private func orderCard(
        englishTitle: String,
        kannadaTitle: String,
        gradientColors: [Color],
        readerType: String
    ) -> some View {
        NavigationLink(destination: OrderOfServiceReaderView(type: readerType, title: englishTitle)) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(showEnglishPrimary ? englishTitle : kannadaTitle)
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .animation(.easeInOut(duration: 0.4), value: showEnglishPrimary)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 44, height: 44)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
                    
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                }
            }
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomRight
                        )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Timer & Caches
    
    private func startTitleAlternatingTimer() {
        // Toggle language title display periodically to match legacy animations
        Timer.scheduledTimer(withTimeInterval: 4.5, repeats: true) { _ in
            withAnimation {
                showEnglishPrimary.toggle()
            }
        }
    }
    
    private func refreshLiturgyCaches() async {
        isRefreshing = true
        let url = URL(string: "https://raw.githubusercontent.com/Reynold29/csi-hymns-vault/refs/heads/main/order-of-service_data.json")!
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            // Save payload to local defaults cache
            UserDefaults.standard.set(data, forKey: "csi_cached_liturgies_json")
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } catch {
            print("OrderOfServiceListView: Remote updates failed: \(error)")
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
        
        isRefreshing = false
    }
}
