import SwiftUI

struct MotivationContainerView: View {
    @ObservedObject var settings = MotivationSettings.shared
    
    var body: some View {
        if settings.hasCompletedOnboarding {
            MotivationDashboardView()
        } else {
            MotivationOnboardingView()
        }
    }
}
