import SwiftUI
import SwiftData

struct MindfulnessHistoryView: View {
    @Query(sort: \MindfulnessSession.date, order: .reverse) private var sessions: [MindfulnessSession]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if sessions.isEmpty {
                    Text("У вас пока нет записей осознанности.")
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.top, 40)
                } else {
                    ForEach(sessions) { session in
                        sessionCard(session)
                    }
                }
            }
            .padding()
        }
        .withAmbientGlow()
        .navigationTitle("История")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
    
    private func sessionCard(_ session: MindfulnessSession) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(session.date, format: .dateTime.day().month().year().hour().minute())
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 10) {
                historySection(icon: "eye.fill", items: session.thingsSeen)
                historySection(icon: "ear", items: session.thingsHeard)
                historySection(icon: "hand.raised.fill", items: session.thingsFelt)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    private func historySection(icon: String, items: [String]) -> some View {
        HStack(alignment: .top) {
            Image(systemName: icon)
                .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.4))
                .frame(width: 24)
            
            Text(items.joined(separator: ", "))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}
