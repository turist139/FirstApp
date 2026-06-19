import SwiftUI
import SwiftData

struct MotivationContainerView: View {
    @ObservedObject var settings = MotivationSettings.shared
    
    @Query private var progressQuery: [UserProgress]
    @Query private var profilesQuery: [DetoxProfile]
    
    var progress: UserProgress {
        progressQuery.first ?? UserProgress()
    }
    
    var activeProfile: DetoxProfile? {
        let activeId = progress.activeProfileId
        return profilesQuery.first(where: { $0.id == activeId }) ?? profilesQuery.first
    }
    
    @State private var showProfileDrawer = false
    @State private var showCreateProfile = false
    @State private var showEditSheet = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                if settings.hasCompletedOnboarding {
                    MotivationDashboardView {
                        showEditSheet = true
                    }
                } else {
                    MotivationOnboardingView()
                }
            }
            .task(id: activeProfile?.id) {
                settings.loadForProfile(id: activeProfile?.id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showProfileDrawer = true
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: activeProfile?.icon ?? "flame.fill")
                            Text(activeProfile?.name ?? "Смыслы")
                                .font(.title3.bold())
                            Image(systemName: "chevron.down")
                                .font(.caption.bold())
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .foregroundColor(.white)
                    }
                }
            }
        }
        .overlay {
            ProfileDrawerView(
                profiles: Array(profilesQuery),
                activeProfile: activeProfile,
                progress: progress,
                isOpen: $showProfileDrawer,
                showCreateProfile: $showCreateProfile
            )
            .animation(.easeInOut(duration: 0.25), value: showProfileDrawer)
        }
        .sheet(isPresented: $showCreateProfile) {
            CreateProfileView(progress: progress)
        }
        .sheet(isPresented: $showEditSheet) {
            MotivationEditView()
        }
        .withSOSToolbar(enabled: settings.hasCompletedOnboarding)
    }
}
