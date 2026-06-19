import SwiftUI
import SwiftData
import Combine

struct ProfileDrawerView: View {
    var profiles: [DetoxProfile]
    var activeProfile: DetoxProfile?
    @Bindable var progress: UserProgress
    @Environment(\.modelContext) private var modelContext
    @Binding var isOpen: Bool
    @Binding var showCreateProfile: Bool
    
    @AppStorage("activePalette", store: .shared) private var activePalette: String = "default"
    var themeColor: Color {
        PaletteManager.shared.paletteColors[activePalette]?.first ?? .green
    }
    
    // Timer for live elapsed time updates
    @State private var now = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    @State private var profileToDelete: DetoxProfile? = nil
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Dimmed background
            if isOpen {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isOpen = false
                        }
                    }
                    .transition(.opacity)
            }
            
            // Drawer panel
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.title2)
                            .foregroundColor(themeColor)
                        Text("Мои Детоксы")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                    .padding(.bottom, 20)
                    
                    // Profiles list
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(profiles) { profile in
                                profileRow(profile)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    Spacer()
                    
                    // Add new button
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isOpen = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showCreateProfile = true
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                            Text("Новый Детокс")
                                .font(.subheadline.bold())
                        }
                        .foregroundColor(themeColor)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(themeColor.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(themeColor.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
                .frame(width: 280)
                .background(
                    ZStack {
                        Color(red: 0.08, green: 0.08, blue: 0.1)
                        
                        // Subtle gradient at the bottom
                        LinearGradient(
                            colors: [themeColor.opacity(0.05), .clear],
                            startPoint: .bottom,
                            endPoint: .center
                        )
                    }
                    .ignoresSafeArea()
                )
                .offset(x: isOpen ? 0 : -300)
                
                Spacer()
            }
        }
        .onReceive(timer) { _ in
            now = Date()
        }
        .alert("Удалить детокс?", isPresented: $showDeleteConfirmation, presenting: profileToDelete) { targetProfile in
            Button("Удалить", role: .destructive) {
                // If it's active, maybe switch to another one or nil
                if progress.activeProfileId == targetProfile.id {
                    let other = profiles.first(where: { $0.id != targetProfile.id })
                    progress.activeProfileId = other?.id
                }
                modelContext.delete(targetProfile)
                try? modelContext.save()
            }
            Button("Отмена", role: .cancel) {}
        } message: { targetProfile in
            Text("Вы уверены, что хотите удалить профиль «\(targetProfile.name)»? Это действие нельзя отменить.")
        }
    }
    
    @ViewBuilder
    private func profileRow(_ profile: DetoxProfile) -> some View {
        let isActive: Bool = {
            guard let activeId = activeProfile?.id else { return false }
            return profile.id == activeId
        }()
        
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(isActive ? themeColor.opacity(0.2) : Color.white.opacity(0.07))
                    .frame(width: 44, height: 44)
                
                Image(systemName: profile.icon)
                    .font(.system(size: 18))
                    .foregroundColor(isActive ? themeColor : .white.opacity(0.6))
            }
            
            // Name + elapsed time
            VStack(alignment: .leading, spacing: 3) {
                Text(profile.name)
                    .font(.subheadline.bold())
                    .foregroundColor(isActive ? .white : .white.opacity(0.8))
                
                Text(elapsedTimeString(for: profile))
                    .font(.caption)
                    .foregroundColor(isActive ? themeColor.opacity(0.8) : .white.opacity(0.4))
            }
            
            Spacer()
            
            // Active indicator
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(themeColor)
                    .font(.body)
            }
            
            // Delete button
            Button(action: {
                profileToDelete = profile
                showDeleteConfirmation = true
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red.opacity(0.8))
                    .font(.body)
                    .padding(8)
                    .background(Color.white.opacity(0.001)) // Make tap target bigger
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isActive ? themeColor.opacity(0.08) : Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isActive ? themeColor.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            progress.activeProfileId = profile.id
            try? modelContext.save()
            withAnimation(.easeInOut(duration: 0.25)) {
                isOpen = false
            }
        }
    }
    
    // MARK: - Time formatting
    
    private func elapsedTimeString(for profile: DetoxProfile) -> String {
        let start = profile.streakStartDate ?? profile.lastCheckInDate ?? profile.creationDate
        let interval = now.timeIntervalSince(start)
        let hours = Int(interval / 3600)
        
        if hours >= 24 && profile.currentStreakDays > 0 {
            return "\(profile.currentStreakDays) д."
        } else {
            if interval < 0 { return "только что" }
            
            let seconds = Int(interval)
            let minutes = seconds / 60
            let hoursCount = minutes / 60
            
            if hoursCount > 0 {
                let remainingMinutes = minutes % 60
                if remainingMinutes > 0 {
                    return "\(hoursCount) ч. \(remainingMinutes) мин."
                }
                return "\(hoursCount) ч."
            }
            if minutes > 0 {
                return "\(minutes) мин."
            }
            return "\(seconds) сек."
        }
    }
}
