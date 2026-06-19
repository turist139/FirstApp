import SwiftUI
import SwiftData

struct ProfileSelectionMenu: View {
    var profilesQuery: [DetoxProfile]
    var activeProfile: DetoxProfile?
    @Bindable var progress: UserProgress
    @Environment(\.modelContext) private var modelContext
    var defaultTitle: String
    var showCreateProfileOption: Bool = false
    @Binding var showCreateProfile: Bool

    var body: some View {
        Menu {
            ForEach(profilesQuery) { profile in
                Button {
                    progress.activeProfileId = profile.id
                    try? modelContext.save()
                } label: {
                    HStack {
                        Text(profile.name)
                        if let activeId = activeProfile?.id, profile.id == activeId {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            if showCreateProfileOption {
                Divider()
                Button {
                    showCreateProfile = true
                } label: {
                    Label("Новый Детокс", systemImage: "plus")
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: activeProfile?.icon ?? "flame.fill")
                Text(activeProfile?.name ?? defaultTitle)
                    .font(.title3.bold())
                Image(systemName: "chevron.down")
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.5))
            }
            .foregroundColor(.white)
        }
    }
}
